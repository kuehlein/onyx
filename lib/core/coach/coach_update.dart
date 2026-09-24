/// The ambient "coach update" — a single, prioritized, task-level nudge shown on
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
import '../story/behavioral_readiness.dart';
import '../util.dart';

/// Which insight the coach chose to surface. Ordered loosely by urgency.
enum CoachInsightKind {
  gettingStarted,
  overloaded,
  behindPace,
  behavioralPrep,
  building,
  algoDue,
  explainDue,
  unproven,
  loadCheckin,
  readyToPush,
  onTrack,
}

/// Visual tone for the badge (mapped to color by the widget).
enum CoachTone { info, caution, positive }

/// The learner's self-reported sense of the load, from the opt-in weekly
/// check-in. Complements the objective signals (retention/backlog): you can be
/// hitting 90% and still be burning out, or coasting and ready for more.
enum LoadFeel { tooMuch, aboutRight, couldDoMore }

/// A proposed change to the vault **daily study budget** (minutes) — the coach's
/// only load lever (ADR-0011: the engine derives the mix; the user owns the size;
/// the coach never touches a per-flow dial). [deltaMinutes] is signed (e.g. +15 or
/// -15); [applyLabel] is the button text (e.g. "Add 15 min/day"). Applied only on
/// the user's explicit tap, with an undo — never silently, and only from a
/// user-requested/consented flow (the check-in or the chat), never an unsolicited
/// engine push (that surface is deferred — ADR-0011).
class CoachProposal {
  const CoachProposal({
    required this.deltaMinutes,
    required this.applyLabel,
  });

  final int deltaMinutes;
  final String applyLabel;
}

