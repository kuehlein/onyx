# ADR 0006 — Daily-plan allocation across aims: feasibility urgency, soft fair-queuing

- **Status:** Accepted (model); implementation = roadmap **S3** (#99, in progress)
- **Date:** 2026-09-22
- **Deciders:** Kyle Uehlein
- **Related:** ADR-0005 (deck/aims model), ADR-0007 (cram-vs-durable); `docs/roadmap.md`
  §Phase 1a S3; `docs/learning-science.md` "Study cadence, deadlines & the coach";
  memory `pace-models`; code `lib/core/plan/daily_plan.dart` (`buildDailyPlan`),
  `lib/shared/providers/daily_plan.dart`, `lib/core/readiness/feasibility.dart`
  (`deckAimFeasibility`), `lib/core/readiness/targeting.dart`; tasks #57, #99, #103.

## Context

A deck can hold several concurrent aims (ADR-0005) that compete for one shared daily
time budget. Today `dailyPlan` folds aims in but **blended**: it reads
`activeTargeting`, which takes the **max** domain-weight across *all* aims and the
**nearest** date for the learn-taper. So a desperately-behind aim and a comfortably-
ahead aim contribute equally to what the day emphasizes — wrong.

Two design questions must be pinned before building S3:

1. **What is "urgency"?** A first instinct was a time-ramp toward the date (ramp
   effort up as the deadline nears). That is wrong: it ignores *content volume*,
   *actual pace*, and *how durable* the knowledge must be. A learner far ahead
   shouldn't be ramped just because a date is close; one far behind with lots left
   should pull hard even if the date is further out.
2. **How is the budget allocated across aims?** Aims are lenses over the *same*
   cards (ADR-0005), and real study units are **indivisible and lumpy** — a review
   card is ~1.5 min but a first-time system-design problem is ~40 min. Any fine-
   grained split (even a "fair" one) is broken the moment the highest-priority
   remaining item is bigger than the slice left for it.

The existing packer (`buildDailyPlan`) is already a **weighted fair-queuing bin-
packer**: it repeatedly hands the *next unit that fits the remaining budget* to
whichever track is furthest below its priority-proportional fair share, skipping
(deferring) any unit too big to fit. Proportions are a **soft attractor**, not a
hard quota. Queues are bounded to the day's candidates and `estMinutes` is
precomputed, so packing never re-parses the vault.

## Decision

1. **Urgency = feasibility, not a time-ramp.** Per active aim, derive a 0..1 urgency
   from `deckAimFeasibility` (ADR-0005 / S4): `infeasible` ≈ 1.0 (but coach-flagged,
   capped so it can't nuke the day), `behind` high and rising as the date nears,
   `onTrack` low, `ready` ≈ 0, **`open-ended` = a flat baseline** (steady, never
   spikes or starves). Scale by date proximity. This is "required-pace vs actual-pace
   + proximity" — the region-of-proximal-learning / agenda-based-regulation model.
2. **Allocate by urgency-weighted *emphasis*, fed into the existing fair-queuing
   packer (option A), NOT hard per-aim budget slices (option B).** Each aim's
   domain/concept emphasis is scaled by its urgency and combined into the effective
   weights that already drive `PlanContext.baseWeight` + learn card-ordering
   (`weightForCard`). No new partitioning stage.
3. **Retention floor.** Reviews stay reserved with a minimum cadence; urgency only
   reallocates *new-learning* emphasis **above** that floor. A behind aim can pull
   more new learning but can never starve a dated aim's due reviews.

## Alternatives considered

- **Option B — explicit per-aim budget slices (the closest rival; matches an earlier
  "new allocation stage" phrasing).** Compute each aim a share of the budget, pack
  within each. Rejected: because units are **indivisible and lumpy**, a hard slice
  strands time whenever its neediest item doesn't fit (a 40-min problem in a 35-min
  slice), forcing a give-back-and-rebalance that *is* fair-queuing again. B fights
  indivisibility; A absorbs it. And since aims share cards, A's weighting already
  routes leftover time to a behind aim's *divisible* work (its small learn/review
  cards) — a property B's stranded slice lacks. A is also single-aim byte-identical
  for free (one aim → uniform scaling → no change; invariant #8).
- **Naive time-ramp urgency.** Rejected (see Context): ignores volume, pace, and the
  durability bar.

## Consequences

- **Positive:** the day bends around real, lumpy work instead of lying about
  proportions; behind-and-soon aims pull hardest; open-ended aims get a steady
  baseline; reviews are protected; no new scheduling machinery; single-aim
  byte-identical.
- **Negative / trade-offs:** allocation is a soft attractor, so exact per-aim ratios
  are never guaranteed (correct given indivisibility, but not a knob for "always ≥N
  min on X" — B would be needed if we ever want *hard* guarantees, which nothing
  asks for today).
- **Known limitations & follow-ups (surfaced 2026-09-22, separable — do not fold
  into S3):**
  - **Time-estimate fidelity:** `PracticeUnit.estMinutes` is flat-per-type (review
    1.5 / learn 3 / SD 40 / mock 20, with an optional per-card `est_minutes`), not
    state-aware. Making it reflect item state (mature review ≈ 0.5, first-time algo ≈
    45, familiar re-solve ≈ 15) tightens bin-packing for *any* allocation — near #32.
  - **Leftover-budget backfill:** big chunks that don't fit defer; small divisible
    review/learn naturally soak up the remainder. Backfilling with *extra* re-exposure
    beyond due when the day under-fills is #58 (overflow) + #104 (cram) territory.
  - A tiny packer inefficiency: `nextFitting` re-scans a too-big item at the cursor
    each pass (budget only shrinks, so it can never fit later) — advance past it.

## Validation

- `test/unit/deck_aim_feasibility_test.dart` — the per-aim urgency substrate
  (`deckAimFeasibility`) it allocates on.
- Existing `buildDailyPlan` tests — the fair-queuing skip-and-defer behavior A relies
  on.
- S3 will add allocation tests asserting: behind-and-soon outweighs comfortably-ahead;
  open-ended = baseline; the retention floor holds; single-aim byte-identical.
