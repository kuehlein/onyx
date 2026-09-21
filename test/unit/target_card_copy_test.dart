import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/features/home/home_screen.dart';

/// G7b: the Home target card draws its copy from the active goal's [Vocabulary].
/// These lock the two contracts — SWE reads byte-identically to pre-G7, and a
/// neutral subject never says "interview".
void main() {
  const swe =
      Vocabulary(examinerNoun: 'interviewer', assessmentNoun: 'interview');
  const neutral = Vocabulary.neutral;

  group('SWE (assessmentNoun: interview) is byte-identical to pre-G7', () {
    test('unset → "Set your interview target"', () {
      final c =
          targetCardCopy(vocab: swe, unset: true, setLabel: '', daysToGo: null);
      expect(c.title, 'Set your interview target');
      expect(c.countdown, isNull);
    });

    test('set + 0 days → "interview is today"', () {
      final c = targetCardCopy(
          vocab: swe,
          unset: false,
          setLabel: 'Senior · FAANG · Backend',
          daysToGo: 0);
      expect(c.title, 'Senior · FAANG · Backend');
      expect(c.countdown, 'interview is today');
    });

    test('set + N days → "N day(s) to go"', () {
      expect(
          targetCardCopy(vocab: swe, unset: false, setLabel: 'x', daysToGo: 3)
              .countdown,
          '3 days to go');
      expect(
          targetCardCopy(vocab: swe, unset: false, setLabel: 'x', daysToGo: 1)
              .countdown,
          '1 day to go');
    });
  });

  group('neutral subject never says "interview"', () {
    test('unset → "Set your target"', () {
      final c = targetCardCopy(
          vocab: neutral, unset: true, setLabel: '', daysToGo: null);
      expect(c.title, 'Set your target');
      expect(c.title, isNot(contains('interview')));
    });

    test('set + 0 days → "target is today" (no "interview")', () {
      final c = targetCardCopy(
          vocab: neutral,
          unset: false,
          setLabel: 'A1 · Casual · Speaking',
          daysToGo: 0);
      expect(c.title, 'A1 · Casual · Speaking');
      expect(c.countdown, 'target is today');
      expect(c.countdown, isNot(contains('interview')));
    });

    test('set + N days → "N days to go" (same neutral countdown as SWE)', () {
      expect(
          targetCardCopy(
                  vocab: neutral, unset: false, setLabel: 'x', daysToGo: 5)
              .countdown,
          '5 days to go');
    });
  });
}
