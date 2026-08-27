import '../vault/vault_source.dart';
import 'claude_service.dart';

/// All-caps acronyms of 2–6 chars (API, HTTP, DNSSEC, L2…). Used only to gather
/// candidates for the one-time AI draft of the glossary note — NOT at runtime.
final _acronymPattern = RegExp(r'\b[A-Z][A-Z0-9]{1,5}\b');

/// Obvious noise to skip before spending tokens; the AI filters the rest.
const _stopWords = {'OK', 'TODO', 'FIXME', 'NOTE', 'TIP', 'ETC', 'AKA'};

/// Distinct candidate acronyms found across [texts].
Set<String> detectGlossaryTerms(Iterable<String> texts) {
  final terms = <String>{};
  for (final text in texts) {
    for (final match in _acronymPattern.allMatches(text)) {
      final term = match[0]!;
      if (!_stopWords.contains(term)) terms.add(term);
    }
  }
  return terms;
}

/// GitHub/Obsidian-style heading slug: `Load Balancer` → `load-balancer`. Card
/// links use this as the anchor (`[API](_meta/glossary.md#api)`).
String glossarySlug(String heading) => heading
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

/// Parses a glossary Markdown note (`## Term` sections) into a `slug → definition`
/// map. The vault note is the single source of truth; this is a pure read.
Map<String, String> parseGlossaryNote(String markdown) {
  final entries = <String, String>{};
  final heading = RegExp(r'^##\s+(.+?)\s*$');
  String? slug;
  final buffer = <String>[];

  void flush() {
    final key = slug;
    if (key != null) {
      final definition = buffer.join('\n').trim();
      if (definition.isNotEmpty) entries[key] = definition;
    }
    buffer.clear();
  }

  for (final line in markdown.split('\n')) {
    final match = heading.firstMatch(line);
    if (match != null) {
      flush();
      slug = glossarySlug(match.group(1)!.trim());
    } else if (slug != null) {
      buffer.add(line);
    }
  }
  flush();
  return entries;
}

/// Reads the vault glossary note, and (optionally) drafts one with AI. The
/// glossary lives at `_meta/glossary.md` — editable in Obsidian, versioned with
/// the vault, and used offline. AI is only a one-time drafting convenience.
class GlossaryService {
  GlossaryService({required VaultSource source, ClaudeService? claude})
      : _source = source,
        _claude = claude;

  final VaultSource _source;
  final ClaudeService? _claude;

  static const fileName = 'glossary.md';

  /// The `slug → definition` map from the vault note (empty if none).
  Future<Map<String, String>> load() async {
    final raw = await _source.readMeta(fileName);
    return raw == null ? const {} : parseGlossaryNote(raw);
  }

  /// One-time draft: ask Claude to write a Markdown glossary for [candidates]
  /// (keeping only genuine terms) and save it to the vault, where you then own
  /// and edit it. Returns the number of defined terms.
  Future<int> draft(Set<String> candidates) async {
    final claude = _claude;
    if (claude == null) throw ClaudeException('No API key configured');
    if (candidates.isEmpty) return 0;

    final list = (candidates.toList()..sort()).join(', ');
    final markdown = await claude.complete(
      maxTokens: 4096,
      prompt:
          'Write a glossary for a software-engineering interview-prep app. For '
          'each candidate acronym below that is a genuine technical term, output '
          'a Markdown H2 section: a line "## TERM" followed by a one-sentence '
          'definition aimed at a learner. Omit anything not a real technical '
          'term or too trivial to define. Sort sections alphabetically. Output '
          'ONLY Markdown, starting with "# Glossary" — no prose, no code fences.'
          '\n\nCandidates: $list',
    );

    final cleaned = _stripFence(markdown).trim();
    await _source.writeMeta(fileName, '$cleaned\n');
    return parseGlossaryNote(cleaned).length;
  }

  String _stripFence(String reply) {
    var s = reply.trim();
    if (s.startsWith('```')) {
      s = s
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '')
          .trim();
    }
    return s;
  }
}
