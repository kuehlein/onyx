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
}
