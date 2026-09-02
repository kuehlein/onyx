import '../../shared/models/card.dart';
import 'prep_goal.dart';
import 'target.dart';

/// The effective study targeting: the base [ReadinessTarget] (your general aim)
/// combined with the ACTIVE interview [PrepGoal]s that layer on top. Consumers
/// (learn order, readiness weighting, pace) read this instead of the raw target,
/// so a specific interview can bias what you study — while FSRS state stays pure
/// (see the fsrs-exam-targeting memory: it biases learn order, readiness, pace,
/// and per-card desired-retention only; an optional non-rescheduling cram is a
/// later add).
///
/// With no active goals this is behaviourally identical to reading the base
/// target directly (weights reduce to `domainWeight(base, …)`).
class Targeting {
  const Targeting({required this.base, required this.goals});

  /// The general aim — supplies level/track and the readiness stability bar.
  final ReadinessTarget base;

  /// The ACTIVE prep goals (caller filters out inactive ones).
  final List<PrepGoal> goals;

  /// Effective per-domain weight: the base heuristic, raised by whichever active
  /// goal demands the domain most (max, not sum — one urgent goal shouldn't be
  /// diluted, nor should overlapping goals double-count).
  double weightForDomain(String domain) {
    var w = domainWeight(base, domain);
    for (final g in goals) {
      final gw =
          domainWeight(g.toTarget(), domain) + (g.domainWeights[domain] ?? 0);
      if (gw > w) w = gw;
    }
    return w;
  }

  /// Card-level weight: its domain weight plus the strongest concept boost any
  /// active goal places on one of the card's concepts. Drives learn ordering.
  double weightForCard(Card card) {
    final base = weightForDomain(card.domain ?? '');
    var boost = 0.0;
    for (final g in goals) {
      if (g.conceptWeights.isEmpty) continue;
      for (final c in card.concepts) {
        final b = g.conceptWeights[c];
        if (b != null && b > boost) boost = b;
      }
    }
    return base + boost;
  }

  /// The soonest interview date across the base target + active goals — the date
  /// pace/urgency should reason about. Null when nothing is scheduled.
  DateTime? get governingDate {
    DateTime? soonest = base.interviewDate;
    for (final g in goals) {
      final d = g.date;
      if (d != null && (soonest == null || d.isBefore(soonest))) soonest = d;
    }
    return soonest;
  }

  /// The readiness "durability" bar (unchanged from the base target for now).
  double get stabilityTarget => base.stabilityTarget;

  /// How many days out a goal's date starts pulling target-card retention up.
  static const peakWindowDays = 21;

  /// The retention ceiling — above this, FSRS workload explodes for little gain
  /// (see fsrs-exam-targeting). We never push a card past this.
  static const retentionCap = 0.95;

  /// The FSRS-safe interview lever: the card's base desired-retention (from its
  /// priority) raised toward [retentionCap] for cards a NEAR-TERM active goal
  /// emphasises, ramping up as the interview nears. This ONLY changes scheduling
  /// (shorter intervals → fresher on the date), never the fitted
  /// stability/difficulty, and reverts to base once the goal passes / is toggled
  /// off. [today] anchors the proximity ramp.
  double desiredRetentionForCard(Card card, {required DateTime today}) {
    final base = card.priority.desiredRetention;
    var best = base;
    for (final g in goals) {
      final date = g.date;
      if (date == null) continue;
      final daysLeft =
          DateTime(date.year, date.month, date.day).difference(today).inDays;
      if (daysLeft < 0 || daysLeft > peakWindowDays) continue;
      if (!_goalTargets(g, card)) continue;
      final proximity =
          1 - daysLeft / peakWindowDays; // 0 at edge → 1 on the day
      final bumped = base + (retentionCap - base) * proximity;
      if (bumped > best) best = bumped;
    }
    return best;
  }

  /// Whether [g] emphasises this card — an explicit domain/concept boost, or a
  /// role whose heuristic weights the card's domain above the base aim.
  bool _goalTargets(PrepGoal g, Card card) {
    final dom = card.domain;
    if (dom != null) {
      if (g.domainWeights.containsKey(dom)) return true;
      if (domainWeight(g.toTarget(), dom) > domainWeight(base, dom) + 1e-9) {
        return true;
      }
    }
    return card.concepts.any((c) => g.conceptWeights.containsKey(c));
  }
}
