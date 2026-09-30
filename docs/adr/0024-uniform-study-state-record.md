# ADR 0024 — Uniform study-state record, keyed by (cardId, dataSlug); mode-keyed, config-free

- **Status:** Accepted
- **Date:** 2026-09-30
- **Deciders:** Kyle Uehlein (+ AI-assisted; a 6-agent scope pass over ADRs 0019/0020/0022/0023, the
  learning-science research, and the state/scheduler code).
- **Related:** Implements **#155** (the state-table unification spiked in **ADR-0020 §3**). The
  config-free-key invariant here is the **foundation for ADR-0025** (deck-owned config). Honors ADR-0008
  (FSRS-safe deadlines), 0014, 0016. Confirms/sharpens ADR-0020 §1 (the key carries no config discriminator).
  Code: `lib/core/database/{tables,database}.dart`, `lib/core/srs/*` (incl. `recognition.dart` +
  `recognition_repository.dart`), `lib/core/backup/snapshot.dart`, the schedulers + queues.

## Context

Study state lives in **two** tables today: `SrsStates` (FSRS recall clock — `{stability, difficulty, state,
step, dueAt, lastReview, reviewCount}`) and `RecognitionStates` (an expanding-interval "practice" clock —
`{intervalDays, streak, dueAt, lastExplainedAt}`), both keyed `(cardId, sectionSlug)`. Mock flows write a
practice datum under the literal slug `'mock'`. Two tables → two repositories → two snapshot shapes → two
merge paths. Collapsing them into "one uniform record + a pluggable per-kind scheduler" is exactly what
ADR-0020 §3 deferred to #155.

The deck-owned-config re-architecture (**ADR-0025**) makes this collapse load-bearing: a card can be surfaced
by **multiple decks** (e.g. Latin vocab in a Year-1 deck and a Year-2 deck), and we must guarantee that
reusing a card across decks keeps **one shared schedule** (advance-anywhere) while genuinely-different
practice keeps **independent** schedules. A scoping pass across the ADRs, the learning-science research, and
the code converged on the crux: **the schedule's discriminator must be the practice MODE, never the
deck/config.**

## Decision

Collapse the two tables into one `StudyStates` record and pin the key.

1. **Key = `(cardId, dataSlug)`, where `dataSlug = aspect + mode`; the key is deck/config-FREE.** `aspect`
   = which part of the card (a section slug, or a whole-card marker); `mode` = the practice activity.
   Advancing a `(cardId, dataSlug)` **anywhere advances it everywhere** (ADR-0019 §1, ADR-0020 §1). A card
   claimed by N decks that practice it the **same way** → the **same** dataSlug → **one shared schedule**; a
   card practiced **different ways** (recall vs solve) → **different** dataSlugs → **independent** schedules.
   The **deck/config never enters the key** — this is the invariant that keeps card-reuse-across-decks a
   single shared memory, and that the learning-science pass showed is *required* (see Alternatives).
2. **One record: a common core + a kind-tagged payload.** Core: `{cardId, dataSlug, kind, dueAt,
   lastActivityAt, activityCount, status}`. `kind` is the scheduling-model discriminator with **two** values
   (the science forbids one universal curve — ADR-0020 §3): **`recall`** (FSRS payload `{stability,
   difficulty, state, step}`) and **`practice`** (expanding-interval `{intervalDays, streak}`). Nullable
   columns are an acceptable *storage* form for the kind-tagged payload; the *model* is core + one payload.
   The algorithm **two-clock card is not a third kind** — it spawns two data mapped onto the two existing
   functions, preserving today's behaviour exactly. *As-built (pinned so the migration is unambiguous): the
   `solve` clock lives in `SrsStates` → `kind='recall'` (FSRS); the `explain`/recognize clock lives in
   `RecognitionStates` → `kind='practice'` (expanding). ADR-0020 §3 matches this; §1's generic "produce/solve
   → practice" is an intended mode→model rule the current algo impl predates — reconciling it is out of scope
   for #155's byte-exact collapse.*
3. **Pluggable per-kind scheduler.** A `kind → schedule()` registry (`recall`→FSRS wrapper,
   `practice`→expanding-interval). The scheduler is **config-agnostic** — it schedules `(cardId, dataSlug)`
   units and reads only the datum's `kind`, never the deck/config. `kind = f(mode)` is globally fixed, so two
   flows over one datum can never disagree on its scheduling model.
