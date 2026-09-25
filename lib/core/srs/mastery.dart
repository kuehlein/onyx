import 'package:fsrs/fsrs.dart' as fsrs;

import '../database/database.dart';

/// The bar for the card view's display-only **"mastered"** auto-collapse
/// (ADR-0012 #6, task 1f.1): a quizzable review section folds up with a *Mastered*
/// badge when you're both **still retaining it** and have **survived real
/// spacing**. Never a scheduling decision — a due section is never mastered, so a
/// due retrieval is never folded away.
///
/// Both thresholds are **fixed engine constants**, not user/deck dials: they're
/// expressed in subject-agnostic FSRS units (retrievability is a probability;
/// stability is an interval in days), so they mean the same thing in every deck,
/// and the feature is display-only — the global off-switch is the only control it
/// needs (ADR-0011's minimize-the-knobs stance). Tune here if evidence warrants.

/// Recall probability at/above which a section still counts as retained (Onyx's
/// default FSRS retention target).
const double kMasteredRetention = 0.9;

/// FSRS stability (≈ the interval in days at which recall falls to ~90%) a section
/// must reach to count as "spaced" — three weeks, so a just-learned section (Onyx
/// graduates Learn straight into the review state with R≈1) is not prematurely
/// flagged as mastered.
const double kMasteredStabilityDays = 21;

// One scheduler instance, reused only for its retrievability curve (the fsrs
// decay constants). Retrievability is independent of desiredRetention, so the
// default scheduler is fine — and the curve comes from the fsrs package, never a
// widget-layer reimplementation (ADR-0012 #6).
final fsrs.Scheduler _curve = fsrs.Scheduler();

/// The section's current retrievability (probability of recall) at [now] from its
/// stored FSRS stability + last review, via the fsrs package's own curve. Returns
/// 0 when the section has never been reviewed. Display-only; never scheduling.
double sectionRetrievability(SrsState state, DateTime now) {
  if (state.lastReview == null || state.stability <= 0) return 0;
  return _curve.getCardRetrievability(
    fsrs.Card(
      cardId: 0,
      state: fsrs.State.fromValue(state.state),
      step: state.step,
      stability: state.stability,
      difficulty: state.difficulty,
      due: state.dueAt.toUtc(),
      lastReview: state.lastReview!.toUtc(),
    ),
    currentDateTime: now.toUtc(),
  );
}

/// Whether a section is "mastered" for the display-only card-view collapse: it has
/// graduated to the FSRS **review** state, is **not currently due** (so a due
/// retrieval is never folded away), has grown to a **spaced** interval
/// ([kMasteredStabilityDays]), and is **still retained** ([kMasteredRetention]).
/// A never-studied / learning / relearning / due section is never mastered.
bool isSectionMastered(SrsState? state, DateTime now) {
  if (state == null) return false;
  if (state.state != fsrs.State.review.value) return false;
  if (state.lastReview == null) return false;
  if (!state.dueAt.isAfter(now)) return false; // due / overdue → not mastered
  if (state.stability < kMasteredStabilityDays) return false;
  return sectionRetrievability(state, now) >= kMasteredRetention;
}
