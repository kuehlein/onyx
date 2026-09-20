/// The unified "practice plan" data model (task #57).
///
/// The app has four practice flows — Review, Learn, Algorithms, System Design —
/// with separate schedulers. To build a single daily queue (and a plan-aware
/// coach, a unified Home, and consistent analytics) they need a *uniform view*.
/// This file is the pure model for that view; provider adapters in
/// `shared/providers/practice_plan.dart` produce it from each flow's existing
/// scheduler (an additive layer — the schedulers themselves are unchanged).
///
/// The meta-scheduler (`buildDailyPlan`, a later phase) consumes
/// [TrackAvailability]s + a time budget to produce the day's ordered, time-boxed
/// task list. Nothing here schedules; it only describes what's available.
library;

/// The four practice-track ids (String, to prepare for config-driven tracks).
///
/// The practice-track ids deliberately equal the SWE FlowSpec `cardType` values
/// so a later phase can derive them from `activeSubject.flows`; review/learn are
/// the two universal recall modes.
const String kTrackReview = 'review';
const String kTrackLearn = 'learn';
const String kTrackAlgorithms = 'algorithm'; // == the algo FlowSpec cardType
const String kTrackSystemDesign =
    'system-design'; // == the SD FlowSpec cardType

// ── Time estimates ──────────────────────────────────────────────────────────
// Rough per-unit minute estimates (used only to size the day; imperfect is fine).
// Algorithms vary widely, so they derive from the problem's difficulty; the other
// flows use sensible defaults (a card can override later via frontmatter).

/// Minutes for one due concept-card section (quick recall).
const double kReviewMinutes = 1.5;

/// Minutes to learn one new concept-card section (read a worked reference + a
/// first self-quiz).
const double kLearnMinutes = 3;

/// Minutes for one full system-design mock.
const double kSystemDesignMinutes = 40;

/// Minutes for an algorithm problem, from its difficulty (parsed from the card
/// section, e.g. "… · Medium"). Falls back to the medium estimate.
double algoEstMinutes(String sectionContent) {
  final lower = sectionContent.toLowerCase();
  if (RegExp(r'·\s*hard|\bhard\b').hasMatch(lower)) return 40;
  if (RegExp(r'·\s*easy|\beasy\b').hasMatch(lower)) return 12;
  return 25; // Medium / unknown
}

/// One schedulable unit of work in a flow (a due card section, a new section, an
/// algorithm problem, or a system-design mock). Lists of these are already
/// ordered by their flow's own priority; the meta-scheduler bin-packs the
/// highest-priority units that fit each flow's time allotment.
class PracticeUnit {
  const PracticeUnit({
    required this.track,
    required this.id,
    required this.label,
    required this.estMinutes,
  });

  final String track;

  /// Stable identifier: `"cardId::sectionSlug"` for section-based flows, or the
  /// card id for whole-card flows (algorithms/system-design).
  final String id;
  final String label;
  final double estMinutes;
}

/// What one flow has available *now*, as a priority-ordered list of units, plus
/// whether the flow is unlocked (prerequisite gating — a later phase fills the
/// real gate; until then a track is simply unlocked).
class TrackAvailability {
  const TrackAvailability({
    required this.track,
    required this.label,
    required this.units,
    this.unlocked = true,
    this.gateReason,
  });

  final String track;

  /// Human-readable track name (e.g. "Review", "System design"). Carried here
  /// because the pure core can't reach `SubjectConfig`; the provider that builds
  /// availabilities supplies it and the UI/summary render it.
  final String label;
  final List<PracticeUnit> units;
  final bool unlocked;

  /// If locked, a short human explanation ("unlocks when you're comfortable with
  /// dynamic programming").
  final String? gateReason;

  int get count => units.length;

  double get totalEstMinutes => units.fold(0, (sum, u) => sum + u.estMinutes);

  /// The first [n] units (or all if fewer) — a convenience for cadence caps.
  List<PracticeUnit> take(int n) =>
      units.length <= n ? units : units.sublist(0, n);
}
