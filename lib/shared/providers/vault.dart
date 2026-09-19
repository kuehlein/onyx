import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  /// Persist [source] as the content root, activate it, and re-index. This is
  /// the one-call path used by onboarding + the Settings folder picker (write
  /// through [VaultRefStore], flip the in-memory state, drop the stale index).
  Future<void> choose(VaultRef source) async {
    await VaultRefStore(ref.read(preferencesRepositoryProvider)).save(source);
    state = source;
    ref.invalidate(vaultIndexProvider);
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
