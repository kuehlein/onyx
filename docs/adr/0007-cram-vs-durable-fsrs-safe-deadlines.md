# ADR 0007 — Cram-vs-durable: honor deadlines without corrupting FSRS

- **Status:** Accepted (model); implementation across S5 + #103/#104
- **Date:** 2026-09-22
- **Deciders:** Kyle Uehlein
- **Related:** ADR-0005 (deck/aims model), ADR-0006 (allocation); `docs/roadmap.md`
  §Phase 1a cram-vs-durable; `docs/learning-science.md` "Study cadence, deadlines &
  the coach"; memory `fsrs-exam-targeting`; code `lib/core/readiness/targeting.dart`
  (`desiredRetentionForCard`), `lib/core/srs/srs_scheduler.dart`; tasks #32, #103, #104.

## Context

Two learners want opposite things from the same deck. One is **cramming** for a test
in ten days — they care about short-term recall *on the date*, not durability. The
other is building **durable** knowledge with no deadline. The app must serve both,
and honor deadlines, **without corrupting the FSRS model** that everything else
(readiness, forecast, pace) trusts.

The failure mode to prevent: "helpfully" hacking the scheduler to make a deadline —
fabricating due dates, or writing inflated stability/difficulty — which poisons the
fitted state, so every downstream readout (readiness %, ready-by forecast, coverage
pace) silently lies from then on. FSRS integrity is a locked principle
(`fsrs-exam-targeting`).

There is also a UX subtlety: FSRS deliberately will **not** minutes-space a *mature*
card (that would be massing, which it exists to prevent). So "let me see this card
again and again today before my test" cannot be served by the normal scheduler at
all — it needs a different surface.

## Decision

1. **"How long you need it" is the durability-bar knob** — the aim's `contextId`
   (ADR-0005), which sets `stabilityTarget`. Cram = a low durability bar (ready = "I
   can recall it on the day"); durable = a high bar (ready = "it's locked in"). This
   is a *readiness* choice, and it already flows through the readiness/forecast/
   feasibility engines per-aim.
2. **Honor deadlines the FSRS-safe way: raise desired-retention toward the date.**
   `Targeting.desiredRetentionForCard` ramps a targeted card's desired retention
   toward a cap as its aim's next round nears — which *shortens intervals* (fresher on
   the day) purely through the legitimate FSRS lever. It **never** mutates fitted
   stability/difficulty and **never** fabricates due dates. It reverts to base once
   the round passes or the aim is muted. (Overlaps the #32 desired-retention knob.)
3. **A cram / final-review SESSION is non-rescheduling re-exposure.** To serve "see
   them again and again today," a dedicated session rapidly re-exposes the aim's due
   + at-risk cards **without writing FSRS reviews** — reusing the existing non-grading
   session infrastructure (gym / practice). It is additive and leaves the fitted
   state untouched.
4. **The coach proposes, never overrides.** When an aim is `infeasible` (ADR-0006),
   the coach flags the incoherent cram with options (move the date / cut scope / lower
   the durability bar / accept it fades) — with rationale, never an auto-override.

## Alternatives considered

- **Schedule-hacking for the deadline** (push due dates in, inflate stability).
  Rejected outright: corrupts the fitted model and every readout that depends on it —
  the exact anti-pattern `fsrs-exam-targeting` locks out.
- **A separate cram scheduler.** Rejected: a parallel scheduler duplicates state and
  risks divergence. Re-use the non-grading session path instead (#104).
- **Only the durability knob, no proximity ramp.** Rejected: the knob sets the *bar*
  but doesn't make near-term material *fresher on the day*; the desired-retention ramp
  is the safe way to do that.

## Consequences

- **Positive:** deadlines are honored; FSRS state stays pure, so readiness/forecast/
  pace remain trustworthy; cram is a first-class but *additive* mode; the "massing"
  need is met safely by a non-grading session.
- **Negative / trade-offs:** a raised desired-retention increases review workload near
  a date (bounded by the retention cap — see `fsrs-exam-targeting`); the cram session
  is separate infra to build.
- **Known limitations & follow-ups:** the durability-bar *editing* UX (framing
  contextId as cram↔durable) lands with **S5**; the **coach cram-coherence nudge** is
  **#103**; the **cram / final-review session** is **#104** — a pre-publish nice-to-
  have, not yet built. Keep the non-grading session path reusable so #104 drops in.

## Validation

- `desiredRetentionForCard` is pure and unit-tested (proximity ramp toward the cap,
  reverting after the round; only targeted cards affected).
- FSRS state purity is the standing invariant: the projection/forecast simulate
  forward *without* persisting reviews; the cram session must do the same (#104 tests).
