import 'deck.dart';

/// Splits the shared daily study budget across concurrent goals (task #30d, G4).
///
/// [totalMinutes] is divided among the **active** goals in proportion to their
/// [Deck.budgetWeight]. Paused/graduated goals (and non-positive weights)
/// get nothing and are simply excluded from the denominator, so a paused goal's
/// share flows to the active ones — "pause redistributes" falls out for free.
/// Returns a `deckId → minutes` map; empty when no goal is active.
///
/// A single active goal receives the whole budget, so single-goal behavior is
/// unchanged.
Map<String, double> allocateBudget({
  required List<Deck> goals,
  required double totalMinutes,
}) {
  final active = [
    for (final g in goals)
      if (g.isActive && g.budgetWeight > 0) g,
  ];
  final sum = active.fold(0.0, (a, g) => a + g.budgetWeight);
  if (sum <= 0) return const {};
  return {
    for (final g in active) g.id: totalMinutes * g.budgetWeight / sum,
  };
}

/// A deck's daily-time allocation health (deck_selection.md: "warn on
/// too-little-time"). [none] = fine.
enum DeckAllocationWarning {
  /// Below the engagement floor — too little to learn or retain much.
  tooLittle,

  /// The deck runs long practice sessions (e.g. a ~40-min system-design mock) that
  /// can't fit in its daily slice — that flow can never run.
  longSessionWontFit,

  none,
}

/// Warn when a deck's share of the shared daily budget leaves it too little time to
/// be useful (deck_selection.md). [allocatedMinutes] is the deck's slice (from
/// [allocateBudget]); [hasLongSessions] is true when the deck declares a
/// practice-track flow (a long conversational / re-solve session), whose unit cost
/// is [longSessionMinutes] (≈ the longest session, system design). Below
/// [engagementFloor] there's too little time to learn or retain; below a long
/// session's cost that flow can never run. Pure → unit-tested; the copy lives in the
/// UI (the subject-neutral seam). Recommendations from feasibility are a later,
/// suggestions-only layer (#116) — this is the hard floor.
DeckAllocationWarning deckAllocationWarning({
  required double allocatedMinutes,
  required bool hasLongSessions,
  double longSessionMinutes = 40,
  double engagementFloor = 15,
}) {
  if (allocatedMinutes < engagementFloor) {
    return DeckAllocationWarning.tooLittle;
  }
  if (hasLongSessions && allocatedMinutes < longSessionMinutes) {
    return DeckAllocationWarning.longSessionWontFit;
  }
  return DeckAllocationWarning.none;
}
