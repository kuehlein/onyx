# ADR 0020 — Card & scheduling model: knowledge-keyed data, thin cards, one uniform state record + pluggable scheduler

- **Status:** Accepted
- **Date:** 2026-09-28
- **Deciders:** Kyle Uehlein (+ AI-assisted scaffolding; 3 adversarial research passes)
- **Related:** Built on **ADR-0019** (the datum/lens guiding principle + `_onyx/` layout). **Supersedes the
  `(deckId, cardId, sectionSlug)` join-key direction of [ADR-0003](0003-card-status-and-deck-seam.md)**
  (the datum key stays deckId-free). **Amends [ADR-0001](0001-progress-sync-merge.md)** (kind-aware merge +
  a mergeable dormant/tombstone marker), **[ADR-0012](0012-card-model-shared-components.md)** (section
  rekey becomes index-diff-driven; edit-identity RESET → tombstone), **[ADR-0013](0013-unified-query-lens-engine.md)**
  (a section-granular lens leaf, Browse-only). Enforces invariant #2 (no card-type branch). Tasks:
  **#155** (unify scheduling models), **#156** (authoring templates), **#153** (config-driven templates).
  Code: `lib/core/database/tables.dart` (`SrsStates`:10, `RecognitionStates`:169), `lib/core/srs/recognition.dart`,
  `lib/core/srs/srs_repository.dart` (`dropSection`:345, `renameSection`:323), `lib/core/template/flow_spec.dart`
  (`QuizzabilityPolicy`:23), `lib/core/vault/card_parser.dart`, `lib/core/query/card_query.dart`,
  `lib/core/backup/snapshot.dart` (`mergeSnapshots`), the 8 `// ignore: no_card_type_branch` engines.

## Context

ADR-0019 fixed the guiding principle: **the datum owns its one global state; decks/lenses are access
paths.** Most of this is *already the shipped architecture* — the redesign is largely ratification +
removing escape-hatches, not a rewrite. Verified facts a reviewer needs:

- **SRS is already knowledge-keyed and deckId-free.** `SrsStates` PK = `(cardId, sectionSlug)`
  (tables.dart:10-12); every read/write keys `"$cardId::$sectionSlug"`; the cross-device merge is
  section-keyed with no concept of a deck. ADR-0003 *reserved* a `(deckId, cardId, sectionSlug)` key for
  the registry — but that contradicts "the datum is deck-independent" (a datum surfaced by two overlapping
  decks must not fork its schedule). Since on-disk data is junk (no migration cost), the clean move is to
  **keep the datum key deckId-free** and retire the reserved direction.
- **Quizzability is already card-kind-derived.** `subject.flowForType(type).quizzability` →
  a `QuizzabilityPolicy` (flow_spec.dart:23) resolved at parse time; the parser never sees a deck. But two
  escape hatches remain: per-card `quiz:`/`quizzable:` overrides, and a **mandatory `type:` field** that is
  the sole flow selector — read directly in ~23 sites, with the SWE engines hard-branching on it behind
  `// ignore: no_card_type_branch` (8 files: `algo_queue`, `algo`, `system_design`, `behavioral`,
  `concept_comfort`, `analytics`, + the two mock screens).
- **There are already exactly TWO scheduling models, not four**, both on the same `(cardId, sectionSlug)`
  key: `SrsStates` (FSRS) for flashcard + the algo *solve* clock, and `RecognitionStates` (a deliberate
  **expanding-interval, explicitly "NOT a second FSRS"**, recognition.dart:8) for the algo *explain* clock
  and — via a fixed `sectionSlug 'mock'` — system-design, behavioral, and the generic config flow.
  `applied_attempts` (transfer) and behavioral **coverage/freshness** (a 30-day window *mean* of mock
  scores) are **not scheduling state** — they are separate readiness axes.
- **The science forbids one universal scheduler.** Spacing/distributed practice generalizes to skills,
  but the FSRS/DSR *forgetting-curve* models retrievability of one declarative memory trace; retrieval
  practice repeatedly fails to build problem-solving/far-transfer. `recognition.dart` already encodes
  this judgment. So the honest #155 target is **one uniform STATE record + a pluggable scheduling FUNCTION
  per kind** (the DASH/DAS3H shape), not FSRS-everywhere.
- **Two lifecycle bugs are live** and worsen at scale: `dropSection` **hard-deletes** the state row
  (srs_repository.dart:345) — but the convergent merge unions rows, so a peer re-adds it (zombie); and
  section rekey fires **only** on the in-app editor (renameSection:323), so an **external Obsidian heading
  rename orphans the forgetting curve** (the ADR-0012 footgun) — fatal in a vault-first, teacher-push world.

## Decision

### 1. Knowledge-keyed datum, deckId-free (supersedes ADR-0003's reserved key)

The atomic unit is the **datum**, keyed `(cardId, dataSlug)` — deck-independent, one global state,
advance-anywhere-advances-everywhere. `cardId` is a **stable slug** (invariant #5; normalize the residual
UUIDs). A deck's lens **surfaces** data; it is never part of the datum key. The `(deckId, …)` direction of
ADR-0003 is **retired** — mark ADR-0003 "amended by 0020" on the join-key point only (its `draft`/`active`
status seam stands).

