# ADR 0025 — A deck owns its config; the path-derived subject/template layer dissolves

- **Status:** Accepted
- **Date:** 2026-09-30
- **Deciders:** Kyle Uehlein (+ AI-assisted; a 6-agent scope pass over the ADRs, the source-of-truth stories,
  the learning-science research, and the deck/template/parser/state code).
- **Related:** **SUPERSEDES ADR-0023 §Decision 1** (a card's template is `templateIdForPath` — path-derived)
  and its "template tie-break" open question. **AMENDS** ADR-0019 §2–3 (drops the shared `subjects/` dir),
  ADR-0020 §2 (flow membership moves from a subject-level selector to deck config), ADR-0006 §1 (a deck is a
  lens **+ config**, not a *pure* lens). **Builds on ADR-0024** (mode-keyed, config-free state — the invariant
  that makes per-deck config safe). Honors ADR-0013 (one query language), 0022 (identity), 0016/0017/0018
  (allocation), 0021 (sharing — simplified). Realizes `docs/user_stories/deck_creation.md` §setup model +
  **#162**. Code: `lib/core/deck/*`, `lib/core/template/*`, `lib/core/vault/*`,
  `lib/shared/providers/{decks,template,vault}.dart`, the readiness engines.

## Context

Today a **deck** is a pure lens — `{membership: CardQuery, templateId, aims}` — that *references* a shared,
path-derived **`DeckTemplate`** (a "subject": flows, parse profile, readiness target/ladder, vocabulary,
domain labels, coach skill). `TemplateRegistry.templateIdForPath(cardPath)` assigns a card's config by
**directory subtree** (longest-prefix). So config sits on an axis **orthogonal to decks** — path-derived, not
lens-derived — and a card gets exactly one config from *where it lives*.

Two problems the generalization surfaces: (1) it's conceptually confusing — a "subject" isn't a deck/lens
group, it's config bolted to a folder; and (2) it forecloses the **self-contained, shareable deck** that
ADR-0021/0023 want (a deck's config + skills should travel *with it*). ADR-0023 already put config + AI skills
under `_onyx/decks/<id>/` and card-ness on the deck lens; the path-derived template is the last piece of the
orthogonal axis. Investigation: the real vault ships **zero** template files (it runs on the in-code SWE
fallback), **nothing requires >1 template per vault**, and `templateIdForPath` has ~one real consumer.

## Decision

**A deck owns its entire config. The path-derived subject/template layer dissolves.**

1. **A deck = a lens + a config bundle**, all in `_onyx/decks/<id>/`: the membership lens (unchanged,
   structural-only — ADR-0013) **plus flows, readiness target/ladder, vocabulary, domain labels, coach skill,
   and aims**. Config resolves from `deck → its bundle`, never from a card's path. `TemplateRegistry`,
   `templateIdForPath`, the `activeTemplate`/`activeRegistry` globals, and `onyx-subject.yaml` discovery
   retire.
2. **A "template" becomes a creation-time PRESET, not a live shared dependency.** The built-ins (SWE, neutral)
   and any authored YAML become a **catalog of `DeckConfig` values copied into a deck at creation**
   (`_onyx/decks/<id>/config.json`). After creation the deck is self-contained; the preset is never consulted
   at runtime. "Sharing a subject across decks" = *start from the same preset* (a copy), not a live link —
   which also makes teacher-push (ADR-0021) fully self-contained (no separate template to ship or reconcile).
3. **Flow resolution moves from per-card (path→template) to per-(deck, card).** A card's flow(s) = the flows
   of the deck(s) that claim it, resolved via the flow selectors inside that deck's config, else the deck's
   default flashcard flow. **Safe because ADR-0024 keys state by `(cardId, dataSlug=aspect+mode)`, config-free:** a card in
   two decks practiced the same way SHARES its schedule; a card practiced different ways = different modes =
   independent schedules (correct). The deck decides *which modes a card is practiced in*; it never owns a copy
   of the schedule.
4. **Parse profile stays VAULT-LEVEL for now (staged).** Card-ness selection reads only frontmatter + path
   (never the body), so the non-circular order is **frontmatter → lens → deck → config → body**. But making the
   BODY parse per-deck (different section splits per deck) would force the state key to become deck-aware for
   the OVERLAP case (one file in two decks with different parse rules → different sections → the `(cardId,
   dataSlug)` key would collide on bare `cardId`), plus N-parses-per-file and wikilink-graph care — machinery
   **no current vault needs**. So: parse profile + `fileExtensions` stay a single vault default now, while the
   *model* treats parse profile as deck config, so per-deck parsing later is *config, not a rewrite*. The
   overlap-handling design is a tracked future item (roadmap).
5. **Multi-subject is served by decks, not path-partitioned templates.** Two domains in one vault = two
   (possibly overlapping) decks, each owning config — strictly better than two subtrees + two YAMLs + a
   longest-prefix resolver. Card reuse across decks (Latin vocab in Year-1 + Year-2) is the shared-schedule
   case (ADR-0024).
6. **Naming consolidates to the final terms in the same structural pass** (avoiding subject→template→config
   double-churn): `DeckTemplate`→`DeckConfig`, `builtInTemplates`→`deckPresets`, `SubjectColor`/`subject*`
   palette→`TrackColor`/`track*`, retire `onyx-subject.yaml` for a per-deck `config.json`, and rewrite the
   ~250 "subject" comments against the surviving code.

## Alternatives considered

- **Keep the shared, path-derived subject** (today). Rejected: config orthogonal to decks is confusing,
  forecloses self-contained shareable decks, and enables sharing nothing needs (0 template files shipped).
- **Per-deck EVERYTHING, including parse profile, now.** Rejected as premature (Decision 4): forces the
  deck-aware state key + N-parse + wikilink work for a need no vault has. Staged instead.
- **Force 1:1 deck↔template.** Unnecessary — the preset-copy model gives 1:1 by default while letting a deck
  diverge.

## Consequences

- **Positive:** one grouping mental model (the deck owns everything); self-contained, shareable decks (ADR-0021
  simplified — no separate template to reconcile); "subject" retires; multi-subject strengthened.
- **Negative / must-hold:** **byte-identical for the SWE vault** (invariant #8) — the default deck's config must
  reproduce the in-code SWE template exactly (same flow selectors, same slugs) so no card re-slugs its state or
  changes flow; **readers-first, writer-flip-last** migration is mandatory given the ~40 `activeTemplate` refs
  (≈17 in pure-core — the readiness math the bulk; the rest UI/providers); the **four readiness knobs stay on
  the AIM** (ADR-0006 unchanged, weakest-link roll-up intact);
  config stays app-managed with a power-user escape hatch (not an authoring studio — `index.md`).
- **Blast radius:** ~40 files (`activeTemplate` 40 refs / 26 files; `DeckTemplate` 46 refs); the pure-core readiness math (`readiness/target.dart`, `ladder.dart`,
  `readiness.dart`) reading the `activeTemplate` global is the bulk; `card_cache` is trivial (it has no
  readers); the **reseat** — pass `List<Deck>` (not `List<CardQuery>`) to the indexer and resolve config via
  `deck.templateId` instead of `path` — is the small, byte-identical unlock.

## Open questions

- **Parse-profile overlap (tracked, roadmap):** if a card is in two decks with **different parse rules**, how
  do we resolve the body split + the `(cardId, dataSlug)` key without collision? (A deck-aware key for the
  overlap only? most-specific-deck-wins? vault-level with per-deck overrides that don't change section
  identity?) Deferred until a real multi-convention vault exists.
- **Preset catalog surface:** where the preset catalog lives (in-repo `deckPresets` + the library-picker of
  `deck_creation.md` §skill-sourcing) and how a user re-applies/updates a preset after creation.

## Validation

- Byte-identical: the SWE vault's card set, flows, and schedule state are unchanged after moving config onto
  the (default) deck (invariant #8; the standing green suite).
- A second deck with different config (e.g. a folder-selected drill flow) resolves its flow from its OWN config,
  independent of the SWE deck.

## Slices (readers-first)

(1) add `DeckConfig` on `Deck` with a template-preset fallback (byte-identical while empty) → (2) repoint the
param-taking pure-core seams (`ReadinessTarget.forAim`, ladder, domain labels) → (3) repoint providers + UI
(drop the `?? activeTemplate` fallbacks; Browse/card_filter resolve per-card via its owning deck) → (4) reseat
parsing to deck→config (keep one shared parse profile) → (5) flip writers + drop the registry/globals →
(6) the naming cleanup + delete dead code.

**Must-fix during this stream (a latent divergence found in review):** flow resolution has TWO paths today —
`Card.flow` (the `card_flow.dart` extension: first matching selector, else `defaultFlow`) and the type-derived
accessors `Card.isPracticeTrack`/`isApproachCard` (in `card.dart`, via `flowForType(card.type)`), plus the
mock plan's `c.type == flow.cardType` match (`practice_plan.dart`) and the flow-runner's skill load
(`flow_runner.dart`, `flowForType(card.type)`). These **agree only when `type ≡ selector`** — true for the
all-`TypeIs` shipped templates (so it's harmless today / suite green), but a **folder/tag selector whose
`cardType` differs from a card's explicit `type:` makes them resolve *different* flows**, orphaning the card
(recall pipelines count it via `isPracticeTrack=false` but it has no quizzable sections; the mock plan skips
it; the skill load misses). Route **all** flow resolution through the single `card.flow` (deck-config) path —
likely by moving `isPracticeTrack`/`isApproachCard` into the `card_flow` extension — so parse-time and
query-time can never disagree.
