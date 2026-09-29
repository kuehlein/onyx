# ADR 0023 — Card-ness = deck-lens membership (the lens is the one grouping knob)

- **Status:** Proposed
- **Date:** 2026-09-29
- **Deciders:** Kyle Uehlein (+ AI-assisted).
- **Related:** Completes the **zero-frontmatter vault** realization begun in **ADR-0022** (`id:` optional)
  and this session's card-ness-via-flow-selector change (`card_parser.dart`), which this ADR **re-layers**.
  Builds on **ADR-0013** (the one query language; structural vs dynamic leaves) and **ADR-0020 §2** (flow
  membership via selector; default flow = flashcard). Realizes the [`deck_creation`](../user_stories/deck_creation.md)
  user story ("a deck = a query lens; simple = a directory"). Code: `lib/core/vault/vault_indexer.dart`,
  `lib/core/vault/card_parser.dart`, `lib/core/deck/deck.dart`, `lib/core/search/card_filter.dart`,
  `lib/core/query/card_query.dart`.

## Context

A **deck is already a query lens** — `Deck.membership` is a `CardQuery` (default `Everything`), and
`Deck.cardsFrom(cards)` selects a deck's members by matching it. The lens mini-language (`parseLens` /
`renderLens`) already supports **directories** (`korean/`, `folder:SWE` — recursive via `FolderUnder`'s
prefix match), **tags**, **boolean logic** (`&&`/`OR`/`()`/negation), and **folder/tag exclusion**
(`-folder:drafts`). `deck_creation.md` documents exactly this: "Add a new query lens to the vault … Name
the lens directly — `korean/`, `tags:korean && !tags:hangul`," with a live "N included / M excluded" count.

**The gap.** The lens groups *cards*, but **card-ness** — which *files* become cards at all — is decided a
layer *below* the lens. It was `type:`; this session it moved to the subject's **flow selectors** (a file is
a card iff some flow's selector matches). So a deck lens of `korean/` over a folder of **frontmatter-less**
notes returns **empty** — the files never become cards, because no flow's `TypeIs` selector matches a note
with no `type:`. That defeats the zero-frontmatter vault: "point at a directory → those are my cards" can't
work while card-ness is gated one layer beneath the grouping the user actually sets.

The user's expectation (correct): **the query lens is the single grouping knob** — a simple lens picks a
directory and every file in it is a card; advanced lenses use tags + boolean logic. There should not be a
*second*, separate "which files are cards" configuration beneath it.

## Decision

**Card-ness = matched by some deck's membership lens.** A file is a card iff, once parsed into a candidate,
it is matched by the **union of all decks' lenses** in the vault. The lens is the one user-facing grouping
knob; card-ness and deck membership are the same act.

1. **The lens is the grouping — and it decides card-ness.** Simple lens = a **directory** (`korean/` /
   `directory:SWE`), **recursive by default** (existing `FolderUnder` semantics). Advanced lenses layer
   tags + boolean logic + exclusions — all already in the language. There is *no* separate card-ness config.
2. **Flow is an automatic template sub-layer, not a grouping knob.** For a card, its flow is the first
   matching flow selector in its template, else the **default flashcard flow** (ADR-0020 §2). A plain vault
   → one flow, everything is a flashcard. SWE → the flow selectors sub-classify (algorithms → drill, etc.).
   This **re-layers** this session's change: the flow selectors stay, but only to resolve *how* a card is
   practiced — no longer *whether* it is one. `card_parser` becomes permissive (any well-formed note is a
   *candidate*); the **indexer** applies the lens-union card-ness gate.
3. **A structural sanity floor** keeps "directory = cards" from slurping non-card notes. A candidate must
   **parse into a valid card** (H1 title + structure; the existing `MalformedCardException` path buckets the
   rest). The floor is **H1-based, not quizzable-based** — mock cards (system-design, behavioral) have zero
   quizzable sections but *are* cards. Plus the existing default excludes: the config dir (`_onyx/`),
   folder-syncer conflict copies, and non-configured file extensions (the parse profile's `fileExtensions`,
   already `{md}`).
4. **Recursion, made clear.** Recursive is the default and the copy says so — "**SWE/** and everything
   inside it" — never bare jargon. A **non-recursive** variant (single-level) is a later option (a `SWE/*`
   glob or an explicit toggle), not day one.
