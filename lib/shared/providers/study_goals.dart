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
class StudyGoals extends _$StudyGoals {
  @override
  Future<List<StudyGoal>> build() async {
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

  /// The persisted goals — everything except the synthesized default.
  List<StudyGoal> get _stored => [
        for (final g in state.asData?.value ?? const <StudyGoal>[])
          if (g.id != defaultGoalId) g,
      ];

  /// Add a goal or replace one by id. The default goal is synthesized, not
  /// stored, so upserting it is a no-op.
  Future<void> upsert(StudyGoal goal) async {
    if (goal.id == defaultGoalId) return;
    final goals = [..._stored];
    final i = goals.indexWhere((g) => g.id == goal.id);
    if (i >= 0) {
      goals[i] = goal;
    } else {
      goals.add(goal);
    }
    await _persist(goals);
  }

  Future<void> remove(String id) async =>
      _persist([..._stored]..removeWhere((g) => g.id == id));

  Future<void> _persist(List<StudyGoal> stored) async {
    final source = ref.read(vaultSourceProvider);
    if (source != null) await GoalStore(source).save(stored);
    ref.invalidateSelf();
    await future;
  }
}

/// The id of the goal currently in focus — what readiness/pace/the daily plan
/// compute against, and (from G5) the selected hub lane. Defaults to the whole-
/// vault default goal, so single-goal behavior is unchanged. Device-local UI state.
@Riverpod(keepAlive: true)
class SelectedStudyGoalId extends _$SelectedStudyGoalId {
  @override
  String build() => defaultGoalId;

  void select(String id) => state = id;
}

/// The goal currently in focus — the selected goal, falling back to the default
/// (first) when the selection isn't present. Readiness scopes its cards to
/// `goal.select(...)` and its target to this goal (G2/G3a).
@riverpod
Future<StudyGoal> activeStudyGoal(Ref ref) async {
  final goals = await ref.watch(studyGoalsProvider.future);
  final id = ref.watch(selectedStudyGoalIdProvider);
  return goals.firstWhere((g) => g.id == id, orElse: () => goals.first);
}
