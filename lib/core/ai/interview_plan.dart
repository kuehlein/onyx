/// The AI "interview planner" (task #24/#25 family, Phase 1): a chat that turns a
/// described interview ("Google, senior backend, Maps, in 2 weeks") into a
/// STRUCTURED prep plan the app can apply as a [PrepGoal]. The model asks
/// clarifying questions until it has enough, then emits a human summary plus a
/// hidden `<plan>{…}</plan>` block (same tagged-JSON trick as the coach's
/// assessment) that we parse here. It biases EXISTING deck material (learning
/// gaps) and only softly flags missing content — the learner authors that.
library;

import 'dart:convert';

import '../readiness/prep_goal.dart';
import '../readiness/target.dart';

/// A structured prep plan proposed by the planner, ready to become a [PrepGoal].
class InterviewPlan {
  const InterviewPlan({
    required this.company,
    required this.role,
    required this.level,
    required this.tier,
    required this.track,
    this.date,
    this.domainWeights = const {},
    this.conceptWeights = const {},
    this.missingConcepts = const [],
    this.appGaps = const [],
    this.summary = '',
  });

  final String company;
  final String role;
  final SeniorityLevel level;
  final CompanyTier tier;
  final Track track;
  final DateTime? date;

  /// Boosts keyed by the deck's own domain tags (so they actually apply).
  final Map<String, double> domainWeights;

  /// Boosts keyed by the deck's own concept tags.
  final Map<String, double> conceptWeights;

  /// Important-for-this-interview concepts NOT found in the deck (soft; the
  /// learner would author cards for these).
  final List<String> missingConcepts;

  /// Things this interview needs that Onyx doesn't cover (e.g. behavioral),
  /// surfaced so the learner preps them elsewhere.
  final List<String> appGaps;

  /// The human-readable plan / rationale (Markdown).
  final String summary;

  /// Convert to a persistable [PrepGoal] (active). [id] is caller-supplied.
  PrepGoal toGoal(String id) => PrepGoal(
        id: id,
        companyName: company,
        tier: tier,
        level: level,
        track: track,
        date: date,
        domainWeights: domainWeights,
        conceptWeights: conceptWeights,
        notes: summary.isEmpty ? null : summary,
      );
}

/// The planner's system prompt, seeded with the deck's available domains +
/// concepts (so the model weights material that actually exists) and the base
/// aim.
String buildInterviewPlannerSystem({
  required List<String> deckDomains,
  required List<String> deckConcepts,
  required ReadinessTarget base,
}) {
  final b = StringBuffer();
  b
    ..writeln('You are an interview-prep strategist inside Onyx (a '
        'spaced-repetition + mock-interview study app). The learner will '
        'describe an upcoming interview (company, role, team, timeframe). Your '
        'job: turn it into a concrete study plan that reprioritizes what they '
        'already study, and honestly flag what Onyx can\'t help with.')
    ..writeln()
    ..writeln('How to behave:')
    ..writeln(
        '- If key facts are missing or ambiguous (which role/level, rough '
        'date, or an UNFAMILIAR company), ask ONE short clarifying question and '
        'STOP — do not emit a plan yet. If the company is one you don\'t know, '
        'say so and ask what role/team they applied for so you can reason from '
        'the role.')
    ..writeln('- Company-specific claims ("Google emphasizes X") are ADVISORY '
        'and can be dated — say so briefly; never present them as certainty.')
    ..writeln('- Prioritize the material they ALREADY have. Weight the deck\'s '
        'own domains/concepts (listed below) toward what this interview demands. '
        'Genuinely-missing-but-important topics go in missingConcepts (soft — '
        'they author those); things Onyx doesn\'t cover at all (e.g. behavioral '
        'STAR rounds, live-coding environment) go in appGaps.')
    ..writeln()
    ..writeln('When you have enough to plan, reply with a SHORT human summary '
        '(what you\'ll prioritize, the advisory caveat, and any appGaps to '
        'prepare elsewhere) AND — on its own final line — a hidden block the '
        'learner never sees:')
    ..writeln('<plan>{"company":"…","role":"…","level":"newGrad|mid|senior|'
        'staff","tier":"faang|typical","track":"general|backend|frontend|'
        'fullStack|ml|mobile","date":"YYYY-MM-DD or omit","domainWeights":'
        '{"<deck-domain>":1.5,…},"conceptWeights":{"<deck-concept>":2.0,…},'
        '"missingConcepts":["…"],"appGaps":["…"],"summary":"markdown"}</plan>')
    ..writeln('Rules for the plan JSON: use ONLY the exact deck domain/concept '
        'keys listed below for domainWeights/conceptWeights (else they won\'t '
        'apply); weights are multipliers > 0 (higher = more important for this '
        'interview); pick the closest level/tier/track; omit date if unknown. '
        'Emit the <plan> block at most once, only when ready.')
    ..writeln()
    ..writeln('Deck domains: '
        '${deckDomains.isEmpty ? '(none)' : deckDomains.join(', ')}')
    ..writeln('Deck concepts: '
        '${deckConcepts.isEmpty ? '(none)' : deckConcepts.join(', ')}')
    ..writeln('Base aim: ${base.label}.');
  return b.toString();
}

final _planTag = RegExp(r'<plan>\s*(\{.*\})\s*</plan>', dotAll: true);

/// Splits a planner reply into the text to show and the parsed plan (if the
/// model emitted one). The tag is stripped so it never shows to the learner.
({String text, InterviewPlan? plan}) parseInterviewPlannerReply(String raw) {
  final match = _planTag.firstMatch(raw);
  final text = raw.replaceAll(_planTag, '').trim();
  if (match == null) return (text: text, plan: null);
  return (text: text, plan: _parsePlan(match.group(1)!));
}

InterviewPlan? _parsePlan(String json) {
  try {
    final m = jsonDecode(json) as Map<String, dynamic>;
    final company = (m['company'] as String?)?.trim() ?? '';
    if (company.isEmpty) return null;
    return InterviewPlan(
      company: company,
      role: (m['role'] as String?)?.trim() ?? '',
      level:
          _enumByName(SeniorityLevel.values, m['level']) ?? SeniorityLevel.mid,
      tier: _enumByName(CompanyTier.values, m['tier']) ?? CompanyTier.typical,
      track: _enumByName(Track.values, m['track']) ?? Track.general,
      date: _parseDate(m['date']),
      domainWeights: _weights(m['domainWeights']),
      conceptWeights: _weights(m['conceptWeights']),
      missingConcepts: _strings(m['missingConcepts']),
      appGaps: _strings(m['appGaps']),
      summary: m['summary'] is String ? (m['summary'] as String).trim() : '',
    );
  } catch (_) {
    return null;
  }
}

Map<String, double> _weights(Object? v) {
  if (v is! Map) return const {};
  final out = <String, double>{};
  for (final e in v.entries) {
    final val = e.value;
    if (val is num && val > 0) out[e.key.toString()] = val.toDouble();
  }
  return out;
}

List<String> _strings(Object? v) {
  if (v is! List) return const [];
  return [
    for (final e in v)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
}

DateTime? _parseDate(Object? v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
