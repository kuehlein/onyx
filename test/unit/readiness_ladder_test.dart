import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/ladder.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(String id, String domain, int tier, List<String> slugs) => Card(
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
  group('computeLadderPosition', () {
    test('nothing studied → clears no rung; pin at the floor', () {
      final pos = computeLadderPosition(
        cards: [
          _card('A', 'ds-a', 1, ['s1'])
        ],
        stabilityByKey: const {},
        target: ReadinessTarget.fallback, // Mid · FAANG
      );
      expect(pos.clearedCount, 0);
      expect(pos.currentLabel, isNull);
      expect(pos.youFraction, 0);
      expect(pos.goalIndex, 3); // Mid · FAANG
      expect(pos.goalFraction, closeTo(0.5, 1e-9));
    });

    test('a durable single domain clears the whole ladder', () {
      final pos = computeLadderPosition(
        cards: [
          _card('A', 'ds-a', 1, ['s1'])
        ],
        stabilityByKey: const {'A::s1': 400},
        target: const ReadinessTarget(
          level: SeniorityLevel.newGrad,
          company: CompanyTier.typical,
          track: Track.general,
        ),
      );
      expect(pos.clearedCount, readinessLadder.length);
      expect(pos.atOrAboveGoal, isTrue);
      expect(pos.rungsToGo, 0);
      expect(pos.currentLabel, 'Staff · FAANG');
    });

    test('strong DS&A but weak system design lands mid-ladder below goal', () {
      // System design is heavily weighted at senior+, so a weak SD pocket drops
      // those rungs below the bar while the DS&A-dominant lower rungs clear.
      final pos = computeLadderPosition(
        cards: [
          _card('A', 'ds-a', 1, ['s1']), // durable
          _card('B', 'system-design', 1, ['s1']), // weak
        ],
        stabilityByKey: const {'A::s1': 300, 'B::s1': 5},
        target: const ReadinessTarget(
          level: SeniorityLevel.senior,
          company: CompanyTier.faang,
          track: Track.general,
        ),
      );
      expect(pos.currentLabel, 'Mid · FAANG');
      expect(pos.rungsToGo, 2); // Senior·Typical, Senior·FAANG
      expect(pos.atOrAboveGoal, isFalse);
      expect(pos.youFraction, lessThan(pos.goalFraction));
    });

    test('higher stability clears at least as many rungs as lower', () {
      int cleared(double s) => computeLadderPosition(
            cards: [
              _card('A', 'ds-a', 1, ['s1']),
              _card('B', 'system-design', 1, ['s1']),
            ],
            stabilityByKey: {'A::s1': s, 'B::s1': s},
            target: ReadinessTarget.fallback,
          ).clearedCount;
      expect(cleared(200), greaterThanOrEqualTo(cleared(20)));
    });
  });
}
