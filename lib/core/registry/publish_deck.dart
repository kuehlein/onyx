import 'dart:convert';

import '../../shared/models/card.dart';
import '../query/card_query.dart';
import '../vault/vault_source.dart';
import 'deck.dart';

/// Builds a content-only [DeckManifest] from local card files for publishing —
/// the inverse of `importDeck` (docs/registry-and-sync.md §4). Reads each
/// selected card's RAW file verbatim and keeps its path relative to [rootPrefix],
/// so the exporter's folder STRUCTURE travels intact.
///
/// v1 callers pass the files of a directory/subtree (the folder lens); a
/// cross-cutting query-lens export is a later advanced option and will preserve
/// paths the same way. Content-only: SRS is never in files, and the importer
/// re-stamps `status: draft`, so scheduling never travels.
Future<DeckManifest> buildDeckManifest({
  required VaultSource source,
  required String deckId,
  required String name,
  required String author,
  required List<String> cardPaths,
  String? license,
  String rootPrefix = '',
}) async {
  final files = <DeckFile>[];
  for (final path in cardPaths) {
    files.add(DeckFile(
      path: _relativize(path, rootPrefix),
      content: await source.readCard(path),
    ));
  }
  return DeckManifest(
    deckId: deckId,
    name: name,
    author: author,
    license: license,
    files: files,
  );
}

/// The distinct folders (at any depth) that hold at least one card — the pickable
/// export subtrees for the publish flow. Root-level cards contribute no folder;
/// offer "whole study folder" (an empty prefix, [buildFolderDeck] with `''`)
/// alongside these.
List<String> publishableFolders(Iterable<Card> cards) {
  final dirs = <String>{};
  for (final c in cards) {
    final segs = c.filePath.split('/');
    for (var i = 1; i < segs.length; i++) {
      dirs.add(segs.take(i).join('/'));
    }
  }
  return dirs.toList()..sort();
}

/// Builds a deck from the cards under [folder] — the **folder lens** (v1 export
/// unit; a cross-cutting query lens is a later advanced option). Paths are made
/// relative to [folder] so the deck arrives cleanly under its own directory. An
/// empty [folder] exports the whole vault.
Future<DeckManifest> buildFolderDeck({
  required VaultSource source,
  required Iterable<Card> cards,
  required String folder,
  required String deckId,
  required String name,
  required String author,
  String? license,
}) {
  final lens = FolderUnder(folder);
  return buildDeckManifest(
    source: source,
    deckId: deckId,
    name: name,
    author: author,
    license: license,
    cardPaths: [
      for (final c in cards)
        if (lens.matches(c)) c.filePath
    ],
    rootPrefix: folder,
  );
}

/// Strips [rootPrefix] (a folder being exported) from [path] so the deck's paths
/// are relative to it — exporting `people/` yields `caesar.md`, not
/// `people/caesar.md`, so the deck arrives cleanly under its own folder.
String _relativize(String path, String rootPrefix) {
  if (rootPrefix.isEmpty) return path;
  final prefix = rootPrefix.endsWith('/') ? rootPrefix : '$rootPrefix/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

// ── abuse guard (push boundary) ──────────────────────────────────────────────
// Reserved to keep malicious / illegal / huge content out of the registry
// (user requirement). Limits are deliberately generous and TBD — tightened when
// the real server lands; UTF-8 validity is guaranteed upstream by the text read.

/// Max size of a single file in a published deck (TBD).
const kMaxDeckFileBytes = 256 * 1024;

/// Max total size of a published deck (TBD).
const kMaxDeckTotalBytes = 8 * 1024 * 1024;

/// Returns a human-readable reason the [manifest] can't be published (a file or
/// the whole deck exceeds the size caps), or null when it's acceptable. Checked
/// at the push boundary before handing off to [RegistryClient.publishDeck].
String? deckPayloadIssue(DeckManifest manifest) {
  var total = 0;
  for (final f in manifest.files) {
    final bytes = utf8.encode(f.content).length;
    if (bytes > kMaxDeckFileBytes) {
      return '"${f.path}" is too large '
          '(${_kib(bytes)} KiB; max ${_kib(kMaxDeckFileBytes)} KiB).';
    }
    total += bytes;
  }
  if (total > kMaxDeckTotalBytes) {
    return 'This deck is too large '
        '(${_kib(total)} KiB; max ${_kib(kMaxDeckTotalBytes)} KiB).';
  }
  return null;
}

int _kib(int bytes) => (bytes / 1024).ceil();
