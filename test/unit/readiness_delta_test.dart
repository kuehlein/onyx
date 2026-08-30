import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(String id, String domain, List<String> slugs) => Card(
      id: id,
      type: CardType.flashcard,
      title: id,
      overview: '',
      tags: [domain],
      tiers: {domain: 1},
      sections: [
        for (final s in slugs)
          CardSection(heading: s, slug: s, content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  final cards = [
    _card('A', 'ds-a', ['s1', 's2']),
    _card('B', 'system-design', ['s1']),
  ];

  group('computeReadinessForTarget + diffReadiness', () {
    test('strengthening a section raises its domain and the overall score', () {
      const target = ReadinessTarget.fallback;
      final before = computeReadinessForTarget(
        cards: cards,
        stabilityByKey: const {'A::s1': 20, 'B::s1': 30},
        target: target,
      );
      // A::s1 matured (20 → 90); everything else unchanged.
      final after = computeReadinessForTarget(
        cards: cards,
        stabilityByKey: const {'A::s1': 90, 'B::s1': 30},
        target: target,
      );

      final delta = diffReadiness(before, after);
      expect(delta.overallChange, greaterThan(0));

      // Only DS&A moved; system-design is untouched and excluded from `touched`.
      final touched = delta.touched;
      expect(touched.map((d) => d.domain), contains('ds-a'));
      expect(touched.map((d) => d.domain), isNot(contains('system-design')));
      expect(
          touched.firstWhere((d) => d.domain == 'ds-a').change, greaterThan(0));
    });

    test('a lapse (lower stability) shows as a negative delta', () {
      const target = ReadinessTarget.fallback;
      final before = computeReadinessForTarget(
        cards: cards,
        stabilityByKey: const {'A::s1': 90, 'B::s1': 30},
        target: target,
      );
      final after = computeReadinessForTarget(
        cards: cards,
        stabilityByKey: const {'A::s1': 5, 'B::s1': 30},
        target: target,
      );
      final delta = diffReadiness(before, after);
      expect(delta.overallChange, lessThan(0));
    });

    test('no change → nothing touched, overall steady', () {
      const target = ReadinessTarget.fallback;
      const stability = {'A::s1': 40.0, 'B::s1': 40.0};
      final before = computeReadinessForTarget(
          cards: cards, stabilityByKey: stability, target: target);
      final after = computeReadinessForTarget(
          cards: cards, stabilityByKey: stability, target: target);
      final delta = diffReadiness(before, after);
      expect(delta.touched, isEmpty);
      expect(delta.overallChange.abs(), lessThan(1e-9));
    });
  });

  group('prettyDomain', () {
    test('maps known domains and title-cases the rest', () {
      expect(prettyDomain('ds-a'), 'DS & A');
      expect(prettyDomain('system-design'), 'System design');
      expect(prettyDomain('databases'), 'Databases');
      expect(prettyDomain('web_dev'), 'Web Dev');
    });
  });
}
