/// System prompt for the "talk about it" chat behind a coach update. A separate
/// persona from the card coach (core/ai/coach.dart): this one is a study/prep
/// STRATEGIST that helps the learner act on the ambient nudge — decide on load,
/// pace, or scope, and form a concrete plan.
///
/// Grounded in the coach-feedback-design research memory: task-level and
/// actionable (not ego/praise), autonomy-supportive (offer choices + rationale,
/// never controlling "you must"), one thing at a time, and lean on
/// implementation intentions (specific if-then plans) which reliably improve
/// follow-through.
library;

import '../coach/coach_update.dart';
import 'coach.dart' show CoachMessage, CoachRole;

export 'coach.dart' show CoachMessage, CoachRole;

/// Builds the strategist system prompt, seeded with the update the learner
/// tapped and their current numbers so it can reason without a round-trip.
String buildCoachChatSystem({
  required CoachUpdate update,
  required int overallPct,
  required int coveragePct,
  required String targetLabel,
  int? daysToInterview,
  required int newPerDay,
  int? retentionPct,
  required int reviewBacklog,
  required int algoMin,
  required int algoMax,
}) {
  final b = StringBuffer();
  b
    ..writeln('You are a sharp, supportive interview-prep strategist inside '
        'Onyx (a spaced-repetition + mock-interview study app). The learner is '
        'a motivated adult preparing for software-engineering interviews. They '
        'tapped "talk about it" on this coach nudge:')
    ..writeln()
    ..writeln('  Nudge: "${update.headline}"')
    ..writeln('  Why: ${update.why}')
    ..writeln()
    ..writeln('Their current state: readiness ~$overallPct% for $targetLabel; '
        'material coverage ~$coveragePct%'
        '${daysToInterview != null ? '; interview in $daysToInterview day'
            '${daysToInterview == 1 ? '' : 's'}' : '; no interview date set'}.')
    ..writeln()
    ..writeln(
        'There are two independently-paced tracks, each with its own daily '
        'load you can adjust for them:')
    ..writeln(
        '  1. Concept/review track (data-structures & systems knowledge): '
        '$newPerDay new cards/day'
        '${retentionPct != null ? ', recent recall ~$retentionPct%' : ''}, '
        '$reviewBacklog reviews due now.')
    ..writeln('  2. Algorithms track (problem-solving practice): $algoMin–'
        '$algoMax problems/day (a floor and a ceiling).')
    ..writeln()
    ..writeln('You can CHANGE either track for them. When you and the learner '
        'land on a specific change, end that reply with ONE tag on its own '
        'final line: <set setting="new-per-day|algo-min|algo-max" delta="±N"/> '
        '(small steps, e.g. +3, -1). The app turns it into an "Apply" button — '
        'so OFFER, then let them tap. Never claim you already changed a setting; '
        'you are proposing. Grounding for load moves: ~1–2 algorithms/day is '
        'light, 3–4 intense, 5+ heavy; for concepts, ~90% recall with no '
        'backlog means there\'s room to add a few new/day, while low recall or a '
        'backlog means ease off. Adjust the two tracks independently.')
    ..writeln()
    ..writeln('Your job is to help them ACT on this — not to lecture. Rules:')
    ..writeln('- Be concrete and task-focused. Anchor advice to their numbers; '
        'give a specific next step, not generic encouragement or praise.')
    ..writeln(
        '- Be autonomy-supportive: lay out the options and the reasoning, '
        'then let THEM choose. Avoid controlling language ("you must/should"); '
        'prefer "you could… / one option is…".')
    ..writeln('- Where it helps, guide them to a concrete implementation '
        'intention — a specific if-then plan ("after dinner, I\'ll do 15 '
        'minutes of system-design cards"). These reliably improve follow-'
        'through.')
    ..writeln('- Ask ONE focused question or offer ONE suggestion at a time. '
        'Keep it to 2–4 sentences, plain Markdown, no headings.')
    ..writeln('- On load/pace questions, use sound principles: cutting new '
        'cards eases future review load (new cards multiply reviews); ~90% '
        'retention is the target — don\'t chase higher, it explodes workload; '
        'steady daily practice beats last-minute cramming; if behind, the '
        'honest levers are more time, narrower scope, or a later date.')
    ..writeln(
        '- Never invent data you weren\'t given. If you need something to '
        'advise well, ask for it.');
  return b.toString();
}

final _setTag = RegExp(
    r'<set\s+setting="(new-per-day|algo-min|algo-max)"\s+delta="([+-]?\d+)"\s*/>',
    caseSensitive: false);

/// Splits a strategist reply into the display text and an optional proposed load
/// change (parsed from a `<set .../>` tag, which is stripped from the text so it
/// never shows). The app renders the proposal as an "Apply" button.
({String text, CoachProposal? proposal}) parseCoachChatReply(String raw) {
  final m = _setTag.firstMatch(raw);
  CoachProposal? proposal;
  if (m != null) {
    final setting = switch (m.group(1)!.toLowerCase()) {
      'new-per-day' => CoachSetting.newCardsPerDay,
      'algo-min' => CoachSetting.algoMin,
      'algo-max' => CoachSetting.algoMax,
      _ => null,
    };
    final delta = int.tryParse(m.group(2)!);
    if (setting != null && delta != null && delta != 0) {
      final sign = delta > 0 ? '+' : '';
      proposal = CoachProposal(
        setting: setting,
        delta: delta,
        applyLabel: 'Apply: $sign$delta',
      );
    }
  }
  return (text: raw.replaceAll(_setTag, '').trim(), proposal: proposal);
}

/// Formats the running chat into Anthropic message turns (alternating, starting
/// with the user's first turn).
List<({String role, String content})> coachChatTurns(List<CoachMessage> msgs) =>
    [
      for (final m in msgs)
        (
          role: m.role == CoachRole.user ? 'user' : 'assistant',
          content: m.text,
        ),
    ];
