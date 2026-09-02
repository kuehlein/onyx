/// The post-interview debrief (Phase 3, step 3): after an interview, the learner
/// tells the coach how it went; the coach gives honest guidance and — when it
/// has enough — emits a hidden `<debrief>{…}</debrief>` block that records the
/// outcome and adjusts the plan (reweight toward revealed weaknesses). Same
/// tagged-JSON trick as the planner; applied back onto the [PrepGoal].
library;

import 'dart:convert';

import '../readiness/prep_goal.dart';

/// A structured debrief result the app applies to a goal.
class DebriefResult {
  const DebriefResult({
    this.outcome,
    this.domainWeights = const {},
    this.conceptWeights = const {},
    this.summary = '',
  });

  /// passed/failed if the learner said; null leaves the goal's outcome as-is.
  final GoalOutcome? outcome;

  /// Weight adjustments (deck keys) — merged over the goal's existing weights.
  final Map<String, double> domainWeights;
  final Map<String, double> conceptWeights;

  /// The coaching summary / what changed (Markdown).
  final String summary;

  /// Fold this debrief into [g]: set the outcome, merge the reweights, and
  /// append the summary to the goal's notes + record it as the outcome note.
  PrepGoal applyTo(PrepGoal g) => g.copyWith(
        outcome: outcome ?? g.outcome,
        domainWeights: {...g.domainWeights, ...domainWeights},
        conceptWeights: {...g.conceptWeights, ...conceptWeights},
        notes: [g.notes, summary]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join('\n\n---\n\n'),
        outcomeNotes: summary.isEmpty ? g.outcomeNotes : summary,
      );
}

/// The debrief system prompt, seeded with the goal and the deck's keys.
String buildDebriefSystem({
  required PrepGoal goal,
  required List<String> deckDomains,
  required List<String> deckConcepts,
}) {
  final b = StringBuffer();
  b
    ..writeln('You are an interview-prep strategist inside Onyx, debriefing a '
        'learner AFTER their interview for: ${goal.label}. Help them learn from '
        'it and adjust their remaining study.')
    ..writeln()
    ..writeln('How to behave:')
    ..writeln('- Ask how it went — strengths, weaknesses, questions they '
        'struggled with or couldn\'t finish. ONE focused question at a time.')
    ..writeln('- Give honest, calibrated guidance. If a problem they got was '
        'rare/unusually hard, say it\'s low-value to over-drill — but point to '
        'the UNDERLYING concepts worth knowing. Weight advice to their target.')
    ..writeln(
        '- Company/role specifics are ADVISORY; the learner\'s own report '
        'of the interview is self-reported, so treat it as input, not gospel.')
    ..writeln(
        '- Be autonomy-supportive: suggest, don\'t command; 2–4 sentences, '
        'plain Markdown, no headings.')
    ..writeln()
    ..writeln('When you have enough, reply with a short human summary AND — on '
        'its own final line — a hidden block the learner never sees:')
    ..writeln('<debrief>{"outcome":"passed|failed|unknown","domainWeights":'
        '{"<deck-domain>":1.5,…},"conceptWeights":{"<deck-concept>":2.0,…},'
        '"summary":"markdown: what to adjust and why"}</debrief>')
    ..writeln(
        'Rules: use ONLY the exact deck keys below for weights (else they '
        'won\'t apply); weights are multipliers > 0 that reprioritise toward '
        'revealed WEAK areas; set outcome only if they told you; emit the block '
        'at most once, only when ready.')
    ..writeln()
    ..writeln('Deck domains: '
        '${deckDomains.isEmpty ? '(none)' : deckDomains.join(', ')}')
    ..writeln('Deck concepts: '
        '${deckConcepts.isEmpty ? '(none)' : deckConcepts.join(', ')}');
  return b.toString();
}

final _debriefTag = RegExp(r'<debrief>\s*(.*?)\s*</debrief>', dotAll: true);

/// Split a debrief reply into shown text + the parsed result (if emitted).
({String text, DebriefResult? result}) parseDebriefReply(String raw) {
  final match = _debriefTag.firstMatch(raw);
  final text = raw.replaceAll(_debriefTag, '').trim();
  if (match == null) return (text: text, result: null);
  return (text: text, result: _parse(match.group(1)!));
}

DebriefResult? _parse(String json) {
  try {
    final m = jsonDecode(json) as Map<String, dynamic>;
    return DebriefResult(
      outcome: _outcome(m['outcome']),
      domainWeights: _weights(m['domainWeights']),
      conceptWeights: _weights(m['conceptWeights']),
      summary: m['summary'] is String ? (m['summary'] as String).trim() : '',
    );
  } catch (_) {
    return null;
  }
}

GoalOutcome? _outcome(Object? v) {
  if (v is! String) return null;
  switch (v) {
    case 'passed':
      return GoalOutcome.passed;
    case 'failed':
      return GoalOutcome.failed;
    default:
      return null; // "unknown" or junk → leave as-is
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
