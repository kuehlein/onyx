import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/ladder.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(String id, String domain, int tier, List<String> slugs) => Card(
      id: id,
      type: 'flashcard',
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
    test('the ladder uses the goal template rungs (multi-template)', () {
      const spec = TargetSpec(
        levels: [
          LevelValue(id: 'a', label: 'A', tierCurve: [1.0]),
          LevelValue(id: 'b', label: 'B', tierCurve: [1.0]),
        ],
        contexts: [ContextValue(id: 'c', label: 'C', stabilityTargetDays: 30)],
        tracks: [TrackValue(id: 't', label: 'T')],
        families: [],
        fallbackLevelId: 'a',
        fallbackContextId: 'c',
        fallbackTrackId: 't',
      );
      final pos = computeLadderPosition(
        cards: const [],
        stabilityByKey: const {},
        // A target carrying this template → the ladder is that template's slots
        // (2 levels × 1 context = 2 rungs), not SWE's 8.
        target: const ReadinessTarget(
            levelId: 'b', contextId: 'c', trackId: 't', templateTarget: spec),
      );
      expect(pos.rungScores.length, 2);
      expect(pos.goalLabel, 'B · C');
    });

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
        target: ReadinessTarget.of(
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

    test('an uncovered advanced (deep-tier) pocket lands below the senior goal',
        () {
      // Foundations are solid, but system-design's ADVANCED tier is unstudied.
      // Higher rungs weight that depth more (tierRelevance), so they fall below
      // the bar while the junior rungs — which barely count the deep tier —
      // clear. This is the seniority signal now: depth, not domain reshuffling.
      final pos = computeLadderPosition(
        cards: [
          _card('A', 'ds-a', 1, ['s1']), // strong foundational
          _card('B', 'system-design', 1, ['s1']), // strong foundational SD
          _card('C', 'system-design', 4, ['s1']), // advanced SD — UNSTUDIED
          _card('D', 'system-design', 4, ['s1']), // advanced SD — UNSTUDIED
          _card('E', 'system-design', 4, ['s1']), // advanced SD — UNSTUDIED
        ],
        stabilityByKey: const {'A::s1': 300, 'B::s1': 300}, // C–E unstudied
        target: ReadinessTarget.of(
          level: SeniorityLevel.senior,
          company: CompanyTier.faang,
          track: Track.general,
        ),
      );
      // Strictly harder as you climb: the missing depth costs more at the top.
      expect(pos.rungScores.first, greaterThan(pos.rungScores.last));
      // Below the senior goal, but some junior rungs are cleared.
      expect(pos.atOrAboveGoal, isFalse);
      expect(pos.youFraction, lessThan(pos.goalFraction));
      expect(pos.clearedCount, greaterThan(0));
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