4. **Migration (drift `schemaVersion` 2→3, byte-exact FSRS).** Create `StudyStates`; copy each `SrsStates`
   row → `kind='recall'`, `dataSlug=sectionSlug`, `lastReview→lastActivityAt`, `reviewCount→activityCount`,
   **FSRS payload verbatim** (never re-fit a fitted curve — ADR-0008); copy each `RecognitionStates` row →
   `kind='practice'`, `dataSlug=sectionSlug` (already `'mock'` for mocks), `lastExplainedAt→lastActivityAt`,
   `streak→activityCount`; drop the old tables. `Reviews`/`AppliedAttempts` keep `sectionSlug` (= dataSlug).
5. **Snapshot (`_version` 3→4, legacy-readable).** Export a single `studyStates[]` array; the merge collapses
   to **one** keyed-state merge over `(cardId, dataSlug)` with a single recency field (`lastActivityAt`) +
   `activityCount` tie-break (must stay provably convergent + idempotent). Restore keeps reading v≤3 files
   (fold legacy `srsStates`/`recognitionStates` → unified) **indefinitely** — an older device in a shared
   folder still writes legacy shapes until it upgrades, and the merge must accept both.

## Alternatives considered

- **Key state by `(cardId, dataSlug, deckId/config)`** — the initial (wrong) framing, and the crux this ADR
  exists to correct. **Rejected.** It forks a datum's schedule across decks *even when the practice is
  identical*, which (a) violates advance-anywhere (ADR-0019 §1, ADR-0020 §1), (b) re-forges the
  `deckId`-in-the-key mistake ADR-0003 → 0020 already killed, and (c) the learning-science pass showed causes
  **self-interference** (the single biggest cause of forgetting), **spacing incoherence** (one memory pulled
  by two schedulers = de-facto massing, violating Cepeda-style distributed practice), **redundant reps** with
  no transfer benefit (minimum-information / no-redundancy doctrine), and **inflated review-debt** that breaks
  the ADR-0016 new-count ceiling. The fork must live in the **mode**, not the config. A deck's config may
  change *presentation / rubric / skill / which modes spawn* — never the schedulable identity of a shared
  trace.
- **One universal scheduler / one state kind.** Rejected — the science forbids a single forgetting curve over
  declarative recall and applied problem-solving (the transfer gap; ADR-0020 §3). Two functions minimum.
- **A wide null-filled union table as the MODEL.** ADR-0020 warns against this as the model; it's fine only
  as the storage form.

## Consequences

- **Positive:** one record + one merge (simpler snapshot / restore / wipe); advance-anywhere is
  *structurally guaranteed* for card-reuse-across-decks; the config-agnostic scheduler lets ADR-0025's
  deck-owned config vary flows/presentation without touching the schedulable trace; two-clock + mock unify
  onto two functions.
- **Negative / must-hold:** FSRS payload migrates bit-exact (characterization test); the snapshot merge stays
  convergent under the single recency field; `renameSection`/`dropSection` (ADR-0012 edit-identity) rekey the
  unified row by `dataSlug` for the matching `kind`; **retain-but-detach** stays a mergeable marker, never row
  absence (#158).
- **Allocation counts UNITS, not deck-memberships** (ADR-0007/0016): a card in two same-mode decks is **one**
  `(cardId, dataSlug)` unit → one schedule, so the new-count ceiling + fair-queuing packer never double-charge
  a multi-deck card's budget or review-debt. (This promotes ADR-0023's deferred "multi-match dedupe" from a
  Browse concern to a scheduler invariant.)

## Validation

- Characterization: migrate a known DB; assert every FSRS field identical + the recognition/mock rows map
  correctly.
- Advance-anywhere: two lenses over one card; grade in one; assert the other sees the advance (one row).
- Snapshot: a v3 file restores; the merge is idempotent + convergent under `lastActivityAt`/`activityCount`.
- Byte-identical: the SWE vault's schedule state is unchanged post-migration (invariant #8).

## Slices (readers-first)

(1) golden characterization tests → (2) `dataSlug`/`kind` key vocabulary (replace the scattered
`"$cardId::$slug"` + the `'mock'` literal) → (3) unified `StudyStates` table + `StudyStateRepository`, old
repos become thin adapters (readers first) → (4) flip writers → (5) collapse the snapshot (+ keep the legacy
reader) → (6) pluggable per-kind scheduler → (7) drop the old tables + dead code.
