import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/goal/budget.dart';
import '../../core/goal/interview_aim.dart';
import '../../core/plan/daily_plan.dart';
import '../../core/plan/gating.dart';
import '../../core/plan/practice_plan.dart';
import '../models/card.dart';
import 'clock.dart';
import 'interview.dart';
import 'practice_plan.dart';
import 'readiness.dart';
import 'settings.dart';
import 'srs.dart';
import 'study_goals.dart';
import 'vault.dart';

part 'daily_plan.g.dart';

/// The day's time budget (minutes): ramps from a short ease-in up to the
/// user's [DailyTargetMinutes] (default ~2.5 h) as the habit takes hold (driven
/// by recent active days). The taper near an interview is applied to the Learn
/// track in [dailyPlan], not by shrinking the whole budget.
@riverpod
Future<double> dailyBudgetMinutes(Ref ref) async {
  final clock = await ref.watch(clockProvider.future);
  final since = clock.now().subtract(const Duration(days: 14));
  final ts =
      await ref.watch(srsRepositoryProvider).studyTimestamps(since: since);
  final activeDays =
      {for (final d in ts) DateTime(d.year, d.month, d.day)}.length;
  final target = await ref.watch(dailyTargetMinutesProvider.future);
  // Never ramp toward a target below the ease-in floor (small custom targets
  // are the whole budget, no ramp).
  final easeIn =
      target < kEaseInStartMinutes ? target.toDouble() : kEaseInStartMinutes;
  return rampedBudgetMinutes(
    recentActiveDays: activeDays,
    targetMinutes: target.toDouble(),
    easeInStartMinutes: easeIn,
  );
}

/// The shared daily budget split across the active goals by weight, honoring
/// pause (task #30d, G4): `goalId → minutes`. A single active goal gets the whole
/// budget, so single-goal behavior is unchanged.
@riverpod
Future<Map<String, double>> goalBudgets(Ref ref) async {
  final goals = await ref.watch(studyGoalsProvider.future);
  final total = await ref.watch(dailyBudgetMinutesProvider.future);
  return allocateBudget(goals: goals, totalMinutes: total);
}

