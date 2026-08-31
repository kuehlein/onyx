import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/practice/practice.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(
  String id,
  String domain, {
  required CardType type,
  int tier = 2,
  List<String> sections = const ['s1'],
}) =>
    Card(
      id: id,
      type: type,
      title: id,
      overview: '',
      tags: [domain],
      tiers: {domain: tier},
      sections: [
        for (final s in sections)
          CardSection(heading: s, slug: s, content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  group('buildPracticeSet', () {
    test('filters to the domain, applied-first, foundational tiers first', () {
      final cards = [
        _card('concept-t1', 'ds-a', type: CardType.flashcard, tier: 1),
        _card('applied-t3', 'ds-a', type: CardType.interviewQuestion, tier: 3),
        _card('applied-t1', 'ds-a', type: CardType.interviewQuestion, tier: 1),
        _card('other', 'system-design', type: CardType.interviewQuestion),
      ];
      final set = buildPracticeSet(cards: cards, domain: 'ds-a');

      // Only ds-a cards; interview questions come before the concept card even
      // though the concept card is tier 1; within applied, tier 1 before tier 3.
      expect(set.map((c) => c.id), ['applied-t1', 'applied-t3', 'concept-t1']);
    });

    test('respects the limit', () {
      final cards = [
        for (var i = 0; i < 10; i++)
          _card('c$i', 'ds-a', type: CardType.interviewQuestion, tier: 1),
      ];
      expect(
          buildPracticeSet(cards: cards, domain: 'ds-a', limit: 3).length, 3);
    });

    test('empty when the domain has no cards', () {
      final cards = [
        _card('x', 'system-design', type: CardType.interviewQuestion)
      ];
      expect(buildPracticeSet(cards: cards, domain: 'ds-a'), isEmpty);
    });
  });

  group('practiceAnswerSection', () {
    test('prefers the first quizzable section', () {
      const card = Card(
        id: 'a',
        type: CardType.flashcard,
        title: 'a',
        overview: '',
        tags: ['ds-a'],
        tiers: {'ds-a': 1},
        sections: [
          CardSection(
              heading: 'intro', slug: 'intro', content: 'x', quizzable: false),
          CardSection(
              heading: 'core', slug: 'core', content: 'x', quizzable: true),
        ],
        wikilinks: [],
        filePath: 'a.md',
      );
      expect(practiceAnswerSection(card)?.slug, 'core');
    });
  });
}
