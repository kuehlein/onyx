import '../vault/vault_source.dart';
import 'deck.dart';

/// Writes a pulled [DeckManifest]'s files into the study folder as **drafts**,
/// preserving the deck's internal structure (docs/registry-and-sync.md §3.4/§4.3).
///
/// Each file lands at `<deckSlug>/<file.path>` — so the deck arrives as one
/// directory in the vault root, with the exporter's `people/`, `places/`,
/// `battles/` layout intact — and each **card** file is stamped:
///
///  * `deck: <manifest.deckId>` — namespacing its future FSRS state by deck
///    (`(deckId, cardId, sectionSlug)`) so it can't collide with a local card;
///  * `status: draft` — excluded from scheduling AND every readiness denominator
///    (it reads FRESH; scheduling never travels). SRS was never in the file.
///
/// A file with no frontmatter (not a card — a note/asset) is copied verbatim.
/// Returns the number of files written.
///
/// Pure-ish: takes a [VaultSource] and no provider deps, so it's unit-testable
/// against a temp desktop source.
Future<int> importDeck(VaultSource source, DeckManifest manifest) async {
  final deckSlug = _slugify(manifest.deckId);
  var written = 0;
  for (final file in manifest.files) {
    final path = '$deckSlug/${_normalizeRel(file.path)}';
    await source.writeFile(
        path, _stampedForImport(manifest.deckId, file.content));
    written++;
  }
  return written;
}

/// Frontmatter block: a leading `---` line, YAML, closing `---`. Group 1 is the
/// YAML, group 2 the body. (Same shape `CardParser` recognizes.)
final _frontmatter =
    RegExp(r'^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?(.*)$', dotAll: true);

/// Top-level `deck:`/`status:` frontmatter lines (no leading indent), which the
/// importer owns and must set — any incoming values are dropped.
final _deckOrStatus = RegExp(r'^(deck|status):');

/// Forces the two import invariants into a card file's frontmatter — the deck
/// namespace + `status: draft` — while preserving every other line and the whole
/// body verbatim. A file without frontmatter is returned unchanged (it's not a
/// card; it rides along as a note/asset).
String _stampedForImport(String deckId, String content) {
  final normalized = content.replaceAll('\r\n', '\n');
  final m = _frontmatter.firstMatch(normalized);
  if (m == null) return content; // not a card — copy verbatim
  final body = m.group(2) ?? '';
  final kept = m.group(1)!.split('\n').where((l) => !_deckOrStatus.hasMatch(l));
  final frontmatter =
      ['deck: ${_scalar(deckId)}', 'status: draft', ...kept].join('\n');
  return '---\n$frontmatter\n---\n$body';
}

/// A double-quoted YAML scalar for a frontmatter value, so a value with
/// YAML-special characters round-trips intact. Registry deck ids are slugs
/// (already safe); quoting defends against messier inputs.
String _scalar(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Normalizes a deck-relative path to safe POSIX: forward slashes, no leading
/// slash, and no `..` segments (a pulled deck can only ever write *inside* its
/// own `<deckSlug>/` folder — never escape the vault).
String _normalizeRel(String path) => path
    .replaceAll(r'\', '/')
    .split('/')
    .where((seg) => seg.isNotEmpty && seg != '.' && seg != '..')
    .join('/');

/// Lowercases and collapses non-alphanumerics to single hyphens (trimming ends)
/// — a filesystem-safe slug for the deck folder. (Matches `CardParser.slugify`.)
String _slugify(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
