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

List<String> _slugs(List<AlgoTask> q) =>
    q.map((e) => e.item.section.slug).toList();

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
    expect(_slugs(q), ['two-sum', 'contains-dup', 'product']);
    // Due re-solves and new problems both nudge toward solving.
    expect(q.every((t) => t.mode == AlgoMode.solve), isTrue);
    expect(q[0].reason, 'Due for a re-solve');
    expect(q[2].reason, 'New problem');
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
    expect(_slugs(q), ['two-sum', 'contains-dup']);
  });

  test('all-new deck introduces problems in progression order', () {
    final q = buildAlgoQueue(
      cards: cards,
      dueByKey: const {},
      now: today,
      goal: 3,
    );
    expect(_slugs(q), ['two-sum', 'contains-dup', 'product']);
  });

  test('explain-due problems (solve not due) surface as explain, after solves',
      () {
    final q = buildAlgoQueue(
      cards: [
        _pattern('arrays', ['two-sum', 'contains-dup', 'product'])
      ],
      dueByKey: {
        'arrays::two-sum': DateTime(2026, 9, 1), // solve due
        'arrays::contains-dup': DateTime(2026, 10, 1), // solve not due
        // 'product' has no solve state → it's new.
      },
      explainDueByKey: {
        'arrays::contains-dup': DateTime(2026, 9, 2), // explain due
      },
      now: today,
      goal: 5,
    );
    // solve-due first, then the explain-due one, then the new problem.
    expect(_slugs(q), ['two-sum', 'contains-dup', 'product']);
    expect(q[0].mode, AlgoMode.solve);
    expect(q[1].mode, AlgoMode.explain);
    expect(q[1].reason, 'Due to explain');
    expect(q[2].mode, AlgoMode.solve); // new
  });

  test('solve wins ties: a problem due on both clocks appears once, as solve',
      () {
    final q = buildAlgoQueue(
      cards: [
        _pattern('arrays', ['two-sum'])
      ],
      dueByKey: {'arrays::two-sum': DateTime(2026, 9, 1)},
      explainDueByKey: {'arrays::two-sum': DateTime(2026, 9, 1)},
      now: today,
      goal: 5,
    );
    expect(q.length, 1);
    expect(q.single.mode, AlgoMode.solve);
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
