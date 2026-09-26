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

import 'dart:math' as math;

/// The four practice-track ids (String, to prepare for config-driven tracks).
///
/// The practice-track ids deliberately equal the SWE FlowSpec `cardType` values
/// so a later phase can derive them from `activeTemplate.flows`; review/learn are
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

/// Minutes for one generic config-flow mock (a vault-authored mock flow that
/// declares no per-card `est_minutes`). System design keeps its own 40; a card's
/// frontmatter `est_minutes` still overrides this.
const double kMockMinutes = 20;

/// First-time cost of an algorithm EXPLAIN (recognition / phone-doable maintenance,
/// the two-clock's `AlgoMode.explain`) — far short of a full solve. Scaled by
/// [scaleEstMinutes] like everything else.
const double kAlgoExplainMinutes = 6;

// ── Maturity scaling (task #133) ─────────────────────────────────────────────
// A first-time cost scales DOWN as FSRS stability grows (a well-learned item is
// recalled/re-solved faster). The stability curve is universal; the per-flow
// FLOOR is the *incompressible fraction* — how much of the activity never gets
// faster: pure recall (review) compresses most; an algo solve keeps a large
// irreducible coding/production cost so it compresses least; an explain sits
// between. Content-heavy outliers are carried by a bigger authored `est_minutes`
// (the T0), not the floor.

/// Review is ~pure recall → compresses to a third at maturity.
const double kReviewFloor = 0.33;

/// An algo solve keeps a large irreducible coding/production cost.
const double kAlgoSolveFloor = 0.5;

/// An algo explain (recognition) compresses more than a solve, less than recall.
const double kAlgoExplainFloor = 0.4;

/// FSRS `State.relearning` as a plain int (a lapsed card being re-studied), so this
/// pure model needs no `fsrs` import.
const int kRelearningFsrsState = 3;

/// Stability (days) at which an item is fully "mature" for est scaling. Mirrors
/// `kMasteredStabilityDays` (core/srs/mastery.dart) — keep in sync.
const double _kMatureStabilityDays = 21;

/// Minutes for an algorithm problem, from its difficulty (parsed from the card
/// section, e.g. "… · Medium"). Falls back to the medium estimate.
double algoEstMinutes(String sectionContent) {
  final lower = sectionContent.toLowerCase();
  if (RegExp(r'·\s*hard|\bhard\b').hasMatch(lower)) return 40;
  if (RegExp(r'·\s*easy|\beasy\b').hasMatch(lower)) return 12;
  return 25; // Medium / unknown
}

/// Scale a first-time cost [t0] by FSRS maturity (task #133): a well-learned item
/// is recalled / re-solved faster. Ramps linearly from ×1.0 (new, [stability] ≤ 0)
/// down to ×[floor] at [_kMatureStabilityDays] of stability, flat beyond. A lapsed
/// ([kRelearningFsrsState]) item costs MORE (×1.2 — you're re-studying), never less.
/// The curve is universal (stability is an FSRS unit that means the same in every
/// subject); [floor] carries the per-flow compressibility. Estimation-only (sizes
/// the daily plan) — never a scheduling decision.
double scaleEstMinutes(
  double t0, {
  required double stability,
  required int fsrsState,
  double floor = kReviewFloor,
}) {
  if (fsrsState == kRelearningFsrsState) return t0 * 1.2;
  if (stability <= 0) return t0;
  final ramp = (stability / _kMatureStabilityDays).clamp(0.0, 1.0);
  return t0 * (1.0 - (1.0 - floor) * ramp);
}

/// Review est-minutes for a section from its FSRS primitives: the first-time cost
/// [t0] when unseen or state-unknown, else [scaleEstMinutes] at the review floor
/// (#133). The single place the review track, the derived new-allowance (ADR-0016),
/// and the ready-date forecast all size a due review, so they stay consistent.
double reviewEst(double t0, {double? stability, int? fsrsState}) =>
    (stability == null || fsrsState == null)
        ? t0
        : scaleEstMinutes(t0,
            stability: stability, fsrsState: fsrsState, floor: kReviewFloor);

// ── Retention floor + new-material ceiling (task #106 / #114 Phase B · ADR-0016)
// The two levers that size the day's balance of review vs. new. The retention floor
// (below) reserves review time first (#106); the new-material ceiling (`sustainableNewCount`)
// then derives how much NEW to introduce from what's left, capped so novelty can't
// out-run the review capacity it creates. The constants are the v1 calibration — the
// *shape* is load-bearing (ADR-0016), the numbers are tunables to validate via
// telemetry (#122).

