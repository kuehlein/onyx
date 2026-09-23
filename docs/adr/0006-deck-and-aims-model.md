# ADR 0006 — Deck as a lens; the target lives on the aim

- **Status:** Accepted
- **Date:** 2026-09-22
- **Deciders:** Kyle Uehlein
- **Related:** ADR-0003 (card status & deck seam — the *other* `deckId`), ADR-0007
  (allocation across aims), ADR-0008 (cram-vs-durable); `docs/roadmap.md` §Phase 1a
  ②; `docs/user_stories/index.md` (competing-aims), `your_target.md`, `scheduler.md`;
  code `lib/core/deck/{deck,aim}.dart`, `lib/core/readiness/{target,targeting,
  readiness,feasibility}.dart`, `lib/shared/providers/readiness.dart`; tasks
  #30, #97–#101.

## Context

Onyx is generalizing from one hardcoded SWE deck into a configurable, multi-subject
platform. Across sessions the domain model drifted: a "target" (level × context ×
track × date) was carried on the **deck** (`StudyGoal`), while interviews were a
separate `List<InterviewAim>` that merely *inherited* the deck's target. That made
the codebase look consistent only by accident — every aim silently shared one blended
target, so the system could never express two genuinely different concurrent goals
(e.g. a *senior backend* interview in three weeks **and** an open-ended *frontend*
ramp) against the same body of cards.

The reframe (planned 2026-09-22 from a multi-agent code map) settled a single model:
**VAULT → DECK (a query lens over the vault) → a SET of concurrent AIMS.** The open
question this ADR pins: *where do the four readiness knobs live, and how does a deck
with several aims roll up to one readiness number?* This is load-bearing — schema,
identity, migration, and nearly every readiness/plan reader depend on the answer.

Locked principles at stake: **config-not-code** (no `if type ==` branching — ADR
elsewhere / `no_card_type_branch` lint); **difficulty affects readiness only via
tier depth**, never a domain-weight swing (a documented past inversion); and
**single-aim/single-deck degradation must be byte-identical** to the pre-reframe
behavior (invariant #8) so the generalization ships without regressing the one real
deck.

## Decision

1. **The deck is a pure lens.** `Deck` = identity + name + a `MembershipQuery` that
   selects its member cards from the vault. It carries no readiness semantics of its
   own once the migration completes.
2. **The four knobs live on the aim.** Each `Aim` owns **difficulty** (`levelId`),
   **durability bar** (`contextId`), **domain emphasis** (`trackId`), and **date**
   (via its `rounds`). Null knob → falls back to the deck's template fallbacks.
   Resolved through `ReadinessTarget.forAim(aim, template)`.
3. **Readiness rolls up weakest-link across active aims**, never averaged. The deck
   headline = the readiness of its hardest-to-clear aim (the **binding aim**), tagged
   on `Readiness.bindingAimId`. A shared `_bindingTarget` resolver makes the ladder
   and the ready-date forecast **follow the same binding aim**, so the number, the
   ladder rung, and the forecast never describe different aims.
4. **A 0-aim deck is coverage-only** — it scores against its own base target with no
   ready-by (a plain study deck, no assessment).
5. **Transitional inheritance, then a writer-flip.** Until S5, aim knobs fall back to
   the deck's still-present slots, so a lone inherited aim resolves *exactly* as the
   old deck target did (byte-identical, #8). S5 flips the writers, migrates each
   deck's slots into its aims one-shot, and **deletes** the deck slots + `toTarget`.

## Alternatives considered

- **Knobs on the deck; aims are just interviews (the "A-model", closest rival).**
  Rejected: it cannot express per-aim difficulty/durability against shared cards —
  the whole point of concurrent aims. It also keeps the accidental "one blended
  target" that caused the drift.
- **Average readiness across aims.** Rejected: averaging hides a weak aim behind a
  strong one; a learner who is interview-ready for frontend but not backend is *not*
  "70% ready." Weakest-link is the honest, safety-preserving roll-up.
- **Delete the deck slots immediately (rename+restructure in one pass).** Rejected:
  every reader inherits those slots today; removing them before the readers are
  per-aim would not be byte-identical. Hence readers-first, writer-flip last (S5).

## Consequences

- **Positive:** concurrent aims are first-class; the headline can't lie (weakest-link
  + binding aim); ladder/forecast/feasibility all agree because they resolve an aim
  through one helper; single-aim stays byte-identical, so the reframe ships safely
  slice by slice.
- **Negative / trade-offs:** a transitional period where knobs exist on both the aim
  and the deck (inheritance) until S5; a one-shot migration to write.
- **Known limitations & follow-ups:** the writer-flip, per-aim editing, migration,
  and slot deletion are **S5** (#101). The forecast substrate is still active-deck
  scoped (a documented single-goal-Home sliver). "Rounds → milestones" is an open
  decision (`scheduler.md`); aims stay round-shaped until decided.

## Validation

- `test/unit/multi_template_readiness_test.dart` — weakest-link roll-up across aims;
  `bindingAimId` is the harder aim; a single aim binds to itself (and reproduces the
  pre-reframe number).
- `test/unit/deck_aim_feasibility_test.dart` — per-aim resolution + the binding-aim
  repoint of the forecast.
- `test/unit/readiness_ladder_test.dart` — the ladder is built from the aim's
  template slots (config-driven, not SWE-hardcoded).
- Invariant #8 (byte-identical single-aim) is the standing guard the whole S-phase is
  held to.
