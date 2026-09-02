/// The ambient "coach update" — a single, prioritised, task-level nudge shown on
/// Home. Pure triage logic, kept out of the providers so it is fully testable.
///
/// Design is grounded in research (see the coach-feedback-design memory):
/// - Surface exactly ONE highest-value, actionable insight, never a dashboard.
/// - Task-level framing (what to do next), never ego/praise or a bare score —
///   >1/3 of feedback interventions HURT, and the damage concentrates in
///   self/ego framing. Each line = goal + current signal + the one next action.
/// - "Health" first (overload), then pace, then unproven recall, then affirm.
/// - Autonomy-supportive: behind-pace offers a CHOICE (effort vs. adjust the
///   goal), informational not controlling.
library;

import '../readiness/pace.dart';

/// Which insight the coach chose to surface. Ordered loosely by urgency.
enum CoachInsightKind {
  gettingStarted,
  overloaded,
  behindPace,
  building,
  unproven,
  onTrack,
}

/// Visual tone for the badge (mapped to colour by the widget).
enum CoachTone { info, caution, positive }

/// A rendered coach update: the one-liner, an expandable "why now", and an
/// optional single action (a route to push).
class CoachUpdate {
  const CoachUpdate({
    required this.kind,
    required this.tone,
    required this.headline,
    required this.why,
    this.actionLabel,
    this.actionRoute,
  });

  final CoachInsightKind kind;
  final CoachTone tone;
  final String headline;
  final String why;
  final String? actionLabel;
  final String? actionRoute;

  bool get hasAction => actionLabel != null && actionRoute != null;
}

/// The signals the triage reasons over, gathered from the same providers the
/// dashboard uses. Kept as a plain value so the logic is trivially testable.
class CoachSignals {
  const CoachSignals({
    required this.anyStudied,
    required this.studiedToday,
    required this.overall,
    required this.coverage,
    required this.interviewTested,
    required this.dueCount,
    required this.newCardLimit,
    required this.reviewsInWindow,
    required this.retention,
    this.paceStatus,
    this.recentPerDay,
    this.requiredPerDay,
    this.weakestDomain,
    this.weakestDomainPretty,
    this.affirmSeed = 0,
  });

  /// Any section studied at all (else the deck is untouched).
  final bool anyStudied;
  final bool studiedToday;
  final double overall; // 0..1 readiness
  final double coverage; // 0..1 fraction of all in-scope sections started
  final bool interviewTested; // mocks exist → transfer measured
  final int dueCount; // reviews due now (backlog proxy)
  final int newCardLimit; // configured new sections/day
  final int reviewsInWindow; // sample size behind [retention]
  final double? retention; // recent review success 0..1, null if sample tiny
  final PaceStatus? paceStatus; // null when no interview date set
  final double? recentPerDay;
  final double? requiredPerDay;
  final String? weakestDomain; // raw tag, for /practice/<domain>
  final String? weakestDomainPretty;

  /// Rotates affirmation copy so the on-track message isn't identical daily.
  final int affirmSeed;

  // --- Grounded thresholds (labelled heuristics; see memory) ---
  /// Below this recent review success, cards are running too hard / load too
  /// high (target is ~0.90; ~10% lapse is expected there).
  static const retentionFloor = 0.80;

  /// Need at least this many reviews before trusting the retention ratio.
  static const minReviewSample = 20;

  /// A due backlog at/above this is "piling up" — the dominant SRS failure mode.
  int get backlogThreshold => newCardLimit * 3 < 60 ? 60 : newCardLimit * 3;

  /// Below this coverage there's still substantial material to learn — building
  /// the base outranks proving transfer or affirming "on track".
  static const coverageBar = 0.85;

  /// Overall readiness at/above this counts as solid enough to affirm (absent an
  /// explicit on-pace-for-a-date signal).
  static const solidBar = 0.55;

  bool get retentionLow =>
      retention != null &&
      reviewsInWindow >= minReviewSample &&
      retention! < retentionFloor;

  bool get backlogHigh => dueCount >= backlogThreshold;

  bool get behind =>
      paceStatus == PaceStatus.behind ||
      paceStatus == PaceStatus.slightlyBehind;

  /// An interview date is set, so pace/deadline reasoning applies.
  bool get hasDate => paceStatus != null;

  bool get onPace =>
      paceStatus == PaceStatus.onTrack ||
      paceStatus == PaceStatus.coverageComplete;
}

