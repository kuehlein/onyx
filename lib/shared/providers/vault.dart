import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/backup/snapshot.dart';
import '../../core/vault/desktop_vault_source.dart';
import '../../core/vault/folder_picker.dart';
import '../../core/vault/vault_indexer.dart';
import '../../core/vault/vault_ref.dart';
import '../../core/vault/vault_ref_store.dart';
import '../../core/vault/vault_source.dart';
import 'database.dart';
import 'settings.dart';
import 'subject.dart';

part 'vault.g.dart';

/// Holds the current on-device content-source [VaultRef] in memory. Seeded from
/// persistence at startup by [loadVaultRef], and updated when the user picks or
/// creates a folder. Kept separate from [vaultSource] so that provider stays a
/// sync function (env → this ref → null) — preserving its many sync consumers and
/// the `overrideWithValue` test seams. See ADR-0002.
@Riverpod(keepAlive: true)
class VaultRefController extends _$VaultRefController {
  @override
  VaultRef? build() => null;

  /// Set (or clear) the active ref. Callers that want it to persist should also
  /// write it via [VaultRefStore] and invalidate [vaultIndexProvider].
  void set(VaultRef? ref) => state = ref;

  /// Persist [source] as the content root, activate it, and re-index — the
  /// one-call path used by onboarding + the Settings folder picker.
  ///
  /// Switching folders is data-safe: the local DB is a derived cache of ONE
  /// folder at a time (ADR-0001/0002 — each folder's `_meta` snapshot is its
  /// durable copy). So on a real switch we (1) export the outgoing folder's
  /// progress to its own snapshot, (2) clear the cache, then (3) restore the
  /// incoming folder's snapshot — the incoming folder resumes its own progress
  /// and nothing in the outgoing folder is lost.
  Future<void> choose(VaultRef source) async {
    final db = ref.read(appDatabaseProvider);
    final prev = state;
    final isSwitch = prev != null && prev.encode() != source.encode();

    if (isSwitch) {
      final prevSource = _tryResolve(prev);
      if (prevSource != null) {
        try {
          await SnapshotService(db, prevSource).export();
        } catch (_) {
          // Best-effort: an unwritable/missing old folder must not block the swap.
        }
      }
      await SnapshotService.clearProgress(db);
    }

    await VaultRefStore(ref.read(preferencesRepositoryProvider)).save(source);
    state = source;

    // Restore the incoming folder's snapshot into the (now-scoped) cache so its
    // schedule is live immediately, not only after the next launch. A missing or
    // malformed snapshot just means "start fresh here".
    final newSource = _tryResolve(source);
    if (newSource != null) {
      try {
        await SnapshotService(db, newSource).restore();
      } catch (_) {}
    }

    ref.invalidate(vaultIndexProvider);
  }

  /// Resolve a ref to a source, tolerating the not-yet-implemented mobile kinds
  /// (iosBookmark / androidTree throw [UnsupportedError]) so a swap still
  /// proceeds on those platforms once native picking is wired.
  VaultSource? _tryResolve(VaultRef r) {
    try {
      return resolveVaultSource(r);
    } on UnsupportedError {
      return null;
    }
  }
}

/// The current vault source, or null if none is configured yet.
///
/// Resolution order (ADR-0002): `ONYX_VAULT_PATH` (dev/desktop wins) → the
/// persisted on-device ref via [VaultRefController] → null.
@riverpod
VaultSource? vaultSource(Ref ref) {
  final envPath = Platform.environment['ONYX_VAULT_PATH'];
  if (envPath != null && envPath.isNotEmpty) {
    return DesktopVaultSource(envPath);
  }
  final vaultRef = ref.watch(vaultRefControllerProvider);
  return vaultRef == null ? null : resolveVaultSource(vaultRef);
}

/// Loads the persisted content-source ref into [VaultRefController] at startup
/// (no-op if none is saved, or if `ONYX_VAULT_PATH` overrides). Awaited by
/// `startupRestore` so the source resolves before the snapshot merge runs.
@Riverpod(keepAlive: true)
Future<void> loadVaultRef(Ref ref) async {
  final envPath = Platform.environment['ONYX_VAULT_PATH'];
  if (envPath != null && envPath.isNotEmpty) {
    return; // env wins; nothing to load
  }
  final store = VaultRefStore(ref.watch(preferencesRepositoryProvider));
  final saved = await store.load();
  if (saved != null) {
    ref.read(vaultRefControllerProvider.notifier).set(saved);
  }
}

/// The folder picker used by onboarding + Settings to choose/create a content
/// source. Overridable in tests/UI. See ADR-0002.
@riverpod
FolderPicker folderPicker(Ref ref) => const PlatformFolderPicker();

/// Indexes the vault and exposes the parsed cards plus diagnostic counts.
/// Re-run after edits or a re-sync with `ref.invalidate(vaultIndexProvider)`.
@riverpod
Future<IndexResult> vaultIndex(Ref ref) async {
  // Read the sync deps BEFORE the async gap — awaiting a provider future and then
  // touching `ref` risks a disposed-element error when an upstream re-settles.
  final source = ref.watch(vaultSourceProvider);
  final db = ref.watch(appDatabaseProvider);
  // Ensure the subject registry is loaded (activeSubject set) BEFORE parsing — the
  // parser reads the flow definitions from each card's subject (#30 Phase 5 / #30d).
  final registry = await ref.watch(subjectRegistryProvider.future);
  if (source == null) {
    return const IndexResult(cards: [], idless: 0, malformed: 0, skipped: 0);
  }
  return VaultIndexer(source, db, registry: registry).reindex();
}

/// Dangling `[[wikilinks]]` grouped by their missing target (task #20), most-
/// referenced first (ties broken alphabetically). Grouping by target is the
/// actionable unit: one note/file created with that name resolves every link to
/// it at the next re-index.
@riverpod
Future<List<({String target, List<UnresolvedLink> refs})>> unresolvedLinks(
  Ref ref,
) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final byTarget = <String, List<UnresolvedLink>>{};
  for (final link in index.unresolvedLinks) {
    (byTarget[link.target] ??= []).add(link);
  }
  final groups = [
    for (final e in byTarget.entries) (target: e.key, refs: e.value),
  ];
  groups.sort((a, b) {
    final byCount = b.refs.length.compareTo(a.refs.length);
    return byCount != 0 ? byCount : a.target.compareTo(b.target);
  });
  return groups;
}
