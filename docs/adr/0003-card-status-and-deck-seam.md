# ADR 0003 — Card lifecycle status (`draft`/`active`) + the `deckId` seam

- **Status:** Accepted
- **Date:** 2026-09-17
- **Deciders:** Kyle Uehlein (+ AI-assisted scaffolding)
- **Related:** `docs/content-creation.md` §3 (the Draft/Review gate),
  `docs/registry-and-sync.md` §3 (deck identity), `docs/ux-rework-stage1.md`
  P0-2/P0-5; Phase-0 of `docs/roadmap.md`. Code: `lib/shared/models/card.dart`,
  `lib/core/vault/card_parser.dart`, `lib/core/vault/vault_indexer.dart`, the
  scheduling/readiness providers.

## Context

The rework's content on-ramps (AI-generation, deck import, upstream deck updates)
must not silently inflate honest readiness or feed the FSRS scheduler with material
the learner has never retrieved. Stage-1 named a **`draft`/`active` card status**
that FSRS *and* every readiness denominator exclude as "the highest-leverage
primitive in the whole rework" (P0-2) — the one mechanism that makes all three
inflows honest *by construction*.

Separately, pulled decks need a **`deckId` namespace** so a foreign card's id can't
collide with local FSRS state; the eventual join key is `(deckId, cardId,
sectionSlug)` (P0-5). That is a large, registry-coupled migration and is **not** in
scope here — but the seam is cheap to carry now.

`Card` is a plain parsed model (the vault is the source of truth); scheduling +
readiness read `IndexResult.cards`. There is already a precedent — `isPracticeTrack`
is a `Card` getter excluded from the recall queues + the readiness denominator.

## Decision

**1. Ship `CardStatus { active, draft }` now.**
- `Card.status` (+ `bool get isDraft`), parsed from `status:` frontmatter. Absent or
  unknown → **`active`**, so every existing card is byte-identical.
- Exclusion is centralized in **one accessor**: `IndexResult.studyCards` = the cards
  eligible for scheduling/readiness (everything except drafts). Every scheduler and
  readiness/coverage computation reads `studyCards`; **Browse reads `cards`** (it
  shows drafts, later marked "not counted"). This keeps the rule in one place rather
  than scattering `&& !isDraft` and risking a missed site.
- No DB/schema change: the exclusion works on the parsed in-memory index. The
  `card_cache` "draft" column + the Browse marker are a later UI unit (they don't
  affect scheduling/readiness).

**2. Reserve `deckId` as a carried field; defer the join-key migration.**
- `Card.deckId` (parsed from `deck:`, default `''` = the local/default deck) exists
  from now on, so inflows can stamp it. The SRS join key stays `(cardId,
  sectionSlug)` today.
- Migrating the join to `(deckId, cardId, sectionSlug)` (and normalizing `cardId` to
  a within-deck slug) is the **registry unit's** work — it ripples through
  `srs_state`/`reviews`/`recognition`/`applied`, the snapshot merge keys (ADR-0001),
  and every query, so it earns its own ADR + migration rather than riding here.

## Alternatives considered

- **Scatter `!isDraft` at each of the ~13 scheduling/readiness sites.** Rejected —
  the single `studyCards` accessor is DRY and a future scheduler is correct by
  default just by reading it.
- **Do the `deckId` join-key migration now** ("before data exists"). Deferred: it is
  large and registry-coupled; conflating it with the status seam would break the
  one-reviewable-unit rule and the snapshot merge keys mid-flight. A carried
  `Card.deckId` is the cheap part; the join is the expensive part and is genuinely
  deferrable (there is only the local deck until the registry lands).
- **A DB `status` column now.** Deferred with the Browse marker — unnecessary for the
  scheduling/readiness exclusion (which reads the parsed index).

## Consequences

- **Positive:** the honest-readiness + FSRS-exclusion guarantee lands now, in one
  place; zero behavioural change for existing vaults (default `active`); the AI-gen /
  import / upstream-update flows have their gate primitive ready; `deckId` is carried
  so inflows can set it without a later model migration.
- **Trade-offs / follow-ups (not in this unit):** the `deckId` join-key migration +
  `cardId`→within-deck-slug normalization; **duplicate-`cardId` detection in the
  indexer** (P0-5 — two cards with the same id, e.g. from a folder-sync conflict
  copy, should be flagged/skipped, not double-scheduled); the `card_cache` `status`
  column + the Browse "Draft · not counted" marker.

## Validation

- `test/unit/card_parser_test.dart`: `status:` absent → `active`; `status: draft` →
  `isDraft`; `deck:` → `deckId` (default `''`).
- A focused test that `IndexResult.studyCards` excludes drafts and keeps active +
  practice-track cards (the exclusion the schedulers rely on).
- The full suite stays green (no existing card carries `status:`, so behaviour is
  unchanged).
