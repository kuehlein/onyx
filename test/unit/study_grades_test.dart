import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/study_grades.dart';

void main() {
  group('study grades', () {
    test('review offers the full FSRS set including Easy', () {
      expect(studyGrades.map((g) => g.value), [1, 2, 3, 4]);
      expect(
          studyGrades.map((g) => g.label), ['Again', 'Hard', 'Good', 'Easy']);
    });

    test('Learn now offers the full set incl. Easy (guarded, n0014)', () {
      // Easy was excluded pre-n0014 (its ~15-day first interval was unearned); now
      // it's offered but the scheduler CAPS a new card's Easy interval, so the grade
      // set can safely mirror Review's.
      expect(learnGrades.map((g) => g.value), [1, 2, 3, 4]);
      expect(learnGrades.any((g) => g.label == 'Easy'), isTrue);
    });

    test('learnGrades mirror the review grades exactly', () {
      expect(learnGrades, same(studyGrades));
      for (final g in learnGrades) {
        final review = studyGrades.firstWhere((s) => s.value == g.value);
        expect(g.label, review.label);
        expect(g.color, review.color);
      }
    });
  });
}
