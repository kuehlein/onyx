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

/// The sustained daily target once the habit is established (~2.5 h). Effective
/// deliberate practice tops out ~2–4 h/day; this is the default aim, adjustable.
const double kDailyTargetMinutes = 150;

/// Where the ramp starts on day one — a shorter session to seat the routine
/// without dropping a new user straight into a full 2.5-hour day.
const double kEaseInStartMinutes = 90;

/// Ramp the daily budget from [easeInStartMinutes] up to [targetMinutes] as the
/// habit takes hold — reaching the target after ~[rampDays] recent active days.
/// A short on-ramp (days, not weeks), because a real interview deadline can't wait
/// out a slow ramp. A missed day barely dents it (driven by *recent* active days,
/// not a fragile streak).
double rampedBudgetMinutes({
  double targetMinutes = kDailyTargetMinutes,
  double easeInStartMinutes = kEaseInStartMinutes,
  required int recentActiveDays,
  int rampDays = 7,
}) {
  final t = (recentActiveDays / rampDays).clamp(0.0, 1.0);
  final b = easeInStartMinutes + (targetMinutes - easeInStartMinutes) * t;
  return b.clamp(easeInStartMinutes, targetMinutes);
}

/// Where a daily study-time budget sits on the sustainability spectrum — the
/// in-the-moment readout when the user moves the budget dial (ADR-0011, the
/// "informed override": the user owns the size, so the app *informs* rather than
/// changes it). Grounded in the deliberate-practice literature: focused, effective
/// practice tops out ~2–4 h/day, and beyond that quality and retention fall. Pure
/// → unit-tested; the label + color live in the UI (subject-neutral). This is a
/// zone, never a red "wrong" — a bigger day is a choice, flagged honestly.
enum BudgetZone { light, sustainable, ambitious, tooMuch }

/// Classify a daily-budget [minutes] into a [BudgetZone] (see [BudgetZone]).
/// ~2.5 h (the default target) is squarely sustainable; past ~3.5 h a day is hard
/// to hold without quality slipping.
BudgetZone budgetZone(int minutes) {
  if (minutes < 45) return BudgetZone.light;
  if (minutes <= 165) return BudgetZone.sustainable;
  if (minutes <= 210) return BudgetZone.ambitious;
  return BudgetZone.tooMuch;
}

/// As an interview nears, taper *new-learning* load (preserve retrieval/mocks).
/// Returns a 0..1 multiplier for the Learn track's weight — 1.0 when far out or no
/// date, easing down to [floor] by the interview day.
double learnTaperFactor({
  int? daysUntilInterview,
  int taperStartDays = 14,
  double floor = 0.2,
}) {
  if (daysUntilInterview == null || daysUntilInterview >= taperStartDays) {
    return 1;
  }
  if (daysUntilInterview <= 0) {
    return floor;
  }
  final f = daysUntilInterview / taperStartDays;
  return f < floor ? floor : f;
}

/// Default per-track importance when the caller supplies none.
const double kDefaultBaseWeight = 0.5;

/// How much a track done a lot lately is down-weighted (variety). At
/// recencyLoad=1 a track's priority is cut by this fraction.
const double kRecencyPenalty = 0.6;

/// The default share of the day the retention floor (due reviews) may claim before
/// the remainder is fair-queued to new/practice — the retention-floor cap
/// (ADR-0010 Phase B / #106). Due reviews clear FIRST up to this fraction, so
/// retrieval never loses to new material; the cap keeps a heavy backlog from eating
/// the whole day (a slice always remains for practice/new). Any budget no other
/// track can use still flows back to reviews (they're never dropped to waste time),
/// so on a normal day — due-load well under the cap — this changes nothing. 0.8
/// mirrors the field consensus: reviews are the priority, but a backlog is shed at
/// the *new* lever, not by letting reviews consume every minute.
const double kRetentionFloorCap = 0.8;

/// Inputs to [buildDailyPlan] beyond raw availability. Populated later phases from
/// readiness (level/domain weights), recent activity, and cadence; injected here
/// so the scheduler stays pure and testable.
class PlanContext {
  const PlanContext({
    this.baseWeight = const {},
    this.recencyLoad = const {},
    this.reserved = const {},
    this.floor = const {},
    this.floorCap = kRetentionFloorCap,
  });

  /// Track importance, 0..1 (research × level × domain). Missing → [kDefaultBaseWeight].
  final Map<String, double> baseWeight;

  /// How much each track has been done recently, 0..1 (down-weights it for variety).
  final Map<String, double> recencyLoad;

  /// Tracks that must get at least their top fitting unit today if available
  /// (e.g. a cadence-due mock). One-and-done, before the fair-queue.
  final Set<String> reserved;

  /// Retention-floor tracks (#106 / ADR-0010 Phase B): their due units are cleared
  /// FIRST, greedily in priority order, before anything else is fair-queued — so
  /// retrieval never loses to new material on a heavy day. Bounded by [floorCap] of
  /// the budget so a big backlog can't crowd out practice/new; any budget no other
  /// track can use still flows back to them (never dropped to waste time). Empty →
  /// the packer behaves exactly as before. Today the provider sets `{review}`.
  final Set<String> floor;

  /// The fraction of the budget the [floor] may claim before the remainder is
  /// fair-queued to the other tracks (default [kRetentionFloorCap]). Only bites on
  /// heavy-review days; normal due-loads sit well under it.
  final double floorCap;

  double priority(String t) {
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
    required this.label,
    required this.units,
    required this.deferred,
    required this.nonNegotiable,
  });

  final String track;

  /// Human-readable track name, carried from [TrackAvailability.label].
  final String label;

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

