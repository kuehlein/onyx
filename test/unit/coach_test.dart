import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/coach.dart';
import 'package:onyx/shared/models/card.dart';

Card _card() => const Card(
      id: 'c1',
      type: CardType.flashcard,
      title: 'Binary Search',
      overview: 'Halve the search space each step.',
      tags: ['ds-a'],
      tiers: {'ds-a': 1},
      sections: [
        CardSection(
          heading: 'Complexity',
          slug: 'complexity',
          content: 'O(log n) time, O(1) space.',
          quizzable: true,
        ),
        CardSection(
          heading: 'Pitfalls',
          slug: 'pitfalls',
          content: 'Off-by-one on the bounds.',
          quizzable: true,
        ),
      ],
      wikilinks: [],
      filePath: 'binary-search.md',
    );

void main() {
  group('buildCoachSystem', () {
    test('hidden answer instructs hint-not-spoiler behaviour', () {
      final prompt = buildCoachSystem(
        card: _card(),
        section: _card().sections.first,
        revealed: false,
        grading: true,
      );
      expect(prompt, contains('HIDDEN'));
      expect(prompt, isNot(contains('<suggest-grade>N')));
      // Focused on the one section under review, not every section.
      expect(prompt, contains('Section under review: Complexity'));
      expect(prompt, isNot(contains('## Pitfalls')));
    });

    test('revealed + grading permits the advisory grade tag', () {
      final prompt = buildCoachSystem(
        card: _card(),
        section: _card().sections.first,
        revealed: true,
        grading: true,
      );
      expect(prompt, contains('REVEALED'));
      expect(prompt, contains('<suggest-grade>N</suggest-grade>'));
    });

    test('browse mode (no section) includes all sections and no grade tag', () {
      final prompt = buildCoachSystem(
        card: _card(),
        section: null,
        revealed: true,
        grading: false,
      );
      expect(prompt, contains('## Complexity'));
      expect(prompt, contains('## Pitfalls'));
      expect(prompt, isNot(contains('suggest-grade')));
    });
  });

  group('parseCoachReply', () {
    test('extracts the grade and strips the tag from the text', () {
      final r = parseCoachReply(
          'Nice recall of the bounds.\n<suggest-grade>3</suggest-grade>');
      expect(r.grade, 3);
      expect(r.text, 'Nice recall of the bounds.');
      expect(r.text, isNot(contains('suggest-grade')));
    });

    test('no tag → null grade, unchanged text', () {
      final r = parseCoachReply('Just a hint, no judgement yet.');
      expect(r.grade, isNull);
      expect(r.text, 'Just a hint, no judgement yet.');
    });

    test('ignores an out-of-range grade tag', () {
      final r = parseCoachReply('text <suggest-grade>7</suggest-grade>');
      expect(r.grade, isNull);
    });
  });
}
