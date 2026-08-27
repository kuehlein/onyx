import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/srs/review_queue.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(String id, String domain, List<String> sectionSlugs) => Card(
      id: id,
      type: CardType.flashcard,
      title: id,
      overview: '',
      tags: [domain],
      tiers: const {},
      sections: [
        for (final s in sectionSlugs)
          CardSection(heading: s, slug: s, content: 'body', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  final now = DateTime(2026, 1, 10, 12);

  group('buildReviewQueue', () {
    test('includes due and new sections, excludes not-yet-due', () {
      final cards = [
        _card('A', 'a', ['s1', 's2']),
        _card('B', 'b', ['s1']),
        _card('C', 'c', ['s1']),
      ];
      final dueByKey = {
        'A::s1': now.subtract(const Duration(days: 1)), // due
        'C::s1': now.add(const Duration(days: 1)), // not yet due -> excluded
        // A::s2 and B::s1 absent -> new
      };

      final queue =
          buildReviewQueue(cards: cards, dueByKey: dueByKey, now: now);
      final keys = queue.map((i) => i.key).toSet();

      expect(keys, {'A::s1', 'A::s2', 'B::s1'});
      expect(keys.contains('C::s1'), isFalse);
      expect(queue.firstWhere((i) => i.key == 'A::s1').isNew, isFalse);
      expect(queue.firstWhere((i) => i.key == 'B::s1').isNew, isTrue);
    });

    test('interleaves across domains', () {
      final cards = [
        _card('A', 'a', ['s1', 's2', 's3']),
        _card('B', 'b', ['s1']),
      ];
      final queue =
          buildReviewQueue(cards: cards, dueByKey: const {}, now: now);
      final domains = queue.map((i) => i.card.domain).toList();

      // Round-robin: a, b, a, a (b's single item lands second, not last).
      expect(domains, ['a', 'b', 'a', 'a']);
    });

    test('caps new items at newLimit', () {
      final cards = [
        _card('A', 'a', List.generate(20, (i) => 's$i')),
      ];
      final queue = buildReviewQueue(
        cards: cards,
        dueByKey: const {},
        now: now,
        newLimit: 5,
      );
      expect(queue.length, 5);
      expect(queue.every((i) => i.isNew), isTrue);
    });

    test('only quizzable sections are scheduled', () {
      const card = Card(
        id: 'A',
        type: CardType.flashcard,
        title: 'A',
        overview: '',
        tags: ['a'],
        tiers: {},
        sections: [
          CardSection(
              heading: 'Quiz', slug: 'quiz', content: 'x', quizzable: true),
          CardSection(
              heading: 'Related',
              slug: 'related',
              content: 'x',
              quizzable: false),
        ],
        wikilinks: [],
        filePath: 'A.md',
      );
      final queue =
          buildReviewQueue(cards: [card], dueByKey: const {}, now: now);
      expect(queue.map((i) => i.key), ['A::quiz']);
    });
  });
}
