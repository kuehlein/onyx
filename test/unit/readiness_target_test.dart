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
      expect(domainWeight(ReadinessTarget.fallback, 'databases'), 1.0);
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
}
