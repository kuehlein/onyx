import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/coach/coach_update.dart';
import 'package:onyx/core/readiness/pace.dart';
import 'package:onyx/core/story/behavioral_readiness.dart';

/// A healthy, well-covered, on-track, mock-tested learner — override per test.
CoachSignals sig({
  bool anyStudied = true,
  bool studiedToday = true,
  bool interviewTested = true,
  double overall = 0.6,
  double coverage = 0.9,
  int dueCount = 0,
  int reviewsInWindow = 30,
  double? retention = 0.9,
  int algoDue = 0,
  int algoExplainDue = 0,
  PaceStatus? paceStatus = PaceStatus.onTrack,
  double? recentPerDay = 5,
  double? requiredPerDay = 5,
  String? weakestDomain = 'system-design',
  String? weakestDomainPretty = 'System design',
  int affirmSeed = 0,
  bool checkInDue = false,
  LoadFeel? loadFeel,
  bool activeRecently = true,
  int? daysToInterview,
  int? daysToReady,
  BehavioralStage? behavioralStage,
  bool hasAssessment = true,
  // Default to the SWE reference timing so existing behavioral tests keep
  // exercising the 35/28-day thresholds; pass null to model a subject whose
  // template configures no behavioral timing (task #107).
  int? behavioralForecastDays = 35,
  int? behavioralWindowDays = 28,
}) =>
    CoachSignals(
      anyStudied: anyStudied,
      studiedToday: studiedToday,
      overall: overall,
      coverage: coverage,
      interviewTested: interviewTested,
      dueCount: dueCount,
      reviewsInWindow: reviewsInWindow,
      retention: retention,
      algoDue: algoDue,
      algoExplainDue: algoExplainDue,
      paceStatus: paceStatus,
      recentPerDay: recentPerDay,
      requiredPerDay: requiredPerDay,
      weakestDomain: weakestDomain,
      weakestDomainPretty: weakestDomainPretty,
      affirmSeed: affirmSeed,
      checkInDue: checkInDue,
      loadFeel: loadFeel,
      activeRecently: activeRecently,
      daysToInterview: daysToInterview,
      daysToReady: daysToReady,
      behavioralStage: behavioralStage,
      hasAssessment: hasAssessment,
      behavioralForecastDays: behavioralForecastDays,
      behavioralWindowDays: behavioralWindowDays,
    );

