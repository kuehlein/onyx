import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/coach/coach_update.dart';
import 'package:onyx/core/readiness/pace.dart';

/// A healthy, well-covered, on-track, mock-tested learner — override per test.
CoachSignals sig({
  bool anyStudied = true,
  bool studiedToday = true,
  bool interviewTested = true,
  double overall = 0.6,
  double coverage = 0.9,
  int dueCount = 0,
  int newCardLimit = 20,
  int reviewsInWindow = 30,
  double? retention = 0.9,
  int algoDue = 0,
  PaceStatus? paceStatus = PaceStatus.onTrack,
  double? recentPerDay = 5,
  double? requiredPerDay = 5,
  String? weakestDomain = 'system-design',
  String? weakestDomainPretty = 'System design',
  int affirmSeed = 0,
}) =>
    CoachSignals(
      anyStudied: anyStudied,
      studiedToday: studiedToday,
      overall: overall,
      coverage: coverage,
      interviewTested: interviewTested,
      dueCount: dueCount,
      newCardLimit: newCardLimit,
      reviewsInWindow: reviewsInWindow,
      retention: retention,
      algoDue: algoDue,
      paceStatus: paceStatus,
      recentPerDay: recentPerDay,
      requiredPerDay: requiredPerDay,
      weakestDomain: weakestDomain,
      weakestDomainPretty: weakestDomainPretty,
      affirmSeed: affirmSeed,
    );

void main() {
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
      // healthy retention, but backlog >= max(60, 3*limit)
      final u = buildCoachUpdate(sig(dueCount: 60, newCardLimit: 20))!;
      expect(u.kind, CoachInsightKind.overloaded);
      expect(u.headline, contains('60 reviews'));
    });

    test('backlog threshold scales with new-card load', () {
      // 3*30 = 90; 80 due is below threshold → not a backlog overload.
      expect(buildCoachUpdate(sig(dueCount: 80, newCardLimit: 30))!.kind,
          isNot(CoachInsightKind.overloaded));
      expect(buildCoachUpdate(sig(dueCount: 90, newCardLimit: 30))!.kind,
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
