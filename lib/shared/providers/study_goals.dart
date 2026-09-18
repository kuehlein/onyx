import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/goal/aim_migration.dart';
import '../../core/goal/goal_store.dart';
import '../../core/goal/study_goal.dart';
import '../../core/readiness/goals_service.dart';
import '../../core/readiness/target_service.dart';
import 'subject.dart';
import 'vault.dart';

part 'study_goals.g.dart';

/// The study goals live in the vault (task #30d, docs/multi-subject-plan.md).
///
/// The user's study goals: the ones persisted in `_meta/` (G3b) if any exist,
/// otherwise a single synthesized default goal (the whole vault, targeted by the
/// primary template). The default is purely the *no-goals* fallback — once the
/// user defines explicit goals, the whole-vault goal steps aside (it would overlap
/// every lane). An empty store → just the default goal, identical to pre-#30d.
///
/// keepAlive (like [SelectedStudyGoalId] and the readiness-target/prep-goal
/// notifiers): it's user state, and `_persist` relies on `invalidateSelf()` +
/// `await future` resolving against a live element rather than a disposed one.
@Riverpod(keepAlive: true)
class StudyGoals extends _$StudyGoals {
  @override
  Future<List<StudyGoal>> build() async {
    final registry = await ref.watch(subjectRegistryProvider.future);
    final source = ref.watch(vaultSourceProvider);
    final loaded =
        source == null ? const <StudyGoal>[] : await GoalStore(source).load();
    final stored = [
      for (final g in loaded)
        if (g.id != defaultGoalId) g,
    ];
    // Fall back to the whole-vault default when there are no *non-graduated*
    // goals — with all goals archived, Home/readiness must not silently run off a
    // graduated goal (it degrades to the default whole-vault view instead).
    final anyLive = stored.any((g) => g.state != GoalState.graduated);
    if (anyLive) return stored;
    if (source == null) return [defaultGoalFor(registry.primary)];
    // The whole-vault default, enriched from the legacy aim stores (Phase B2):
    // the base target's slots/deadline + the interview PrepGoals fold in. This is
    // a read-only fold — the legacy files stay authoritative, and nothing reads
    // the default goal's slots/interviews yet (readiness short-circuits to the
    // legacy target for the default goal), so it's inert until B3 flips targeting.
    final baseTarget = await TargetService(source).load();
    final prepGoals = await GoalsService(source).load();
    return [
      migratedDefaultGoal(registry.primary,
          baseTarget: baseTarget, prepGoals: prepGoals),
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

/// The one spine of "which goal am I looking at" (ADR-0005). **Nullable: null =
/// the all-goals hub altitude** (only reached with ≥2 active goals, before a lane
/// is entered); a goal id = that goal is focused. Replaces both the old local
/// `_focused` setState in Home *and* the `SelectedStudyGoalId` side-effect
/// provider — Home, Browse, Insights, readiness, pace and the daily plan all read
/// this one value, so a route/deep-link can set it and every surface agrees.
/// Device-local UI state; keepAlive so it can be set before Home builds.
@Riverpod(keepAlive: true)
class FocusedGoal extends _$FocusedGoal {
  @override
  String? build() => null;

  /// Focus a goal by id, or clear focus (null = the hub).
  void focus(String? id) => state = id;
}

/// The number of **active** goals (paused and graduated excluded) — the single
/// helper every degradation check reads, so "1 active + N paused" behaves like a
/// single-goal app everywhere (ADR-0005).
@riverpod
Future<int> activeGoalCount(Ref ref) async {
  final goals = await ref.watch(studyGoalsProvider.future);
  return goals.where((g) => g.isActive).length;
}

/// The goal currently in focus — the selected goal, falling back to the default
/// (first) when the selection isn't present. Readiness scopes its cards to
/// `goal.select(...)` and its target to this goal (G2/G3a).
@riverpod
Future<StudyGoal> activeStudyGoal(Ref ref) async {
  final goals = await ref.watch(studyGoalsProvider.future);
  // null focus (the hub) resolves to the default id, which the orElse below maps
  // to the first live goal — preserving the pre-spine single-goal behavior.
  final id = ref.watch(focusedGoalProvider) ?? defaultGoalId;
  return goals.firstWhere(
    (g) => g.id == id,
    // No selection match → the first non-graduated goal (never an archived one),
    // else just the first.
    orElse: () => goals.firstWhere(
      (g) => g.state != GoalState.graduated,
      orElse: () => goals.first,
    ),
  );
}

/// The set of card ids that belong to a goal — its [StudyGoal.select] membership
/// applied to the studiable cards (task #30d, G2). This is the **one scoping key**
/// every per-goal analytic filters its rows by (retention, mocks, forecast,
/// leeches…), mirroring how `goalReadiness` scopes its card set. The whole-vault
/// default goal selects every studiable card, so a single-goal app filters
/// against "all ids" — a no-op — and the numbers are byte-identical.
@riverpod
Future<Set<String>> goalMemberCardIds(Ref ref, String goalId) async {
  final goalsF = ref.watch(studyGoalsProvider.future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final goals = await goalsF;
  final index = await indexF;
  final goal =
      goals.firstWhere((g) => g.id == goalId, orElse: () => goals.first);
  return {for (final c in goal.select(index.studyCards)) c.id};
}
