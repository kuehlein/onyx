import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/analytics/retention.dart';

void main() {
  group('computeRetention', () {
    final domainByCard = {
      'a': 'ds-a',
      'b': 'ds-a',
      'c': 'system-design',
      'z': 'ds-a', // has state but no reviews
    };

    List<({String cardId, int grade})> reviews(Map<String, List<int>> byCard) =>
        [
          for (final e in byCard.entries)
            for (final g in e.value) (cardId: e.key, grade: g),
        ];

    test('recall counts grade >= 2 (a lapse is only "Again")', () {
      final r = computeRetention(
        reviews: reviews({
          'a': [1, 2, 3, 4, 3, 3], // 6 reviews, 5 not-Again
        }),
        stabilities: const [],
        domainByCard: domainByCard,
        minSample: 5,
      );
      final dsa = r.firstWhere((d) => d.domain == 'ds-a');
      expect(dsa.reviews, 6);
      expect(dsa.recall, closeTo(5 / 6, 1e-9));
    });

    test('withholds recall below the minimum sample', () {
      final r = computeRetention(
        reviews: reviews({
          'c': [3, 3], // only 2 reviews
        }),
        stabilities: const [],
        domainByCard: domainByCard,
        minSample: 5,
      );
      final sd = r.firstWhere((d) => d.domain == 'system-design');
      expect(sd.reviews, 2);
      expect(sd.recall, isNull);
      expect(sd.lowSample, isTrue);
    });

    test('averages current stability across the domain’s studied sections', () {
      final r = computeRetention(
        reviews: const [],
        stabilities: const [
          (cardId: 'a', stability: 10),
          (cardId: 'b', stability: 30),
          (cardId: 'c', stability: 5),
        ],
        domainByCard: domainByCard,
        minSample: 5,
      );
      final dsa = r.firstWhere((d) => d.domain == 'ds-a');
      expect(dsa.avgStabilityDays, 20); // (10+30)/2
      expect(dsa.studiedSections, 2);
      final sd = r.firstWhere((d) => d.domain == 'system-design');
      expect(sd.avgStabilityDays, 5);
    });

    test('ignores reviews for cards with no known domain', () {
      final r = computeRetention(
        reviews: reviews({
          'unknown': [3, 3, 3, 3, 3],
        }),
        stabilities: const [],
        domainByCard: domainByCard,
      );
      expect(r, isEmpty);
    });

    test('sorts weakest trustworthy domain first, low-sample last', () {
      final r = computeRetention(
        reviews: reviews({
          'a': [3, 3, 3, 3, 3, 3], // ds-a: strong (100%)
          'c': [1, 1, 3, 3, 3], // system-design: weaker (60%)
          'z': [3, 3], // ds-a low-sample contribution... (still ds-a)
        }),
        stabilities: const [],
        domainByCard: domainByCard,
        minSample: 5,
      );
      // ds-a has a+z = 8 reviews (6 + 2), system-design 5 reviews. Both meet the
      // sample; weaker (system-design) should sort first.
      expect(r.first.domain, 'system-design');
    });
  });

  group('computeRetentionByTag', () {
    test('a card counts toward EVERY tag it carries', () {
      final r = computeRetentionByTag(
        reviews: const [
          (cardId: 'x', grade: 3),
          (cardId: 'x', grade: 3),
          (cardId: 'x', grade: 1),
          (cardId: 'x', grade: 3),
          (cardId: 'x', grade: 3),
        ],
        stabilities: const [(cardId: 'x', stability: 12)],
        tagsByCard: const {
          'x': ['databases', 'query-optimization'],
        },
        minSample: 5,
      );
      final byKey = {for (final d in r) d.domain: d};
      expect(byKey.keys.toSet(), {'databases', 'query-optimization'});
      // The single card's reviews + stability land on BOTH tags.
      for (final tag in ['databases', 'query-optimization']) {
        expect(byKey[tag]!.reviews, 5);
        expect(byKey[tag]!.recall, closeTo(4 / 5, 1e-9));
        expect(byKey[tag]!.avgStabilityDays, 12);
      }
    });

    test('a shared tag aggregates across cards; distinct tags stay separate',
        () {
      final r = computeRetentionByTag(
        reviews: const [
          (cardId: 'x', grade: 3),
          (cardId: 'y', grade: 1),
        ],
        stabilities: const [],
        tagsByCard: const {
          'x': ['caching', 'databases'],
          'y': ['caching', 'networking'],
        },
        minSample: 1,
      );
      final byKey = {for (final d in r) d.domain: d};
      // 'caching' spans both cards — the domain-only view would have split them.
      expect(byKey['caching']!.reviews, 2);
      expect(byKey['databases']!.reviews, 1);
      expect(byKey['networking']!.reviews, 1);
      expect(byKey.keys.toSet(), {'caching', 'databases', 'networking'});
    });
  });
}