void main() {
  group('behavioral nudge', () {
    test('forecast ready-soon + not sharp → behavioralPrep (no interview set)',
        () {
      // The PRIMARY trigger: at the current pace you're ~a month from ready, so
      // it's time to start applying — behavioral prep begins now, before any
      // interview is scheduled.
      final u = buildCoachUpdate(sig(
        daysToReady: 30,
        behavioralStage: BehavioralStage.readyToRehearse,
      ))!;
      expect(u.kind, CoachInsightKind.behavioralPrep);
      expect(u.actionRoute, '/interview-prep');
      expect(u.tone, CoachTone.info); // no imminent date → informational
      expect(u.headline, contains('ready to apply'));
    });

    test('scheduled interview near is a safety net + urgent framing', () {
      final u = buildCoachUpdate(sig(
        daysToInterview: 10,
        behavioralStage: BehavioralStage.readyToRehearse,
      ))!;
      expect(u.kind, CoachInsightKind.behavioralPrep);
      expect(u.tone, CoachTone.caution); // ≤14 days
      expect(u.headline, contains('Interview in 10 days'));
    });

    test('does not fire when ready is far out, sharp, or no signal', () {
      expect(
          buildCoachUpdate(sig(
                  daysToReady: 120,
                  behavioralStage: BehavioralStage.readyToRehearse))
              ?.kind,
          isNot(CoachInsightKind.behavioralPrep));
      expect(
          buildCoachUpdate(
                  sig(daysToReady: 20, behavioralStage: BehavioralStage.sharp))
              ?.kind,
          isNot(CoachInsightKind.behavioralPrep));
      expect(
          buildCoachUpdate(sig(behavioralStage: BehavioralStage.notStarted))
              ?.kind,
          isNot(CoachInsightKind.behavioralPrep));
    });

    test('default-absent template timing → no timed behavioral nudge (#107)',
        () {
      // The 35/28-day windows are SWE-template data, not an engine constant. A
      // subject that doesn't configure behavioral timing gets no timed nudge —
      // even ready-soon with an imminent interview and a live stage. The mechanic
      // stays general; only the windows are subject data.
      final u = buildCoachUpdate(sig(
        behavioralForecastDays: null,
        behavioralWindowDays: null,
        daysToReady: 20,
        daysToInterview: 5,
        behavioralStage: BehavioralStage.readyToRehearse,
      ));
      expect(u?.kind, isNot(CoachInsightKind.behavioralPrep));
    });

    test('health/overload still outranks the behavioral nudge', () {
      final u = buildCoachUpdate(sig(
        daysToReady: 20,
        behavioralStage: BehavioralStage.readyToRehearse,
        dueCount: 999, // big backlog
      ))!;
      expect(u.kind, CoachInsightKind.overloaded);
    });
  });

  group('buildCoachUpdate triage', () {
    test('nothing studied → getting-started, before anything else', () {
      // Even with a would-be overload signal, an untouched deck gets "start".
      final u = buildCoachUpdate(
          sig(anyStudied: false, retention: 0.1, dueCount: 999))!;
      expect(u.kind, CoachInsightKind.gettingStarted);
      expect(u.actionRoute, '/learn');
    });

    test('low recent retention → overloaded (ease off new cards)', () {
      final u = buildCoachUpdate(sig(retention: 0.6, reviewsInWindow: 30))!;
      expect(u.kind, CoachInsightKind.overloaded);
      expect(u.tone, CoachTone.caution);
      expect(u.headline, contains('60%'));
      expect(u.actionRoute, '/quiz');
    });

    test('low retention is IGNORED when the sample is too small', () {
      final u = buildCoachUpdate(sig(retention: 0.5, reviewsInWindow: 5))!;
      expect(u.kind, isNot(CoachInsightKind.overloaded));
    });

    test('large due backlog → overloaded (clear backlog)', () {
      // healthy retention, but backlog >= the fixed threshold (60).
      final u = buildCoachUpdate(sig(dueCount: 60))!;
      expect(u.kind, CoachInsightKind.overloaded);
      expect(u.headline, contains('60 reviews'));
    });

    test(
        'backlog threshold is a fixed 60 (new-material load is engine-derived)',
        () {
      // ADR-0011: the coach no longer scales the threshold off a new-card dial.
      expect(buildCoachUpdate(sig(dueCount: 59))!.kind,
          isNot(CoachInsightKind.overloaded));
      expect(buildCoachUpdate(sig(dueCount: 60))!.kind,
          CoachInsightKind.overloaded);
    });

    test('overload outranks being behind (health first)', () {
      final u = buildCoachUpdate(sig(
        retention: 0.6,
        reviewsInWindow: 30,
        paceStatus: PaceStatus.behind,
        requiredPerDay: 12,
        recentPerDay: 4,
      ))!;
      expect(u.kind, CoachInsightKind.overloaded);
    });

    test('behind pace (healthy load) → offers a choice with the rates', () {
      final u = buildCoachUpdate(sig(
        paceStatus: PaceStatus.behind,
        requiredPerDay: 12,
        recentPerDay: 4,
      ))!;
      expect(u.kind, CoachInsightKind.behindPace);
      expect(u.headline, contains('12/day'));
      expect(u.headline, contains('4'));
      expect(u.why.toLowerCase(), contains('your call')); // autonomy-supportive
    });

    test('covered but not mock-tested → unproven, mock the weakest domain', () {
      final u = buildCoachUpdate(sig(interviewTested: false))!;
      expect(u.kind, CoachInsightKind.unproven);
      expect(u.actionLabel, 'Mock System design');
      expect(u.actionRoute, '/practice/system-design');
    });

    test('a subject with no assessment never gets the mock nudge (G7e)', () {
      // Same signals, but the subject declares no assessment → the "prove it
      // with a mock" nudge is silent (nothing to prove it with); it falls
      // through to a generic on-track nudge with no "mock" copy.
      final u =
          buildCoachUpdate(sig(interviewTested: false, hasAssessment: false))!;
      expect(u.kind, isNot(CoachInsightKind.unproven));
      expect(u.kind, CoachInsightKind.onTrack);
      expect(u.why.toLowerCase(), isNot(contains('mock')));
    });

    test('unproven with no weakest domain → no action, still surfaces', () {
      final u = buildCoachUpdate(sig(
        interviewTested: false,
        weakestDomain: null,
        weakestDomainPretty: null,
      ))!;
      expect(u.kind, CoachInsightKind.unproven);
      expect(u.hasAction, isFalse);
    });

    test('low coverage → building, even when mock-tested and nominally on pace',
        () {
      final u = buildCoachUpdate(sig(coverage: 0.1))!;
      expect(u.kind, CoachInsightKind.building);
      expect(u.headline, contains('10%'));
      expect(u.actionRoute, '/learn');
    });

    test(
        'thriving mid-build → readyToPush (informational, points at the budget)',
        () {
      // ADR-0011: no one-tap dial; the engine already fills to the ceiling, so
      // the nudge affirms headroom and points at the daily-budget dial.
      final u =
          buildCoachUpdate(sig(coverage: 0.5, retention: 0.95, dueCount: 0))!;
      expect(u.kind, CoachInsightKind.readyToPush);
      expect(u.tone, CoachTone.positive);
      expect(u.why.toLowerCase(), contains('daily study time'));
    });

    test('no push when not showing up lately (engagement gate)', () {
      final u = buildCoachUpdate(sig(
          coverage: 0.5, retention: 0.95, dueCount: 0, activeRecently: false))!;
      expect(u.kind, isNot(CoachInsightKind.readyToPush));
    });

    test('"too much" feel suppresses the push even when numbers are green', () {
      final u = buildCoachUpdate(sig(
          coverage: 0.5,
          retention: 0.95,
          dueCount: 0,
          loadFeel: LoadFeel.tooMuch))!;
      expect(u.kind, isNot(CoachInsightKind.readyToPush));
    });

    test('"could do more" relaxes the retention bar for a push', () {
      // 0.86 is below the 0.90 bar but clears the relaxed 0.85 bar.
      final u = buildCoachUpdate(sig(
          coverage: 0.5,
          retention: 0.86,
          dueCount: 0,
          loadFeel: LoadFeel.couldDoMore))!;
      expect(u.kind, CoachInsightKind.readyToPush);
    });

    test('check-in (enabled+due) surfaces on a calm day', () {
      final u = buildCoachUpdate(sig(coverage: 0.5, checkInDue: true))!;
      expect(u.kind, CoachInsightKind.loadCheckin);
    });

    test('check-in waits behind a backlog (health first)', () {
      final u = buildCoachUpdate(sig(
          checkInDue: true,
          dueCount: 90,
          retention: 0.6,
          reviewsInWindow: 30))!;
      expect(u.kind, CoachInsightKind.overloaded);
    });

    test('only-ok retention while building → plain building, no push', () {
      final u =
          buildCoachUpdate(sig(coverage: 0.5, retention: 0.85, dueCount: 0))!;
      expect(u.kind, CoachInsightKind.building);
    });

    test('no push with a backlog (health first)', () {
      final u =
          buildCoachUpdate(sig(coverage: 0.5, retention: 0.95, dueCount: 3))!;
      expect(u.kind, isNot(CoachInsightKind.readyToPush));
    });

    test('algorithms due → surfaces the re-solve nudge to /algorithms', () {
      final u = buildCoachUpdate(sig(algoDue: 4))!;
      expect(u.kind, CoachInsightKind.algoDue);
      expect(u.headline, contains('4 algorithms'));
      expect(u.actionRoute, '/algorithms');
    });

    test('building the base outranks due algorithms', () {
      final u = buildCoachUpdate(sig(coverage: 0.1, algoDue: 5))!;
      expect(u.kind, CoachInsightKind.building);
    });

    test('due algorithms outrank the mock nudge', () {
      final u = buildCoachUpdate(sig(algoDue: 2, interviewTested: false))!;
      expect(u.kind, CoachInsightKind.algoDue);
    });

    test('health (overload) still outranks due algorithms', () {
      final u = buildCoachUpdate(
          sig(algoDue: 9, retention: 0.6, reviewsInWindow: 30))!;
      expect(u.kind, CoachInsightKind.overloaded);
    });

    test('explain-due (no solves due) → phone-doable explain nudge', () {
      final u = buildCoachUpdate(sig(algoExplainDue: 3))!;
      expect(u.kind, CoachInsightKind.explainDue);
      expect(u.headline, contains('3 patterns'));
      expect(u.actionRoute, '/algorithms');
    });

    test('due solves outrank due explains (solve is the stronger mode)', () {
      final u = buildCoachUpdate(sig(algoDue: 1, algoExplainDue: 5))!;
      expect(u.kind, CoachInsightKind.algoDue);
    });

    test('building (learn the base) outranks unproven', () {
      final u = buildCoachUpdate(sig(coverage: 0.1, interviewTested: false))!;
      expect(u.kind, CoachInsightKind.building);
      expect(u.actionRoute, '/learn');
    });

    test('barely studied + no date is "building", NOT "on track"', () {
      // The reported bug: one day of progress then a big clock jump.
      final u = buildCoachUpdate(sig(
        coverage: 0.07,
        overall: 0.1,
        paceStatus: null,
      ))!;
      expect(u.kind, CoachInsightKind.building);
      expect(u.kind, isNot(CoachInsightKind.onTrack));
    });

    test(
        'covered but soft readiness + no date → deepen with review, not affirm',
        () {
      final u = buildCoachUpdate(sig(
        coverage: 0.9,
        overall: 0.3,
        paceStatus: null,
        dueCount: 5,
      ))!;
      expect(u.kind, CoachInsightKind.building);
      expect(u.headline.toLowerCase(), contains('deepen'));
      expect(u.actionRoute, '/quiz');
    });

    test('on pace for a set date affirms even at early readiness', () {
      final u = buildCoachUpdate(sig(
        coverage: 0.9,
        overall: 0.2,
        paceStatus: PaceStatus.onTrack,
      ))!;
      expect(u.kind, CoachInsightKind.onTrack);
    });

    test('solid readiness (no date) affirms', () {
      final u =
          buildCoachUpdate(sig(coverage: 0.9, overall: 0.6, paceStatus: null))!;
      expect(u.kind, CoachInsightKind.onTrack);
    });

    test('healthy + mock-tested → on-track affirmation', () {
      final u = buildCoachUpdate(sig())!;
      expect(u.kind, CoachInsightKind.onTrack);
      expect(u.tone, CoachTone.positive);
    });

    test('on-track affirmation rotates with the seed', () {
      final a = buildCoachUpdate(sig(affirmSeed: 0))!.headline;
      final b = buildCoachUpdate(sig(affirmSeed: 1))!.headline;
      expect(a, isNot(b));
    });

    test('on-track but not studied today nudges a quick session', () {
      final u = buildCoachUpdate(sig(studiedToday: false))!;
      expect(u.kind, CoachInsightKind.onTrack);
      expect(u.headline.toLowerCase(), contains('today'));
    });

    test('on-track surfaces a review action only when reviews are due', () {
      expect(buildCoachUpdate(sig(dueCount: 0))!.hasAction, isFalse);
      final withDue = buildCoachUpdate(sig(dueCount: 5))!;
      expect(withDue.actionRoute, '/quiz');
    });
  });
}
