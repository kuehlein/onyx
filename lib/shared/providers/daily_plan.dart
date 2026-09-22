import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/goal/budget.dart';
import '../../core/goal/aim.dart';
import '../../core/plan/daily_plan.dart';
import '../../core/plan/gating.dart';
import '../../core/plan/practice_plan.dart';
import '../../core/template/active_template.dart';
import '../../core/template/flow_spec.dart';
import 'clock.dart';
import 'concept_comfort.dart';
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
  // Register every dependency synchronously (before the first await) so a
  // mid-flight invalidation (e.g. a goal edit rebuilding studyGoals) can't leave
  // this using a disposed ref after the async gap.
  final availF = ref.watch(practiceAvailabilityProvider.future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final statesF = ref.watch(srsStatesProvider.future);
  final targetingF = ref.watch(activeTargetingProvider.future);
  final clockF = ref.watch(clockProvider.future);
  final goalF = ref.watch(activeStudyGoalProvider.future);
  final budgetsF = ref.watch(goalBudgetsProvider.future);
  final availRaw = await availF;
  final index = await indexF;
  final states = await statesF;
  final targeting = await targetingF;
  final clock = await clockF;
  final now = clock.now();
  // The active goal's slice of the shared budget. A single active goal owns the
  // whole budget (goalBudgets → {id: total}); an inactive (paused/graduated)
  // selected goal isn't in the split, so it gets no plan budget (0), not the
  // whole day.
  final goal = await goalF;
  final budgets = await budgetsF;
  final double budget = budgets[goal.id] ?? 0;

  // Days until the nearest upcoming interview (for the learn taper). The active
  // goal's ACTIVE interviews (Phase B — interviews live on the study goal now;
  // [goal] is watched above, before the first await).
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

  // Per-concept comfort for prerequisite gating — shared with the flow runner
  // (was duplicated in both). See buildConceptComfort.
  final cc = buildConceptComfort(index.cards, states.byKey.keys.toSet());

  // Prerequisites, from three sources, each resolved to a concept whose comfort
  // we can gauge: algorithm groups (static, keyed by concept card id), plus each
  // card's own concepts — drawn from its `## Related` wikilinks or its
  // `depends-on` field, chosen by the card's FLOW (config, not a `type ==`
  // branch — invariant #2): SD problems gate on wikilinks, everything else on
  // `depends-on` (e.g. a Korean `conversation` gating on its vocabulary). No SWE
  // card declares `depends-on`, so that branch is additive for the SWE deck.
  final prereqs = <String, List<String>>{...algoGroupPrereqs};
  for (final c in index.cards) {
    final source =
        templateFor(c.templateId).flowForType(c.type)?.prereqSource ??
            PrereqSource.dependsOn;
    switch (source) {
      case PrereqSource.wikilinks:
        prereqs[c.id] = [
          for (final w in c.wikilinks)
            if (cc.idByFile[w] case final id? when cc.comfort.containsKey(id))
              id,
        ];
      case PrereqSource.dependsOn:
        if (c.dependsOn.isNotEmpty) {
          prereqs[c.id] = [
            for (final dep in c.dependsOn)
              if ((cc.idByFile[dep] ?? dep) case final id
                  when cc.comfort.containsKey(id))
                id,
          ];
        }
    }
  }

  final gated = gatePracticeAvailabilities(
    availabilities: availRaw,
    prereqsByCard: prereqs,
    comfortByConcept: cc.comfort,
    labelForConcept: (s) => cc.label[s] ?? s,
  );

  // Base weights: review/learn are high foundational constants; each practice
  // track rides the readiness target's domain weight named by its flow's
  // `weightDomain`, so the mix shifts with level (junior → algos heavier, staff
  // → system design heavier). Recall tracks (review/learn) keep their constants.
  final flowByType = {for (final f in activeTemplate.flows) f.cardType: f};
  bool isRecall(String t) => t == kTrackReview || t == kTrackLearn;

  final baseWeight = <String, double>{
    kTrackReview: 1.2,
    // Taper new learning as an interview nears (preserve retrieval + mocks).
    kTrackLearn: 1.0 * learnTaperFactor(daysUntilInterview: daysUntilInterview),
    for (final a in gated)
      if (!isRecall(a.track))
        a.track: switch (flowByType[a.track]?.weightDomain) {
          final d? => targeting.weightForDomain(d),
          _ => 1.0,
        },
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
  final recency = <String, double>{
    kTrackReview: days(reviewTs) / 7,
    kTrackLearn: days(learnTs) / 7,
    for (final a in gated)
      if (!isRecall(a.track))
        a.track: switch (flowByType[a.track]?.attemptSource) {
          final s? => days([
                for (final at in attempts)
                  if (at.source == s) at.occurredAt
              ]) /
              7,
          _ => 0.0,
        },
  };

  // Reserved: review is a daily non-negotiable; a mock track (system design,
  // behavioral) is reserved only when one is genuinely due to re-practice (its
  // spaced clock is overdue), so it surfaces on cadence (~2–3×/week), never
  // back-to-back.
  final reserved = <String>{kTrackReview};
  final recog = await ref.watch(recognitionRepositoryProvider).loadStates();
  bool anyMockDue(String track) {
    final a = gated.firstWhere(
      (a) => a.track == track,
      orElse: () => TrackAvailability(track: track, label: '', units: const []),
    );
    if (!a.unlocked || a.units.isEmpty) return false;
    return a.units.any((u) {
      final st = recog['${u.id}::mock'];
      return st != null && !st.dueAt.isAfter(now);
    });
  }

  for (final a in gated) {
    if (flowByType[a.track]?.scheduling == SchedulingModel.mock &&
        anyMockDue(a.track)) {
      reserved.add(a.track);
    }
  }

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
