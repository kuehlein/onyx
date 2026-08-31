import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/interview/transfer.dart';
import 'package:onyx/core/readiness/readiness.dart';
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
  group('durability', () {
    test('0 at no stability, rises with stability, ~1 at target', () {
      expect(durability(0), 0);
      expect(durability(90), closeTo(1.0, 0.001));
      expect(durability(7), lessThan(durability(30)));
    });
  });

  group('computeReadiness', () {
    test('coverage counts unstudied; strength only over studied', () {
      // Domain 'ds-a': 2 sections, one studied (durable), one never studied.
      final cards = [
        _card('A', 'ds-a', 1, ['s1', 's2'])
      ];
      final r = computeReadiness(
        cards: cards,
        stabilityByKey: {'A::s1': 120}, // strong; s2 unstudied
      );
      final d = r.domains.single;
      expect(d.total, 2);
      expect(d.studied, 1);
      expect(d.coverage, 0.5);
      expect(d.strength, greaterThan(0.8)); // the one studied item is durable
      // coverage^0.7 (~0.62) * strength → well below strength alone
      expect(d.score, lessThan(d.strength));
    });

    test('a weak pocket drags strength below the mean (p20 floor)', () {
      final cards = [
        _card('A', 'ds-a', 1, ['a', 'b', 'c', 'd', 'e'])
      ];
      // Four strong, one very weak.
      final r = computeReadiness(cards: cards, stabilityByKey: {
        'A::a': 200,
        'A::b': 200,
        'A::c': 200,
        'A::d': 200,
        'A::e': 1, // weak
      });
      final d = r.domains.single;
      final plainMean = (durability(200) * 4 + durability(1)) / 5;
      expect(d.strength, lessThan(plainMean)); // floor pulls it down
    });

    test('weakest domain sorts first and drives the focus signal', () {
      final r = computeReadiness(
        cards: [
          _card('A', 'ds-a', 1, ['s1']), // studied, strong
          _card('B', 'system-design', 1, ['s1']), // unstudied
        ],
        stabilityByKey: {'A::s1': 150},
      );
      expect(r.domains.first.domain, 'system-design'); // weakest first
      expect(r.weakestDomain, 'system-design');
      expect(r.domains.first.label, 'Not started');
    });

    test('empty when there are no cards', () {
      final r = computeReadiness(cards: const [], stabilityByKey: const {});
      expect(r.isEmpty, isTrue);
      expect(r.overall, 0);
    });
  });

  group('transfer factor (Phase B)', () {
    final cards = [
      _card('A', 'ds-a', 1, ['s1'])
    ];
    const durable = {'A::s1': 300.0}; // strong recall

    test('no transfer map → recall-only, interview flag false', () {
      final r = computeReadiness(cards: cards, stabilityByKey: durable);
      expect(r.interview, isFalse);
      expect(r.domains.single.transfer, isNull);
    });

    test('zero-evidence transfer caps recall at the prior factor', () {
      final recallOnly = computeReadiness(cards: cards, stabilityByKey: durable)
          .domains
          .single;
      final gated = computeReadiness(
        cards: cards,
        stabilityByKey: durable,
        transferByDomain: {'ds-a': computeTransfer(const [])},
      );
      expect(gated.interview, isTrue);
      // Capped: score = recall · (τ + (1-τ)·0.4) = recall · 0.7.
      expect(gated.domains.single.score, closeTo(recallOnly.score * 0.7, 1e-6));
    });

    test('strong proven transfer lifts the score back toward full recall', () {
      final strongTransfer = computeTransfer([
        for (var i = 0; i < 12; i++)
          const AppliedSample(score: 0.95, novel: true, ageDays: 0),
      ]);
      final gated = computeReadiness(
        cards: cards,
        stabilityByKey: durable,
        transferByDomain: {'ds-a': strongTransfer},
      );
      final capped = computeReadiness(
        cards: cards,
        stabilityByKey: durable,
        transferByDomain: {'ds-a': computeTransfer(const [])},
      );
      expect(
          gated.domains.single.score, greaterThan(capped.domains.single.score));
      expect(gated.domains.single.appliedN, greaterThan(0));
    });

    test('poor applied performance drags a high-recall domain down', () {
      final poor = computeTransfer([
        for (var i = 0; i < 8; i++)
          const AppliedSample(score: 0.1, novel: true, ageDays: 0),
      ]);
      final gated = computeReadiness(
        cards: cards,
        stabilityByKey: durable,
        transferByDomain: {'ds-a': poor},
      );
      // Strong recall, but weak transfer caps it well below "strong".
      expect(gated.domains.single.score, lessThan(0.6));
    });
  });
}
