import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/srs/learn_queue.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(String id,
        {required int tier,
        required List<String> slugs,
        String domain = 'd'}) =>
    Card(
      id: id,
      type: CardType.flashcard,
      title: id,
      overview: '',
      tags: [domain],
      tiers: {domain: tier},
      sections: [
        for (final s in slugs)
          CardSection(heading: s, slug: s, content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  group('buildLearnQueue', () {
    test('only un-seeded quizzable sections, tier-ordered when unlinked', () {
      final cards = [
        _card('A', tier: 1, slugs: ['s1', 's2']),
        _card('B', tier: 2, slugs: ['s1']),
      ];
      final queue = buildLearnQueue(
        cards: cards,
        seededKeys: {'A::s1'}, // already learned -> excluded
        adjacency: const {},
      );
      // A::s1 excluded; A (tier 1) before B (tier 2).
      expect(queue.map((i) => i.key), ['A::s2', 'B::s1']);
    });

    test('groups linked cards into a family and learns it together', () {
      final cards = [
        _card('A', tier: 2, slugs: ['s1']),
        _card('C', tier: 1, slugs: ['s1']),
        _card('B', tier: 1, slugs: ['s1']), // isolated
      ];
      // A <-> C form a family; B is alone.
      final queue = buildLearnQueue(
        cards: cards,
        seededKeys: const {},
        adjacency: {
          'A': {'C'},
          'C': {'A'},
        },
      );
      // Family {A,C} (size 2) before singleton {B}; within family, tier asc: C,A.
      expect(queue.map((i) => i.card.id), ['C', 'A', 'B']);
    });

    test('caps at newSectionLimit', () {
      final cards = [
        _card('A', tier: 1, slugs: List.generate(10, (i) => 's$i')),
      ];
      final queue = buildLearnQueue(
        cards: cards,
        seededKeys: const {},
        adjacency: const {},
        newSectionLimit: 4,
      );
      expect(queue.length, 4);
    });

    test('priorityOf breaks ties among equally-foundational families', () {
      // Two tier-1 singletons in different domains. Target-relevance decides.
      final sd = _card('sd', tier: 1, slugs: ['s1'], domain: 'system-design');
      final algo = _card('algo', tier: 1, slugs: ['s1'], domain: 'ds-a');
      final queue = buildLearnQueue(
        cards: [algo, sd], // input order puts algo first
        seededKeys: const {},
        adjacency: const {},
        priorityOf: (c) => c.domain == 'system-design' ? 2.0 : 1.0,
      );
      // Same tier, so the higher-target-weight domain wins.
      expect(queue.first.card.id, 'sd');
    });

    test('priorityOf is SECONDARY — foundational tier still wins', () {
      // A tier-1 low-priority card must precede a tier-2 high-priority one.
      final basic = _card('basic', tier: 1, slugs: ['s1'], domain: 'ds-a');
      final advanced =
          _card('advanced', tier: 2, slugs: ['s1'], domain: 'system-design');
      final queue = buildLearnQueue(
        cards: [advanced, basic],
        seededKeys: const {},
        adjacency: const {},
        priorityOf: (c) => c.domain == 'system-design' ? 5.0 : 1.0,
      );
      expect(queue.first.card.id, 'basic'); // tier beats priority
    });

    test('a fully-seeded card is not learnable', () {
      final cards = [
        _card('A', tier: 1, slugs: ['s1'])
      ];
      final queue = buildLearnQueue(
        cards: cards,
        seededKeys: {'A::s1'},
        adjacency: const {},
      );
      expect(queue, isEmpty);
    });
  });

  group('isPretestSection', () {
    test('conditional headings pretest; declarative ones are read', () {
      expect(isPretestSection('When to Use'), isTrue);
      expect(isPretestSection('Common Pitfalls'), isTrue);
      expect(isPretestSection('Approach'), isTrue);
      expect(isPretestSection('Key Properties'), isFalse);
      expect(isPretestSection('Time & Space Complexity'), isFalse);
    });
  });
}
