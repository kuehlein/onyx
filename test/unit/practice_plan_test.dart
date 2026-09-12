import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/practice_plan.dart';

void main() {
  group('algoEstMinutes', () {
    test('derives from difficulty in the section, defaulting to medium', () {
      expect(algoEstMinutes('[Solve on LeetCode](x) · Easy\n\n**Problem.** …'),
          12);
      expect(algoEstMinutes('[Solve](x) · Medium'), 25);
      expect(algoEstMinutes('[Solve](x) · Hard'), 40);
      expect(algoEstMinutes('no difficulty here'), 25);
    });
  });

  group('TrackAvailability', () {
    PracticeUnit u(double m) => PracticeUnit(
        track: TrackId.algorithms, id: 'c::s', label: 'x', estMinutes: m);

    test('sums estimated minutes and counts units', () {
      const t = TrackId.algorithms;
      final a = TrackAvailability(track: t, units: [u(10), u(25), u(40)]);
      expect(a.count, 3);
      expect(a.totalEstMinutes, 75);
    });

    test('take() caps the unit list', () {
      final a = TrackAvailability(
          track: TrackId.review, units: [u(1), u(1), u(1), u(1)]);
      expect(a.take(2).length, 2);
      expect(a.take(10).length, 4);
    });
  });

  group('TrackId labels', () {
    test('are human-readable', () {
      expect(TrackId.systemDesign.label, 'System design');
      expect(TrackId.review.label, 'Review');
    });
  });
}
