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
    test('domain weights are level-independent (seniority rides tierRelevance)',
        () {
      // Seniority must not reshuffle whole-domain weights — that let a harder
      // target read as closer. Depth (tierRelevance) carries level instead.
      double w(SeniorityLevel l, String d) => domainWeight(
            ReadinessTarget.of(
                level: l, company: CompanyTier.faang, track: Track.general),
            d,
          );
      for (final l in SeniorityLevel.values) {
        expect(
            w(l, 'system-design'), w(SeniorityLevel.newGrad, 'system-design'),
            reason: 'system-design weight should not vary by level');
        expect(w(l, 'ds-a'), w(SeniorityLevel.newGrad, 'ds-a'),
            reason: 'ds-a weight should not vary by level');
      }
    });

    test('frontend track lightens DS&A', () {
      final base = ReadinessTarget.of(
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
      final senior = ReadinessTarget.of(
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
      final t = ReadinessTarget.of(
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
    final cards = [
      _card('A', 'ds-a', 1, ['s1']), // strong
      _card('B', 'system-design', 1, ['s1']), // weak
    ];
    const stability = {'A::s1': 200.0, 'B::s1': 5.0};

    Readiness roll(ReadinessTarget t) => computeReadiness(
          cards: cards,
          stabilityByKey: stability,
          domainWeights: {
            'ds-a': domainWeight(t, 'ds-a'),
            'system-design': domainWeight(t, 'system-design'),
          },
        );

    test('changing only the level does NOT move the overall (no inversion)',
        () {
      final ng = roll(ReadinessTarget.fallback
          .copyWith(level: SeniorityLevel.newGrad, track: Track.general));
      final staff = roll(ReadinessTarget.fallback
          .copyWith(level: SeniorityLevel.staff, track: Track.general));
      // Same track → identical domain weights → identical overall. The old model
      // made staff *higher* here (weighted the strong algo domain differently),
      // which is exactly the inversion we removed.
      expect(staff.overall, closeTo(ng.overall, 1e-9));
    });

    test('backend track pulls the overall toward the weaker system-design', () {
      final general = roll(ReadinessTarget.fallback
          .copyWith(level: SeniorityLevel.senior, track: Track.general));
      final backend = roll(ReadinessTarget.fallback
          .copyWith(level: SeniorityLevel.senior, track: Track.backend));
      // Backend up-weights the weak system-design domain → lower overall.
      expect(backend.overall, lessThan(general.overall));
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
    final senior = ReadinessTarget.of(
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
