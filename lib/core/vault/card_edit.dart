/// In-app card creation + editing (task #28): the pure markdown-reconstruction
/// helpers that back the editor. The safety-critical rule (docs/content-creation)
/// is that **editing must never lose or corrupt a card's frontmatter** — its
/// `id`/`type`/`deck`/`status`/`created`/`confidence`/`priority`/`tiers`/… . So
/// on edit we PRESERVE the frontmatter block verbatim and rewrite only the H1
/// title + body; we never re-emit the whole frontmatter from parsed fields (that
/// would silently drop any field the model doesn't round-trip).
///
/// Pure (no I/O): the save/create/delete service (below) wraps these with a
/// [VaultSource], so both layers are unit-testable against a temp desktop source.
library;

import 'vault_source.dart';

/// Frontmatter block: a leading `---` line, YAML, then a closing `---` line.
/// Group 1 is the YAML, group 2 the body — the SAME shape [CardParser] uses, so
/// what we preserve is exactly what it will read back.
final RegExp _frontmatter =
    RegExp(r'^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?(.*)$', dotAll: true);

/// A top-level (unindented) `key:` line inside the frontmatter — the boundary
/// that ends a block-list value. e.g. `deck: x`, `status: draft`, `tiers:`.
final RegExp _topLevelKey = RegExp(r'^[A-Za-z0-9_-]+[ \t]*:');

/// The `tags:` line itself (top-level, case-sensitive — frontmatter keys are).
final RegExp _tagsKey = RegExp(r'^tags[ \t]*:');

/// Rebuilds a card's markdown for an EDIT, preserving its frontmatter.
///
/// Extracts the frontmatter YAML (g1) via the same regex [CardParser] uses; if
/// the source has no frontmatter it throws — an edit path must never invent one.
/// The returned file is `---\n<YAML>\n---\n\n# <title>\n\n<body>\n` with exactly
/// one trailing newline; [body] is the raw markdown that follows the H1 (the
/// overview + `## ` sections as the user typed them).
///
/// When [tags] is non-null it edits ONLY the tags within the otherwise-verbatim
/// YAML, via [_replaceTags] (handles both flow and block forms). When null the
/// frontmatter is left entirely byte-for-byte.
String rebuildCardMarkdown(
  String rawExisting, {
  required String title,
  required String body,
  List<String>? tags,
}) {
  final match = _frontmatter.firstMatch(rawExisting);
  if (match == null) {
    throw const FormatException(
      'Cannot edit a card without frontmatter — the file has no `---` block.',
    );
  }
  final yaml = match.group(1)!;
  final preserved = tags == null ? yaml : _replaceTags(yaml, tags);
  return _assemble(preserved, title: title, body: body);
}

/// Fresh markdown for a hand-authored card (CREATE).
///
/// Hand-authored cards are the user's own, trusted content, so they enter as
/// `status: active` — NOT `draft` (unlike an import/AI-generation, which needs
/// the review gate). `deck:` is written only when [deckId] is non-empty (local
/// content has no deck). Tags are a flow list the parser reads back intact.
String newCardMarkdown({
  required String id,
  String type = 'flashcard',
  required String title,
  required String body,
  List<String> tags = const [],
  String? deckId,
}) {
  final buffer = StringBuffer()
    ..writeln('id: ${_scalar(id)}')
    ..writeln('type: ${_scalar(type)}')
    ..writeln('status: active');
  if (deckId != null && deckId.isNotEmpty) {
    buffer.writeln('deck: ${_scalar(deckId)}');
  }
  buffer.write('tags: ${_flowList(tags)}');
  return _assemble(buffer.toString(), title: title, body: body);
}

/// Joins a (preserved or fresh) YAML block with the H1 + body into a full card
/// file with exactly one trailing newline. The body is emitted verbatim (its own
/// internal blank lines untouched); we only normalize the leading/trailing gaps
/// around it so the parser's `# Title\n\n<body>` shape always holds.
String _assemble(String yaml, {required String title, required String body}) {
  final trimmedBody = body.trim();
  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln(yaml)
    ..writeln('---')
    ..writeln()
    ..write('# ${title.trim()}')
    ..write('\n');
  if (trimmedBody.isNotEmpty) {
    buffer
      ..write('\n')
      ..write(trimmedBody)
      ..write('\n');
  }
  return buffer.toString();
}

