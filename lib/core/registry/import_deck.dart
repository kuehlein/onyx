import '../vault/vault_source.dart';
import 'deck.dart';

/// Writes a pulled [DeckManifest]'s cards into the study folder as **drafts**.
///
/// This is the content half of a registry pull (docs/registry-and-sync.md §3.4 /
/// §4.3). Every card is written under `<deckSlug>/<cardSlug>.md` with:
///
///  * `deck: <manifest.deckId>` — so its future FSRS state is namespaced by deck
///    (`(deckId, cardId, sectionSlug)`) and can't collide with a local card;
///  * `status: draft` — so it enters excluded from scheduling AND every readiness
///    denominator (it reads as FRESH; scheduling never travels). The manifest has
///    no SRS/review data to carry in the first place — that's structural.
///
/// Drafts are shown in Browse (marked "Draft") but are NOT studiable yet: there
/// is no promote gate built. Returns the number of cards written.
///
/// Pure-ish: takes a [VaultSource] and no provider/Riverpod deps, so it's
/// unit-testable against a temp desktop source.
Future<int> importDeck(VaultSource source, DeckManifest manifest) async {
  final deckSlug = _slugify(manifest.deckId);
  var written = 0;
  for (final card in manifest.cards) {
    final path = '$deckSlug/${_slugify(card.id)}.md';
    await source.writeFile(path, _cardMarkdown(manifest.deckId, card));
    written++;
  }
  return written;
}

/// The exact on-disk shape of an imported card. Mirrors an existing card's shape
/// (a `---` frontmatter block with `id`/`type`, an H1, then `## ` sections) so
/// `CardParser` reads it back; adds `deck:` and `status: draft`.
String _cardMarkdown(String deckId, DeckCard card) {
  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('id: ${_scalar(card.id)}')
    ..writeln('type: ${_scalar(card.type)}')
    ..writeln('deck: ${_scalar(deckId)}')
    ..writeln('status: draft')
    ..writeln('tags: ${_flowList(card.tags)}')
    ..writeln('---')
    ..writeln()
    ..writeln('# ${_oneLine(card.title)}')
    ..writeln();
  buffer.write(card.body);
  if (!card.body.endsWith('\n')) buffer.writeln();
  return buffer.toString();
}

/// A YAML flow-sequence the parser accepts (`_stringList` reads a `YamlList`),
/// e.g. `["geography", "capitals"]`, or `[]` when empty.
String _flowList(List<String> tags) => '[${tags.map(_scalar).join(', ')}]';

/// Collapses internal line breaks (and surrounding whitespace) to a single space
/// so a card title written into a one-line `#` markdown heading can't split the
/// line and corrupt the card on re-parse (the H1 regex is single-line).
String _oneLine(String value) =>
    value.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

/// A double-quoted YAML scalar for a frontmatter value, so a string carrying
/// YAML-special characters (`#`, `:`, leading `-`, etc.) round-trips intact
/// rather than being truncated or reinterpreted. Real registry ids are
/// deck-prefixed slugs (already safe); quoting defends against messier inputs.
String _scalar(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Lowercases and collapses every run of non-alphanumerics to a single hyphen,
/// trimming leading/trailing hyphens — a filesystem-safe slug for the deck folder
/// and card filename. (Matches `CardParser.slugify`'s rule.)
String _slugify(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