/// A rendered coach update: the one-liner, an expandable "why now", and either a
/// single navigation action (a route to push) or a [proposal] to apply.
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
    required this.reviewsInWindow,
    required this.retention,
    this.algoDue = 0,
    this.algoExplainDue = 0,
    this.paceStatus,
    this.recentPerDay,
    this.requiredPerDay,
    this.weakestDomain,
    this.weakestDomainPretty,
    this.affirmSeed = 0,
    this.checkInDue = false,
    this.loadFeel,
    this.activeRecently = true,
    this.daysToInterview,
    this.daysToReady,
    this.behavioralStage,
    this.hasAssessment = true,
  });

  /// Any section studied at all (else the deck is untouched).
  final bool anyStudied;
  final bool studiedToday;
  final double overall; // 0..1 readiness
  final double coverage; // 0..1 fraction of all in-scope sections started
  final bool interviewTested; // mocks exist → transfer measured
  final int dueCount; // reviews due now (backlog proxy)
  final int reviewsInWindow; // sample size behind [retention]
  final double? retention; // recent review success 0..1, null if sample tiny
  final int algoDue; // algorithm problems due for a spaced re-solve
  final int algoExplainDue; // problems due to explain (solve not due) — phone
  final PaceStatus? paceStatus; // null when no interview date set
  final double? recentPerDay;
  final double? requiredPerDay;
  final String? weakestDomain; // raw tag, for /practice/<domain>
  final String? weakestDomainPretty;

  /// Rotates affirmation copy so the on-track message isn't identical daily.
  final int affirmSeed;

  /// The opt-in weekly check-in is enabled and hasn't been answered in ~a week.
  final bool checkInDue;

  /// The learner's last self-reported load feel (recent), or null.
  final LoadFeel? loadFeel;

  /// They've actually been showing up lately (used to gate ramping up — don't
  /// pile on load for someone who isn't practicing). Defaults true.
  final bool activeRecently;

  /// Days until the nearest upcoming interview, or null if none set. A scheduled
  /// interview is the safety-net trigger for the behavioral nudge (below).
  final int? daysToInterview;

  /// Days until, at the current study pace, readiness is forecast to cross the
  /// target ("ready to interview") — or null if no forecast / unreachable in the
  /// horizon. This is the PRIMARY trigger for the behavioral nudge: when you're
  /// ~a month from ready you should start applying, and behavioral prep is the
  /// last-mile work that begins then — before any interview is even scheduled.
  final int? daysToReady;

  /// Behavioral delivery readiness stage, or null when behavioral isn't relevant
  /// (no stories/mocks and no interview). Drives the behavioral nudge's copy.
  final BehavioralStage? behavioralStage;

  /// Whether the subject frames study around an assessment event (an interview /
  /// exam / mock) at all — from its `Vocabulary.hasAssessment`. Gates the
  /// "prove it with a mock" nudge so a subject with no assessment concept is
  /// never told to do one (task #88 / G7e). Defaults true (the SWE assumption);
  /// the provider sets it from the active goal's vocabulary.
  final bool hasAssessment;

  /// Within this many days of a scheduled interview, behavioral practice is worth
  /// surfacing regardless of the readiness forecast (imminent — no time to wait).
  /// This is the safety net; the primary trigger is [behavioralForecastDays].
  static const behavioralWindowDays = 28;

  /// When the readiness forecast says you're within this many days of ready, it's
  /// time to start applying — and to begin behavioral prep. Chosen at ~a month so
  /// stories are built and rehearsed before interviews (which you land only after
  /// applying) actually arrive, not scrambled after one is scheduled.
  static const behavioralForecastDays = 35;

  /// Whether an actual interview is imminent (a scheduled prep-goal round soon).
  bool get _interviewImminent =>
      daysToInterview != null &&
      daysToInterview! >= 0 &&
      daysToInterview! <= behavioralWindowDays;

  /// Whether the pace forecast puts "ready to interview" within reach — the cue
  /// to start applying (and thus to start behavioral prep).
  bool get _readySoon =>
      daysToReady != null &&
      daysToReady! >= 0 &&
      daysToReady! <= behavioralForecastDays;

  /// Behavioral delivery isn't sharp yet AND it's time to work it — either the
  /// forecast says you're about ready to apply, or an interview is already close.
  bool get behavioralDue {
    if (behavioralStage == null || behavioralStage == BehavioralStage.sharp) {
      return false;
    }
    return _readySoon || _interviewImminent;
  }

  // --- Grounded thresholds (labeled heuristics; see memory) ---
  /// Below this recent review success, cards are running too hard / load too
  /// high (target is ~0.90; ~10% lapse is expected there).
  static const retentionFloor = 0.80;

  /// Need at least this many reviews before trusting the retention ratio.
  static const minReviewSample = 20;

  /// A due backlog at/above this is "piling up" — the dominant SRS failure mode.
  /// A fixed line now that new-material intake is engine-derived, not a user/coach
  /// dial (ADR-0011): ~60 due is the "clear the backlog first" threshold.
  static const backlogThreshold = 60;

  /// Below this coverage there's still substantial material to learn — building
  /// the base outranks proving transfer or affirming "on track".
  static const coverageBar = 0.85;

  /// A "room for more" push needs a real base first: below this coverage the
  /// honest nudge is "keep building", not "go faster". Replaces the old
  /// new-card-ceiling gate that incidentally suppressed the push (ADR-0011).
  static const pushCoverageFloor = 0.2;

  /// Overall readiness at/above this counts as solid enough to affirm (absent an
  /// explicit on-pace-for-a-date signal).
  static const solidBar = 0.55;

  /// Recent review success strong enough that adding a little load is safe.
  static const pushRetentionBar = 0.90;

  /// Retention bar for a push, relaxed a touch when the learner has said they
  /// could handle more (their input, not just the numbers).
  double get _pushBar =>
      loadFeel == LoadFeel.couldDoMore ? 0.85 : pushRetentionBar;

  /// Everything's green with headroom while still building the base: strong
  /// retention, zero backlog, engaged (today AND showing up lately), and they
  /// haven't said the load's too much. The moment to *affirm* headroom (and point
  /// at the daily-budget dial if they want more) — informational, no auto-dial
  /// (ADR-0011: the engine already fills to the automatic ceiling on a strong day).
  bool get readyToPush =>
      anyStudied &&
      activeRecently &&
      coverage >= pushCoverageFloor &&
      coverage < coverageBar &&
      dueCount == 0 &&
      studiedToday &&
      loadFeel != LoadFeel.tooMuch &&
      retention != null &&
      reviewsInWindow >= minReviewSample &&
      retention! >= _pushBar;

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
      headline: "Recall's slipping (~${pct(s.retention!)}%) — clear reviews "
          'first.',
      why: 'Your recent review success is ~${pct(s.retention!)}% (aim ~90%). '
          "That usually means new material is arriving faster than it's "
          'sticking. Clear today’s reviews first — the app automatically eases '
          'new material while your recall recovers, so it settles quickly. (If it '
          'keeps feeling heavy, trim your daily study time in Settings.)',
      actionLabel: 'Review now',
      actionRoute: '/quiz',
    );
  }
  if (s.backlogHigh) {
    return CoachUpdate(
      kind: CoachInsightKind.overloaded,
      tone: CoachTone.caution,
      headline: '${s.dueCount} reviews due — clear the backlog first.',
      why: 'Reviews have piled up (${s.dueCount} due). New material multiplies '
          'future reviews, so the app automatically holds it back while you catch '
          'up — a review session now gets you ahead of it instead of falling '
          'further behind.',
      actionLabel: 'Review now',
      actionRoute: '/quiz',
    );
  }

  // Behind on COVERAGE for the interview date — offer a choice, don't command.
  // Scoped to coverage (finishing the material), which is the prerequisite for
  // readiness; the calendar shows the stricter ready-by date. Behind on coverage
  // ⟹ behind on readiness, so this is always a valid leading-indicator warning.
  if (s.behind && s.requiredPerDay != null && s.recentPerDay != null) {
    return CoachUpdate(
      kind: CoachInsightKind.behindPace,
      tone: CoachTone.caution,
      headline:
          'Behind on coverage — ~${_rate(s.requiredPerDay!)}/day to get through '
          "your material by then (you're ~${_rate(s.recentPerDay!)}). Push, or "
          'move the date?',
      why:
          'At your recent ~${_rate(s.recentPerDay!)} new sections/day you won’t '
          'have covered everything before your date; ~${_rate(s.requiredPerDay!)}'
          '/day finishes the material in time. Covering it comes first — reviews '
          'then deepen it into readiness (the calendar shows your ready-by '
          'date). Raise your daily learning, trim scope, or shift the date — '
          'your call. Steady daily wins beat last-minute cramming.',
      actionLabel: 'Learn now',
      actionRoute: '/learn',
    );
  }

  // Opt-in weekly check-in — asked on a calm, engaged day (nothing urgent got
  // here first). A quick subjective read that then gates the load suggestions.
  if (s.checkInDue && s.anyStudied && s.dueCount == 0) {
    return const CoachUpdate(
      kind: CoachInsightKind.loadCheckin,
      tone: CoachTone.info,
      headline: "How's the study load feeling this week?",
      why:
          'A quick gut-check. Your numbers show retention and backlog, but only '
          'you know if it feels sustainable — tell me and I’ll factor it into '
          'what I suggest next.',
    );
  }

  // You're about ready to apply (pace forecast) — or an interview is already
  // close — and behavioral delivery isn't sharp. The last-mile prompt. Behavioral
  // lives in the Interview-prep hub, not the daily queue, so this is how it
  // surfaces on Home: only when it's genuinely time to work it. Forecast-driven
  // is primary because you start behavioral when you begin APPLYING, well before
  // any interview is scheduled — not four weeks after one lands on the calendar.
  if (s.behavioralDue) {
    final building = s.behavioralStage == BehavioralStage.notStarted ||
        s.behavioralStage == BehavioralStage.buildingStories;
    final verb =
        building ? 'build your behavioral stories' : 'rehearse your stories';
    // An imminent scheduled interview is the more urgent framing; otherwise lead
    // with the "ready to apply" forecast.
    final d = s.daysToInterview;
    final imminent =
        d != null && d >= 0 && d <= CoachSignals.behavioralWindowDays;
    return CoachUpdate(
      kind: CoachInsightKind.behavioralPrep,
      tone: imminent && d <= 14 ? CoachTone.caution : CoachTone.info,
      headline: imminent
          ? 'Interview in $d day${d == 1 ? '' : 's'} — $verb.'
          : 'You’re about ready to apply — $verb.',
      why: imminent
          ? 'Behavioral rounds are last-mile: ${s.behavioralStage!.hint} A strong '
              'story per competency, said out loud a few times (not memorized), is '
              'what carries the round.'
          : 'At your current pace you’re on track to be interview-ready soon, so '
              'it’s time to start applying — and behavioral is the last-mile work '
              'that starts now, before interviews land. ${s.behavioralStage!.hint} '
              'A strong story per competency, said out loud a few times (not '
              'memorized), is what carries the round.',
      actionLabel: 'Open interview prep',
      actionRoute: '/interview-prep',
    );
  }

  // Building the base AND thriving (strong retention, no backlog) → offer a
  // small, reversible load increase instead of a plain "keep learning". Ranked
  // just above the generic building nudge so the good-news path wins when it's
  // genuinely earned.
  if (s.readyToPush) {
    return CoachUpdate(
      kind: CoachInsightKind.readyToPush,
      tone: CoachTone.positive,
      headline: "Retention's strong (~${pct(s.retention!)}%) with no backlog — "
          "you're in a great groove.",
      why:
          "You're holding ~${pct(s.retention!)}% and reviews aren't piling up, so "
          'you have real headroom. The app already gives you new material up to a '
          'sustainable ceiling; if you want to go faster, nudge your daily study '
          'time up in Settings — small steps keep it sustainable, and you can '
          'always ease back.',
    );
  }

  // Still substantial material uncovered → build the base. This ranks above
  // proving/affirming: you can't be "ready" from a sliver, and (with no date)
  // you can't be "behind" — but you can always keep learning.
  if (s.coverage < CoachSignals.coverageBar) {
    return CoachUpdate(
      kind: CoachInsightKind.building,
      tone: CoachTone.info,
      headline: "You've covered ~${pct(s.coverage)}% — keep learning.",
      why: 'Only ~${pct(s.coverage)}% of your material has been started, so '
          'readiness (~${pct(s.overall)}%) can’t climb far yet. The highest-'
          'value move is to keep learning new sections a few at a time.',
      actionLabel: 'Learn now',
      actionRoute: '/learn',
    );
  }

  // Spaced algorithm re-solves have come due — the execution clock. Honor them
  // like reviews: re-solving on schedule is what turns "I recall the trick"
  // into "I can produce it cold", and each solve feeds readiness.
  if (s.algoDue > 0) {
    return CoachUpdate(
      kind: CoachInsightKind.algoDue,
      tone: CoachTone.info,
      headline: '${s.algoDue} algorithm${s.algoDue == 1 ? '' : 's'} due for a '
          're-solve — keep the patterns sharp.',
      why:
          'Spaced re-solving is what makes a pattern automatic under pressure. '
          '${s.algoDue} ${s.algoDue == 1 ? 'problem is' : 'problems are'} due '
          'for a re-solve; a short session now keeps them on schedule and '
          'counts toward your readiness.',
      actionLabel: 'Solve now',
      actionRoute: '/algorithms',
    );
  }

  // Nothing solve-due, but patterns have come due to *explain* — the
  // phone-doable maintenance rep. Lower priority than solving (the stronger
  // mode), but a great away-from-a-computer next action.
  if (s.algoExplainDue > 0) {
    return CoachUpdate(
      kind: CoachInsightKind.explainDue,
      tone: CoachTone.info,
      headline:
          '${s.algoExplainDue} pattern${s.algoExplainDue == 1 ? '' : 's'} due '
          'to explain — no computer needed.',
      why:
          'Away from your machine? Talk a problem through with the coach — the '
          'recognition trigger, approach, complexity, and edge cases. It keeps '
          "the pattern sharp between full solves; it won't replace solving, but "
          'it stops the recognition from fading.',
      actionLabel: 'Explain now',
      actionRoute: '/algorithms',
    );
  }

  // Covered but never mock-tested — recall isn't the interview bar; a mock is.
  // Only for subjects that HAVE an assessment (mock) concept — a subject with no
  // assessment can't "prove it with a mock", so this nudge stays silent for it
  // (G7e). The "mock interview" copy + /practice route are still SWE-specific;
  // generalizing them per applied-flow is the deeper flow-routing work (#92).
  if (!s.interviewTested && s.hasAssessment) {
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

  // Genuinely on track: solid readiness, or on pace to finish covering toward a
  // set date. Only here do we affirm — never at low readiness just because
  // nothing's on fire. When it's coverage-pace (not yet solid recall) the copy
  // stays scoped to coverage so it never over-claims "ready" — the calendar owns
  // the ready-by date.
  if ((s.hasDate && s.onPace) || s.overall >= CoachSignals.solidBar) {
    final solid = s.overall >= CoachSignals.solidBar;
    const affirms = [
      'On track — steady daily reps are doing the work.',
      'Nicely paced. Keep the daily habit going.',
      'Solid — your consistency is compounding.',
    ];
    final headline = solid
        ? (s.studiedToday
            ? affirms[s.affirmSeed % affirms.length]
            : 'On track — a quick session today keeps it that way.')
        : (s.studiedToday
            ? 'On pace to cover your material — reviews will deepen it into '
                'readiness.'
            : 'On pace to cover your material — a quick session keeps it '
                'going.');
    return CoachUpdate(
      kind: CoachInsightKind.onTrack,
      tone: CoachTone.positive,
      headline: headline,
      why: solid
          ? 'Readiness is ~${pct(s.overall)}% and your pace looks healthy. '
              'Nothing needs fixing — keep showing up.'
          : 'You’re on pace to finish covering your material; recall is still '
              'maturing (~${pct(s.overall)}%). Keep going — reviews turn '
              'coverage into readiness, and the calendar shows your ready-by '
              'date.',
      actionLabel: s.dueCount > 0 ? 'Review now' : null,
      actionRoute: s.dueCount > 0 ? '/quiz' : null,
    );
  }

  // Covered + mock-tested, but readiness is still soft and there's no deadline
  // pressure → deepen recall via review rather than falsely affirm "on track".
  return CoachUpdate(
    kind: CoachInsightKind.building,
    tone: CoachTone.info,
    headline: 'Readiness ~${pct(s.overall)}% — deepen it with review.',
    why: 'You’ve covered the material but recall and transfer are still '
        'building (readiness ~${pct(s.overall)}%). Keep reviewing to '
        'strengthen it${s.hasDate ? '' : '; set a target date if you want pace '
            'tracking'}.',
    actionLabel: s.dueCount > 0 ? 'Review now' : null,
    actionRoute: s.dueCount > 0 ? '/quiz' : null,
  );
}
