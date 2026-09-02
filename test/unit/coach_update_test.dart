import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/coach/coach_update.dart';
import 'package:onyx/core/readiness/pace.dart';

/// A healthy, on-track, mock-tested learner — override fields per test.
CoachSignals sig({
  bool anyStudied = true,
  bool studiedToday = true,
  bool interviewTested = true,
  int dueCount = 0,
  int newCardLimit = 20,
  int reviewsInWindow = 30,
  double? retention = 0.9,
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
      overall: 0.6,
      interviewTested: interviewTested,
      dueCount: dueCount,
      newCardLimit: newCardLimit,
      reviewsInWindow: reviewsInWindow,
      retention: retention,
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
