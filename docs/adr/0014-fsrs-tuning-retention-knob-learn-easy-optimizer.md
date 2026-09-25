# ADR 0014 — FSRS tuning (#32): a global retention knob, guarded Learn-Easy, deferred optimizer

- **Status:** Accepted
- **Date:** 2026-09-25
- **Deciders:** Kyle Uehlein
- **Related:** ADR-0008 (cram-vs-durable, the near-deadline retention ramp), ADR-0011
  (load control — *minimize the knobs*); memory `fsrs-exam-targeting`, `pace-models`;
  code `lib/core/srs/srs_scheduler.dart`, `lib/core/readiness/targeting.dart`
  (`desiredRetentionForCard`), `lib/core/template/study_policy.dart`,
  `lib/shared/study_grades.dart`, `lib/shared/providers/settings.dart`; task #32.

## Context

Task #32 bundles three FSRS-quality items. Scoping them against the current code and
the `fsrs: ^2.0.0` package surfaced very different size/risk, so they get one decision
record but ship (or don't) independently.

Current state the decision rests on:

- **Desired retention** already has a clean policy band in `study_policy.dart`
  (`retentionFloor 0.80 · retentionDefault 0.90 · retentionCramTarget 0.95 ·
  retentionCeiling 0.97`, `clampRetention`) and a live per-card path: each
  `Priority` carries a fixed target (`high 0.93 · normal 0.90 · low 0.85`), and
  `Targeting.desiredRetentionForCard` ramps a *targeted* card toward `0.95` as an aim
  nears (ADR-0008). There is **no user-facing control** — it is entirely engine-derived.
- **Learn's grade set** (`learnGrades`) deliberately excludes **Easy**: on a fresh
  card FSRS seeds Easy at `w[3]` (~15-day first interval), unearned for something just
  seen. `grade()` already accepts `4`; only the Learn UI withholds the button.
- **Optimizer:** the `fsrs` package ships **only the scheduler** — no weight-fitter.
  It *does* accept custom 21-weight `parameters`. The review-log input exists (the
  `reviews` table, persisted + vault-restored) but nothing reads it back. FSRS
  guidance is that fitting needs **~1000+ reviews** before it beats the defaults.

`_nextInterval = (stability / factor) · (R^(1/decay) − 1)` — **linear in stability**;
this fact lets the Learn-Easy guard cap an interval by capping stability, keeping FSRS
state self-consistent (no due-date hacking, per `fsrs-exam-targeting`).

## Decision

1. **One global "target retention" knob** (Settings), clamped to the policy band via
   `clampRetention`, default `0.90`. It sets the **normal** baseline; Priority becomes
   a *relative* offset preserved around it:
   `retentionForPriority(p, base) = clampRetention(base + (p.desiredRetention −
   Priority.normal.desiredRetention))`. At `base = 0.90` this reproduces `0.93 / 0.90 /
   0.85` exactly (**byte-identical**). The near-deadline ramp (ADR-0008) still applies
   on top, from this shifted base. **One dial, global** — not per-deck / per-flow —
   honoring ADR-0011's minimize-the-knobs stance while exposing the one lever that is
   genuinely the user's (the load-vs-recall trade, à la Anki's "desired retention").
2. **Add Easy to Learn, guarded.** A NEW card graded Easy has its first interval capped
   at `learnEasyMaxIntervalFactor` (= `2.0`) × what **Good** would seed the same fresh
   card, by scaling the seeded stability (interval ∝ stability). Good/Hard are ≤ their
   own value, so they are never clipped — the existing Good-only Learn path is
   **byte-identical**. Review mode passes no cap (native Easy).
3. **Defer the optimizer-from-history.** Do not implement weight-fitting now. Keep the
   review log accruing. Revisit behind a review-count threshold *and* package/tooling
   support. Recorded so it isn't re-attempted casually.

## Alternatives considered

- **Per-deck / per-priority retention overrides** (closest on the knob): more surface
  (Deck field + migration + editor UI) for marginal gain — the near-deadline ramp
  already covers the "this deck needs it fresher" case. Rejected for one global dial.
- **Knob replaces `priority.desiredRetention` flat** (drops the high/normal/low
  differentiation): a regression — high-priority material should still be held harder.
- **Learn-Easy via due-date clamp only** (keep native stability, shorten `due`): leaves
  stability and interval inconsistent; drifts toward the due-hacking `fsrs-exam-targeting`
  warns against. Rejected for the stability-scaled cap.
- **Learn-Easy unguarded** (native ~15-day jump): trusts a first-exposure self-rating
  too much. Rejected.
- **Build the optimizer now** (real Dart weight-fitter, or a lightweight
  observed-vs-target heuristic): large/fragile for the real thing; the heuristic risks
  being worse than defaults. Neither pays off at current data scale.

## Consequences

- **Positive:** users get the one meaningful FSRS dial; Easy becomes usable in Learn
  for already-known cards without an unearned jump; the optimizer decision is explicit,
  not drift. Both shipped changes are byte-identical at their defaults.
- **Negative / trade-offs:** one more Settings control (weighed against ADR-0011);
  the Learn-Easy guard adds a second (cheap) scheduler call on new-card Easy.
- **Known limitations & follow-ups:** no personalized weights until the optimizer lands
  (#32 residual); retention stays global (per-deck is a future option if evidence asks).

## Validation

- `retentionForPriority` unit tests: byte-identical at `0.90` (0.93/0.90/0.85), shifts
  and clamps to `[0.80, 0.97]` at other bases.
- `SrsScheduler` tests: a NEW Easy first interval ≤ `2×` the Good first interval and
  stability scaled to match; Good/Hard new-card outcomes unchanged (byte-identical);
  Review-mode Easy (no cap) unchanged.
- Settings-provider test: persists + clamps the target-retention value.
