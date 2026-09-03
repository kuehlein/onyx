import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/analytics/insights.dart';

void main() {
  group('computeMockSkills', () {
    test('averages score, hints, novel %, and each rubric dimension', () {
      final m = computeMockSkills([
        (
          appliedScore: 80,
          hintLevel: 1,
          novel: true,
          rubric: {'correctness': 4, 'complexity': 2}
        ),
        (
          appliedScore: 60,
          hintLevel: 3,
          novel: false,
          rubric: {'correctness': 2}
        ),
      ]);
      expect(m.count, 2);
      expect(m.avgScore, 70);
      expect(m.avgHintLevel, 2);
      expect(m.novelFraction, 0.5);
      expect(m.dims['correctness'], 3); // (4+2)/2
      expect(m.dims['complexity'], 2); // only one attempt scored it
    });

    test('empty attempts → isEmpty', () {
      expect(computeMockSkills(const []).isEmpty, isTrue);
    });
  });

  group('computeDueForecast', () {
    final today = DateTime(2026, 9, 3);
    test('buckets by day offset; overdue folds into today', () {
      final f = computeDueForecast(
        dueDates: [
          DateTime(2026, 8, 20), // overdue → day 0
          DateTime(2026, 9, 3), // today → day 0
          DateTime(2026, 9, 5), // +2
          DateTime(2026, 9, 5, 23), // +2 (same day)
          DateTime(2026, 10, 1), // +28 → beyond window, dropped
        ],
        today: today,
        days: 14,
      );
      expect(f.length, 14);
      expect(f[0], 2); // overdue + today
      expect(f[2], 2);
      expect(f.fold(0, (a, b) => a + b), 4); // the +28 one is out of range
    });
  });

  group('topStruggling', () {
    test('keeps cards at/over the lapse threshold, most-failed first', () {
      final s = topStruggling(
        [
          (cardId: 'a', lapses: 5, total: 12),
          (cardId: 'b', lapses: 1, total: 3), // below threshold
          (cardId: 'c', lapses: 3, total: 8),
        ],
        {'a': 'Dijkstra', 'c': 'Two-pointer'},
        minLapses: 2,
      );
      expect(s.map((e) => e.cardId), ['a', 'c']);
      expect(s.first.title, 'Dijkstra');
      expect(s.first.lapses, 5);
    });

    test('falls back to the id when the title is unknown', () {
      final s = topStruggling(
        [(cardId: 'x', lapses: 2, total: 4)],
        const {},
      );
      expect(s.single.title, 'x');
    });
  });

  group('computeConsistency', () {
    final today = DateTime(2026, 9, 3);
    test('counts events per day, oldest first and today last', () {
      final c = computeConsistency(
        events: [
          DateTime(2026, 9, 3, 9), // today
          DateTime(2026, 9, 3, 20), // today
          DateTime(2026, 9, 1), // 2 days ago
          DateTime(2026, 8, 1), // >7 days ago → out of range
        ],
        today: today,
        days: 7,
      );
      expect(c.length, 7);
      expect(c.last, 2); // today
      expect(c[7 - 1 - 2], 1); // two days ago
      expect(c.fold(0, (a, b) => a + b), 3); // the Aug 1 event is out of range
    });
  });
}
