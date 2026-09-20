import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/practice/mock_schedule.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(String id) => Card(
      id: id,
      type: 'system-design',
      title: id,
      overview: '',
      tags: const ['system-design'],
      tiers: const {},
      sections: const [],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  group('orderByMockDue', () {
    final now = DateTime(2026, 9, 20, 12);

    test('overdue first (most overdue first), then never, then upcoming', () {
      final overdueSoon = _card('overdue-soon'); // 1 day overdue
      final overdueOld = _card('overdue-old'); // 5 days overdue
      final never = _card('never');
      final upcomingSoon = _card('upcoming-soon'); // due in 2 days
      final upcomingFar = _card('upcoming-far'); // due in 10 days

      final due = {
        'overdue-soon': now.subtract(const Duration(days: 1)),
        'overdue-old': now.subtract(const Duration(days: 5)),
        'upcoming-soon': now.add(const Duration(days: 2)),
        'upcoming-far': now.add(const Duration(days: 10)),
      };

      // Input deliberately shuffled to prove ordering isn't incidental.
      final ordered = orderByMockDue(
        [upcomingFar, never, overdueSoon, upcomingSoon, overdueOld],
        now,
        (c) => due[c.id],
      );

      expect(
        ordered.map((c) => c.id),
        [
          'overdue-old', // most overdue first
          'overdue-soon',
          'never', // never-mocked bucket
          'upcoming-soon', // upcoming, soonest first
          'upcoming-far',
        ],
      );
    });

    test('title breaks ties among never-mocked cards', () {
      final ordered = orderByMockDue(
        [_card('charlie'), _card('alpha'), _card('bravo')],
        now,
        (_) => null,
      );
      expect(ordered.map((c) => c.id), ['alpha', 'bravo', 'charlie']);
    });

    test('is pure — leaves the input list untouched', () {
      final input = [_card('b'), _card('a')];
      final before = [...input];
      orderByMockDue(input, now, (_) => null);
      expect(input.map((c) => c.id), before.map((c) => c.id));
    });

    test('due exactly now counts as overdue, not upcoming', () {
      final atNow = _card('at-now');
      final future = _card('future');
      final ordered = orderByMockDue(
        [future, atNow],
        now,
        (c) => c.id == 'at-now' ? now : now.add(const Duration(days: 3)),
      );
      expect(ordered.map((c) => c.id), ['at-now', 'future']);
    });
  });
}