/// A compact, human-readable summary of the day's plan, for the coach's context
/// (so it can talk about today's load, sequencing, and what to trim without
/// another round-trip). Pure.
String describeDailyPlan(DailyPlan plan) {
  if (plan.tracks.isEmpty && plan.locked.isEmpty) {
    return 'Today: nothing scheduled — all caught up '
        '(budget ~${plan.budgetMinutes.round()} min/day).';
  }
  final b = StringBuffer()
    ..writeln("Today's plan (~${plan.plannedMinutes.round()} of "
        '${plan.budgetMinutes.round()} min budget):');
  for (final t in plan.tracks) {
    final n = t.units.length;
    final core = t.nonNegotiable ? ', must-do' : '';
    final later = t.deferred > 0 ? ', +${t.deferred} deferred' : '';
    b.writeln('  - ${t.label}: $n item${n == 1 ? '' : 's'}, '
        '~${t.estMinutes.round()} min$core$later');
  }
  for (final l in plan.locked) {
    b.writeln('  - ${l.label}: locked — '
        '${l.gateReason ?? 'prerequisites not yet met'}');
  }
  return b.toString().trimRight();
}

/// Build the day's plan. Pure. [budgetMinutes] is the day's time budget.
///
/// Weighted fair-queuing bin-packer: proportions (from [PlanContext.baseWeight])
/// are a soft attractor, not hard quotas — indivisible lumpy units bend them, and
/// leftover time flows to whoever has a fitting unit. This is the mechanism the
/// across-aims allocation rides (urgency-weighted emphasis, not per-aim slices —
/// n007); S3 sets the weights, this packs them.
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

  final scheduled = {for (final a in eligible) a.track: <PracticeUnit>[]};
  final used = {for (final a in eligible) a.track: 0.0};
  final cursor = {for (final a in eligible) a.track: 0};
  var budgetLeft = budgetMinutes;

  // First not-yet-considered unit of [t] that fits the remaining budget, or -1.
  // Skips (abandons) higher-priority units that are too big — budget only shrinks,
  // so they can't fit later this build; they become "deferred".
  int nextFitting(String t) {
    final units = byTrack[t]!.units;
    for (var i = cursor[t]!; i < units.length; i++) {
      if (units[i].estMinutes <= budgetLeft + 1e-9) return i;
    }
    return -1;
  }

  void schedule(String t, int i) {
    final u = byTrack[t]!.units[i];
    scheduled[t]!.add(u);
    used[t] = used[t]! + u.estMinutes;
    budgetLeft -= u.estMinutes;
    cursor[t] = i + 1;
  }

  // 0) Retention floor (#106 / ADR-0010 Phase B): clear the floor tracks' due units
  // FIRST, greedily in priority order, up to floorCap of the budget — so reviews
  // clear before new material competes, and a heavy backlog can't eat the whole day.
  // The rest divide only what's left; true leftover flows back to the floor (step 3).
  final floorTracks = [
    for (final a in eligible)
      if (ctx.floor.contains(a.track)) a.track,
  ]..sort((x, y) => pri[y]!.compareTo(pri[x]!));
  final floorCapMinutes = budgetMinutes * ctx.floorCap;
  var floorUsed = 0.0;
  for (final t in floorTracks) {
    for (var i = nextFitting(t); i >= 0; i = nextFitting(t)) {
      final m = byTrack[t]!.units[i].estMinutes;
      if (floorUsed + m > floorCapMinutes + 1e-9) break;
      floorUsed += m;
      schedule(t, i);
    }
  }

  // The non-floor tracks split the post-floor remainder; floor tracks sit out the
  // reserve + fair-queue (they've had their priority pass) until step 3.
  final rest = [
    for (final a in eligible)
      if (!ctx.floor.contains(a.track)) a,
  ];
  final restPri = rest.fold(0.0, (s, a) => s + pri[a.track]!);
  final postFloorBudget = budgetLeft;

  // 1) Reserve non-negotiable (non-floor) tracks' top fitting unit (priority order).
  final reservedEligible = [
    for (final a in rest)
      if (ctx.reserved.contains(a.track)) a.track,
  ]..sort((x, y) => pri[y]!.compareTo(pri[x]!));
  for (final t in reservedEligible) {
    final i = nextFitting(t);
    if (i >= 0) schedule(t, i);
  }

  // 2) Weighted fair-queuing among the rest: repeatedly give the next fitting unit
  // to the track furthest below its priority-proportional share of the post-floor
  // budget.
  double fairShare(String t) => restPri > 0
      ? pri[t]! / restPri * postFloorBudget
      : (rest.isEmpty ? 0 : postFloorBudget / rest.length);

  while (true) {
    String? best;
    var bestDeficit = double.negativeInfinity;
    for (final a in rest) {
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

  // 3) Leftover → floor tracks (uncapped): if budget remains that no other track can
  // use, clear more due reviews rather than waste the day.
  for (final t in floorTracks) {
    for (var i = nextFitting(t); i >= 0; i = nextFitting(t)) {
      schedule(t, i);
    }
  }

  // 3) Assemble — only tracks with work; priority order; mark non-negotiables.
  final topPri =
      eligible.map((a) => a.track).reduce((x, y) => pri[x]! >= pri[y]! ? x : y);
  final planned = [
    for (final a in eligible)
      if (scheduled[a.track]!.isNotEmpty)
        PlannedTrack(
          track: a.track,
          label: a.label,
          units: scheduled[a.track]!,
          deferred: a.units.length - scheduled[a.track]!.length,
          nonNegotiable: ctx.reserved.contains(a.track) ||
              (ctx.reserved.isEmpty && a.track == topPri),
        ),
  ]..sort((x, y) => pri[y.track]!.compareTo(pri[x.track]!));

  return DailyPlan(
      tracks: planned, budgetMinutes: budgetMinutes, locked: locked);
}
