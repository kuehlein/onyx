/// The general dependency-gating engine (task #30c / Phase 2, see
/// docs/practice-flow-plan.md). Generalizes the SWE-specific coverage gating in
/// `lib/core/plan/gating.dart` to any flow/card via a declared `depends-on` list,
/// gated on **competence** (durability), not mere coverage.
///
/// Pure and competence-measure-agnostic: the caller supplies `competenceOf`
/// (0..1 per concept — durability from FSRS state in production), so this same
/// engine serves both flow-unlocking and the AI's covered-concept frontier.
library;

/// A gated flow/card unlocks once at least this fraction of its dependencies
/// clear the bar. The single unlock fraction for BOTH gates — the daily plan's
/// comfort gate (`plan/gating.dart`) delegates to [evaluateGate] too.
const double kDefaultPrereqFraction = 0.6;

/// The result of evaluating one flow/card's dependency gate.
class GateStatus {
  const GateStatus({
    required this.unlocked,
    required this.metFraction,
    required this.satisfied,
    required this.weak,
  });

  /// True once [metFraction] clears the required fraction.
  final bool unlocked;

  /// Fraction of dependencies at/above the competence bar (0..1).
  final double metFraction;

  /// Dependency concept ids that clear the bar.
  final List<String> satisfied;

  /// Dependency concept ids still below the bar — what to route back into the
  /// concept study queue (and what an override is "provisional" on).
  final List<String> weak;

  bool get hasDeps => satisfied.isNotEmpty || weak.isNotEmpty;
}

/// Evaluate a flow/card's dependency gate. [competenceOf] returns 0..1 for a
/// concept id (unknown → treated as 0). No dependencies → unlocked.
GateStatus evaluateGate({
  required List<String> dependsOn,
  required double Function(String conceptId) competenceOf,
  required double competenceBar,
  double requiredFraction = kDefaultPrereqFraction,
}) {
  if (dependsOn.isEmpty) {
    return const GateStatus(
        unlocked: true, metFraction: 1, satisfied: [], weak: []);
  }
  final satisfied = <String>[];
  final weak = <String>[];
  for (final c in dependsOn) {
    (competenceOf(c) >= competenceBar ? satisfied : weak).add(c);
  }
  final frac = satisfied.length / dependsOn.length;
  return GateStatus(
    unlocked: frac >= requiredFraction - 1e-9,
    metFraction: frac,
    satisfied: satisfied,
    weak: weak,
  );
}

/// The learner's covered-knowledge **frontier**: the concepts at/above the bar —
/// the set a conversation/mock AI may draw on (so it never uses material the
/// learner hasn't covered). Same competence measure as [evaluateGate].
Set<String> coveredFrontier({
  required Iterable<String> concepts,
  required double Function(String conceptId) competenceOf,
  required double competenceBar,
}) =>
    {
      for (final c in concepts)
        if (competenceOf(c) >= competenceBar) c,
    };
