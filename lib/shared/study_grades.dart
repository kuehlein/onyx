import 'package:flutter/material.dart';

import 'design/onyx_colors.dart';
import 'design/status_color.dart';

/// The four FSRS self-grades, with their labels and accent colors. Shared so
/// the study action bar and the coach's advisory highlight stay in sync.
/// Values map to the `fsrs` package's Rating (1=Again … 4=Easy).
const studyGrades = <({int value, String label, Color color})>[
  (value: 1, label: 'Again', color: StatusColor.bad),
  (value: 2, label: 'Hard', color: StatusColor.warn),
  (value: 3, label: 'Good', color: StatusColor.good),
  (value: 4, label: 'Easy', color: StatusColor.info),
];

/// Grades offered in **Learn** (first exposure) — the full set, including Easy. Easy
/// is safe here because it's GUARDED at the scheduler (n0014): a new card's Easy first
/// interval is capped at [learnEasyMaxIntervalFactor]× what Good would seed, so an
/// already-known card can skip ahead without FSRS's unearned ~15-day jump. (Review
/// keeps native, uncapped Easy for genuinely mastered cards.)
const learnGrades = studyGrades;

/// The accent color for a grade value (1–4), falling back to muted. Lets other
/// graded flows (e.g. the algorithm solve outcomes, which map onto FSRS grades)
/// reuse the same 4-color scale. The one place grade coloring lives is
/// [OnyxColors.grade]; this delegates to it (design-system §7 Step 1).
Color gradeColor(int value) => OnyxColors.dark.grade(value);