String _rate(double v) {
  if (v >= 10) return v.round().toString();
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

int _pct(double v) => (v.clamp(0, 1) * 100).round();

/// Picks the single highest-value update to show, or null to stay quiet.
/// Priority: getting-started → overloaded → behind pace → unproven → on-track.
CoachUpdate? buildCoachUpdate(CoachSignals s) {
  // Nothing studied yet — one gentle "start" nudge (momentum > planning).
  if (!s.anyStudied) {
    return const CoachUpdate(
      kind: CoachInsightKind.gettingStarted,
      tone: CoachTone.info,
      headline: 'Start small — a few cards today builds the habit.',
      why: 'Nothing studied yet. A short first session beats a big plan you '
          'never start; with spaced repetition, consistency is what compounds.',
      actionLabel: 'Learn now',
      actionRoute: '/learn',
    );
  }

  // Health first: overload. Retention dip and backlog are distinct causes.
  if (s.retentionLow) {
    return CoachUpdate(
      kind: CoachInsightKind.overloaded,
      tone: CoachTone.caution,
      headline: "Recall's slipping (~${_pct(s.retention!)}%) — ease off new "
          'cards.',
      why: 'Your recent review success is ~${_pct(s.retention!)}% (aim ~90%). '
          "That usually means new material is arriving faster than it's "
          'sticking. Lower your new-cards/day in Settings and clear today’s '
          'reviews first — it settles quickly.',
      actionLabel: 'Review now',
      actionRoute: '/quiz',
    );
  }
  if (s.backlogHigh) {
    return CoachUpdate(
      kind: CoachInsightKind.overloaded,
      tone: CoachTone.caution,
      headline:
          '${s.dueCount} reviews due — clear the backlog before new cards.',
      why:
          'Reviews have piled up (${s.dueCount} due). New cards multiply future '
          'reviews, so pausing or lowering new-cards/day lets you catch up '
          'instead of falling further behind.',
      actionLabel: 'Review now',
      actionRoute: '/quiz',
    );
  }

  // Behind the interview date — offer a choice, don't command.
  if (s.behind && s.requiredPerDay != null && s.recentPerDay != null) {
    return CoachUpdate(
      kind: CoachInsightKind.behindPace,
      tone: CoachTone.caution,
      headline:
          'Behind for your date — ~${_rate(s.requiredPerDay!)}/day needed '
          "(you're ~${_rate(s.recentPerDay!)}). Push, or move the date?",
      why: 'At your recent ~${_rate(s.recentPerDay!)} sections/day you’ll miss '
          'the target; ~${_rate(s.requiredPerDay!)}/day gets there. You can '
          'raise your daily learning, trim scope, or shift the date — your '
          'call. Steady daily wins beat last-minute cramming.',
      actionLabel: 'Learn now',
      actionRoute: '/learn',
    );
  }

  // Still substantial material uncovered → build the base. This ranks above
  // proving/affirming: you can't be "ready" from a sliver, and (with no date)
  // you can't be "behind" — but you can always keep learning.
  if (s.coverage < CoachSignals.coverageBar) {
    return CoachUpdate(
      kind: CoachInsightKind.building,
      tone: CoachTone.info,
      headline: "You've covered ~${_pct(s.coverage)}% — keep learning.",
      why: 'Only ~${_pct(s.coverage)}% of your material has been started, so '
          'readiness (~${_pct(s.overall)}%) can’t climb far yet. The highest-'
          'value move is to keep learning new sections a few at a time.',
      actionLabel: 'Learn now',
      actionRoute: '/learn',
    );
  }

  // Covered but never mock-tested — recall isn't the interview bar; a mock is.
  if (!s.interviewTested) {
    final hasDomain = s.weakestDomain != null;
    return CoachUpdate(
      kind: CoachInsightKind.unproven,
      tone: CoachTone.info,
      headline: 'You know it on paper — prove it with a mock.',
      why:
          'Your readiness is recall-only so far — no mock evidence yet. A mock '
          'interview${hasDomain ? ' in ${s.weakestDomainPretty}' : ''} tests '
          'whether you can apply it under pressure, which is what actually gets '
          'graded.',
      actionLabel: hasDomain ? 'Mock ${s.weakestDomainPretty}' : null,
      actionRoute: hasDomain ? '/practice/${s.weakestDomain}' : null,
    );
  }

  // Genuinely on track: on pace toward a set date, or solid readiness. Only
  // here do we affirm — never at low readiness just because nothing's on fire.
  if ((s.hasDate && s.onPace) || s.overall >= CoachSignals.solidBar) {
    const affirms = [
      'On track — steady daily reps are doing the work.',
      'Nicely paced. Keep the daily habit going.',
      'Solid — your consistency is compounding.',
    ];
    return CoachUpdate(
      kind: CoachInsightKind.onTrack,
      tone: CoachTone.positive,
      headline: s.studiedToday
          ? affirms[s.affirmSeed % affirms.length]
          : 'On track — a quick session today keeps it that way.',
      why: 'Readiness is ~${_pct(s.overall)}% and your pace looks healthy. '
          'Nothing needs fixing — keep showing up.',
      actionLabel: s.dueCount > 0 ? 'Review now' : null,
      actionRoute: s.dueCount > 0 ? '/quiz' : null,
    );
  }

  // Covered + mock-tested, but readiness is still soft and there's no deadline
  // pressure → deepen recall via review rather than falsely affirm "on track".
  return CoachUpdate(
    kind: CoachInsightKind.building,
    tone: CoachTone.info,
    headline: 'Readiness ~${_pct(s.overall)}% — deepen it with review.',
    why: 'You’ve covered the material but recall and transfer are still '
        'building (readiness ~${_pct(s.overall)}%). Keep reviewing to '
        'strengthen it${s.hasDate ? '' : '; set a target date if you want pace '
            'tracking'}.',
    actionLabel: s.dueCount > 0 ? 'Review now' : null,
    actionRoute: s.dueCount > 0 ? '/quiz' : null,
  );
}
