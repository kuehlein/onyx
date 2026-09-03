import 'package:flutter/material.dart';
import 'status_colors.dart';

/// The four FSRS self-grades, with their labels and accent colors. Shared so
/// the study action bar and the coach's advisory highlight stay in sync.
/// Values map to the `fsrs` package's Rating (1=Again … 4=Easy).
const studyGrades = <({int value, String label, Color color})>[
  (value: 1, label: 'Again', color: statusBad),
  (value: 2, label: 'Hard', color: statusWarn),
  (value: 3, label: 'Good', color: statusGood),
  (value: 4, label: 'Easy', color: Color(0xFF5AA7E6)),
];

/// Grades offered in **Learn** (first exposure). Excludes Easy: on a brand-new
/// card FSRS's Easy jumps to a ~15-day first interval, which is unearned for
/// something you've only just seen — so new material graduates with Good at
/// most. Review mode keeps the full set (Easy included) for genuinely mastered
/// cards.
const learnGrades = <({int value, String label, Color color})>[
  (value: 1, label: 'Again', color: statusBad),
  (value: 2, label: 'Hard', color: statusWarn),
  (value: 3, label: 'Good', color: statusGood),
];

/// The label for a grade value (1–4), or empty for an unknown value.
String gradeLabel(int value) =>
    studyGrades.where((g) => g.value == value).map((g) => g.label).firstOr('');

extension _FirstOr<T> on Iterable<T> {
  T firstOr(T fallback) => isEmpty ? fallback : first;
}
