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
    test('includes only due sections; excludes new and not-yet-due', () {
      final cards = [
        _card('A', 'a', ['s1', 's2']),
        _card('B', 'b', ['s1']),
        _card('C', 'c', ['s1']),
      ];
      final dueByKey = {
        'A::s1': now.subtract(const Duration(days: 1)), // due
        'C::s1': now.add(const Duration(days: 1)), // not yet due -> excluded
        // A::s2 and B::s1 have no state -> new -> belong to Learn, not Review
      };

      final queue =
          buildReviewQueue(cards: cards, dueByKey: dueByKey, now: now);

      expect(queue.map((i) => i.key), ['A::s1']);
    });

    test('interleaves due sections across domains', () {
      final cards = [
        _card('A', 'a', ['s1', 's2', 's3']),
        _card('B', 'b', ['s1']),
      ];
      final past = now.subtract(const Duration(days: 1));
      final dueByKey = {
        'A::s1': past,
        'A::s2': past,
        'A::s3': past,
        'B::s1': past,
      };
      final queue =
          buildReviewQueue(cards: cards, dueByKey: dueByKey, now: now);
      final domains = queue.map((i) => i.card.domain).toList();

      // Round-robin: a, b, a, a (b's single item lands second, not last).
      expect(domains, ['a', 'b', 'a', 'a']);
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
      final past = now.subtract(const Duration(days: 1));
      final queue = buildReviewQueue(
        cards: [card],
        dueByKey: {'A::quiz': past, 'A::related': past},
        now: now,
      );
      expect(queue.map((i) => i.key), ['A::quiz']);
    });
  });
}
