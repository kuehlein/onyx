import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/goal/study_goal.dart';
import 'subject.dart';

part 'study_goals.g.dart';

/// The study goals live in the vault (task #30d, docs/multi-subject-plan.md).
///
/// G1: yields exactly one implicit default goal — the whole vault, targeted by the
/// primary template — so a single-subject vault behaves identically to pre-#30d.
/// Later phases add user-defined goals persisted in `_meta/` (G3) and lifecycle
/// state (G6).
@riverpod
Future<List<StudyGoal>> studyGoals(Ref ref) async {
  final registry = await ref.watch(subjectRegistryProvider.future);
  return [defaultGoalFor(registry.primary)];
}

/// The goal currently in focus — the one readiness, pace, and the daily plan are
/// computed against (G2). For now the single default goal; once the hub lands
/// (G5) this becomes the selected lane. Readiness scopes its cards to
/// `goal.select(...)`, so a single whole-vault goal reproduces pre-#30d numbers.
@riverpod
Future<StudyGoal> activeStudyGoal(Ref ref) async =>
    (await ref.watch(studyGoalsProvider.future)).first;
