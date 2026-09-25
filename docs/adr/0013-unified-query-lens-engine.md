# ADR 0013 — One query/lens engine: Browse filters == deck membership

- **Status:** Accepted
- **Date:** 2026-09-25
- **Deciders:** Kyle Uehlein
- **Related:** `docs/user_stories/browse.md` (Accepted: "one query API shared by Browse filters and lens creation"; "same
  engine"; "browse → save this filter as a deck falls out for free"), `deck_creation.md` (the scoped card-explorer +
  lens suggestions), `index.md` / `glossary.md` (**Deck = a query lens over the vault**). ADR-0006 (deck is a pure
  lens; aims own readiness), ADR-0003 (draft gate; the deferred `(deckId,cardId,sectionSlug)` key), ADR-0012 (shared
  card components / `showCardEditor` single editor entry). `architecture.md` invariants #2 (no card-type branch), #5
  (`cardId::sectionSlug`), #8 (single-deck/aim byte-identical). Roadmap task **1g** (this); **#84** (parse-profile /
  user-editable sets). Supersedes the near-term `MembershipQuery` selectors (folded in).

## Context

The SoT model is **VAULT → DECK (a query lens) → a set of aims**: a deck is *"a saved folder path or tag expression
(`korean/`, `tags:music && !tags:done`) selecting a subset of the vault … not a separate pile of cards — a view."*
`browse.md` then makes an Accepted call: Browse's filters and a deck's lens are *the same language, one engine*, so
"save this filter as a deck" falls out for free, with the advanced form a power option, not the default.

Today that is **two disjoint query languages** (a 5-stream scope confirmed it, incl. reading both files):

- **Browse** — `core/search/card_filter.dart`: `CardFilter{types, domains, tiers, mastery}`, OR-within-facet /
  AND-across, no negation; `parseSearchQuery` handles `type:`/`tag:`/`tier:`/`is:`; **not serializable**; transient.
- **Deck lens** — `core/deck/membership_query.dart`: sealed `MembershipQuery` = `AllCards | TagMembership |
  FolderMembership`; single predicate per kind; **serializable** (`toJson`/`fromJson`), persisted on `Deck` and
  consumed by `Deck.select`. Every per-deck readiness/plan/analytic keys off this **stable** member set
  (`deckMemberCardIds`).

They overlap only on *tag* (and even there Browse is a `Set` OR, the lens a single string). Browse has type/tier/
mastery the lens can't express; the lens has folder Browse can't. No shared IR, parser, or evaluator — the "same
engine" decision is unrealized.

Online research (Anki, Obsidian search/Bases, Notion, Apple smart folders/playlists, DEVONthink, OmniFocus, Logseq/
Roam) shows the dominant, proven pattern is **one language, two surfaces — a saved query *is* the collection** — and
that the consumer-grade winners use a **structured "match all / match any" builder as the default** with a
**read-mostly text mirror**; pure text-DSLs (Dataview/Datalog) are the repeatedly-cited barrier ("two-tier cliff").

## Decision

**Unify Browse filtering and deck membership onto ONE serializable, evaluable query IR; expose it as a structured
builder (default) plus a conventional text mini-language (power option). `MembershipQuery` folds into it; `CardFilter`
becomes a projection.**

1. **The IR** (`lib/core/query/`): a sealed `CardQuery` **boolean tree** — leaves + `And` / `Or` / `Not`. Leaves:
   **structural** `TagIs`, `FolderUnder`, `TypeIs`, `TierIs`, `TextMatches`; **dynamic** `StateIs(fresh|due|strong)`.
   A pure `matches(card, {QueryContext ctx})` evaluator (ctx carries `dueByKey`/`now` for `StateIs`); `toJson`/
   `fromJson` with **back-compat** for the existing `{all|tag|folder}` JSON so saved decks keep working. It is the
   single home for both surfaces.

2. **Deck membership is STRUCTURAL only.** A persisted deck lens contains no `StateIs` leaf — so `deckMemberCardIds`
   stays a **stable set** and per-deck readiness/forecast/plan/analytics are unchanged (ADR-0006). `StateIs` (study
   state) is a **Browse-only** transient refinement. (No "smart decks" whose membership drifts daily — deferred.)

3. **Full boolean in the engine + text form (conventional); only the visual builder starts shallow.** The IR and the
   **text mini-language support arbitrary `And/Or/Not` nesting** — `(folder:korean/ OR tag:korean) tier:1 -tag:done`,
   any `()` depth — exactly Anki's and Obsidian's search grammar (and *free*: a recursive tree + a recursive-descent
   parser; *capping* them would be the extra code). The **structured builder** ships the conventional **"Match all /
   Match any / None" groups**; how deep it lets you *visually* nest is an MVP scope choice — start shallow — **not** an
   engine limit and **not** a break from convention (every mainstream builder caps visual depth somewhere; Notion at
   3). Because the IR is the full tree, widening the builder later is **purely additive (zero migration)**, and any
   lens deeper than the builder stays editable via the text mirror. This covers the defining lens job — *gather
   scattered cards* (`folder:korean/ OR tag:korean`) — and the SoT's `tags:music && !tags:done`.

4. **Text mini-language mirrors the IR, matching Anki/Obsidian convention**: `key:value` facets, `OR`/`||`, `()`
   grouping, `-`/`!` negation (`(folder:korean/ OR tag:korean) tier:1 -tag:done`). **Builder is the default; the text
   string is a read-mostly mirror** (copy/share/learn) — never a required entry point (avoids the two-tier cliff).

