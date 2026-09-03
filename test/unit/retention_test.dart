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
}
