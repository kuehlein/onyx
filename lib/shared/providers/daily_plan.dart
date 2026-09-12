import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/plan/daily_plan.dart';
import '../../core/plan/gating.dart';
import '../../core/plan/practice_plan.dart';
import '../models/card.dart';
import 'clock.dart';
import 'interview.dart';
import 'practice_plan.dart';
import 'readiness.dart';
import 'srs.dart';
import 'vault.dart';

part 'daily_plan.g.dart';

/// The day's time budget (minutes). A flat default for now; phase 4 ramps this up
/// with sustained consistency and tapers it near a prep date.
@riverpod
double dailyBudgetMinutes(Ref ref) => 90;

/// The assembled daily plan: raw availability (phase 1) + prerequisite gating +
/// level/recency/cadence context, run through the pure meta-scheduler (phase 2).
/// This is what Home renders and the coach reasons about.
@riverpod
Future<DailyPlan> dailyPlan(Ref ref) async {
  final availRaw = await ref.watch(practiceAvailabilityProvider.future);
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final targeting = await ref.watch(targetingProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final now = clock.now();
  final budget = ref.watch(dailyBudgetMinutesProvider);

  // Per-concept comfort = fraction of a concept card's sections that are studied.
  final comfort = <String, double>{};
  final conceptLabel = <String, String>{};
  for (final c in index.cards) {
    if (c.type != CardType.flashcard) continue;
    final q = c.quizzableSections.toList();
    if (q.isEmpty) continue;
    final studied =
        q.where((s) => states.byKey.containsKey('${c.id}::${s.slug}')).length;
    comfort[c.id] = studied / q.length;
    conceptLabel[c.id] = c.title;
  }

  // Prerequisites: algorithm groups (static) + system-design problems (their
  // `## Related` concept links that resolve to real concept cards).
  final conceptIds = comfort.keys.toSet();
  final prereqs = <String, List<String>>{...algoGroupPrereqs};
  for (final c in index.cards) {
    if (c.type != CardType.systemDesign) continue;
    prereqs[c.id] = [
      for (final w in c.wikilinks)
        if (conceptIds.contains(w)) w,
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
    TrackId.learn: 1.0,
    TrackId.algorithms: targeting.weightForDomain('ds-a'),
    TrackId.systemDesign: targeting.weightForDomain('system-design'),
  };

  // Recency = fraction of the last 7 days each track was practiced (variety).
  final since = now.subtract(const Duration(days: 7));
  final attempts =
      await ref.watch(appliedRepositoryProvider).attempts(since: since);
  final reviewTs =
      await ref.watch(srsRepositoryProvider).studyTimestamps(since: since);
  int days(Iterable<DateTime> ds) =>
      {for (final d in ds) DateTime(d.year, d.month, d.day)}.length;
  final recency = <TrackId, double>{
    TrackId.review: days(reviewTs) / 7,
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
    // Learn recency is left at 0 for now (its activity isn't in these logs).
  };

  // Reserved: review is a daily non-negotiable; a system-design mock is reserved
  // only when one is genuinely due to re-practice (its spaced clock is overdue),
  // so it surfaces on cadence (~2–3×/week), never back-to-back.
  final reserved = <TrackId>{TrackId.review};
  final sd = gated.firstWhere(
    (a) => a.track == TrackId.systemDesign,
    orElse: () =>
        const TrackAvailability(track: TrackId.systemDesign, units: []),
  );
  if (sd.unlocked && sd.units.isNotEmpty) {
    final recog = await ref.watch(recognitionRepositoryProvider).loadStates();
    final anyDue = sd.units.any((u) {
      final st = recog['${u.id}::mock'];
      return st != null && !st.dueAt.isAfter(now);
    });
    if (anyDue) reserved.add(TrackId.systemDesign);
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