/// The default share of the day the retention floor (due reviews) may claim before
/// the remainder is fair-queued to new/practice — the retention-floor cap
/// (ADR-0010 Phase B / #106). Due reviews clear FIRST up to this fraction, so
/// retrieval never loses to new material; the cap keeps a heavy backlog from eating
/// the whole day (a slice always remains for practice/new). Any budget no other
/// track can use still flows back to reviews (they're never dropped to waste time),
/// so on a normal day — due-load well under the cap — this changes nothing. 0.8
/// mirrors the field consensus: reviews are the priority, but a backlog is shed at
/// the *new* lever, not by letting reviews consume every minute.
const double kRetentionFloorCap = 0.8;

/// The gentle default daily new-count (the Phase-A value) — the calibration anchor
/// the derivation lands on for a typical day, and the fallback when no budget is
/// known (nADR-0016).
const int kDefaultDailyNew = 8;

/// Share of the post-review budget new material may claim (the time bound). Tuned so
/// a default day (~[kDailyTargetMinutes], reviews ≈ half in steady state) lands at
/// ≈[kDefaultDailyNew]; a bigger budget scales new up until a debt/cognitive bound
/// binds. See [sustainableNewCount]. (At the default 150-min budget with reviews
/// taking half the day, `floor(0.32·75/3) = 8`.)
const double kNewShare = 0.32;

/// Minutes of daily review each new item, sustained per day, eventually costs at
/// steady state — the review-debt bound is `budget ÷ this`. From the verified ~10:1
/// review:new ratio (Anki, graded in ADR-0016) at ~1 min a mature review, rounded up
/// for headroom. Caps front-loading on a light / brand-new-deck day, and scales the
/// ceiling *with* the budget (a bigger day supports a higher sustainable rate).
const double kSustainableMinutesPerNew = 12;

/// Absolute cognitive cap on new items/day regardless of time (cognitive-load /
/// dropout evidence, ADR-0016) — the firehose limit on cheap-card decks the time
/// bound alone wouldn't hold.
const int kNewHardMax = 20;

/// The sustainable daily new-material count (task #114 Phase B · ADR-0016): the
/// minimum of three research-backed bounds, over the retention floor. Replaces the
/// fixed Phase-A guardrail (`newCardLimit`) with a count DERIVED from the day's
/// [budgetMinutes] and its [dueReviewMinutes] (the est-minutes of today's due
/// reviews). Pure — sizes the plan, never schedules.
///
///  - **Time:** new gets [newShare] of the budget left AFTER due reviews take their
///    retention-floor share ([floorCap]·budget, #106), at [costPerNew] min each — so
///    a heavy-review day sheds new, a light day / bigger budget allow more. This is
///    the "more budget → sooner" lever, review-debt-aware by construction.
///  - **Review-debt:** ≤ `budget ÷ [minutesPerNew]` — you can't sustainably learn
///    faster than you can review what you learn (the ~10:1 ratio); caps front-loading.
///  - **Cognitive:** a hard [hardMax]/day (CLT / dropout) — the cap on cheap decks
///    where the time bound alone would permit dozens.
int sustainableNewCount({
  required double budgetMinutes,
  required double dueReviewMinutes,
  double newShare = kNewShare,
  double costPerNew = kLearnMinutes,
  double floorCap = kRetentionFloorCap,
  double minutesPerNew = kSustainableMinutesPerNew,
  int hardMax = kNewHardMax,
}) {
  if (budgetMinutes <= 0) return 0;
  final reviewClaim = math.min(dueReviewMinutes, floorCap * budgetMinutes);
  final postReview = (budgetMinutes - reviewClaim).clamp(0.0, budgetMinutes);
  // +1e-9 so an exact-integer boundary (e.g. 0.32·75/3 = 8.0) doesn't fall to 7 on
  // a hair-below float — the same guard the packer's nextFitting uses.
  final byTime = (newShare * postReview / costPerNew + 1e-9).floor();
  final byDebt = (budgetMinutes / minutesPerNew + 1e-9).floor();
  final n = math.min(byTime, math.min(byDebt, hardMax));
  return n < 0 ? 0 : n;
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
  /// because the pure core can't reach `DeckTemplate`; the provider that builds
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
