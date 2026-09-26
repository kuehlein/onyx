import '../plan/practice_plan.dart'
    show kReviewMinutes, reviewEst, sustainableNewCount;
import '../srs/srs_scheduler.dart';
import '../../shared/models/card.dart';
import 'readiness.dart';
import 'target.dart';

/// Forward-simulation projection of recall readiness (#49). It answers "at this
/// daily time budget, when will my relevance-weighted recall readiness cross the
/// target?" by rolling the deck forward day-by-day through the REAL FSRS scheduler:
/// each day clears the due-review queue, then introduces the new sections the budget
/// affords — DERIVED via [sustainableNewCount] from the budget minus that day's
/// review load (ADR-0016), re-derived daily so review-debt honestly throttles intake
/// (essential-first) — advancing per-section stability, then samples
/// [computeReadiness] to find the crossing day. (A fixed `newSectionsPerDay` pace is
/// the base primitive for the pure sim tests.)
///
/// Scope + honesty: this projects RECALL maturation only (coverage growth +
/// FSRS stability growth) — the applied/mock (transfer) dimension is a separate
/// axis the user schedules independently, so it's excluded from the date. It
/// assumes reviews are cleared daily and a sustained passing grade (the desired
/// retention). Report the result as a hedged range (see [readyDay] + scenarios),
/// never a false-precise single day.

/// The current FSRS state of one section, or "unstudied" when [state] is null.
class SectionSrsState {
  const SectionSrsState({
    this.stability,
    this.difficulty,
    this.state,
    this.step,
    this.due,
    this.lastReview,
  });

  final double? stability;
  final double? difficulty;
  final int? state; // fsrs 1=learning 2=review 3=relearning; null = unstudied
  final int? step;
  final DateTime? due;
  final DateTime? lastReview;

  bool get studied => state != null;
}

/// A study-pace policy to project under. Reviews are cleared first each day; the
/// lever for NEW material is either a fixed count or — the budget-native forecast
/// (ADR-0016) — a daily time [budgetMinutes] the engine converts to a new-count.
class PacePolicy {
  const PacePolicy({
    this.newSectionsPerDay = 0,
    this.budgetMinutes,
    this.desiredRetention = 0.9,
  }) : assert(newSectionsPerDay > 0 || budgetMinutes != null,
            'a pace needs a fixed new/day or a budget');

  /// Fixed new-sections/day. The base primitive (used by the pure sim tests);
  /// IGNORED when [budgetMinutes] is set.
  final int newSectionsPerDay;

  /// When set, the day's new-count is DERIVED from this daily time budget minus that
  /// day's due-review load ([sustainableNewCount], ADR-0016) — and re-derived EACH
  /// simulated day, so growing review-debt honestly throttles new intake (the same
  /// dynamic the real daily plan runs). This is what makes the ready-date respond to
  /// the user's budget dial, and it's why the forecast is honest for a fresh deck
  /// (whose intake naturally slows as reviews pile up).
  final double? budgetMinutes;

  final double desiredRetention;
}

class ProjectionPoint {
  const ProjectionPoint(this.day, this.readiness);
  final int day; // days from today
  final double readiness; // overall relevance-weighted readiness at that day
}

class ReadinessProjection {
  const ReadinessProjection({
    required this.trajectory,
    required this.readyDay,
    required this.threshold,
    required this.horizonDays,
    required this.startReadiness,
  });

  /// Sampled (day, readiness) points from today to the horizon.
  final List<ProjectionPoint> trajectory;

  /// Days from today until readiness first crosses [threshold]; null if it does
  /// not within [horizonDays] at this pace.
  final int? readyDay;

  final double threshold;
  final int horizonDays;
  final double startReadiness;

  bool get alreadyReady => readyDay == 0;
  bool get unreachable => readyDay == null;
}

/// One point on the **budget → ready-day** curve: at this daily time budget
/// (minutes), the target is reached in [readyDay] days (null if unreachable within
/// the horizon). The user's lever is the budget (ADR-0010), so the curve is keyed on
/// it — not on the derived new/day.
class BudgetPoint {
  const BudgetPoint(this.budgetMinutes, this.readyDay);
  final double budgetMinutes;
  final int? readyDay;
}

/// The daily-time-budget span (minutes) the forecast samples over — a light day up
/// to an ambitious one. Beyond ~[kMaxForecastBudget] a day isn't sustainable (see
/// `budgetZone`), so a date needing more reads as infeasible rather than prescribing
/// an unrealistic budget.
const double kMinForecastBudget = 30;
const double kMaxForecastBudget = 300;

