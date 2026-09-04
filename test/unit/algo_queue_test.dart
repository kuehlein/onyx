import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/srs/algo_queue.dart';
import 'package:onyx/shared/models/card.dart';

Card _pattern(String id, List<String> problems) => Card(
      id: id,
      type: CardType.algorithm,
      title: id,
      overview: '',
      tags: const ['ds-a'],
      tiers: const {},
      sections: [
        for (final p in problems)
          CardSection(heading: p, slug: p, content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  final today = DateTime(2026, 9, 4);
  final cards = [
    _pattern('arrays', ['two-sum', 'contains-dup', 'product']),
    _pattern('stack', ['valid-parens']),
  ];

  test('fills the goal with due re-solves first, most-overdue first', () {
    final q = buildAlgoQueue(
      cards: cards,
      dueByKey: {
        'arrays::two-sum': DateTime(2026, 9, 1), // overdue 3d
        'arrays::contains-dup': DateTime(2026, 9, 3), // overdue 1d
        'stack::valid-parens': DateTime(2026, 10, 1), // not due
      },
      now: today,
      goal: 3,
    );
    // Two due (most-overdue first), then one new to fill the goal of 3.
    expect(q.map((e) => e.section.slug).toList(),
        ['two-sum', 'contains-dup', 'product']);
  });

  test('caps at the daily goal even when more are due', () {
    final q = buildAlgoQueue(
      cards: cards,
      dueByKey: {
        'arrays::two-sum': DateTime(2026, 9, 1),
        'arrays::contains-dup': DateTime(2026, 9, 2),
        'arrays::product': DateTime(2026, 9, 3),
        'stack::valid-parens': DateTime(2026, 9, 3),
      },
      now: today,
      goal: 2,
    );
    expect(q.length, 2);
    expect(q.map((e) => e.section.slug).toList(), ['two-sum', 'contains-dup']);
  });

  test('all-new deck introduces problems in progression order', () {
    final q = buildAlgoQueue(
      cards: cards,
      dueByKey: const {},
      now: today,
      goal: 3,
    );
    expect(q.map((e) => e.section.slug).toList(),
        ['two-sum', 'contains-dup', 'product']);
  });

  test('ignores non-algorithm cards', () {
    const concept = Card(
      id: 'bfs',
      type: CardType.flashcard,
      title: 'BFS',
      overview: '',
      tags: ['ds-a'],
      tiers: {},
      sections: [
        CardSection(heading: 'k', slug: 'k', content: 'x', quizzable: true),
      ],
      wikilinks: [],
      filePath: 'bfs.md',
    );
    final q = buildAlgoQueue(
        cards: [concept], dueByKey: const {}, now: today, goal: 5);
    expect(q, isEmpty);
  });
}