5. **One engine → Browse and lenses share it.** Browse filtering + `parseSearchQuery` emit/consume `CardQuery`
   (`CardFilter` becomes a thin projection or is retired). **"Save this Browse filter as a deck"** falls out —
   restricted to structural leaves (drops any `StateIs`).

6. **Scoped card-explorer lives in deck creation only** (not a whole-vault Browse; `browse.md` non-goal). It's the
   shared builder with a live **"N included / M excluded"** count + **lens suggestions from commonalities** (a shared
   folder → "a deck of `foo/`?"; a shared tag → "a deck around `tag:CS`?"). Card-by-card picking stays non-MVP.

7. **Authoring entry stays `showCardEditor`** (the single editor entry, ADR-0012 — Browse `+` / card Edit /
   draft-review / stub already route through it). 1g only **closes the reuse gaps** (deck-creation + onboarding
   compose it) and may dedup the frontmatter-assembly helpers (`newCardMarkdown` / generated-cards / import-stamp)
   behind one builder. Authoring stays **light, not a studio** (AI edit-chat remains **1f.2**-deferred).

**Sequencing.** **G0** characterization (pin current Browse `matchesFilter`/`parseSearchQuery` results + `Deck.select`
for all/tag/folder + membership JSON round-trip) → **G1** the IR + fold in `MembershipQuery` (`Deck.membership` becomes
`CardQuery`; `Deck.select` byte-identical vs G0; delete `MembershipQuery`) → **G2** Browse on the IR (+ `folder:`/
`path:`, `OR`, `-`/`!`; `StateIs` Browse-only; results byte-identical vs G0) → **G3** save-as-deck + the scoped
card-explorer (structural-only, live counts, suggestions) → **G4** authoring reuse (deck-creation/onboarding compose
`showCardEditor`; optional frontmatter dedup).

## Alternatives considered

- **A string DSL as the source of truth** (parse on every use). Rejected — brittle + a barrier for non-technical users
  (the Dataview/Datalog evidence), and it discards `MembershipQuery`'s serializable sealed design. The text form is a
  *mirror* of the IR, not the truth.
- **Keep two languages + adapters between them.** Rejected — directly contradicts the Accepted "same engine"; two
  parsers/evaluators drift, and "save filter as a deck" never falls out cleanly.
- **A rich visual nested-group builder now** (an unbounded all/any/none group tree in the UI, à la Notion's advanced
  mode). Deferred for MVP — that GUI is the "nesting-ceiling" surface the research warns of, and the SoT wants the
  advanced form as a power option, not the default. This defers only the *visual builder depth*: the IR and the text
  form already express arbitrary nesting (Anki/Obsidian convention), so nothing is lost — a deep lens is authored and
  edited as text until the builder catches up.
- **A hard flat-only data model** (no `Or` node). Rejected — it can't express the real gather case and would need a
  data migration to add OR later. Modeling the tree and capping the *surface* is strictly better.
- **Dynamic "smart decks"** (state in the lens). Rejected for now — a daily-moving member set breaks the stable
  denominator readiness/analytics depend on; revisit as its own change if ever wanted.

## Consequences

- **Positive:** realizes the SoT's "one engine" — a single IR + parser + evaluator behind Browse *and* deck lenses;
  "save this filter as a deck" and the scoped lens-builder fall out; the lens can finally **gather scattered cards**
  (cross-source OR) — the thing a lens is *for*. Deletes a whole duplicated query language (`MembershipQuery` → IR;
  `CardFilter` → projection), not rename-and-carry.
- **Trade-offs / risk:** the refactor touches the load-bearing membership path (readiness/plan/analytics scope through
  `Deck.select`) — mitigated by G0 characterization-first + byte-identical proofs for all/tag/folder and for Browse
  results, and by keeping membership **structural/stable**. Adds an `OR`+`()` text parser and an "any-of" builder
  affordance (bounded, one-time, shared). New capability (folder in Browse, negation, cross-facet OR) ships behind the
  existing tests.
- **Guarded invariants:** deck = pure lens (ADR-0006); stable member set; `cardId::sectionSlug` (#5); no card-type
  branch — facets are attribute/config-driven (#2); directory-agnostic; subject-neutral copy; single-deck/single-aim
  byte-identical (#8); vault = source of truth (the lens persists in the deck's JSON; DB stays derived).

## Validation

- **G0** green on `main` before any refactor: Browse filter + search results and `Deck.select` (all/tag/folder) +
  membership JSON round-trip are pinned.
- **G1**: `Deck.select` is byte-identical to G0 for all/tag/folder; old `{all|tag|folder}` JSON still deserializes;
  `MembershipQuery` is deleted (not carried).
- **G2**: Browse results byte-identical to G0 for the existing facets; `folder:`/`path:`, `-`/`!`, and `OR`/`()` parse
  and evaluate correctly **at arbitrary nesting depth**; `StateIs` is rejected from a persisted lens.
- **G3**: a Browse filter saves to a deck whose membership equals the query (structural leaves only; `StateIs`
  dropped); the card-explorer's "N included / M excluded" matches `matches()`; a `folder:korean/ OR tag:korean` lens
  gathers cards from both sources.
- **G4**: deck-creation + onboarding create cards through `showCardEditor`; no second authoring chrome.