/// The forecast surfaced in the UI, keyed on the user's actual lever — the daily
/// time **budget** (ADR-0010). Holds a budget → ready-day CURVE so the same data
/// powers the ready-date readout, the "to hit a chosen date, raise your budget to
/// ~N min" answer, and the budget-dial date-shift (ADR-0011 §D5) — no per-interaction
/// recompute. [currentPerDay] is the engine-DERIVED new/day at [currentBudget]
/// (ADR-0016) — a felt quantity for display, never a dial.
class ReadinessForecast {
  const ReadinessForecast({
    required this.curve,
    required this.currentBudget,
    required this.currentPerDay,
    required this.today,
    required this.startReadiness,
    required this.threshold,
  });

  final List<BudgetPoint> curve; // ascending by budgetMinutes
  final double currentBudget;
  final int currentPerDay;
  final DateTime today;
  final double startReadiness;
  final double threshold;

  bool get alreadyReady => startReadiness >= threshold;

  DateTime? _date(int? day) =>
      day == null ? null : today.add(Duration(days: day));

  BudgetPoint? _pointAt(double budget) {
    BudgetPoint? best;
    var bestD = double.infinity;
    for (final p in curve) {
      final d = (p.budgetMinutes - budget).abs();
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  int? readyDayForBudget(double budget) =>
      alreadyReady ? 0 : _pointAt(budget)?.readyDay;
  DateTime? readyDateForBudget(double budget) =>
      _date(readyDayForBudget(budget));

  int? get currentReadyDay => readyDayForBudget(currentBudget);
  DateTime? get currentReadyDate => _date(currentReadyDay);

  double get chillBudget =>
      (currentBudget * 0.66).clamp(kMinForecastBudget, kMaxForecastBudget);
  double get pushBudget =>
      (currentBudget * 1.5).clamp(kMinForecastBudget, kMaxForecastBudget);
  DateTime? get chillReadyDate => readyDateForBudget(chillBudget);
  DateTime? get pushReadyDate => readyDateForBudget(pushBudget);

  /// Smallest sampled BUDGET that reaches the target within [daysFromToday], or null
  /// if even the largest sampled budget can't. Ascending budget → the first that
  /// meets the deadline is the minimum (more budget → sooner, so this is monotone).
  double? requiredBudgetFor(int daysFromToday) {
    if (alreadyReady) {
      return curve.isEmpty ? currentBudget : curve.first.budgetMinutes;
    }
    for (final p in curve) {
      final rd = p.readyDay;
      if (rd != null && rd <= daysFromToday) return p.budgetMinutes;
    }
    return null;
  }

  /// The soonest day any sampled budget reaches the target (fastest curve point).
  int? get earliestReadyDay {
    if (alreadyReady) return 0;
    int? best;
    for (final p in curve) {
      final rd = p.readyDay;
      if (rd != null && (best == null || rd < best)) best = rd;
    }
    return best;
  }

  DateTime? get earliestReadyDate => _date(earliestReadyDay);

  /// The largest budget we sampled — used to phrase "even at ~N min/day…".
  double get maxSampledBudget =>
      curve.isEmpty ? currentBudget : curve.last.budgetMinutes;
}

/// Runs the projection across a spread of daily-time BUDGETS (plus the current + a
/// push/ease around it) to build the budget → ready-day curve, with the shared start
/// readiness (budget doesn't affect day 0). Each budget re-derives its new-count
/// per day (ADR-0016), so the curve is the honest "at this budget, ready when".
({List<BudgetPoint> curve, double startReadiness}) projectBudgetCurve({
  required List<Card> cards,
  required Map<String, SectionSrsState> stateByKey,
  required ReadinessTarget target,
  required double currentBudget,
  required DateTime today,
  double desiredRetention = 0.9,
  double threshold = 0.75,
  int horizonDays = 365,
}) {
  final cur = currentBudget.clamp(kMinForecastBudget, kMaxForecastBudget);
  final chill = (cur * 0.66).clamp(kMinForecastBudget, cur);
  final push = (cur * 1.5).clamp(cur, kMaxForecastBudget);
  final budgets = <double>{
    30,
    60,
    90,
    120,
    150,
    180,
    210,
    240,
    300,
    chill,
    cur,
    push,
  }.toList()
    ..sort();
  final points = <BudgetPoint>[];
  var start = 0.0;
  for (final b in budgets) {
    final proj = projectReadiness(
      cards: cards,
      stateByKey: stateByKey,
      target: target,
      pace: PacePolicy(budgetMinutes: b, desiredRetention: desiredRetention),
      today: today,
      threshold: threshold,
      horizonDays: horizonDays,
    );
    start = proj.startReadiness;
    points.add(BudgetPoint(b, proj.readyDay));
  }
  return (curve: points, startReadiness: start);
}

class _SecSim {
  _SecSim(SectionSrsState s)
      : stability = s.stability,
        difficulty = s.difficulty,
        state = s.state,
        step = s.step,
        due = s.due,
        lastReview = s.lastReview;

  double? stability;
  double? difficulty;
  int? state;
  int? step;
  DateTime? due;
  DateTime? lastReview;
}

/// Runs the projection. [today] and any [SectionSrsState.due] are absolute dates
/// used to drive FSRS scheduling. [threshold] defaults to the dashboard's
/// "Strong" goal line (0.75).
ReadinessProjection projectReadiness({
  required List<Card> cards,
  required Map<String, SectionSrsState> stateByKey,
  required ReadinessTarget target,
  required PacePolicy pace,
  required DateTime today,
  double threshold = 0.75,
  int horizonDays = 365,
  int sampleEvery = 7,
  SrsScheduler? scheduler,
}) {
  // No fuzz in a forecast: the projected ready-date must be deterministic (stable
  // run-to-run) and monotonic across paces — fuzz would jitter both.
  final sched = scheduler ?? SrsScheduler(enableFuzzing: false);
  final tierWeights = tierWeightsFor(target);
  final domains = <String>{
    for (final c in cards)
      if (c.domain != null) c.domain!,
  };
  final domainWeights = {for (final d in domains) d: domainWeight(target, d)};

  final work = <String, _SecSim>{};
  final stability = <String, double>{};
  // Unstudied in-scope sections, ordered most-relevant-first (a smart plan
  // front-loads essential material, so readiness rises as fast as it can).
  final unstudied = <({String key, double rel})>[];

  for (final card in cards) {
    if (card.domain == null) continue;
    final rel = (domainWeights[card.domain] ?? 1.0) *
        target.spec.tierRelevance(target.levelId, card.tiers[card.domain]);
    for (final section in card.quizzableSections) {
      final key = '${card.id}::${section.slug}';
      final st = stateByKey[key];
      if (st != null && st.studied) {
        work[key] = _SecSim(st);
        stability[key] = st.stability ?? 0;
      } else {
        unstudied.add((key: key, rel: rel));
      }
    }
  }
  unstudied.sort((a, b) => b.rel.compareTo(a.rel));

  double readinessNow() => computeReadiness(
        cards: cards,
        stabilityByKey: stability,
        stabilityTarget: target.stabilityTarget,
        domainWeights: domainWeights,
        tierWeights: tierWeights,
      ).overall;

  void reviewInto(String key, _SecSim sim, DateTime at) {
    final out = sched.review(
      grade: 3, // sustained "Good" at the desired retention
      reviewedAt: at,
      desiredRetention: pace.desiredRetention,
      stability: sim.stability,
      difficulty: sim.difficulty,
      state: sim.state,
      step: sim.step,
      due: sim.due,
      lastReview: sim.lastReview,
    );
    sim
      ..stability = out.stability
      ..difficulty = out.difficulty
      ..state = out.state
      ..step = out.step
      ..due = out.due
      ..lastReview = out.lastReview;
    stability[key] = out.stability;
  }

  final traj = <ProjectionPoint>[];
  final start = readinessNow();
  traj.add(ProjectionPoint(0, start));
  int? readyDay = start >= threshold ? 0 : null;

  var newIdx = 0;
  for (var day = 1; day <= horizonDays; day++) {
    final date = today.add(Duration(days: day));
    // 1. clear due reviews, tallying their est-minutes (at pre-review maturity) so
    // the budget-native path knows how much of today the budget goes to reviews.
    var reviewMinutes = 0.0;
    for (final entry in work.entries) {
      final due = entry.value.due;
      if (due != null && !due.isAfter(date)) {
        if (pace.budgetMinutes != null) {
          reviewMinutes += reviewEst(kReviewMinutes,
              stability: entry.value.stability, fsrsState: entry.value.state);
        }
        reviewInto(entry.key, entry.value, date);
      }
    }
    // 2. introduce new sections (essential-first). The count is either the fixed
    // pace or — the budget-native forecast (ADR-0016) — DERIVED from the budget minus
    // today's review load, re-derived each day so growing review-debt throttles it.
    final newCount = pace.budgetMinutes != null
        ? sustainableNewCount(
            budgetMinutes: pace.budgetMinutes!, dueReviewMinutes: reviewMinutes)
        : pace.newSectionsPerDay;
    for (var i = 0; i < newCount && newIdx < unstudied.length; i++, newIdx++) {
      final key = unstudied[newIdx].key;
      final sim = _SecSim(const SectionSrsState());
      reviewInto(key, sim, date);
      work[key] = sim;
    }
    // 3. sample
    if (day % sampleEvery == 0 || day == horizonDays) {
      final r = readinessNow();
      traj.add(ProjectionPoint(day, r));
      if (readyDay == null && r >= threshold) {
        // linear-interpolate the crossing between the previous sample and here
        final prev = traj[traj.length - 2];
        final span = day - prev.day;
        final frac = (r - prev.readiness) <= 0
            ? 0.0
            : (threshold - prev.readiness) / (r - prev.readiness);
        readyDay = (prev.day + frac.clamp(0, 1) * span).round();
      }
    }
  }

  return ReadinessProjection(
    trajectory: traj,
    readyDay: readyDay,
    threshold: threshold,
    horizonDays: horizonDays,
    startReadiness: start,
  );
}
