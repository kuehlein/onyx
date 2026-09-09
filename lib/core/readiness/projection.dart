import '../srs/srs_scheduler.dart';
import '../../shared/models/card.dart';
import 'readiness.dart';
import 'target.dart';

/// Forward-simulation projection of recall readiness (#49). It answers "at this
/// pace, when will my relevance-weighted recall readiness cross the target?" by
/// rolling the deck forward day-by-day through the REAL FSRS scheduler: each day
/// clears the due-review queue and introduces up to `newSectionsPerDay` new
/// sections (essential-first), advancing per-section stability, then samples
/// [computeReadiness] to find the crossing day.
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

/// A study-pace policy to project under. Reviews are assumed cleared daily; the
/// lever is how many NEW sections/day are introduced.
class PacePolicy {
  const PacePolicy({
    required this.newSectionsPerDay,
    this.desiredRetention = 0.9,
  });

  final int newSectionsPerDay;
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
  final sched = scheduler ?? SrsScheduler();
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
        tierRelevance(target.level, card.tiers[card.domain]);
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
    // 1. clear due reviews
    for (final entry in work.entries) {
      final due = entry.value.due;
      if (due != null && !due.isAfter(date)) {
        reviewInto(entry.key, entry.value, date);
      }
    }
    // 2. introduce new sections (essential-first)
    for (var i = 0;
        i < pace.newSectionsPerDay && newIdx < unstudied.length;
        i++, newIdx++) {
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

/// Convenience: project three pace scenarios (chill / current / push) so the UI
/// can show a range rather than a false-precise single date.
Map<String, ReadinessProjection> projectScenarios({
  required List<Card> cards,
  required Map<String, SectionSrsState> stateByKey,
  required ReadinessTarget target,
  required int currentPerDay,
  required DateTime today,
  double desiredRetention = 0.9,
  double threshold = 0.75,
  int horizonDays = 365,
}) {
  final chill = (currentPerDay * 0.5).round().clamp(1, 1 << 20);
  final push = (currentPerDay * 2).clamp(1, 1 << 20);
  ReadinessProjection run(int perDay) => projectReadiness(
        cards: cards,
        stateByKey: stateByKey,
        target: target,
        pace: PacePolicy(
            newSectionsPerDay: perDay, desiredRetention: desiredRetention),
        today: today,
        threshold: threshold,
        horizonDays: horizonDays,
      );
  return {
    'chill': run(chill),
    'current': run(currentPerDay.clamp(1, 1 << 20)),
    'push': run(push),
  };
}
