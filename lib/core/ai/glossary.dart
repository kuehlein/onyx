import 'dart:convert';

import '../vault/vault_source.dart';
import 'claude_service.dart';

/// All-caps acronyms of 2–6 chars (API, HTTP, DNSSEC, L2…). Detection runs over
/// raw card text just to build the candidate list; the AI then filters out
/// non-terms, and rendering never touches code (see GlossarySyntax ordering).
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

/// Loads and (via Claude) generates the term→definition glossary, stored at
/// `_meta/glossary.json` in the vault so it's built once and used offline after.
class GlossaryService {
  GlossaryService({required VaultSource source, ClaudeService? claude})
      : _source = source,
        _claude = claude;

  final VaultSource _source;
  final ClaudeService? _claude;

  static const fileName = 'glossary.json';

  Future<Map<String, String>> load() async {
    final raw = await _source.readMeta(fileName);
    if (raw == null) return const {};
    return _parseTerms(raw);
  }

  /// Asks Claude for concise definitions of [candidates], keeping only genuine
  /// technical terms, and writes the result to the vault. Returns the map.
  Future<Map<String, String>> generate(Set<String> candidates) async {
    final claude = _claude;
    if (claude == null) throw ClaudeException('No API key configured');
    if (candidates.isEmpty) return const {};

    final list = (candidates.toList()..sort()).join(', ');
    final reply = await claude.complete(
      maxTokens: 4096,
      prompt:
          'You are building a glossary for a software-engineering interview-prep '
          'flashcard app. For each candidate acronym/abbreviation below, if it is '
          'a genuine technical term, give a concise one-sentence definition aimed '
          'at a learner. OMIT anything that is not a real technical term or is too '
          'trivial to need defining. Respond with ONLY a JSON object mapping term '
          'to definition — no prose, no code fences.\n\nCandidates: $list',
    );

    final terms = _parseJsonObject(reply);
    await _source.writeMeta(
      fileName,
      jsonEncode({
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'terms': terms,
      }),
    );
    return terms;
  }

  Map<String, String> _parseTerms(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final terms =
          (data['terms'] as Map?)?.cast<String, dynamic>() ?? const {};
      return terms.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return const {};
    }
  }

  /// Tolerant of a ```json fence Claude might add around the object.
  Map<String, String> _parseJsonObject(String reply) {
    var s = reply.trim();
    if (s.startsWith('```')) {
      s = s
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '')
          .trim();
    }
    final data = jsonDecode(s) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, v.toString()));
  }
}
