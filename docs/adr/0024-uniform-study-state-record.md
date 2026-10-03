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
   lastActivityAt, activityCount}` (+ a `status` lifecycle marker **deferred to its consumer, #158
   retain-but-detach** — build-when-consumed; today a dropped datum is row-absence as before). `kind` is the
   scheduling-model discriminator with **two** values
   (the science forbids one universal curve — ADR-0020 §3): **`recall`** (FSRS payload `{stability,
   difficulty, state, step}`) and **`practice`** (expanding-interval `{intervalDays}`; the practice *streak*
   is carried in the core `activityCount`, not a separate column). Nullable columns are an acceptable
   *storage* form for the kind-tagged payload; the *model* is core + one payload.
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
   row → `kind='recall'`, `dataSlug=sectionSlug` (the **bare** aspect), `lastReview→lastActivityAt`,
   `reviewCount→activityCount`, **FSRS payload verbatim** (never re-fit a fitted curve — ADR-0008); copy each
   `RecognitionStates` row → `kind='practice'`, `dataSlug=studyDataSlug(sectionSlug, practice)` (the aspect
   **namespaced** — `'recognize:' + sectionSlug`, so `'mock'`→`'recognize:mock'`), `lastExplainedAt→lastActivityAt`,
   `streak→activityCount`. `Reviews`/`AppliedAttempts` keep `sectionSlug` (= the recall `dataSlug`). The legacy
   tables are **kept, not dropped**, until the writer+reader flip completes (slices 4–7).
   *Correction (found in slice 3): the recall and practice rows **cannot both** key on the bare `sectionSlug` —
   an algorithm card writes the **same** `(cardId, sectionSlug)` to BOTH clocks (a solve → `SrsStates`, the
   same-section explain → `RecognitionStates`; see `algo.dart`), so a bare-slug practice row would collide with
   its own solve row on the `(cardId, dataSlug)` PK. Namespacing practice (recall stays bare) is exactly the
   `aspect + mode` of §1, and keeps the precious FSRS keys + their `Reviews`/`AppliedAttempts` join byte-exact.
   Section slugs are `[a-z0-9-]`, so the `':'` namespace is collision-proof.*
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

(1) golden characterization tests ✅ (`snapshot_v3_golden_test`) → (2) `dataSlug`/`kind` key vocabulary ✅
(folded into slice 3 — build-when-consumed; `study_state.dart`) → (3) unified `StudyStates` table +
`StudyStateRepository` (readers-first; `schemaVersion` 2→3 + byte-exact `backfillStudyStates`) ✅ — the new
table + read repo exist and are proven byte-identical to the two legacy clocks, which stay the source of truth
untouched (making the old repos *thin adapters* moves with the reader flip) → (4) flip writers ✅ — every
state writer (`recordReview`/`seedState`/`recordExplain`/`renameSection`/`dropSection` + the dev seeds)
**dual-writes** the unified row in the same transaction (expand; the legacy path stays byte-identical so
reads + snapshot can't regress, and advance-anywhere is live + tested). *The snapshot reads the legacy tables
directly, so a hard writer-move would break it mid-stream — dual-write is the safe expand step; the hard move
(stop writing the legacy tables) lands in slice 5 with the reader flip.* Restore (`_applyPayload`) +
`clearProgress` also rebuild/clear the mirror in the same transaction, so it stays consistent on **every**
write path — bulk cross-device restore included — not just live writes (verified by a real v2→v3 `onUpgrade`
test + restore/clear tests). → (5a) flip readers ✅ — the old repos' `loadStates` read the unified table and
reconstruct the legacy `SrsState`/`RecognitionState` shapes, so consumers are unchanged but the unified record
is the live read source. → (5b) snapshot → v4 ✅ — export one `studyStates[]`; `mergeSnapshots` folds any v≤3
file to the unified shape first (one keyed merge over `(cardId, dataSlug)`, `lastActivityAt` recency +
`activityCount` tie-break; the golden guards legacy-readability); restore writes `study_states` directly;
`recordReview`'s count source moved to the unified row [must-do (b) done]. → (5c) ✅ writers write **only** the
unified record (every legacy `srsStates`/`recognitionStates` write dropped) + tolerant `StudyKind.fromWire`
[must-do (a) done] — the legacy tables are now fully vestigial (written by nothing, read only by the one-shot
v2→v3 backfill). → (6) ✅ pluggable per-kind scheduler — `study_scheduler.dart` registers the two models
(`RecallScheduler` = FSRS, a drop-in subtype of `SrsScheduler`; `PracticeScheduler` = the expanding clock)
behind `studySchedulerFor(kind)`, the single config-agnostic kind→model seam; `recordExplain` + the recall
provider dispatch through it. → (7) ✅ drop the old tables + dead code. **Option C (as-built):** the consumer layer now reads two concrete
`core + payload` domain types — `RecallState` | `PracticeState`, one per `kind` (the §2 "core + one payload"
model; the flat nullable row is the §2 *storage* form). `loadStates` deserializes the row into the matching
type **once** via `*.fromRow` factories (defaults centralized, byte-identical to the retired adapters); the
`SrsState`/`RecognitionState` shapes **and** the reconstruction adapter are gone, not carried. A `sealed` base
was weighed and **deferred** (build-when-consumed) — no consumer holds a mixed-kind collection, and the
cross-kind uniform handle already exists as the raw row (`StudyStateRow`, renamed from `StudyState` to clear the
domain/storage collision). 7a introduced the types + migrated every consumer (readers-first, suite-guarded,
tables still present); 7b dropped `SrsStates`/`RecognitionStates` + `backfillStudyStates`, bumping
`schemaVersion` 3→4 with a `from<4` `DROP TABLE IF EXISTS` (a drop-guard test pins `deleteTable`'s first use).
The v2→v3 backfill was **dropped, not rewritten** — no production data to carry, and `startupRestore`'s v≤3
snapshot-fold is the durable net.*
  - *Slice-5 must-dos surfaced in the slice-4 audit:* (a) make `StudyKind.fromWire` **tolerant** of an unknown
    `kind` (degrade, don't throw) before readers depend on it; (b) move `recordReview`'s review-count source
    from the legacy `SrsStates` row to the unified row once the legacy writes stop; (c) `renameSection` /
    `dropSection` today rekey/drop only the recall datum (byte-identical to the legacy clocks, which never
    touched the explain row) — revisit whether the practice datum should follow when #158 lands.
