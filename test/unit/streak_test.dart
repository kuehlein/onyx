import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/stats/streak.dart';

void main() {
  final today = DateTime(2026, 8, 30);
  DateTime at(int daysAgo, [int hour = 12]) =>
      DateTime(today.year, today.month, today.day - daysAgo, hour);

  group('computeStreak', () {
    test('no activity → empty', () {
      final s = computeStreak(timestamps: const [], today: today);
      expect(s.current, 0);
      expect(s.best, 0);
      expect(s.studiedToday, isFalse);
      expect(s.todayCount, 0);
    });

    test('today + prior consecutive days count up', () {
      final s = computeStreak(
        timestamps: [at(0), at(1), at(2)],
        today: today,
      );
      expect(s.current, 3);
      expect(s.studiedToday, isTrue);
      expect(s.todayCount, 1);
      expect(s.best, 3);
    });

    test('multiple actions today count once for the day, N for today', () {
      final s = computeStreak(
        timestamps: [at(0, 9), at(0, 20), at(1)],
        today: today,
      );
      expect(s.current, 2);
      expect(s.todayCount, 2);
    });

    test('a missed yesterday resets the run to just today', () {
      final s = computeStreak(timestamps: [at(0), at(2)], today: today);
      expect(s.current, 1);
      expect(s.studiedToday, isTrue);
    });

    test('streak stays alive from yesterday when nothing yet today', () {
      final s = computeStreak(
        timestamps: [at(1), at(2), at(3)],
        today: today,
      );
      expect(s.studiedToday, isFalse);
      expect(s.current, 3); // still alive; today can extend it
    });

    test('streak is broken when neither today nor yesterday has activity', () {
      final s = computeStreak(timestamps: [at(2), at(3)], today: today);
      expect(s.current, 0);
      expect(s.studiedToday, isFalse);
      expect(s.best, 2);
    });

    test('best captures the longest past run, not the current one', () {
      // A 4-run a while ago, a 1 today.
      final s = computeStreak(
        timestamps: [at(10), at(11), at(12), at(13), at(0)],
        today: today,
      );
      expect(s.current, 1);
      expect(s.best, 4);
    });
  });
}
