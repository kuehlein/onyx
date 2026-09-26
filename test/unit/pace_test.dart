import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/pace.dart';

void main() {
  final today = DateTime(2026, 9, 1);
  DateTime inDays(int n) => today.add(Duration(days: n));

  group('computePace', () {
    test('coverage complete when nothing remains', () {
      final p = computePace(
        today: today,
        interviewDate: inDays(30),
        remainingSections: 0,
        recentPerDay: 2,
      );
      expect(p.status, PaceStatus.coverageComplete);
      expect(p.daysLeft, 30);
    });

    test('not started when a date is set but no recent studying', () {
      final p = computePace(
        today: today,
        interviewDate: inDays(20),
        remainingSections: 40,
        recentPerDay: 0,
      );
      expect(p.status, PaceStatus.notStarted);
      expect(p.requiredPerDay, closeTo(2.0, 1e-9));
    });

    test('on track when recent rate meets the required rate', () {
      final p = computePace(
        today: today,
        interviewDate: inDays(20),
        remainingSections: 40, // 2/day required
        recentPerDay: 2.2,
      );
      expect(p.status, PaceStatus.onTrack);
    });

    test('slightly behind between 60% and 95% of required', () {
      final p = computePace(
        today: today,
        interviewDate: inDays(20),
        remainingSections: 40, // 2/day required
        recentPerDay: 1.5, // 75%
      );
      expect(p.status, PaceStatus.slightlyBehind);
    });

    test('behind below 60% of required', () {
      final p = computePace(
        today: today,
        interviewDate: inDays(20),
        remainingSections: 40, // 2/day required
        recentPerDay: 0.5, // 25%
      );
      expect(p.status, PaceStatus.behind);
    });

    test('past-due date treats the whole remainder as due now', () {
      final p = computePace(
        today: today,
        interviewDate: inDays(-3),
        remainingSections: 10,
        recentPerDay: 1,
      );
      expect(p.daysLeft, 0);
      expect(p.requiredPerDay, 10);
      expect(p.status, PaceStatus.behind);
    });
  });

  group('recentPaceDenominator', () {
    test('no history → the full window (plan-based outlook, not a spike)', () {
      expect(recentPaceDenominator(firstLearnDate: null, today: today), 14);
      expect(
          recentPaceDenominator(firstLearnDate: null, today: today, window: 30),
          30);
    });

    test('short history uses the ACTUAL days, not a flat window', () {
      // 5 days in → denom 5, so 10 started sections read as 2/day (not 10/14).
      expect(
          recentPaceDenominator(firstLearnDate: inDays(-5), today: today), 5);
    });

    test('history at/over the window clamps down to it', () {
      expect(
          recentPaceDenominator(firstLearnDate: inDays(-14), today: today), 14);
      expect(
          recentPaceDenominator(firstLearnDate: inDays(-40), today: today), 14);
    });

    test('a same-day first learn clamps up to 1 (never divides by zero)', () {
      expect(recentPaceDenominator(firstLearnDate: today, today: today), 1);
    });

    test('is date-only — ignores the first-learn time of day', () {
      expect(
          recentPaceDenominator(
              firstLearnDate: inDays(-5).add(const Duration(hours: 14)),
              today: today),
          5);
    });
  });
}