### 2. Thin cards: flow membership from a subject-level selector; the card marker is an optional guardrail

- **The flow's selector is the source of truth for membership.** Each flow declares a **subject-level**
  selector — a `CardQuery` over card-intrinsic attributes (tag / folder / an optional reserved marker) —
  and a card's flow = the selector that matches it. **Subject-level, so flow is GLOBAL** (a card is the same
  flow in every deck; a deck's membership lens only *surfaces or hides* it, never reassigns it — the
  invariant that keeps one-datum-one-state true across overlapping decks).
- **Default flow = the basic flashcard/learn flow**, claimed as the *complement* (any card no explicit-flow
  selector matches). So a plain card needs **no marker at all** — the thinnest common case — and "no flow
  metadata" is a valid state, never "broken". The learn selector can therefore never overlap an explicit
  flow, so **two-flow ambiguity is only possible between two *explicit* flows.**
- **No mandatory per-card designator.** A **self-authored card works with zero Onyx glue** — it flows by
  its own attributes (its natural tags/folder, which the subject's selector keys on). We never require a
  card to carry Onyx metadata to function. **Remove the mandatory `type:` field + the per-card
  `quiz:`/`quizzable:` overrides**; quizzability = the flow's `QuizzabilityPolicy`, and the flow just quizzes
  the `##` sections present (so declension-vs-conjugation-style variation is free).
- **The card marker is an optional, self-describing guardrail, not a gate.** The **authoring flow stamps**
  the selector attribute when you pick a non-default flow (so Onyx-made cards self-describe); the default
  flashcard stamps **nothing**. You may delete/change it after — it's a nudge, not a constraint.
- **Guardrails (dismissable, never blocking) — two tiers** (avoid alarm fatigue):
  - *Hard/deterministic:* a card matching **two explicit flows** → pick one; a card routed to a flow but
    **failing that flow's required core** (a template's required sections — see #156) → "may be misfiled".
  - *Soft/informational* (broken-links style, quiet): "N cards have no explicit flow (treated as
    flashcards)". A per-card **dismiss** ("don't warn about this one") lives in **app state, not card
    frontmatter** — so silencing a warning never adds glue to the card.
