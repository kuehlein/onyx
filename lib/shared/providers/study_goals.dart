import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/goal/goal_store.dart';
import '../../core/goal/study_goal.dart';
import 'subject.dart';
import 'vault.dart';

part 'study_goals.g.dart';

/// The study goals live in the vault (task #30d, docs/multi-subject-plan.md).
///
/// Always leads with the implicit default goal (the whole vault, targeted by the
/// primary template), followed by any user-defined goals persisted in `_meta/`
/// (G3b). An empty store → just the default goal, identical to pre-#30d. A stored
/// goal that collides with the default id is ignored (the default is synthesized).
@riverpod
Future<List<StudyGoal>> studyGoals(Ref ref) async {
  final registry = await ref.watch(subjectRegistryProvider.future);
  final source = ref.watch(vaultSourceProvider);
  final stored =
      source == null ? const <StudyGoal>[] : await GoalStore(source).load();
  return [
    defaultGoalFor(registry.primary),
    for (final g in stored)
      if (g.id != defaultGoalId) g,
  ];
}

/// The goal currently in focus — the one readiness, pace, and the daily plan are
/// computed against (G2). For now the single default goal; once the hub lands
/// (G5) this becomes the selected lane. Readiness scopes its cards to
/// `goal.select(...)`, so a single whole-vault goal reproduces pre-#30d numbers.
@riverpod
Future<StudyGoal> activeStudyGoal(Ref ref) async =>
    (await ref.watch(studyGoalsProvider.future)).first;
