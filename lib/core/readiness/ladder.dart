/// Where the user's *current* knowledge sits on a ladder of interview targets,
/// independent of the target they're aiming at. The same recall model is scored
/// against every rung (each rung's weights + durability bar), so the answer is
/// "the most demanding rung your knowledge base currently clears" — a
/// recalibration signal: aim at Senior·FAANG, but discover you're at Mid·FAANG
/// today and could apply accordingly. Still recall-only; not a mock-validated
/// "interview-ready" claim.
library;

import '../../shared/models/card.dart';
import '../interview/transfer.dart';
import 'readiness.dart';
import 'target.dart';

/// One rung: a (level, company) pair. Track is held to the user's choice.
class Rung {
  const Rung(this.level, this.company);

  final SeniorityLevel level;
  final CompanyTier company;

  String get label => '${level.label} · ${company.label}';
}

/// The rungs in increasing demand — level-major, Typical before FAANG.
const readinessLadder = <Rung>[
  Rung(SeniorityLevel.newGrad, CompanyTier.typical),
  Rung(SeniorityLevel.newGrad, CompanyTier.faang),
  Rung(SeniorityLevel.mid, CompanyTier.typical),
  Rung(SeniorityLevel.mid, CompanyTier.faang),
  Rung(SeniorityLevel.senior, CompanyTier.typical),
  Rung(SeniorityLevel.senior, CompanyTier.faang),
  Rung(SeniorityLevel.staff, CompanyTier.typical),
  Rung(SeniorityLevel.staff, CompanyTier.faang),
];

/// The overall recall score at which a rung counts as "solidly cleared".
const ladderReadyThreshold = 0.7;

class LadderPosition {
  const LadderPosition({
    required this.rungScores,
    required this.clearedCount,
    required this.youFraction,
    required this.goalIndex,
    required this.goalFraction,
    required this.currentLabel,
    required this.rungsToGo,
  });

  /// Overall recall score against each rung, in ladder order.
  final List<double> rungScores;

  /// Length of the longest cleared prefix (rungs cleared from the bottom up).
  final int clearedCount;

  /// The "you are here" pin, 0..1 across the ladder.
  final double youFraction;

  final int goalIndex;

  /// The goal pin, 0..1 across the ladder (the goal rung's upper boundary).
  final double goalFraction;

  /// The highest cleared rung's label, or null when nothing is cleared yet.
  final String? currentLabel;

  /// Rungs between the highest cleared rung and the goal; 0 when at/above goal.
  final int rungsToGo;

  bool get atOrAboveGoal => rungsToGo == 0;
}

/// Locates the user on [readinessLadder]. Each rung is scored with its own
/// weights and durability bar, then the longest cleared prefix (contiguous from
/// the bottom, so a fluke high rung above a gap doesn't jump the marker) sets
/// the current position.
LadderPosition computeLadderPosition({
  required List<Card> cards,
  required Map<String, double> stabilityByKey,
  required ReadinessTarget target,
  Map<String, TransferEstimate>? transferByDomain,
  double threshold = ladderReadyThreshold,
}) {
  final domains = <String>{
    for (final c in cards)
      if (c.domain != null) c.domain!,
  };

  final scores = <double>[];
  for (final rung in readinessLadder) {
    final t = target.copyWith(level: rung.level, company: rung.company);
    final r = computeReadiness(
      cards: cards,
      stabilityByKey: stabilityByKey,
      stabilityTarget: t.stabilityTarget,
      domainWeights: {for (final d in domains) d: domainWeight(t, d)},
      transferByDomain: transferByDomain,
    );
    scores.add(r.overall);
  }

  final n = readinessLadder.length;
  var cleared = 0;
  for (final s in scores) {
    if (s >= threshold) {
      cleared++;
    } else {
      break;
    }
  }

  // Continuous position = fully cleared rungs + partial progress into the first
  // rung that isn't cleared yet.
  final partial =
      cleared < n ? (scores[cleared] / threshold).clamp(0.0, 1.0) : 0.0;
  final youFraction = ((cleared + partial) / n).clamp(0.0, 1.0).toDouble();

  final goalIndex = _rungIndex(target.level, target.company);
  final goalFraction = ((goalIndex + 1) / n).clamp(0.0, 1.0).toDouble();

  return LadderPosition(
    rungScores: scores,
    clearedCount: cleared,
    youFraction: youFraction,
    goalIndex: goalIndex,
    goalFraction: goalFraction,
    currentLabel: cleared == 0 ? null : readinessLadder[cleared - 1].label,
    rungsToGo: ((goalIndex + 1) - cleared).clamp(0, n),
  );
}

int _rungIndex(SeniorityLevel level, CompanyTier company) {
  for (var i = 0; i < readinessLadder.length; i++) {
    if (readinessLadder[i].level == level &&
        readinessLadder[i].company == company) {
      return i;
    }
  }
  return 0;
}
