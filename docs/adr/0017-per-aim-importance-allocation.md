# ADR 0017 — Per-aim importance: a user weight on allocation (not readiness)

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Kyle Uehlein
- **Related:** **Extends [ADR-0007](0007-daily-plan-allocation-across-aims.md)** (daily-plan allocation across
  aims by feasibility-urgency) and is the **aim-level analog of [ADR-0010](0010-workload-budget-and-proportions.md)**'s
  user-owned deck **proportion** — a "how much I care" preference only the user can supply. Also ADR-0006
  (deck/aims model), ADR-0009 (aims surface). Task **#136**. Code: `lib/core/deck/aim.dart`
  (`AimImportance`), `lib/shared/providers/readiness_feasibility.dart` (`deckPlanDomainWeights`),
  `lib/features/home/target_sheet.dart` (the editor chip).

## Context

The daily plan allocates across a deck's active aims by **feasibility-urgency** (ADR-0007): a *behind* aim
pulls more than an *on-track* one. But urgency can't express **personal importance** — a candidate's dream
role vs a fallback application, or a final exam vs a weekly quiz. Two *on-track* aims currently split the
plan evenly, even when the learner cares far more about one. That's a preference the engine can't infer
(exactly like the daily budget and the deck proportion in ADR-0010 — the things only the user honestly
knows).

## Decision

**Each aim carries a user-set `importance` — `high | normal | low` — that scales its urgency share in the
daily-plan allocation. It shapes the PLAN only; it never touches readiness.**

1. **Allocation.** In `deckPlanDomainWeights`, each aim's share becomes `aimUrgency(feasibility) ×
   importance.weight` (high 1.5 · normal 1.0 · low 0.5; tunable). So a high-importance aim pulls more of the
   day even at equal urgency — but because urgency-status still dominates, a *behind* low-importance aim
   (0.5 × ~1.0) still outranks an *on-track* normal one (1.0 × 0.3). Importance tilts; it doesn't override
   the feasibility signal.
2. **Readiness is untouched — deliberately.** Readiness stays an honest **weakest-link across aims** (ADR
   S2 / invariant #6). De-weighting a backup aim in the headline would *hide a real gap* ("you look ready"
   when you're weak on something you still listed). Importance answers "where should my time go," not "am I
   ready" — those are different questions and must not be conflated.
3. **`normal` is the default → byte-identical.** An all-normal deck allocates exactly as before (weights all
   ×1.0); the field is omitted from JSON when normal. A single-aim deck is unaffected (one aim, its share is
   1 regardless).
4. **A tier, not a slider.** Three levels (high/normal/low), matching the mental model (dream/standard/
   backup; final/normal/quiz) and keeping the editor to one chip row — no false precision, SDT-friendly
   (a clear, low-effort choice).

## Alternatives considered

- **Let importance also weight the readiness weakest-link.** Rejected — it hides weakness; readiness must
  stay honest (the whole point of weakest-link). If a learner wants to *drop* a backup, they mute/remove the
  aim (an explicit act), not silently de-weight it.
- **A continuous 0–1 weight.** Rejected — false precision + a fiddlier control; three tiers carry the intent.
- **Importance replaces urgency as the driver.** Rejected — a behind aim must still surface even if
  "low importance"; urgency-status leads, importance is a multiplier on top.
- **Infer importance (dream = the soonest / the named company).** Rejected — it's a genuine preference the
  engine can't read; guessing it re-creates the autonomy erosion ADR-0010 warns against.

## Consequences

- **Positive:** the plan reflects what the learner actually cares about, not just what's behind; honest
  readiness preserved; byte-identical default; generalizes (subject-neutral tiers, no SWE shape); the
  aim-level companion to ADR-0010's deck proportion.
- **Trade-offs / risk:** one more knob. Mitigated: optional, sensible default, a single chip row in the aim
  editor, and it *only* re-weights an allocation that already existed. The multipliers are heuristic
  (tunable); urgency still dominates so a mis-set importance can't strand a behind aim.

## Validation

- `deckPlanDomainWeights`: at equal urgency, a high-importance aim's domain outweighs a low-importance one;
  all-normal is byte-identical to pre-#136 (unit-tested).
- `Aim` JSON round-trips a non-default importance and omits `normal`; the weight ordering is high > normal
  (=1.0) > low (unit-tested).
- The aim editor exposes importance as a chip row; saving routes through `upsertAim` (the whole aim).
