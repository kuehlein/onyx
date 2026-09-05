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

  test('due re-solves first (most-overdue first), then new problems to the min',
      () {
    final q = buildAlgoQueue(
      cards: cards,
      dueByKey: {
        'arrays::two-sum': DateTime(2026, 9, 1), // overdue 3d
        'arrays::contains-dup': DateTime(2026, 9, 3), // overdue 1d
        'stack::valid-parens': DateTime(2026, 10, 1), // not due
      },
      now: today,
      min: 3,
      max: 5,
    );
    // Two due (most-overdue first), then one new to reach the floor of 3.
    expect(_slugs(q), ['two-sum', 'contains-dup', 'product']);
    expect(q.every((t) => t.mode == AlgoMode.solve), isTrue);
    expect(q[0].reason, 'Due for a re-solve');
    expect(q[2].reason, 'New problem');
  });

  test('caps at the max even when more are due', () {
    final q = buildAlgoQueue(
      cards: cards,
      dueByKey: {
        'arrays::two-sum': DateTime(2026, 9, 1),
        'arrays::contains-dup': DateTime(2026, 9, 2),
        'arrays::product': DateTime(2026, 9, 3),
        'stack::valid-parens': DateTime(2026, 9, 3),
      },
      now: today,
      min: 2,
      max: 2,
    );
    expect(q.length, 2);
    expect(_slugs(q), ['two-sum', 'contains-dup']);
  });

  test('new problems fill only to the min, not the max', () {
    // No due work; only the floor of new problems is introduced (steady intake).
    final q = buildAlgoQueue(
      cards: cards,
      dueByKey: const {},
      now: today,
      min: 2,
      max: 5,
    );
    expect(_slugs(q), ['two-sum', 'contains-dup']); // floor of 2, not 5
    expect(q.every((t) => t.reason == 'New problem'), isTrue);
  });

  test('explain-due fills leftover capacity after the new-problem floor', () {
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
      min: 2,
      max: 5,
    );
    // due-solve → new-to-floor(2) → explain fills the rest.
    expect(q[0].item.section.slug, 'two-sum');
    expect(q[0].mode, AlgoMode.solve);
    expect(q[1].item.section.slug, 'product');
    expect(q[1].mode, AlgoMode.solve); // new, to reach the floor of 2
    expect(q[2].item.section.slug, 'contains-dup');
    expect(q[2].mode, AlgoMode.explain);
    expect(q[2].reason, 'Due to explain');
  });

  test('pulls upcoming re-solves forward when the deck is exhausted below min',
      () {
    // Every problem already solved & scheduled in the future; nothing due, no
    // new. The floor is met by pulling the soonest-due re-solves forward.
    final q = buildAlgoQueue(
      cards: [
        _pattern('arrays', ['two-sum', 'contains-dup', 'product'])
      ],
      dueByKey: {
        'arrays::two-sum': DateTime(2026, 9, 8), // +4d (soonest)
        'arrays::contains-dup': DateTime(2026, 9, 20), // +16d
        'arrays::product': DateTime(2026, 9, 30), // +26d
      },
      now: today,
      min: 2,
      max: 5,
    );
    expect(q.length, 2); // pulled to the floor, not the whole deck
    expect(_slugs(q), ['two-sum', 'contains-dup']); // soonest-due first
    expect(q.every((t) => t.reason == 'Practicing ahead'), isTrue);
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
      min: 1,
      max: 5,
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
        cards: [concept], dueByKey: const {}, now: today, min: 2, max: 5);
    expect(q, isEmpty);
  });
}
