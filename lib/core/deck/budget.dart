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
