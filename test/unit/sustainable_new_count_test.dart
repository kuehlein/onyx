import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/practice_plan.dart';

/// The derived new-material ceiling (task #114 Phase B · ADR-0016): the daily new
/// count = min(time bound, review-debt bound, cognitive hard-max), over the
/// retention floor. Pure — these lock the *shape* (the constants are a tunable
/// calibration, validated later by telemetry #122). Default params throughout unless
/// a bound is being isolated.
void main() {
  group('sustainableNewCount', () {
    test('a default day lands at the gentle 8 (the Phase-A hold)', () {
      // 150-min budget, reviews taking half the day (75 min) → floor(0.32·75/3)=8.
      expect(
        sustainableNewCount(budgetMinutes: 150, dueReviewMinutes: 75),
        kDefaultDailyNew,
      );
      expect(kDefaultDailyNew, 8);
    });

    test('a heavy-review day sheds new material (reviews eat the remainder)',
        () {
      // A big backlog: reviews are capped at the retention floor (0.8·150=120),
      // leaving 30 min → floor(0.32·30/3)=3. New is shed, not the reviews.
      expect(
        sustainableNewCount(budgetMinutes: 150, dueReviewMinutes: 200),
        3,
      );
    });

    test(
        'the retention-floor cap keeps a sliver for new even under a monster '
        'backlog', () {
      // Even 1000 min of due reviews can only claim 0.8·150=120; the remaining 30
      // min still buys 3 new — new is throttled, never fully starved on-budget.
      expect(
        sustainableNewCount(budgetMinutes: 150, dueReviewMinutes: 1000),
        3,
      );
    });

    test('a light day rises above the default but the debt bound caps it', () {
      // Only 15 min of reviews → time bound would allow floor(0.32·135/3)=14, but
      // the review-debt bound (150/12=12) caps front-loading at 12.
      expect(
        sustainableNewCount(budgetMinutes: 150, dueReviewMinutes: 15),
        12,
      );
    });

    test(
        'a brand-new deck (no reviews yet) is held by the debt bound, not the '
        'whole budget', () {
      // No due reviews → time bound floor(0.32·150/3)=16, but debt caps at 12 so a
      // beginner does not front-load a firehose that spikes review-debt in 2 weeks.
      expect(
        sustainableNewCount(budgetMinutes: 150, dueReviewMinutes: 0),
        12,
      );
    });

    test('a bigger budget buys more new — the "more budget → sooner" lever',
        () {
      // Same deck (75 min reviews), budget 150→240: floor(0.32·165/3)=17 > 8.
      expect(
        sustainableNewCount(budgetMinutes: 240, dueReviewMinutes: 75),
        17,
      );
    });

    test('the cognitive hard-max caps a very large budget', () {
      // 360-min budget: time (30) and debt (30) both exceed the hard-max → 20.
      expect(
        sustainableNewCount(budgetMinutes: 360, dueReviewMinutes: 75),
        kNewHardMax,
      );
      expect(kNewHardMax, 20);
    });

    test('an ease-in day (small budget) stays gentle', () {
      // 90-min ease-in, new deck: debt bound 90/12=7 binds under the time bound (9).
      expect(
        sustainableNewCount(budgetMinutes: 90, dueReviewMinutes: 0),
        7,
      );
    });

    test('zero or negative budget → no new material', () {
      expect(sustainableNewCount(budgetMinutes: 0, dueReviewMinutes: 0), 0);
      expect(sustainableNewCount(budgetMinutes: -5, dueReviewMinutes: 0), 0);
    });

    test('non-decreasing in budget (a bigger day never gives less new)', () {
      var prev = -1;
      for (final b in [60.0, 90.0, 120.0, 150.0, 240.0, 360.0]) {
        final n = sustainableNewCount(budgetMinutes: b, dueReviewMinutes: 0);
        expect(n, greaterThanOrEqualTo(prev),
            reason: 'budget $b gave $n after $prev');
        prev = n;
      }
    });

    test(
        'cheaper cards do not become a firehose — the debt + cognitive bounds '
        'hold', () {
      // Cards 3× cheaper (costPerNew 1): the TIME bound would explode
      // (floor(0.32·150/1)=48), but at the default budget the debt bound still
      // caps at 12, and on a big budget the cognitive hard-max holds at 20. So a
      // trivial-card deck can intake a bit more, never a flood.
      expect(
        sustainableNewCount(
            budgetMinutes: 150, dueReviewMinutes: 0, costPerNew: 1),
        12,
      );
      expect(
        sustainableNewCount(
            budgetMinutes: 360, dueReviewMinutes: 0, costPerNew: 1),
        kNewHardMax,
      );
    });
  });
}
