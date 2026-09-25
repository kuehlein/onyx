/// The shared YAML/markdown serialization primitives for the card WRITE paths
/// (`card_edit` hand-authoring, `generated_cards` AI drafts, `import_deck` pulls).
///
/// These were three private copies (acknowledged debt) — one home now, so the
/// correctness-critical escaping rule lives in a single, tested place and a
/// quoting fix lands on every write path (ADR-0013 §Addendum, G4). Each helper's
/// output is byte-for-byte what its callers emitted before this extraction.
library;

/// A double-quoted YAML scalar so a value carrying YAML-special characters (`#`,
/// `:`, leading `-`, etc.) round-trips intact rather than being reinterpreted.
/// Backslashes and quotes are escaped.
String yamlScalar(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// A YAML flow-sequence the parser accepts (`_stringList` reads a `YamlList`),
/// e.g. `["tcp", "networking"]`, or `[]` when empty; values are quoted via
/// [yamlScalar]. [spaced] adds inner-bracket padding (`[ "a", "b" ]`) — the form
/// hand-authored cards use; generated drafts pass it false (the compact form).
String yamlFlowList(List<String> values, {bool spaced = false}) {
  if (values.isEmpty) return '[]';
  final inner = values.map(yamlScalar).join(', ');
  return spaced ? '[ $inner ]' : '[$inner]';
}

/// Collapses internal line breaks (and surrounding whitespace) to a single space
/// so a value written into a one-line `#` / `##` / frontmatter line can't split
/// the line and shift the parse on re-read (the H1/H2 regexes are single-line).
String oneLine(String value) =>
    value.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();

/// Lowercases and collapses every run of non-alphanumerics to a single hyphen,
/// trimming leading/trailing hyphens — a filesystem-safe slug for a card/folder
/// filename + id. (Matches `CardParser.slugify`'s rule.)
String slugify(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
