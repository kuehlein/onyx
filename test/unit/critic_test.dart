import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/interview/critic.dart';
import 'package:onyx/shared/models/card.dart';

const _card = Card(
  id: 'c1',
  type: CardType.interviewQuestion,
  title: 'Two Sum',
  overview: 'Find two numbers that add to a target.',
  tags: ['ds-a'],
  tiers: {'ds-a': 1},
  sections: [
    CardSection(
        heading: 'Approach',
        slug: 'approach',
        content: 'Use a hash map for O(n).',
        quizzable: true),
  ],
  wikilinks: [],
  filePath: 'two-sum.md',
);

void main() {
  group('buildCriticSystem', () {
    test('is independent/skeptical and includes the reference answer', () {
      final s = buildCriticSystem(card: _card, section: _card.sections.first);
      expect(s.toLowerCase(), contains('independent'));
      expect(s, contains('<verdict>'));
      expect(s, contains('Two Sum'));
      expect(s, contains('Use a hash map')); // reference answer for its eyes
    });
  });

  group('parseCriticVerdict', () {
    test('parses the tagged verdict', () {
      final v = parseCriticVerdict(
          'noise <verdict>{"appliedScore":55,"note":"partial"}</verdict>');
      expect(v, isNotNull);
      expect(v!.appliedScore, 55);
      expect(v.note, 'partial');
    });

    test('falls back to a bare JSON object', () {
      final v = parseCriticVerdict('{"appliedScore":80}');
      expect(v!.appliedScore, 80);
    });

    test('clamps and rejects unparseable / scoreless input', () {
      expect(
          parseCriticVerdict('<verdict>{"appliedScore":140}</verdict>')!
              .appliedScore,
          100);
      expect(parseCriticVerdict('no json here'), isNull);
      expect(parseCriticVerdict('<verdict>{"note":"x"}</verdict>'), isNull);
    });
  });

  group('criticAgrees', () {
    test('within tolerance agrees, beyond disagrees', () {
      expect(criticAgrees(70, 60), isTrue); // diff 10
      expect(criticAgrees(70, 40), isFalse); // diff 30 > 25
    });
  });

  group('effectiveApplied01', () {
    test('coach-only when no critic', () {
      expect(effectiveApplied01(80, null), closeTo(0.8, 1e-9));
    });

    test('averages coach and critic', () {
      expect(effectiveApplied01(80, 40), closeTo(0.6, 1e-9));
    });

    test('a harsh critic pulls a lenient coach score down', () {
      final lenient = effectiveApplied01(90, null);
      final reconciled = effectiveApplied01(90, 50);
      expect(reconciled, lessThan(lenient));
    });
  });
}
