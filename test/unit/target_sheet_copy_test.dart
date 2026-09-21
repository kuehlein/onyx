import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/subject/subject_config.dart';
import 'package:onyx/features/home/target_sheet.dart';

/// G7c: the target sheet's date-field label reads from the goal's [Vocabulary] —
/// SWE stays byte-identical, a neutral subject never says "Interview".
void main() {
  test('SWE (assessmentNoun: interview) → "Interview date (optional)"', () {
    expect(
      targetDateLabel(const Vocabulary(
          examinerNoun: 'interviewer', assessmentNoun: 'interview')),
      'Interview date (optional)',
    );
  });

  test('neutral subject → "Target date (optional)", never "Interview"', () {
    final l = targetDateLabel(Vocabulary.neutral);
    expect(l, 'Target date (optional)');
    expect(l, isNot(contains('Interview')));
  });

  test('another assessment noun title-cases (e.g. "Exam date")', () {
    expect(
      targetDateLabel(const Vocabulary(assessmentNoun: 'exam')),
      'Exam date (optional)',
    );
  });
}
