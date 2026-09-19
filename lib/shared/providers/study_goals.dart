import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/goal/aim_migration.dart';
import '../../core/goal/goal_store.dart';
import '../../core/goal/study_goal.dart';
import '../../core/readiness/target_service.dart';
import 'subject.dart';
import 'vault.dart';

part 'study_goals.g.dart';

/// The study goals live in the vault (task #30d, docs/multi-subject-plan.md).
///
/// The user's study goals, persisted in `_meta/` (G3b). Explicit (non-default)
/// goals, when any is live, replace the whole-vault default (it would overlap every
/// lane). Otherwise a single default goal — the whole vault targeted by the primary
/// template — which is *synthesized* until the user sets a target/interview on it
/// (Phase B), at which point it persists like any goal and supersedes the
/// legacy-aim migration. An empty store → the synthesized default, identical to
/// pre-#30d.
///
/// keepAlive: it's user state, and `_persist` relies on `invalidateSelf()` +
/// `await future` resolving against a live element rather than a disposed one.
@Riverpod(keepAlive: true)
class StudyGoals extends _$StudyGoals {
  @override
  Future<List<StudyGoal>> build() async {
    final registry = await ref.watch(subjectRegistryProvider.future);
    final source = ref.watch(vaultSourceProvider);
    final loaded =
        source == null ? const <StudyGoal>[] : await GoalStore(source).load();
    // Explicit (non-default) goals replace the whole-vault default. With any
    // *live* one, run as the multi-goal hub; with all archived, Home/readiness
    // degrade to the default whole-vault view rather than a graduated goal.
    final explicit = [
      for (final g in loaded)
        if (g.id != defaultGoalId) g,
    ];
    if (explicit.any((g) => g.state != GoalState.graduated)) return explicit;
    // Single-goal mode. A *persisted* default wins over re-deriving: once the user
    // sets a target/interview on the whole-vault goal (Phase B), it's stored like
    // any goal, and the legacy aim files are ignored from then on.
    for (final g in loaded) {
      if (g.id == defaultGoalId) return [g];
    }
    if (source == null) return [defaultGoalFor(registry.primary)];
    // First run on a pre-#30d vault: fold the legacy base target + interviews
    // (the old onyx-goals.json) into the default goal, then persist it (B5) so the
    // legacy files are no longer consulted.
    final baseTarget = await TargetService(source).load();
    final interviews = await legacyInterviews(source);
    final migrated = migratedDefaultGoal(registry.primary,
        baseTarget: baseTarget, interviews: interviews);
    // Write-through: durably persist the folded default so the legacy files are no
    // longer needed (only when there IS legacy data — never persist a bare default).
    // Preserve any graduated explicit goals alongside it (they're hidden here but
    // not deleted — a plain [migrated] save would erase them). Awaited (not
    // fire-and-forget) so the file lands before this build resolves: re-derivation
    // then stops (the next build reads the stored default) and no concurrent save
    // or user edit can race it. Best-effort — a persist failure must not fail load.
    if (baseTarget != null || interviews.isNotEmpty) {
      try {
        await GoalStore(source).save([...explicit, migrated]);
      } catch (_) {
        // Non-fatal: the read-only fold still stands; we retry on the next build.
      }
    }
    return [migrated];
  }

  /// The goals currently on disk — the source of truth for a mutation, since the
  /// in-memory [state] may hold a synthesized default that isn't persisted yet.
  Future<List<StudyGoal>> _onDisk() async {
    final source = ref.read(vaultSourceProvider);
    // A fresh, modifiable copy — GoalStore.load() may hand back a const [].
    return source == null ? <StudyGoal>[] : [...await GoalStore(source).load()];
  }

  /// Add a goal or replace one by id. The whole-vault default is persistable now
  /// (Phase B — it carries the single-subject target + interviews); storing it
  /// supersedes the legacy-aim migration on the next [build].
  Future<void> upsert(StudyGoal goal) async {
    final goals = await _onDisk();
    final i = goals.indexWhere((g) => g.id == goal.id);
    if (i >= 0) {
      goals[i] = goal;
    } else {
      goals.add(goal);
    }
    await _persist(goals);
  }

  Future<void> remove(String id) async {
    final goals = await _onDisk();
    goals.removeWhere((g) => g.id == id);
    await _persist(goals);
  }

  /// The current in-memory goal by id (null if absent / still loading).
  StudyGoal? _current(String goalId) {
    for (final g in state.asData?.value ?? const <StudyGoal>[]) {
      if (g.id == goalId) return g;
    }
    return null;
  }

  /// Add or replace an interview on a goal, matched by [InterviewAim.id], then
  /// persist the goal. The interview cluster edits goals through here (Phase B) —
  /// on the whole-vault default this is what first persists it (see [upsert]).
  Future<void> upsertInterview(String goalId, InterviewAim aim) async {
    final goal = _current(goalId);
    if (goal == null) return;
    final interviews = [...goal.interviews];
    final i = interviews.indexWhere((iv) => iv.id == aim.id);
    if (i >= 0) {
      interviews[i] = aim;
    } else {
      interviews.add(aim);
    }
    await upsert(goal.copyWith(interviews: interviews));
  }

  /// Remove an interview (by id) from a goal.
  Future<void> removeInterview(String goalId, String aimId) async {
    final goal = _current(goalId);
    if (goal == null) return;
    await upsert(goal.copyWith(interviews: [
      for (final iv in goal.interviews)
        if (iv.id != aimId) iv,
    ]));
  }

  /// Mute/unmute an interview (the on/off toggle, distinct from its lifecycle
  /// status) so it does/doesn't shape targeting.
  Future<void> setInterviewActive(
      String goalId, String aimId, bool active) async {
    final goal = _current(goalId);
    if (goal == null) return;
    await upsert(goal.copyWith(interviews: [
      for (final iv in goal.interviews)
        if (iv.id == aimId) iv.copyWith(active: active) else iv,
    ]));
  }

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
