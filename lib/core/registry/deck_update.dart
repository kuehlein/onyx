import '../vault/vault_source.dart';
import 'deck.dart';
import 'import_deck.dart';

/// The result of reconciling a freshly re-pulled deck against the previous pull —
/// the **content rule** for upstream updates (registry-and-sync.md §3.4/§4.3):
/// *nothing mutates silently into FSRS.* Added + changed files re-enter through
/// the **draft gate** (written via `importDeck` → `status: draft`, so they're
/// excluded from scheduling + readiness until the learner re-earns them); removed
/// files are **preserved** — a tombstone, never a silent delete of your history.
///
/// This owns only the content policy; the propagation WIRE (how a maintainer's
/// push reaches a subscriber) and the harder §10.9 change grading (a text tweak
/// keeping the schedule vs a meaning change becoming a new `sectionSlug`) live
/// with the real server and are deferred — here, any content difference re-drafts.
class DeckUpdate {
  const DeckUpdate({
    required this.added,
    required this.changed,
    required this.removed,
  });

  /// Files present upstream now but not before.
  final List<DeckFile> added;

  /// Files whose content changed upstream (same relative path, different bytes).
  final List<DeckFile> changed;

  /// Relative paths present before but gone upstream — tombstoned, not deleted.
  final List<String> removed;

  bool get isEmpty => added.isEmpty && changed.isEmpty && removed.isEmpty;

  /// The files to (re)write through the draft gate: added ∪ changed.
  List<DeckFile> get drafts => [...added, ...changed];
}

/// Diffs a freshly-pulled [incoming] deck against the [previous] pull (both raw
/// upstream payloads) by relative path. Pure.
DeckUpdate reconcileDeckUpdate(DeckManifest previous, DeckManifest incoming) {
  final before = {for (final f in previous.files) f.path: f.content};
  final added = <DeckFile>[];
  final changed = <DeckFile>[];
  for (final f in incoming.files) {
    final prior = before[f.path];
    if (prior == null) {
      added.add(f);
    } else if (prior != f.content) {
      changed.add(f);
    }
  }
  final incomingPaths = {for (final f in incoming.files) f.path};
  final removed = [
    for (final f in previous.files)
      if (!incomingPaths.contains(f.path)) f.path,
  ];
  return DeckUpdate(added: added, changed: changed, removed: removed);
}

/// Applies [update] into the vault: added + changed files are (re)written under
/// the deck folder as **drafts** (via [importDeck], which stamps `status: draft`
/// and overwrites a changed card in place — so even a locally-promoted card stops
/// counting until re-reviewed). Removed files are left untouched (tombstone).
/// Returns the number of files (re)entered as drafts.
Future<int> applyDeckUpdate(
  VaultSource source,
  DeckManifest incoming,
  DeckUpdate update,
) {
  if (update.drafts.isEmpty) return Future.value(0);
  return importDeck(
    source,
    DeckManifest(
      deckId: incoming.deckId,
      name: incoming.name,
      author: incoming.author,
      license: incoming.license,
      files: update.drafts,
    ),
  );
}
