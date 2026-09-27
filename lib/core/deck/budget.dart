import 'deck.dart';

/// Cross-deck allocation of the shared daily study budget (task #30d G4 · #137 ·
/// [ADR-0018](../../../docs/adr/0018-cross-deck-allocation-priority-tiers.md)).
///
/// Each active deck's share is DERIVED from its aims' priority tiers × a
/// budget-independent deadline factor (never a numeric dial), over a per-deck
/// engagement floor so a de-prioritized subject slows but never stalls. The whole
/// computation is **budget-independent** by necessity: `deckBudgets` runs UPSTREAM of
/// the budget-aware readiness forecast (B2, ADR-0016), so reading feasibility/the
/// forecast here would form a cycle.

/// Minutes below which a deck can't learn or retain much — the engagement floor
/// (deck_selection.md). Every ACTIVE deck is kept at or above this in the split so a
/// de-prioritized subject keeps progressing (SuperMemo "deprioritize, not delete").
const double kEngagementFloorMinutes = 15;

/// Peak multiplier a near deadline adds to a dated aim's cross-deck weight — capped
/// so deadline urgency never dominates the user's importance tier (the "mere urgency
/// effect", ADR-0018). Tunable (calibration is dogfood, not literature).
const double kDeadlinePeak = 1.5;

/// Days over which [deadlineFactor] ramps 1.0 → [kDeadlinePeak] as an aim's date
/// nears (mirrors the within-deck proximity window). Tunable.
const int kDeadlineWindowDays = 60;

/// The budget-INDEPENDENT deadline-urgency multiplier for a dated aim (ADR-0018):
/// 1.0 when far off or undated, ramping to [peak] as [date] approaches [today], and
/// [peak] on/after it. Pure. Deliberately coarse (proximity only, NOT the FSRS
/// feasibility) so it can run upstream of the budget-aware forecast without a cycle.
double deadlineFactor(DateTime? date, DateTime today,
    {int window = kDeadlineWindowDays, double peak = kDeadlinePeak}) {
  if (date == null) return 1.0;
  final days = date.difference(today).inDays;
  if (days >= window) return 1.0;
  if (days <= 0) return peak;
  return 1.0 + (peak - 1.0) * (1.0 - days / window);
}

/// A deck's cross-deck priority WEIGHT (ADR-0018): the **max** over its active aims of
/// `importance.weight × deadlineFactor` — the deck's pull is set by its most-demanding
/// aim, so aims from different decks interleave by their own priority (the Latin-exam
/// > chem-test > Latin-quiz case; the within-deck split then orders the two Latin
/// aims, #136). Max (not sum) keeps an all-normal multi-deck vault an equal split
/// regardless of aim count. A coverage-only deck (no active aims) uses its own
/// [Deck.priority] tier. Pure; budget-independent.
double deckPriorityWeight(Deck deck, DateTime today) {
  var maxW = 0.0;
  for (final a in deck.aims) {
    if (!a.active || a.status.isEnded) continue;
    final w =
        a.importance.weight * deadlineFactor(a.currentRound()?.date, today);
    if (w > maxW) maxW = w;
  }
  // maxW == 0 ⇒ no active aims ⇒ a coverage-only deck: fall back to its deck tier.
  return maxW > 0 ? maxW : deck.priority.weight;
}

/// Splits [totalMinutes] across the ACTIVE decks by [deckPriorityWeight], keeping
/// every active deck at or above [floor] (ADR-0018): give each the floor first, then
/// divide the remainder by weight. A single active deck gets the whole budget. If the
/// floors can't all fit (too many active decks for the day), they scale down to an
/// equal split — the too-little-time warning ([deckAllocationWarning]) fires on the
/// result. Returns `deckId → minutes`; empty when nothing is active. Pure.
Map<String, double> allocateBudget({
  required List<Deck> goals,
  required double totalMinutes,
  required DateTime today,
  double floor = kEngagementFloorMinutes,
}) {
  final active = [
    for (final g in goals)
      if (g.isActive) g,
  ];
  if (active.isEmpty || totalMinutes <= 0) return const {};
  final n = active.length;
  // Floors don't all fit → an equal split (each below the floor; warned on the result).
  if (floor * n >= totalMinutes) {
    return {for (final g in active) g.id: totalMinutes / n};
  }
  final weights = {for (final g in active) g.id: deckPriorityWeight(g, today)};
  final sumW = weights.values.fold(0.0, (a, w) => a + w);
  if (sumW <= 0) {
    return {for (final g in active) g.id: totalMinutes / n}; // all-zero → equal
  }
  final remainder = totalMinutes - floor * n;
  return {
    for (final g in active) g.id: floor + remainder * weights[g.id]! / sumW,
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
/// UI (the subject-neutral seam). Fires when too many active decks push a slice under
/// the floor (ADR-0018 scale-down case).
DeckAllocationWarning deckAllocationWarning({
  required double allocatedMinutes,
  required bool hasLongSessions,
  double longSessionMinutes = 40,
  double engagementFloor = kEngagementFloorMinutes,
}) {
  if (allocatedMinutes < engagementFloor) {
    return DeckAllocationWarning.tooLittle;
  }
  if (hasLongSessions && allocatedMinutes < longSessionMinutes) {
    return DeckAllocationWarning.longSessionWontFit;
  }
  return DeckAllocationWarning.none;
}