/// The assembled daily plan: raw availability (phase 1) + prerequisite gating +
/// level/recency/cadence context, run through the pure meta-scheduler (phase 2).
/// This is what Home renders and the coach reasons about. Computed for the active
/// goal, budgeted to its slice of the shared daily time (G4).
@riverpod
Future<DailyPlan> dailyPlan(Ref ref) async {
  final availRaw = await ref.watch(practiceAvailabilityProvider.future);
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final targeting = await ref.watch(activeTargetingProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final now = clock.now();
  // The active goal's slice of the shared budget. A single active goal owns the
  // whole budget (goalBudgets → {id: total}); an inactive (paused/graduated)
  // selected goal isn't in the split, so it gets no plan budget (0), not the
  // whole day.
  final goal = await ref.watch(activeStudyGoalProvider.future);
  final budgets = await ref.watch(goalBudgetsProvider.future);
  final double budget = budgets[goal.id] ?? 0;

  // Days until the nearest upcoming interview (for the learn taper). The active
  // goal's ACTIVE interviews (Phase B — interviews live on the study goal now;
  // [goal] was already watched above, before the first await).
  final interviews = [
    for (final iv in goal.interviews)
      if (iv.active) iv
  ];
  final today = DateTime(now.year, now.month, now.day);
  int? daysUntilInterview;
  for (final iv in interviews) {
    if (iv.status.isEnded) continue;
    final d = iv.currentRound(goal.id, goal.deadline)?.date;
    if (d == null) continue;
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (days >= 0 &&
        (daysUntilInterview == null || days < daysUntilInterview)) {
      daysUntilInterview = days;
    }
  }

  // Per-concept comfort = fraction of a concept card's sections that are studied.
  // Also index concept cards by filename slug, because `## Related` wikilinks
  // resolve by FILENAME while comfort is keyed by card id — and the vault mixes
  // id conventions (some slug, some UUID), so a filename→id hop is required for
  // gating to see the prerequisite at all.
  final comfort = <String, double>{};
  final conceptLabel = <String, String>{};
  final conceptIdByFile = <String, String>{};
  for (final c in index.cards) {
    if (c.type != kTypeFlashcard) continue;
    final slug = c.filePath.split('/').last.replaceFirst(RegExp(r'\.md$'), '');
    conceptIdByFile[slug] = c.id;
    final q = c.quizzableSections.toList();
    if (q.isEmpty) continue;
    final studied =
        q.where((s) => states.byKey.containsKey('${c.id}::${s.slug}')).length;
    comfort[c.id] = studied / q.length;
    conceptLabel[c.id] = c.title;
  }

  // Prerequisites: algorithm groups (static, keyed by concept card id) +
  // system-design problems (their `## Related` links, each resolved
  // filename→card id and kept only if we can gauge its comfort).
  final prereqs = <String, List<String>>{...algoGroupPrereqs};
  for (final c in index.cards) {
    if (c.type != kTypeSystemDesign) continue;
    prereqs[c.id] = [
      for (final w in c.wikilinks)
        if (conceptIdByFile[w] case final id? when comfort.containsKey(id)) id,
    ];
  }

  final gated = gatePracticeAvailabilities(
    availabilities: availRaw,
    prereqsByCard: prereqs,
    comfortByConcept: comfort,
    labelForConcept: (s) => conceptLabel[s] ?? s,
  );

  // Base weights: review/learn are high foundational constants; algorithms and
  // system design ride the readiness target's domain weights, so the mix shifts
  // with level (junior → algos heavier, staff → system design heavier).
  final baseWeight = <TrackId, double>{
    TrackId.review: 1.2,
    // Taper new learning as an interview nears (preserve retrieval + mocks).
    TrackId.learn:
        1.0 * learnTaperFactor(daysUntilInterview: daysUntilInterview),
    TrackId.algorithms: targeting.weightForDomain('ds-a'),
    TrackId.systemDesign: targeting.weightForDomain('system-design'),
  };

  // Recency = fraction of the last 7 days each track was practiced (variety).
  final since = now.subtract(const Duration(days: 7));
  final attempts =
      await ref.watch(appliedRepositoryProvider).attempts(since: since);
  final srs = ref.watch(srsRepositoryProvider);
  final reviewTs = await srs.studyTimestamps(since: since);
  final learnTs = await srs.learnTimestamps(since: since);
  int days(Iterable<DateTime> ds) =>
      {for (final d in ds) DateTime(d.year, d.month, d.day)}.length;
  final recency = <TrackId, double>{
    TrackId.review: days(reviewTs) / 7,
    TrackId.learn: days(learnTs) / 7,
    TrackId.algorithms: days([
          for (final a in attempts)
            if (a.source == 'algo') a.occurredAt
        ]) /
        7,
    TrackId.systemDesign: days([
          for (final a in attempts)
            if (a.source == 'sd-practice') a.occurredAt
        ]) /
        7,
  };

  // Reserved: review is a daily non-negotiable; a mock track (system design,
  // behavioral) is reserved only when one is genuinely due to re-practice (its
  // spaced clock is overdue), so it surfaces on cadence (~2–3×/week), never
  // back-to-back.
  final reserved = <TrackId>{TrackId.review};
  final recog = await ref.watch(recognitionRepositoryProvider).loadStates();
  bool anyMockDue(TrackId track) {
    final a = gated.firstWhere(
      (a) => a.track == track,
      orElse: () => TrackAvailability(track: track, units: const []),
    );
    if (!a.unlocked || a.units.isEmpty) return false;
    return a.units.any((u) {
      final st = recog['${u.id}::mock'];
      return st != null && !st.dueAt.isAfter(now);
    });
  }

  if (anyMockDue(TrackId.systemDesign)) reserved.add(TrackId.systemDesign);

  return buildDailyPlan(
    availabilities: gated,
    budgetMinutes: budget,
    ctx: PlanContext(
      baseWeight: baseWeight,
      recencyLoad: recency,
      reserved: reserved,
    ),
  );
}