5. **Two ways in, one lens.** A **folder picker** (for everyone) writes a `directory:` / `folder:` lens; the
   **raw query is editable** (power users). It round-trips through `renderLens` ↔ `parseLens`. `directory:`
   is a friendly **alias** for the existing `folder:` / `path:` operators.
6. **Exclusions, layered.** Folder/tag excludes already work (`-folder:drafts`, `!tags:x`, `Not`).
   Extension filtering is **already** the parse profile (`fileExtensions`) — not rebuilt. The one genuinely
   new capability is **glob/pattern** excludes (skip `.txt`, skip dotfiles `.*`, "only files matching …") —
   a gitignore-style `Glob`/`Matches` leaf + a default dotfile skip. Surfaced as a jargon-free "exclude"
   affordance with the live included/excluded count.

**Byte-identical for the shipped SWE vault** is the invariant to hold: the default deck's lens is
`Everything`; over the SWE vault, with the structural floor + existing excludes, that must reproduce exactly
today's card set (every shipped card has an H1 + sections; non-cards are the config dir / excluded). Proven
by the suite; if any stray note over-indexes, narrow the default lens (to the type-union or a directory) or
tighten the floor — never by re-introducing a `type:` requirement.

## Alternatives considered

- **Per-flow folder/tag config** (each flow declares its card-bearing folder — the earlier proposal in this
  thread). Rejected: it creates **two directory knobs** (a flow selector *and* a deck lens), which for a
  simple vault point at the same folder and confuse. The lens is already the grouping; don't add a second.
- **Permissive card-ness with no deck bound** (every well-formed note is a card, decks just filter for
  study). Rejected: it **over-indexes** `card_cache` / Browse / readiness denominators with un-decked notes.
  Binding card-ness to the lens union keeps the "what's a card" count honest.
- **Keep card-ness at the flow-selector layer** (this session's state). Insufficient: it still needs a
  per-flow folder config to escape `type:`, and it doesn't match "the lens is the one grouping knob."
- **Content/structure heuristics as the sole gate** (a note is a card if it "looks like" one). Rejected as
  the *primary* gate (too magical, over-indexes) — kept only as the **floor** beneath the explicit lens.

## Consequences

- **Positive:** the zero-frontmatter vault fully works ("point at a directory → cards"); **one** grouping
  mental model (the lens), matching `deck_creation.md`; directories, booleans, and folder/tag excludes come
  for free from the existing language; `type:`/`id:` are pure opt-in overrides.
- **Negative / trade-offs:** the exclusion + structural floor is now **load-bearing** (a mixed folder needs
  excludes); the **indexer must load deck lenses** to gate card-ness (bootstrap: parse candidates → filter
  by the lens union — no circularity, lenses are pure queries; a fresh vault always has the default deck, so
  card-ness is never empty by construction); the byte-identical-for-SWE proof must be kept green.
- **Follow-ups (build order):** (1) `directory:` alias + recursion copy/tests; (2) **card-ness = lens union**
  in the indexer + re-layer `card_parser` to flow-resolution-only (the core; keep SWE byte-identical);
  (3) glob/dotfile exclude leaf; (4) folder-picker UI + live count (overlaps **#82** picker, **#162**
  template↔flow wiring, the folder-path onboarding thread).

## Open questions

- Non-recursive UX: a single-level `SWE/*` glob vs an explicit "include subfolders" toggle — decide when the
  picker is built.
- Interaction with **multi-subject** vaults: card-ness = union across *all* decks, but a card's *template*
  is still `registry.templateIdForPath` — confirm a card in two decks with different templates resolves its
  flow sensibly (likely: template is path-derived, independent of which deck matched).
- Whether an un-decked but well-formed note should be *invisible* (not a card) or a *candidate* surfaced in
  Browse with "add to a deck?" (leans invisible, per the over-index argument — revisit with Browse).

## Validation

- Indexer test: a zero-frontmatter note under a deck whose lens is `directory:X` indexes as a card; the same
  note with no deck matching it does **not**; a README/MOC (no H1 or no sections) is skipped as malformed,
  not indexed.
- Byte-identical test: over the SWE fixture vault, the card set + counts are unchanged vs the `type:`-gated
  baseline (the existing parser/indexer suites stay green with no fixture edits beyond intent).
