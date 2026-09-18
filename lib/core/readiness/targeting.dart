import '../../shared/models/card.dart';
import '../goal/interview_aim.dart';
import 'target.dart';

/// The effective study targeting for one goal: the goal's base [ReadinessTarget]
/// combined with its ACTIVE [InterviewAim]s (Phase B — the interviews replace the
/// legacy `List<PrepGoal>`). Consumers (learn order, readiness weighting, pace)
/// read this, so a specific interview biases study — while FSRS state stays pure
/// (see the fsrs-exam-targeting memory: it biases learn order, readiness, pace,
/// and per-card desired-retention only).
///
/// With no active interviews this is behaviorally identical to reading the base
/// target directly. The interviews share the goal's [base] slots (their AI-plan
/// `domainWeights`/`conceptWeights` carry the per-company bias), so `domainWeight`
/// — which depends only on the track — is the base's for each.
class Targeting {
  const Targeting({
    required this.base,
    this.interviews = const [],
    this.goalId = '',
    this.deadline,
  });

  /// The goal's aim — supplies level/track and the readiness stability bar.
  final ReadinessTarget base;

  /// The goal's ACTIVE interviews (the caller filters out muted ones).
  final List<InterviewAim> interviews;

  /// The goal's id + due date — seed a single-date interview's synthetic round.
  final String goalId;
  final DateTime? deadline;

  /// Effective per-domain weight: the base heuristic, raised by whichever active
  /// interview boosts the domain most (max, not sum — one urgent interview
  /// shouldn't be diluted, nor overlapping ones double-count).
  double weightForDomain(String domain) {
    final baseW = domainWeight(base, domain);
    var w = baseW;
    for (final iv in interviews) {
      final gw = baseW + (iv.domainWeights[domain] ?? 0);
      if (gw > w) w = gw;
    }
    return w;
  }

  /// Card-level weight: its domain weight plus the strongest concept boost any
  /// active interview places on one of the card's concepts. Drives learn ordering.
  double weightForCard(Card card) {
    final w = weightForDomain(card.domain ?? '');
    var boost = 0.0;
    for (final iv in interviews) {
      if (iv.conceptWeights.isEmpty) continue;
      for (final c in card.concepts) {
        final b = iv.conceptWeights[c];
        if (b != null && b > boost) boost = b;
      }
    }
    return w + boost;
  }

  /// The soonest interview date across the base target + active interviews — the
  /// date pace/urgency should reason about. Null when nothing is scheduled.
  DateTime? get governingDate {
    DateTime? soonest = base.interviewDate;
    for (final iv in interviews) {
      for (final d in iv.roundDates(goalId, deadline)) {
        if (soonest == null || d.isBefore(soonest)) soonest = d;
      }
    }
    return soonest;
  }

  /// The readiness "durability" bar (unchanged from the base target for now).
  double get stabilityTarget => base.stabilityTarget;

  /// How many days out an interview's date starts pulling target-card retention up.
  static const peakWindowDays = 21;

  /// The retention ceiling — above this, FSRS workload explodes for little gain
  /// (see fsrs-exam-targeting). We never push a card past this.
  static const retentionCap = 0.95;

  /// The FSRS-safe interview lever: the card's base desired-retention raised toward
  /// [retentionCap] for cards a NEAR-TERM active interview emphasizes, ramping up
  /// as the interview nears. This ONLY changes scheduling (shorter intervals →
  /// fresher on the date), never the fitted stability/difficulty, and reverts to
  /// base once the interview passes / is muted. [today] anchors the proximity ramp.
  double desiredRetentionForCard(Card card, {required DateTime today}) {
    final base = card.priority.desiredRetention;
    var best = base;
    for (final iv in interviews) {
      // Ramp retention toward the NEXT upcoming round — as round 1 passes, the
      // focus shifts to round 2, etc.
      final date = iv.nextRoundDate(goalId, deadline, today);
      if (date == null) continue;
      final daysLeft =
          DateTime(date.year, date.month, date.day).difference(today).inDays;
      if (daysLeft < 0 || daysLeft > peakWindowDays) continue;
      if (!_interviewTargets(iv, card)) continue;
      final proximity =
          1 - daysLeft / peakWindowDays; // 0 at edge → 1 on the day
      final bumped = base + (retentionCap - base) * proximity;
      if (bumped > best) best = bumped;
    }
    return best;
  }

  /// Whether [iv] emphasizes this card — an explicit domain/concept boost.
  /// (The track heuristic is the base's, shared by all interviews, so it can't
  /// distinguish one interview here.)
  bool _interviewTargets(InterviewAim iv, Card card) {
    final dom = card.domain;
    if (dom != null && iv.domainWeights.containsKey(dom)) return true;
    return card.concepts.any((c) => iv.conceptWeights.containsKey(c));
  }
}
