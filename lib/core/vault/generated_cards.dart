import '../ai/card_generation.dart';
import 'vault_source.dart';

/// Writes an AI-generated [GeneratedBatch] into the study folder as **local
/// drafts** (docs/content-creation.md §2.2).
///
/// Each card is written under `<nameSlug>/<titleSlug>.md` with `status: draft`
/// and — deliberately — **no `deck:` field**. Generated cards are the learner's
/// own content, like hand-authored cards, so they live in the local (empty)
/// deck namespace; `draft` is what keeps them out of scheduling and every
/// readiness denominator until the learner promotes each through the review gate
/// (self-test-then-promote). Generation is the first retrieval rep, not finished
/// knowledge.
///
/// Filenames are slugified from the batch name + card title; within a single
/// batch a slug collision is de-duped by suffixing `-2`, `-3`, … so two cards
/// with the same title don't overwrite each other. The frontmatter `id` is the
/// deduped slug (a stable within-deck slug, per card-schema.md — not a device
/// UUID).
///
/// [sourceLabel] (the learner's paste/topic) is recorded as a trailing HTML
/// comment for light provenance (card_schema.md source-linkback seam); the card
/// parser ignores body comments, so it round-trips as a normal card.
///
/// Pure-ish: takes a [VaultSource] and no provider/Riverpod deps, so it's
/// unit-testable against a temp desktop source. Returns the number written.
Future<int> writeGeneratedCards(
  VaultSource source,
  GeneratedBatch batch, {
  String? sourceLabel,
}) async {
  final nameSlug = _slugify(batch.name);
  final folder = nameSlug.isEmpty ? 'generated' : nameSlug;
  final used = <String>{};
  var written = 0;
  for (final card in batch.cards) {
    final slug = _uniqueSlug(_slugify(card.title), used);
    final path = '$folder/$slug.md';
    await source.writeFile(path, _cardMarkdown(slug, card, sourceLabel));
    written++;
  }
  return written;
}

/// Ensures [base] is unique within [used], suffixing `-2`, `-3`, … on collision.
/// An empty base (a title that slugifies to nothing) falls back to `card`.
String _uniqueSlug(String base, Set<String> used) {
  final root = base.isEmpty ? 'card' : base;
  var slug = root;
  var n = 2;
  while (!used.add(slug)) {
    slug = '$root-$n';
    n++;
  }
  return slug;
}

/// The on-disk shape of a generated card: a `---` frontmatter block with
/// `id`/`type`/`status`/`tags` (NO `deck:` — local content), an H1 title, then
/// each `## ` section. Mirrors an existing card's shape so `CardParser` reads it
/// back as a draft in the local deck (`deckId == ''`).
String _cardMarkdown(
  String id,
  GeneratedCard card,
  String? sourceLabel,
) {
  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('id: ${_scalar(id)}')
    ..writeln('type: "flashcard"')
    ..writeln('status: draft')
    ..writeln('tags: ${_flowList(card.tags)}')
    ..writeln('---')
    ..writeln()
    ..writeln('# ${card.title}');
  for (final section in card.sections) {
    buffer
      ..writeln()
      ..writeln('## ${section.heading}')
      ..writeln()
      ..writeln(section.content);
  }
  final provenance = _provenance(sourceLabel);
  if (provenance != null) {
    buffer
      ..writeln()
      ..writeln(provenance);
  }
  return buffer.toString();
}

/// A one-line HTML-comment provenance marker, or null when there's no label.
/// Truncated so a long paste doesn't bloat the file; newlines flattened so the
/// comment stays a single line the parser skips as body text.
String? _provenance(String? sourceLabel) {
  final label = sourceLabel?.trim();
  if (label == null || label.isEmpty) return null;
  final flat = label.replaceAll(RegExp(r'\s+'), ' ');
  final clipped = flat.length > 120 ? '${flat.substring(0, 120)}…' : flat;
  // Guard against a stray comment-terminator in the user's text.
  final safe = clipped.replaceAll('-->', '— >');
  return '<!-- generated: $safe -->';
}

/// A YAML flow-sequence the parser accepts (`_stringList` reads a `YamlList`),
/// e.g. `["tcp", "networking"]`, or `[]` when empty.
String _flowList(List<String> tags) => '[${tags.map(_scalar).join(', ')}]';

/// A double-quoted YAML scalar so a value carrying YAML-special characters (`#`,
/// `:`, leading `-`, etc.) round-trips intact rather than being reinterpreted.
/// (Duplicated from import_deck.dart — the two write paths keep their own tiny
/// helpers so neither depends on the other's private internals.)
String _scalar(String value) =>
    '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

/// Lowercases and collapses every run of non-alphanumerics to a single hyphen,
/// trimming leading/trailing hyphens — a filesystem-safe slug for the folder and
/// card filename. (Matches `CardParser.slugify`'s rule.)
String _slugify(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
