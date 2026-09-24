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
  required int budgetMinutes,
  int? retentionPct,
  required int reviewBacklog,
  String? todayPlan,
}) {
  final b = StringBuffer();
  b
    ..writeln(
        'You are a sharp, supportive study/pace strategist inside Onyx (a '
        'spaced-repetition study app). The learner is a motivated adult working '
        'toward their study goal. They tapped "talk about it" on this coach '
        'nudge:')
    ..writeln()
    ..writeln('  Nudge: "${update.headline}"')
    ..writeln('  Why: ${update.why}')
    ..writeln()
    ..writeln('Their current state: readiness ~$overallPct% for $targetLabel; '
        'material coverage ~$coveragePct%'
        '${daysToInterview != null ? '; target date in $daysToInterview day'
            '${daysToInterview == 1 ? '' : 's'}' : '; no target date set'}.')
    ..writeln()
    ..writeln(
        'The ONE load lever you can adjust for them is the daily study budget '
        '(how much time per day). The app derives the study MIX — reviews vs new '
        'vs practice — from that budget automatically; there are no per-flow '
        'counts to hand-tune:')
    ..writeln('  - Daily study budget: ~$budgetMinutes min/day'
        '${retentionPct != null ? '; recent recall ~$retentionPct%' : ''}; '
        '$reviewBacklog reviews due now.')
    ..writeln()
    ..writeln();
  if (todayPlan != null && todayPlan.trim().isNotEmpty) {
    b
      ..writeln("Here is the app's prioritized plan for today — a time-boxed "
          'queue across the tracks, sized to a daily budget that ramps as the '
          'habit builds and tapers new learning as an interview nears:')
      ..writeln(todayPlan.trim())
      ..writeln('Reason about this concretely: if they are short on time, tell '
          'them what to keep (must-do rows first) and what can slip; help them '
          'sequence or trim it. But you only change ongoing load via the <set/> '
          'tag below (the daily budget) — the plan itself recomputes from that '
          'budget plus their progress, so never claim you edited today\'s list '
          'directly.')
      ..writeln();
  }
  b
    ..writeln(
        'You can CHANGE the daily study budget for them (in minutes). When '
        'you and the learner land on a specific change, end that reply with ONE '
        'tag on its own final line: <set setting="budget" delta="±N"/> where N is '
        'MINUTES (small steps, e.g. +15, -15). The app turns it into an "Apply" '
        'button — so OFFER, then let them tap. Never claim you already changed a '
        'setting; you are proposing, and it applies only when they tap. Grounding: '
        'more time lets the app fit more in each day; less time lightens the load, '
        'and the app always keeps reviews first and eases new material '
        'automatically. If they feel overloaded, the levers are trimming time or '
        'just clearing the backlog — never tell them to hand-tune new cards or '
        'problems per day; those are automatic now.')
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
        'minutes of review cards"). These reliably improve follow-through.')
    ..writeln('- Ask ONE focused question or offer ONE suggestion at a time. '
        'Keep it to 2–4 sentences, plain Markdown, no headings.')
    ..writeln(
        '- On load/pace questions, use sound principles: the app auto-eases '
        'new material when they fall behind (new material multiplies future '
        'reviews); ~90% retention is the target — don\'t chase higher, it explodes '
        'workload; steady daily practice beats last-minute cramming; if behind, '
        'the honest levers are more time, narrower scope, or a later date.')
    ..writeln(
        '- Never invent data you weren\'t given. If you need something to '
        'advise well, ask for it.');
  return b.toString();
}

final _setTag = RegExp(r'<set\s+setting="budget"\s+delta="([+-]?\d+)"\s*/>',
    caseSensitive: false);

/// Splits a strategist reply into the display text and an optional proposed
/// daily-budget change in MINUTES (parsed from a `<set setting="budget" .../>`
/// tag, stripped from the text so it never shows). The app renders the proposal
/// as an "Apply" button — the budget is the coach's one load lever (ADR-0011).
({String text, CoachProposal? proposal}) parseCoachChatReply(String raw) {
  final m = _setTag.firstMatch(raw);
  CoachProposal? proposal;
  if (m != null) {
    final delta = int.tryParse(m.group(1)!);
    if (delta != null && delta != 0) {
      final sign = delta > 0 ? '+' : '';
      proposal = CoachProposal(
        deltaMinutes: delta,
        applyLabel: 'Apply: $sign$delta min/day',
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
