/// The daily-plan meta-scheduler (task #57, phase 2).
///
/// Pure: given each flow's [TrackAvailability] (phase 1) and a time budget, it
/// produces the day's ordered, time-boxed task list. It schedules nothing itself
/// and reads no providers — the per-flow schedulers stay the source of truth; this
/// only *selects and sizes* what to surface today.
///
/// Design (matches the study-plan doc):
///  - **Balance across domains, not all-in-on-one.** The budget is split by track
///    priority (research/level weight, down-weighted by how much you've done a
///    track lately), so no single flow drains the day.
///  - **Bin-pack the highest-priority units that FIT.** Within a track, take units
///    in the flow's own priority order, skipping any that don't fit the remaining
///    budget — a 40-min problem is skipped for a 10-min one and left deferred
///    (it rises in its own scheduler and returns near the front next day).
///  - **Reserve non-negotiables.** Tracks the caller marks reserved (e.g. daily
///    review, a cadence-due mock) get their top fitting unit before the rest.
///  - **Hide low-value overflow.** Tracks that get no time today are omitted (no
///    inviting exhausted, low-value work); locked tracks are surfaced separately
///    so the UI can explain what unlocks them.
library;

import 'practice_plan.dart';

/// Default per-track importance when the caller supplies none.
const double kDefaultBaseWeight = 0.5;

/// How much a track done a lot lately is down-weighted (variety). At
/// recencyLoad=1 a track's priority is cut by this fraction.
const double kRecencyPenalty = 0.6;

/// Inputs to [buildDailyPlan] beyond raw availability. Populated later phases from
/// readiness (level/domain weights), recent activity, and cadence; injected here
/// so the scheduler stays pure and testable.
class PlanContext {
  const PlanContext({
    this.baseWeight = const {},
    this.recencyLoad = const {},
    this.reserved = const {},
  });

  /// Track importance, 0..1 (research × level × domain). Missing → [kDefaultBaseWeight].
  final Map<TrackId, double> baseWeight;

  /// How much each track has been done recently, 0..1 (down-weights it for variety).
  final Map<TrackId, double> recencyLoad;

  /// Tracks that must get at least their top fitting unit today if available
  /// (e.g. daily review, a cadence-due mock).
  final Set<TrackId> reserved;

  double priority(TrackId t) {
    final base = baseWeight[t] ?? kDefaultBaseWeight;
    final rec = (recencyLoad[t] ?? 0).clamp(0.0, 1.0);
    final p = base * (1 - kRecencyPenalty * rec);
    return p < 0 ? 0 : p;
  }
}

/// One track's scheduled work for the day.
class PlannedTrack {
  const PlannedTrack({
    required this.track,
    required this.units,
    required this.deferred,
    required this.nonNegotiable,
  });

  final TrackId track;

  /// Units to do today, in the flow's priority order.
  final List<PracticeUnit> units;

  /// Available-but-not-scheduled units (rolled to a later day).
  final int deferred;

  /// A "short on time? do these" core item.
  final bool nonNegotiable;

  double get estMinutes => units.fold(0, (s, u) => s + u.estMinutes);
}

/// The day's plan: tracks to do (priority order, only those with scheduled work),
/// the total time, and any locked tracks (for "unlocks when…" UI).
class DailyPlan {
  const DailyPlan({
    required this.tracks,
    required this.budgetMinutes,
    required this.locked,
  });

  final List<PlannedTrack> tracks;
  final double budgetMinutes;
  final List<TrackAvailability> locked;

  double get plannedMinutes => tracks.fold(0, (s, t) => s + t.estMinutes);

  bool get isEmpty => tracks.isEmpty;
}

/// Build the day's plan. Pure. [budgetMinutes] is the day's time budget.
DailyPlan buildDailyPlan({
  required List<TrackAvailability> availabilities,
  required double budgetMinutes,
  PlanContext ctx = const PlanContext(),
}) {
  final locked = [
    for (final a in availabilities)
      if (!a.unlocked) a,
  ];
  final eligible = [
    for (final a in availabilities)
      if (a.unlocked && a.units.isNotEmpty) a,
  ];
  if (eligible.isEmpty || budgetMinutes <= 0) {
    return DailyPlan(
        tracks: const [], budgetMinutes: budgetMinutes, locked: locked);
  }

  final byTrack = {for (final a in eligible) a.track: a};
  final pri = {for (final a in eligible) a.track: ctx.priority(a.track)};
  final totalPri = pri.values.fold(0.0, (s, v) => s + v);

  final scheduled = {for (final a in eligible) a.track: <PracticeUnit>[]};
  final used = {for (final a in eligible) a.track: 0.0};
  final cursor = {for (final a in eligible) a.track: 0};
  var budgetLeft = budgetMinutes;

  // First not-yet-considered unit of [t] that fits the remaining budget, or -1.
  // Skips (abandons) higher-priority units that are too big — budget only shrinks,
  // so they can't fit later this build; they become "deferred".
  int nextFitting(TrackId t) {
    final units = byTrack[t]!.units;
    for (var i = cursor[t]!; i < units.length; i++) {
      if (units[i].estMinutes <= budgetLeft + 1e-9) return i;
    }
    return -1;
  }

  void schedule(TrackId t, int i) {
    final u = byTrack[t]!.units[i];
    scheduled[t]!.add(u);
    used[t] = used[t]! + u.estMinutes;
    budgetLeft -= u.estMinutes;
    cursor[t] = i + 1;
  }

  // 1) Reserve non-negotiable tracks' top fitting unit (priority order).
  final reservedEligible = [
    for (final a in eligible)
      if (ctx.reserved.contains(a.track)) a.track,
  ]..sort((x, y) => pri[y]!.compareTo(pri[x]!));
  for (final t in reservedEligible) {
    final i = nextFitting(t);
    if (i >= 0) schedule(t, i);
  }

  // 2) Weighted fair-queuing: repeatedly give the next fitting unit to the track
  // furthest below its priority-proportional fair share of the whole budget.
  double fairShare(TrackId t) => totalPri > 0
      ? pri[t]! / totalPri * budgetMinutes
      : budgetMinutes / eligible.length;

  while (true) {
    TrackId? best;
    var bestDeficit = double.negativeInfinity;
    for (final a in eligible) {
      final t = a.track;
      if (nextFitting(t) < 0) continue;
      final deficit = fairShare(t) - used[t]!;
      if (deficit > bestDeficit ||
          (deficit == bestDeficit && (best == null || pri[t]! > pri[best]!))) {
        best = t;
        bestDeficit = deficit;
      }
    }
    if (best == null) break;
    schedule(best, nextFitting(best));
  }

  // 3) Assemble — only tracks with work; priority order; mark non-negotiables.
  final topPri =
      eligible.map((a) => a.track).reduce((x, y) => pri[x]! >= pri[y]! ? x : y);
  final planned = [
    for (final a in eligible)
      if (scheduled[a.track]!.isNotEmpty)
        PlannedTrack(
          track: a.track,
          units: scheduled[a.track]!,
          deferred: a.units.length - scheduled[a.track]!.length,
          nonNegotiable: ctx.reserved.contains(a.track) ||
              (ctx.reserved.isEmpty && a.track == topPri),
        ),
  ]..sort((x, y) => pri[y.track]!.compareTo(pri[x.track]!));

  return DailyPlan(
      tracks: planned, budgetMinutes: budgetMinutes, locked: locked);
}
