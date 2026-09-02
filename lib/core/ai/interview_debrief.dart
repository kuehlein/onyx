/// The post-interview debrief (Phase 3, step 3): after an interview, the learner
/// tells the coach how it went; the coach gives honest guidance and — when the
/// evidence supports it — emits a hidden `<debrief>{…}</debrief>` block that
/// records the outcome and makes SMALL, conservative reweights toward genuine,
/// recurring weaknesses. Same tagged-JSON trick as the planner; applied back
/// onto the [PrepGoal].
///
/// Hardened against overreaction: one interview is a tiny, noisy sample, so the
/// prompt only reweights durable patterns (not one-off unlucky questions),
/// separates learnable content gaps from nerves/luck, grounds rare-vs-common in
/// the deck's own `frequency` labels, and the parser CLAMPS every multiplier to
/// [1.0, [weightCap]] so the model can never destabilise the plan.
library;

import 'dart:convert';

import '../../shared/models/card.dart';
import '../readiness/prep_goal.dart';

/// The hard ceiling on any debrief-proposed weight multiplier. Deliberately
/// lower than the planner's (a full plan can weight ~2.0) — a single interview
/// should nudge, never overhaul. Analogous to the FSRS retention cap.
const weightCap = 1.6;

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

/// Which deck domains/concepts appear OFTEN vs RARELY in real interviews,
/// derived from the `frequency` (high|medium|low) on interview-question cards.
/// A key's signal is the MAX frequency across the questions that touch it (if
/// it shows up in a common question, it's worth knowing). Lets the debrief avoid
/// over-drilling genuinely rare topics.
({List<String> high, List<String> low}) deckFrequencySignal(List<Card> cards) {
  int rankOf(String? f) => switch (f?.toLowerCase().trim()) {
        'high' => 2,
        'medium' => 1,
        'low' => 0,
        _ => -1, // absent/unknown → no signal
      };
  final rank = <String, int>{};
  void bump(String key, int v) {
    final cur = rank[key];
    if (cur == null || v > cur) rank[key] = v;
  }

  for (final c in cards) {
    final v = rankOf(c.frequency);
    if (v < 0) continue; // only interview-question cards carry frequency
    final dom = c.domain;
    if (dom != null) bump(dom, v);
    for (final d in c.domains) {
      bump(d, v);
    }
    for (final k in c.concepts) {
      bump(k, v);
    }
  }
  return (
    high: [
      for (final e in rank.entries)
        if (e.value == 2) e.key
    ],
    low: [
      for (final e in rank.entries)
        if (e.value == 0) e.key
    ],
  );
}

/// The debrief system prompt, seeded with the goal, the deck's keys, and the
/// deck's frequency signal (which topics are common vs rare in real interviews).
String buildDebriefSystem({
  required PrepGoal goal,
  required List<String> deckDomains,
  required List<String> deckConcepts,
  List<String> highFrequency = const [],
  List<String> lowFrequency = const [],
}) {
  final b = StringBuffer();
  b
    ..writeln('You are an interview-prep strategist inside Onyx, debriefing a '
        'learner AFTER their interview for: ${goal.label}. Help them learn from '
        'it and — ONLY where the evidence supports it — adjust their remaining '
        'study.')
    ..writeln()
    ..writeln('Treat this cautiously: ONE interview is a small, noisy sample '
        '(interviewer and question luck, nerves, time pressure). Do NOT overhaul '
        'a plan off it.')
    ..writeln('- Reweight for durable PATTERNS, not one-off events. A weakness '
        'counts only if it plausibly recurs — it is core to the role, or they '
        'also struggle with it in study — not a single unlucky or unusually hard '
        'question. Probe whether it is a pattern before you weight it.')
    ..writeln('- Separate a learnable CONTENT gap from nerves, communication, '
        'time pressure, or bad luck. Only reweight the content gap; for the rest, '
        'coach the behaviour and leave the plan alone.')
    ..writeln(
        '- Counter recency bias: have them recall the WHOLE interview, not '
        'just the worst moment. The vivid problem they blanked on may matter less '
        'than it feels.')
    ..writeln(
        '- Prefer FEW, SMALL changes: boost at most 2–3 areas, lightly. If '
        'they passed, or nothing clearly recurs, propose NO reweight (empty maps) '
        'and just give guidance — that is often the right call.')
    ..writeln('- Do NOT over-drill rare topics: if a missed problem is '
        'low-frequency in real interviews, say so and point to the UNDERLYING '
        'concept worth knowing rather than the exact problem.')
    ..writeln()
    ..writeln('How to behave:')
    ..writeln('- Ask how it went — strengths, weaknesses, questions they '
        'struggled with or couldn\'t finish. ONE focused question at a time.')
    ..writeln('- The learner\'s report is self-reported and company/role '
        'specifics are advisory — input, not gospel.')
    ..writeln(
        '- Be autonomy-supportive: suggest, don\'t command; 2–4 sentences, '
        'plain Markdown, no headings.');
  if (highFrequency.isNotEmpty) {
    b.writeln('Common in real interviews (safe to prioritise): '
        '${highFrequency.join(', ')}.');
  }
  if (lowFrequency.isNotEmpty) {
    b.writeln('Rare in real interviews (don\'t over-invest; learn the '
        'underlying idea): ${lowFrequency.join(', ')}.');
  }
  b
    ..writeln()
    ..writeln('When you have enough, reply with a short human summary AND — on '
        'its own final line — a hidden block the learner never sees:')
    ..writeln('<debrief>{"outcome":"passed|failed|unknown","domainWeights":'
        '{"<deck-domain>":1.3,…},"conceptWeights":{"<deck-concept>":1.5,…},'
        '"summary":"markdown: what to adjust and why"}</debrief>')
    ..writeln(
        'Rules: use ONLY the exact deck keys below (else it won\'t apply); '
        'weights are small multipliers between 1.0 and $weightCap — a gentle '
        'nudge, never an overhaul; include a key only to RAISE emphasis on a '
        'CONFIRMED recurring weakness; empty weight maps are fine and often '
        'correct; set outcome only if they told you; emit the block at most '
        'once, only when ready.')
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

/// Parse a weight map, dropping non-positive values and CLAMPING the rest into
/// [1.0, [weightCap]] — the hard guard that stops an over-eager model from
/// destabilising the plan, regardless of what the prompt asked for.
Map<String, double> _weights(Object? v) {
  if (v is! Map) return const {};
  final out = <String, double>{};
  for (final e in v.entries) {
    final val = e.value;
    if (val is num && val > 0) {
      out[e.key.toString()] = val.toDouble().clamp(1.0, weightCap);
    }
  }
  return out;
}
