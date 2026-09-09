import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/readiness.dart';
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
  group('domainWeight', () {
    test('system design weight rises with level', () {
      double w(SeniorityLevel l) => domainWeight(
            ReadinessTarget(
                level: l, company: CompanyTier.faang, track: Track.general),
            'system-design',
          );
      expect(w(SeniorityLevel.newGrad), lessThan(w(SeniorityLevel.mid)));
      expect(w(SeniorityLevel.mid), lessThan(w(SeniorityLevel.senior)));
      expect(w(SeniorityLevel.senior), lessThan(w(SeniorityLevel.staff)));
    });

    test('algorithms weight falls with level', () {
      double w(SeniorityLevel l) => domainWeight(
            ReadinessTarget(
                level: l, company: CompanyTier.faang, track: Track.general),
            'ds-a',
          );
      expect(w(SeniorityLevel.newGrad), greaterThan(w(SeniorityLevel.staff)));
    });

    test('frontend track lightens DS&A', () {
      const base = ReadinessTarget(
          level: SeniorityLevel.mid,
          company: CompanyTier.faang,
          track: Track.general);
      final fe = base.copyWith(track: Track.frontend);
      expect(domainWeight(fe, 'ds-a'), lessThan(domainWeight(base, 'ds-a')));
    });

    test('unknown domains weigh 1.0', () {
      expect(domainWeight(ReadinessTarget.fallback, 'astrophysics'), 1.0);
    });

    test('backend-knowledge domains weigh like system design', () {
      const senior = ReadinessTarget(
          level: SeniorityLevel.senior,
          company: CompanyTier.faang,
          track: Track.backend);
      final sd = domainWeight(senior, 'system-design');
      for (final d in [
        'databases',
        'distributed-systems',
        'networking',
        'security'
      ]) {
        expect(domainWeight(senior, d), sd,
            reason: '$d should ride the systems/backend weight');
      }
      // Still above the neutral default, and boosted by the backend track.
      expect(sd, greaterThan(1.0));
    });
  });

  group('ReadinessTarget serialization', () {
    test('round-trips including date', () {
      final t = ReadinessTarget(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.backend,
        interviewDate: DateTime(2026, 11, 3),
      );
      final back = ReadinessTarget.tryDecode(t.encode());
      expect(back, isNotNull);
      expect(back!.level, SeniorityLevel.senior);
      expect(back.company, CompanyTier.faang);
      expect(back.track, Track.backend);
      expect(back.interviewDate, DateTime(2026, 11, 3));
      expect(back.label, 'Senior · FAANG · Backend');
    });

    test('null date omitted and decodes back to null', () {
      const t = ReadinessTarget.fallback;
      expect(t.encode().contains('interviewDate'), isFalse);
      expect(ReadinessTarget.tryDecode(t.encode())!.interviewDate, isNull);
    });

    test('malformed input decodes to null (caller falls back)', () {
      expect(ReadinessTarget.tryDecode('not json'), isNull);
      expect(ReadinessTarget.tryDecode(''), isNull);
      expect(ReadinessTarget.tryDecode(null), isNull);
    });

    test('FAANG raises the durability bar', () {
      expect(ReadinessTarget.fallback.stabilityTarget, 120);
      expect(
        ReadinessTarget.fallback
            .copyWith(company: CompanyTier.typical)
            .stabilityTarget,
        90,
      );
    });
  });

  group('computeReadiness with target weights', () {
    test('senior weighting pulls overall toward the weaker system-design', () {
      final cards = [
        _card('A', 'ds-a', 1, ['s1']), // strong
        _card('B', 'system-design', 1, ['s1']), // weak
      ];
      const stability = {'A::s1': 200.0, 'B::s1': 5.0};

      final newGrad = computeReadiness(
        cards: cards,
        stabilityByKey: stability,
        domainWeights: {
          'ds-a': domainWeight(
              ReadinessTarget.fallback.copyWith(level: SeniorityLevel.newGrad),
              'ds-a'),
          'system-design': domainWeight(
              ReadinessTarget.fallback.copyWith(level: SeniorityLevel.newGrad),
              'system-design'),
        },
      );
      final senior = computeReadiness(
        cards: cards,
        stabilityByKey: stability,
        domainWeights: {
          'ds-a': domainWeight(
              ReadinessTarget.fallback.copyWith(level: SeniorityLevel.senior),
              'ds-a'),
          'system-design': domainWeight(
              ReadinessTarget.fallback.copyWith(level: SeniorityLevel.senior),
              'system-design'),
        },
      );

      // System design is the weak domain; senior weights it far more heavily,
      // so the senior overall should be lower than the new-grad overall.
      expect(senior.overall, lessThan(newGrad.overall));
    });
  });

  group('tierRelevance (grounded curve)', () {
    test('foundations (tier 1) are fully weighted at every level', () {
      for (final l in SeniorityLevel.values) {
        expect(tierRelevance(l, 1), 1.0,
            reason: 'tier1 is table-stakes for $l');
      }
    });

    test('advanced-tier weight rises with seniority', () {
      double t3(SeniorityLevel l) => tierRelevance(l, 3);
      expect(t3(SeniorityLevel.newGrad), lessThan(t3(SeniorityLevel.mid)));
      expect(t3(SeniorityLevel.mid), lessThan(t3(SeniorityLevel.senior)));
      expect(t3(SeniorityLevel.senior),
          lessThanOrEqualTo(t3(SeniorityLevel.staff)));
    });

    test('the deepest specialist tier is < 1 for everyone', () {
      for (final l in SeniorityLevel.values) {
        expect(tierRelevance(l, 4), lessThan(1.0),
            reason: 'no total mastery for $l');
      }
    });

    test('untiered falls back to foundational', () {
      expect(tierRelevance(SeniorityLevel.senior, null), 1.0);
    });
  });

  group('relevance-weighted coverage', () {
    const senior = ReadinessTarget(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.backend);
    final tw = tierWeightsFor(senior);
    double cov(List<Card> cards) => computeReadiness(
          cards: cards,
          stabilityByKey: const {'A::s': 200.0},
          tierWeights: tw,
        ).domains.first.coverage;

    test(
        'an unstudied peripheral (deep-tier) card dilutes coverage less than '
        'an unstudied essential (foundational) one', () {
      final base = [
        _card('A', 'ds-a', 1, ['s'])
      ];
      expect(cov(base), closeTo(1.0, 1e-9));
      final withPeripheral = cov([
        ...base,
        _card('P', 'ds-a', 4, ['s'])
      ]);
      final withEssential = cov([
        ...base,
        _card('E', 'ds-a', 1, ['s'])
      ]);
      expect(withPeripheral, greaterThan(withEssential));
      expect(withEssential, closeTo(0.5, 1e-9)); // raw dilution
      expect(withPeripheral,
          greaterThan(0.6)); // ~0.667, peripheral barely dilutes
    });
  });
}