- The 8 `no_card_type_branch` engines are **re-expressed against the selector** (byte-identical,
  characterization-first); the lint is tightened so a raw kind-branch fails CI (invariant #2, made total).
  This is invariant #2 finally made total.

### 3. One uniform state record + a pluggable per-kind scheduling function (#155)

- Collapse `SrsStates` + `RecognitionStates` into **one uniform state table**: a thin common core
  `{ (cardId, dataSlug), kind, dueAt, lastActivityAt, activityCount, status }` + a **kind-tagged payload**
  (recall: `{stability, difficulty, state, step}`; practice: `{intervalDays, streak}`). A content unit
  **spawns 1..N data** (flashcard → one per quizzable section; algo → `solve` + `recognize`; SD/behavioral
  → a `mock` practice datum). *Not* one datum with heterogeneous blobs; *not* a wide null-filled union.
- A **flow is an EXPRESSION** = { spawn-rule (which data a card spawns) · interaction · grade-normalization
  (map the native grade — FSRS 1-4, {solid,shaky,lost}, applied 0-100 — to one internal outcome) ·
  intra-unit precedence (e.g. algo "solve wins ties") }. The state table stays interaction-agnostic; the
  scheduling **function** is pluggable per kind.
- **Two functions, not one** (the defensible floor): a **recall curve** (FSRS) for flashcard + algo
  recognition; a **practice/expanding-interval** function for algo-solve + SD + behavioral. Never one
  universal forgetting curve over skills.
- **Transfer (`applied_attempts`) and behavioral coverage/freshness stay OUT of the state model** — they
  are non-scheduling readiness axes, aggregated separately (preserve the `readiness.dart` seam verbatim).
  "Behavioral → freshness" is a derived read-out, not a spawned scheduling datum.

### 4. Retain-but-detach lifecycle (amends ADR-0001 + ADR-0012)

Three events, three behaviors — never conflated:

- **Lens narrows** → a pure **surfacing recompute** of that deck's member set/denominator. No state write;
  the datum stays fully schedulable via any other overlapping deck. (Free today — readers + denominators
  derive from the live index.)
- **Card deleted upstream / file gone** → the state row is **retained and becomes inert** (the index join
  misses it). Re-inclusion resurrects the curve via the stable key (OR-Set add-wins). Detach is a
  **mergeable dormant marker** (`status: dormant` / `detachedAt`), **never row absence** — folded into
  `mergeSnapshots` with re-attach-wins, or a peer resurrects a deletion.
- **Explicit forget / edit-identity RESET** (ADR-0012, meaning changed) → the only destructive path, and
  it is a **mergeable tombstone**, not a bare delete. `dropSection`'s hard-delete is converted to a
  tombstone write.

Detached/dormant data drop from **both** the numerator and the readiness/coverage denominator (Anki
suspend semantics), so a narrowed lens never reports dishonest readiness.

### 5. Section identity is index-diff-driven; section-granular lens is Browse-only (amends 0012 + 0013)

- **Rekey on reindex, not only in the editor:** diff each card's last-indexed section slugs vs current and
  rekey the dormant/live data, so an **external heading rename** rekeys instead of orphaning. Prefer a
  name-agnostic section key (a curated section marker/ordinal) over `slugify(heading)` where feasible.
- A **section-granular lens predicate** (`section:usage`) is added as a **Browse-only surfacing filter**
  first (like the dynamic `StateIs` leaf, which is already stripped from persisted membership). It is
  **not** persisted into deck membership until (a) a stable section key exists and (b) readiness/analytics
  denominators move from a card-id set to a `(cardId, sectionSlug)` unit set. A section predicate that
  can't resolve **widens to card-level, never empties.**

## Alternatives considered

- **One universal scheduler (FSRS everywhere).** Rejected by the science *and* the existing code
  (`recognition.dart` is already "NOT a second FSRS"); far-transfer from retrieval practice ≈ 0. The
  uniform *state record* is the win; one *function* is a category error.
- **Keep two separate state tables.** Rejected: one uniform record + pluggable function is what makes a new
  flow a config expression rather than a new table + new merge branch; the two tables already share a key.
- **Keep `(deckId, cardId, sectionSlug)` (ADR-0003).** Rejected: it forks a datum's schedule across
  overlapping decks, contradicting the guiding principle; deckId-free is correct and, with junk data, free.
- **Keep `type:` + per-card quizzability as overrides.** Rejected: they're the glue the thin-card model
  removes; a subject-level tag/attribute selector + authoring templates give uniformity without per-card drift.
- **Mandate a dedicated `kind:` frontmatter field on every card.** Rejected: it forces Onyx-specific glue onto
  self-authored cards to make them usable. Instead the selector keys on the card's *own* attributes (tags/folder),
  the default flow needs no marker at all, and the authoring flow stamps a marker only as an optional guardrail.
- **Pure structure inference (no metadata — the flow is guessed from a card's section shape).** Rejected: the
  thinnest-looking option but the least safe — structure is fuzzy (a concept card can contain code) and fragile
  (a heading rename silently reflows the card). A selector over declared attributes + required-core validation is
  the robust middle.
- **A deck as a *collection* of per-flow lenses** (one lens per flow). Rejected: it makes the *lens* decide
  a card's flow, which forks the datum's single global state (a card caught by the "algo" lens but authored
  `kind:concept` would have two flow answers). Flow is card-intrinsic (`kind`), so a deck's multiple flows
  are **emergent** from its members' kinds. `kind` is exposed as a **queryable lens leaf** (`kind:algo`), so
  a single membership lens expresses both a multi-flow deck (no kind filter) and a single-flow deck
  (`… && kind:algo`) with zero ambiguity — one lens, not a bundle. (Pinned in ADR-0019 §Decision.1.)
- **Persistable section-granular membership now.** Deferred: it silently shifts the member-set grain from
  card to `(cardId,sectionSlug)` — a cross-cutting analytics refactor — and inherits slug instability.
  Browse-only first.

## Consequences

- **Positive:** one state model + a pluggable function makes flows config-expressible and the scheduler
  honest per kind; thin cards + a `kind:` marker kill per-card glue and make invariant #2 total; the
  deckId-free datum key is the clean foundation the sync layer (ADR-0021) needs; retain-but-detach +
  index-diff rekey close two live data-integrity holes (zombie resurrection, external-rename orphans).
- **Negative / trade-offs:** a state-table rewrite + kind-aware `mergeSnapshots` (the ADR-0001 CRDT core
  — must stay provably convergent); re-expressing 8 engines + ~23 `card.type` sites against the selector;
  removing `type:`/`quiz:` is a member-set change for any card that used them (handle with care). Unbounded
  dormant-row growth (benign — tiny, inert; prune only behind an explicit user "forget" tombstone, since
  ADR-0001 has no vector clocks for safe GC).
- **Known limitations & follow-ups:** the actual FSRS-vs-practice function boundary + grade-normalization
  types are pinned during build (#155); authoring templates are #156; config-driven subject templates
  (lifting the SWE template out of code) are #153/ADR-0019's `_onyx/subjects/`; the section-granular
  *denominator* migration is deferred with the persistable section lens.

## Validation

- Pure scheduler tests per kind (recall curve; expanding interval) — the deterministic style ADR-0016 used.
- A `mergeSnapshots` convergence test over the unified table: device A resets/forgets a datum, device B
  still holds the live row → after merge in either order the datum stays reset (no zombie); a dormant datum
  re-attaches add-wins on re-inclusion.
- An index-diff rekey test: an external heading rename rekeys the datum (curve preserved), not orphans it.
- A selector totality test: every card resolves to exactly one flow; the tightened `no_card_type_branch`
  lint fails on a raw kind-branch. Characterization tests prove the 8 re-expressed engines are byte-identical.
- Section-granular lens: a `section:` predicate filters Browse; is refused from persisted membership; widens
  to card-level when unresolved. Full suite green through the `type:`/`quiz:` removal (junk data = no migration).
