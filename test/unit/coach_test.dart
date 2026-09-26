import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/coach.dart';
import 'package:onyx/shared/models/card.dart';

Card _card() => const Card(
      id: 'c1',
      type: 'flashcard',
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
    test('hidden answer instructs hint-not-spoiler behavior', () {
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

    test(
        'with no skill, the research-backed foundation stands (examiner/tutor)',
        () {
      final examiner = buildCoachSystem(
          card: _card(),
          section: _card().sections.first,
          revealed: true,
          grading: true);
      final tutor = buildCoachSystem(
          card: _card(), section: null, revealed: true, grading: false);
      // CoachSkill.none → the subject-neutral foundation: an examiner / tutor,
      // never a hardcoded software "interviewer".
      expect(examiner.toLowerCase(), contains('examiner'));
      expect(examiner.toLowerCase(), isNot(contains('interviewer')));
      expect(tutor.toLowerCase(), contains('tutor'));
      expect(tutor.toLowerCase(), isNot(contains('examiner')));
    });

    test('a vault skill AUGMENTS the foundation, never replaces it', () {
      const skill = CoachSkill(
        reviewAugment: 'REVIEW-AUG-XYZ',
        learnAugment: 'LEARN-AUG-XYZ',
        topicFit: 'TOPICFIT-XYZ',
      );
      final review = buildCoachSystem(
          card: _card(),
          section: _card().sections.first,
          revealed: true,
          grading: true,
          skill: skill);
      final learn = buildCoachSystem(
          card: _card(),
          section: null,
          revealed: true,
          grading: false,
          skill: skill);
      // Foundation still present (examiner/tutor) AND the domain augmentation.
      expect(review.toLowerCase(), contains('examiner'));
      expect(review, contains('REVIEW-AUG-XYZ'));
      expect(review, contains('TOPICFIT-XYZ'));
      expect(learn.toLowerCase(), contains('tutor'));
      expect(learn, contains('LEARN-AUG-XYZ'));
      expect(learn, isNot(contains('REVIEW-AUG-XYZ')));
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

  group('coachSkillFromMarkdown', () {
    test('parses Reviewing / Learning / Topic fit augmentations', () {
      final s = coachSkillFromMarkdown('<!-- header -->\n\n'
          '## Reviewing\n\nThe review augment.\n\n'
          '## Learning\n\nThe learn augment.\n\n'
          '## Topic fit\n\nThe emphasis.\n');
      expect(s.reviewAugment, 'The review augment.');
      expect(s.learnAugment, 'The learn augment.');
      expect(s.topicFit, 'The emphasis.');
    });

    test('every section is optional (a skill only augments the foundation)',
        () {
      final s = coachSkillFromMarkdown('## Reviewing\nonly review');
      expect(s.reviewAugment, 'only review');
      expect(s.learnAugment, isNull);
      expect(s.topicFit, isNull);
      // No recognized headings → an empty augmentation (foundation stands alone).
      final none = coachSkillFromMarkdown('no headings at all');
      expect(none.reviewAugment, isNull);
      expect(none.learnAugment, isNull);
      expect(none.topicFit, isNull);
    });

    test('parses a First exposure augmentation (n0015)', () {
      final s = coachSkillFromMarkdown('## First exposure\n\nKeep it playful.');
      expect(s.firstExposureAugment, 'Keep it playful.');
      expect(s.learnAugment, isNull);
    });
  });

  group('buildCoachSystem — first exposure (n0015)', () {
    String tutor({
      bool firstExposure = false,
      CoachSkill skill = CoachSkill.none,
    }) =>
        buildCoachSystem(
          card: _card(),
          section: _card().sections.first,
          revealed: true,
          grading: false,
          firstExposure: firstExposure,
          skill: skill,
        );

    test('firstExposure swaps in the withholding, self-explanation contract',
        () {
      final p = tutor(firstExposure: true);
      expect(p, contains('WITHHOLD the synthesis'));
      expect(p, contains('<tutor-done/>'));
      expect(p, contains('SELF-EXPLANATION rung'));
      // Capped at self-explanation — no transfer escalation at first exposure.
      expect(p, isNot(contains('where else could you use this')));
      // Never grades at first exposure.
      expect(p, isNot(contains('suggest-grade')));
    });

    test('firstExposure:false keeps the existing tutor wording (unchanged)',
        () {
      final p = tutor(firstExposure: false);
      expect(p, contains('help them understand it deeply'));
      expect(p, isNot(contains('<tutor-done/>')));
      expect(p, isNot(contains('WITHHOLD the synthesis')));
    });

    test('firstExposure consumes only firstExposureAugment, not learnAugment',
        () {
      const skill = CoachSkill(
          learnAugment: 'LEARN-AUG-XYZ', firstExposureAugment: 'FIRST-AUG-XYZ');
      final p = tutor(firstExposure: true, skill: skill);
      expect(p, contains('FIRST-AUG-XYZ'));
      expect(p, isNot(contains('LEARN-AUG-XYZ'))); // no SWE/learn leak
      // The tutor foundation still stands.
      expect(p.toLowerCase(), contains('tutor'));
    });

    test('firstExposure does not affect the examiner persona', () {
      String examiner(bool fe) => buildCoachSystem(
            card: _card(),
            section: _card().sections.first,
            revealed: true,
            grading: true,
            firstExposure: fe,
          );
      expect(examiner(true), examiner(false)); // grading path ignores it
    });
  });

  group('parseFirstExposureReply (n0015)', () {
    test('strips the <tutor-done/> sentinel and flags done', () {
      final r = parseFirstExposureReply('Say it in one line.\n<tutor-done/>');
      expect(r.done, isTrue);
      expect(r.text, 'Say it in one line.');
      expect(r.text, isNot(contains('tutor-done')));
    });

    test('no sentinel → not done, text unchanged', () {
      final r = parseFirstExposureReply('What makes you say that?');
      expect(r.done, isFalse);
      expect(r.text, 'What makes you say that?');
    });

    test('a stray grade/assessment tag is stripped, never surfaced', () {
      final r =
          parseFirstExposureReply('Good.\n<suggest-grade>3</suggest-grade>');
      expect(r.text, 'Good.');
      expect(r.text, isNot(contains('suggest-grade')));
    });
  });
}