/// Replaces the `tags:` value within [yaml] with a single flow line
/// `tags: [ "a", "b" ]`, leaving every other frontmatter line byte-for-byte.
///
/// Handles BOTH YAML forms safely:
///  * flow — `tags: [a, b]` (a single line), and
///  * block — `tags:` followed by indented `  - a` / `  - b` lines.
///
/// The span to replace is the `tags:` line plus any immediately-following lines
/// that are indented or list items (`  ` / `- `), up to the next top-level
/// `key:` line or the end of the frontmatter. Only that span changes; a trailing
/// key like `deck:` right after a block list is preserved intact. If there is no
/// `tags:` key at all, the new flow line is appended (so a tag edit still lands).
String _replaceTags(String yaml, List<String> tags) {
  final lines = yaml.split('\n');
  final flow = 'tags: ${_flowList(tags)}';

  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (_tagsKey.hasMatch(lines[i])) {
      start = i;
      break;
    }
  }
  if (start == -1) {
    // No tags key present — append the flow line rather than corrupt anything.
    return yaml.isEmpty ? flow : '$yaml\n$flow';
  }

  // Absorb the block-list body: contiguous following lines that are indented
  // (leading space/tab) or a list item (`-`), i.e. NOT a new top-level key.
  var end = start + 1;
  while (end < lines.length) {
    final line = lines[end];
    if (line.isEmpty) break; // a blank line ends the value
    if (_topLevelKey.hasMatch(line)) break; // next top-level key
    final isIndented = line.startsWith(' ') || line.startsWith('\t');
    final isListItem = line.trimLeft().startsWith('-');
    if (!isIndented && !isListItem) break;
    end++;
  }

  final rebuilt = [...lines.sublist(0, start), flow, ...lines.sublist(end)];
  return rebuilt.join('\n');
}

/// A YAML flow-sequence the parser accepts (`_stringList` reads a `YamlList`),
/// e.g. `[ "tcp", "networking" ]`, or `[]` when empty. Values are double-quoted
/// so a tag carrying YAML-special characters round-trips intact.
String _flowList(List<String> tags) =>
    tags.isEmpty ? '[]' : '[ ${tags.map(_scalar).join(', ')} ]';

/// A double-quoted YAML scalar so a value carrying YAML-special characters (`#`,
/// `:`, leading `-`, etc.) round-trips intact rather than being reinterpreted.
/// (Mirrors generated_cards.dart / import_deck.dart — each write path keeps its
/// own tiny helper so none depends on another's private internals.)
String _scalar(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Lowercases and collapses every run of non-alphanumerics to a single hyphen,
/// trimming leading/trailing hyphens — a filesystem-safe slug for a new card's
/// filename + id. (Matches `CardParser.slugify`'s rule.)
String slugifyTitle(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

// ── Save / create / delete service ───────────────────────────────────────────
// Provider-free (a [VaultSource] in) so the file layer is unit-testable. The UI
// calls these then `ref.invalidate(vaultIndexProvider)` to re-index.

/// Saves an EDIT to an existing card: re-reads its raw file, rebuilds the
/// markdown preserving frontmatter (title/body rewritten; tags edited only when
/// non-null), and writes back to the SAME path — so `id`/`status`/`deck` are all
/// preserved (a draft stays a draft, so the review gate's Edit works).
Future<void> saveCardEdit(
  VaultSource source,
  String filePath, {
  required String title,
  required String body,
  List<String>? tags,
}) async {
  final raw = await source.readCard(filePath);
  final rebuilt =
      rebuildCardMarkdown(raw, title: title, body: body, tags: tags);
  await source.writeFile(filePath, rebuilt);
}

/// Creates a new hand-authored card at the vault ROOT as `<slug>.md`, where the
/// slug (also the frontmatter `id`) is derived from [title] and de-duped against
/// existing card paths (suffix `-2`, `-3`, … when `<slug>.md` already exists).
/// Returns the new card's relative path. Enters as `status: active` (trusted).
Future<String> createCard(
  VaultSource source, {
  required String title,
  required String body,
  List<String> tags = const [],
}) async {
  final existing = (await source.listCardPaths()).toSet();
  final base = slugifyTitle(title);
  final root = base.isEmpty ? 'card' : base;
  var slug = root;
  var n = 2;
  while (existing.contains('$slug.md')) {
    slug = '$root-$n';
    n++;
  }
  final path = '$slug.md';
  await source.writeFile(
    path,
    newCardMarkdown(id: slug, title: title, body: body, tags: tags),
  );
  return path;
}

/// Deletes the card file at [filePath] (POSIX, relative to the vault root).
Future<void> deleteCardFile(VaultSource source, String filePath) =>
    source.deleteFile(filePath);
