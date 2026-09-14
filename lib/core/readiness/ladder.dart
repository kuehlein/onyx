/// Where the user's *current* knowledge sits on a ladder of interview targets,
/// independent of the target they're aiming at. The same recall model is scored
/// against every rung (each rung's weights + durability bar), so the answer is
/// "the most demanding rung your knowledge base currently clears" — a
/// recalibration signal: aim at Senior·FAANG, but discover you're at Mid·FAANG
/// today and could apply accordingly. Still recall-only; not a mock-validated
/// "interview-ready" claim.
library;

import '../../shared/models/card.dart';
import '../subject/active_subject.dart';
import '../interview/transfer.dart';
import 'readiness.dart';
import 'target.dart';

/// One rung: a (level, context) pair by slot id. Track is held to the user's
/// choice. #30 Phase 2: generated from the active subject's slots, not hardcoded.
class Rung {
  const Rung(this.levelId, this.contextId, this.label);

  final String levelId;
  final String contextId;
  final String label;
}

/// The rungs in increasing demand — level-major, first context value before the
/// second (SWE: Typical before FAANG), generated from the active subject config.
/// A getter (not a memoized final) so it always reflects the current
/// [activeSubject] — which the vault loader may set after startup (#30 Phase 5).
List<Rung> get readinessLadder => [
      for (final level in activeSubject.target.levels)
        for (final context in activeSubject.target.contexts)
          Rung(level.id, context.id, '${level.label} · ${context.label}'),
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

  // Snapshot the (config-generated) ladder once — the getter rebuilds it on every
  // access, so read it a single time here for consistency + to avoid O(n²) rebuilds.
  final ladder = readinessLadder;
  final scores = <double>[];
  for (final rung in ladder) {
    final t = target.copyWith(levelId: rung.levelId, contextId: rung.contextId);
    final r = computeReadiness(
      cards: cards,
      stabilityByKey: stabilityByKey,
      stabilityTarget: t.stabilityTarget,
      domainWeights: {for (final d in domains) d: domainWeight(t, d)},
      // Seniority now differentiates rungs by tier DEPTH (higher rungs require
      // advanced tiers), not by reshuffling domain weights — so the ladder stays
      // meaningful with domainWeight level-independent.
      tierWeights: tierWeightsFor(t),
      transferByDomain: transferByDomain,
    );
    scores.add(r.overall);
  }

  final n = ladder.length;
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

  final goalIndex = _rungIndex(ladder, target.levelId, target.contextId);
  final goalFraction = ((goalIndex + 1) / n).clamp(0.0, 1.0).toDouble();

  return LadderPosition(
    rungScores: scores,
    clearedCount: cleared,
    youFraction: youFraction,
    goalIndex: goalIndex,
    goalFraction: goalFraction,
    currentLabel: cleared == 0 ? null : ladder[cleared - 1].label,
    rungsToGo: ((goalIndex + 1) - cleared).clamp(0, n),
  );
}

int _rungIndex(List<Rung> ladder, String levelId, String contextId) {
  for (var i = 0; i < ladder.length; i++) {
    if (ladder[i].levelId == levelId && ladder[i].contextId == contextId) {
      return i;
    }
  }
  return 0;
}
