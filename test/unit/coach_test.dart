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

    test('hidden state marks the section withheld and forbids a grade tag', () {
      final prompt = buildCoachSystem(
        card: _card(),
        section: _card().sections.first,
        revealed: false,
        grading: true,
      );
      // The in-context answer is explicitly flagged as reference-only…
      expect(prompt, contains('WITHHELD'));
      // …and the model is told not to emit the advisory grade tag yet.
      expect(prompt, isNot(contains('<suggest-grade>N</suggest-grade>')));
    });

    test('revealed + grading permits the advisory grade + assessment tags', () {
      final prompt = buildCoachSystem(
        card: _card(),
        section: _card().sections.first,
        revealed: true,
        grading: true,
      );
      expect(prompt, contains('REVEALED'));
      expect(prompt, contains('<suggest-grade>N</suggest-grade>'));
      expect(prompt, contains('<assessment>'));
      expect(prompt, contains('appliedScore'));
    });

    test('hidden state forbids the assessment tag', () {
      final prompt = buildCoachSystem(
        card: _card(),
        section: _card().sections.first,
        revealed: false,
        grading: true,
      );
      expect(prompt, isNot(contains('<assessment>')));
    });

    test('grading selects the interviewer persona; otherwise the tutor', () {
      final interviewer = buildCoachSystem(
          card: _card(),
          section: _card().sections.first,
          revealed: true,
          grading: true);
      final tutor = buildCoachSystem(
          card: _card(), section: null, revealed: true, grading: false);
      expect(interviewer.toLowerCase(), contains('interviewer'));
      expect(tutor.toLowerCase(), contains('tutor'));
      expect(tutor.toLowerCase(), isNot(contains('interviewer')));
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

    test('a themed mock injects the interview context (grading only)', () {
      final themed = buildCoachSystem(
        card: _card(),
        section: null,
        revealed: false,
        grading: true,
        interviewContext: 'Google · Senior · Backend',
      );
      expect(themed, contains('Google · Senior · Backend'));
      expect(themed.toLowerCase(), contains('prep for a specific interview'));

      // Ignored by the tutor persona (non-grading).
      final tutor = buildCoachSystem(
        card: _card(),
        section: null,
        revealed: true,
        grading: false,
        interviewContext: 'Google · Senior · Backend',
      );
      expect(tutor, isNot(contains('Google · Senior · Backend')));
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

    test('extracts a structured assessment and strips its tag', () {
      final r = parseCoachReply(
        'Good debrief.\n<suggest-grade>3</suggest-grade>\n'
        '<assessment>{"appliedScore":72,"rubric":{"correctness":4,'
        '"complexity":3},"novel":true,"hintLevel":1}</assessment>',
      );
      expect(r.text, 'Good debrief.');
      expect(r.text, isNot(contains('assessment')));
      expect(r.grade, 3);
      expect(r.assessment, isNotNull);
      expect(r.assessment!.appliedScore, 72);
      expect(r.assessment!.rubric, {'correctness': 4, 'complexity': 3});
      expect(r.assessment!.novel, isTrue);
      expect(r.assessment!.hintLevel, 1);
    });

    test('no assessment tag → null assessment', () {
      expect(parseCoachReply('just a hint').assessment, isNull);
    });

    test('malformed assessment JSON → null, tag still stripped', () {
      final r = parseCoachReply('Text <assessment>not json</assessment>');
      expect(r.assessment, isNull);
      expect(r.text, 'Text');
    });

    test('clamps out-of-range assessment values', () {
      final r = parseCoachReply(
        '<assessment>{"appliedScore":150,"rubric":{"correctness":9},'
        '"hintLevel":42}</assessment>',
      );
      expect(r.assessment!.appliedScore, 100);
      expect(r.assessment!.rubric['correctness'], 5);
      expect(r.assessment!.hintLevel, 5);
    });
  });
}
