import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/study_grades.dart';

void main() {
  group('study grades', () {
    test('review offers the full FSRS set including Easy', () {
      expect(studyGrades.map((g) => g.value), [1, 2, 3, 4]);
      expect(
          studyGrades.map((g) => g.label), ['Again', 'Hard', 'Good', 'Easy']);
    });

    test(
        'Learn excludes Easy — a first-seen card can graduate with Good at most',
        () {
      expect(learnGrades.map((g) => g.value), [1, 2, 3]);
      expect(learnGrades.any((g) => g.label == 'Easy'), isFalse);
      // Good (>= 3, the graduation threshold in LearnSession) is still offered.
      expect(learnGrades.last.value, 3);
    });

    test('learnGrades mirror the review grades for the values it keeps', () {
      for (final g in learnGrades) {
        final review = studyGrades.firstWhere((s) => s.value == g.value);
        expect(g.label, review.label);
        expect(g.color, review.color);
      }
    });
  });
}
