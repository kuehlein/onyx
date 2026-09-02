import '../../shared/models/card.dart';
import 'prep_goal.dart';
import 'target.dart';

/// The effective study targeting: the base [ReadinessTarget] (your general aim)
/// combined with the ACTIVE interview [PrepGoal]s that layer on top. Consumers
/// (learn order, readiness weighting, pace) read this instead of the raw target,
/// so a specific interview can bias what you study — while FSRS state stays pure
/// (see the fsrs-exam-targeting memory; desired-retention/cram come later).
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
}
