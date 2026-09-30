# ADR 0023 — Card-ness = deck-lens membership (the lens is the one grouping knob)

- **Status:** Accepted — §Decision 1 (a card's template is path-derived via `templateIdForPath`) and the
  "Template tie-break" open question are **superseded by ADR-0025** (a deck owns its config; the path-derived
  template layer dissolves). The rest stands.
- **Date:** 2026-09-29
- **Deciders:** Kyle Uehlein (+ AI-assisted; a deep-research pass over Anki, Mochi, RemNote, Logseq,
  org-drill, the Obsidian SR-plugin ecosystem, SSGs (Jekyll/Hugo), ignore-file tooling (git/ripgrep/npm),
  and smart-collection UX (Apple/OmniFocus/Finder/Notion/Dataview) — 17 agents, 15 primary sources,
  decision-changing claims adversarially verified). The research **confirmed the core is mainstream prior
  art, not a novel bet**, and sharpened the exclusion/glob details below.
- **Related:** Completes the **zero-frontmatter vault** realization begun in **ADR-0022** (`id:` optional)
  and this session's card-ness-via-flow-selector change (`card_parser.dart`), which this ADR **re-layers**.
  Builds on **ADR-0013** (the one query language; structural vs dynamic leaves) and **ADR-0020 §2** (flow
  membership via selector; default flow = flashcard). Realizes the [`deck_creation`](../user_stories/deck_creation.md)
  user story ("a deck = a query lens; simple = a directory"). Code: `lib/core/vault/vault_indexer.dart`,
  `lib/core/vault/card_parser.dart`, `lib/core/vault/desktop_vault_source.dart`, `lib/core/vault/vault_source.dart`,
  `lib/core/deck/deck.dart`, `lib/core/search/card_filter.dart`, `lib/core/query/card_query.dart`.

## Context

A **deck is already a query lens** — `Deck.membership` is a `CardQuery` (default `Everything`), and
`Deck.cardsFrom(cards)` selects a deck's members by matching it. The lens mini-language (`parseLens` /
`renderLens`) already supports **directories** (`korean/`, `folder:SWE` — recursive via `FolderUnder`'s
prefix match), **tags**, **boolean logic** (`&&`/`OR`/`()`/negation), and **folder/tag exclusion**
(`-folder:drafts`). `deck_creation.md` documents exactly this: "Add a new query lens to the vault … Name
the lens directly — `korean/`, `tags:korean && !tags:hangul`," with a live "N included / M excluded" count.

**This is a well-established model, not a bet.** A saved query that *defines* a live membership, with static
assignment only as a fallback, is exactly Anki's *filtered decks* (the "home deck" is the static fallback);
Mochi calls a saved lens over a deck a "custom view"; macOS Smart Folders, smart playlists, and OmniFocus
perspectives are all saved-query membership. In every one, **per-item state lives on the item and membership
is a derived view** — which is precisely Onyx's "the vault file owns state; deck membership is a view; the DB
is a cache" premise. Anki's own manual even *discourages* deck-per-topic ("a single card can only belong to
one deck, which makes tags a more powerful and flexible categorization system than decks in most cases") and
warns large deck trees "can actually break the display" — the deck-proliferation failure mode this ADR's
single-lens knob avoids.

**The gap.** The lens groups *cards*, but **card-ness** — which *files* become cards at all — is decided a
layer *below* the lens. It was `type:`; this session it moved to the subject's **flow selectors** (a file is
a card iff some flow's selector matches). So a deck lens of `korean/` over a folder of **frontmatter-less**
notes returns **empty** — the files never become cards, because no flow's `TypeIs` selector matches a note
with no `type:`. That defeats the zero-frontmatter vault: "point at a directory → those are my cards" can't
work while card-ness is gated one layer beneath the grouping the user actually sets.

The user's expectation (correct, and industry-standard): **the query lens is the single grouping knob** — a
simple lens picks a directory and every file in it is a card; advanced lenses use tags + boolean logic. There
should not be a *second*, separate "which files are cards" configuration beneath it.

## Decision

**Card-ness = matched by some deck's membership lens.** A file is a card iff, once parsed into a candidate,
it is matched by the **union of all decks' lenses** in the vault. The lens is the one user-facing grouping
knob; card-ness and deck membership are the same act.

1. **The lens is the grouping — and it decides card-ness.** Simple lens = a **directory** (`korean/` /
   `directory:SWE`), **recursive by default** (existing `FolderUnder` semantics). Advanced lenses layer
   tags + boolean logic + exclusions — all already in the language. There is *no* separate card-ness config.
   **Membership is non-exclusive:** a card matched by two decks' lenses belongs to *both* (decks are views,
   not Anki's one-home-deck rule; OSR likewise lets one card sit in multiple decks). A card's **template** is
   `registry.templateIdForPath` — **path-derived, independent of which deck matched** — so flow resolution is
   deck-independent even when a file is in several decks.
2. **Flow is an automatic template sub-layer, not a grouping knob.** For a card, its flow is the first
   matching flow selector in its template, else the **default flashcard flow** (ADR-0020 §2). A plain vault
   → one flow, everything is a flashcard. SWE → the flow selectors sub-classify (algorithms → drill, etc.).
   This **re-layers** this session's change: the flow selectors stay, but only to resolve *how* a card is
   practiced — no longer *whether* it is one. `card_parser` becomes permissive (any well-formed note is a
   *candidate*); the **indexer** applies the lens-union card-ness gate.
3. **No mandatory structure — the H1 requirement is gone (finalized 2026-09-29).** A candidate parses into a
   card with **no imposed shape**: the title falls back to the **filename** when there's no H1 (Obsidian's
   convention — the filename *is* the note name), sections split per the parse profile, and a body-only note is
   a valid (0-section) card. *The user shapes what a card is via the parse profile + lens; the engine imposes
   nothing.* The only **not-a-card** outcomes are: **broken frontmatter** — a `---` block that's unparseable or
   not a key/value map → `MalformedCardException`, surfaced as a fix-this vault-health signal (this is what
   `malformed` means now — **repurposed** from the interim "missing H1", which silently vanished otherwise); a
   subject that declares **no flows** (null); or the default excludes below. Card-ness stays **parse-time /
   structural, never runtime-computed** — no `StateIs`-style leaf in a card-ness lens (that would make cards
   blink in/out mid-session, the documented smart-playlist frustration). Default excludes: the config dir
   (`_onyx/`, `kConfigDir`, + legacy `_meta/`), folder-syncer conflict copies (`isConflictCopy`), and
   non-configured file extensions (`ParseProfile.fileExtensions`, `{md}`).
   *(Interim note: 2b briefly used an H1-as-floor with "malformed only if a selector claimed it"; dropping the
   H1 entirely — the actual goal — replaced it. The over-inclusion it guarded against is now the excludes'
   job.) Candidate default exclude (open):* a **folder note** (file name == parent-folder name — the index/MOC
   pattern) is a known folder-selection over-index vector (Yanki excludes exactly these); see open questions.
4. **Recursion, made clear.** Recursive is the default (universal across ripgrep/Hugo/gitignore/Smart
   Folders) and the copy says so — "**SWE/** and everything inside it" — never bare jargon. This copy is
   **confusion-prevention, not decoration**: recursive-by-default demonstrably surprises even technical users
   who read "this folder" as direct-children-only (repeated Obsidian `path:`/Dataview/Bases forum threads). A
   **non-recursive** single-level variant is a **new leaf** (a `SWE/*` glob, or an exact-parent match à la
   Dataview `WHERE file.folder = 'X'`) — `FolderUnder` is prefix-match/recursive-only today, so this is a
   small declarative addition, not a free tweak; decide the primitive when the picker is built.
5. **Two ways in, one lens.** A **folder picker** (for everyone) writes a `directory:` / `folder:` lens; the
   **raw query is editable** (power users) — the two-tier split the research confirms (non-technical users
   ask for pickers/toggles; developers ask for glob/ignore-file syntax; no one asks non-technical users to
   write globs). It round-trips through `renderLens` ↔ `parseLens`. `directory:` is a friendly **alias** for
   the existing `folder:` / `path:` operators (**shipped**). For the advanced boolean path: surface the
   top-level combinator as a **labeled sentence — "Match all / any / none"**, not raw `&&`/`OR`/`()`, and
   allow **nested rule groups** (OmniFocus/Finder pattern; Apple Photos' flat AND-only ceiling is a
   documented frustration). The **live "N included / M excluded" count is load-bearing** (prevents
   zero-result dead-ends; filter engagement drops when the count is removed), not ornamental.
6. **Exclusions, layered — with the glob details pinned.** Folder/tag *lens* excludes already work
   (`-folder:drafts`, `!tags:x`, `Not`) and **stay post-parse `CardQuery` predicates** (they need parsed card
   attributes). Extension filtering is **already** the parse profile (`fileExtensions`) — not rebuilt. The one
   genuinely new capability is **path-shaped glob excludes** (skip `.txt`, skip dotfiles `.*`, a `dir/`
   exclude):
   - **Evaluate pre-parse, during the walk** — in `VaultSource.listCardPaths` alongside the existing
     dotfile-segment skip (`desktop_vault_source.dart`) and `isConflictCopy`, **not** as a post-parse
     `CardQuery.matches` (which would force parsing every excluded file first; best practice is to filter
     *during* directory descent — ripgrep/globby/glob-gitignore all do).
   - **Pin the capability tier explicitly** (the ecosystem has *not* converged; "gitignore-compatible" tools
     silently drop features): support **literal, `*`, `**`, `?`, leading-`/` anchor, trailing-`/`
     directory-only, and `!` negation — NO POSIX bracket ranges `[a-z]`**. Anything beyond the tier is out of
     scope and must not fail silently-but-differently. Precedence is **last-match-wins** (the gitignore-family
     norm).
   - **User excludes are additive to system defaults**, never a replacement — they *extend* the built-in
     dotfile / config-dir / conflict-copy skips; there is no way to re-enable slurping those via the exclude
     field (avoids npm's `.npmignore`-supersedes-`.gitignore` footgun; matches Jekyll-4 / ESLint additive
     behavior).
   - **If `!` re-includes ship**, an excluded directory must be spelled `dir/*` (exclude its entries), **not**
     bare `dir/` or `dir` (which prunes the directory node so no child `!` can fire — git: "cannot re-include a
     file if a parent directory is excluded"); and *not* `dir/**` (the recursive form that itself breaks
     several implementations). **Validate the chosen glob library against this parent-prune/negation edge**
     before shipping — it is broadly mis-implemented.
7. **Config AND AI skills live in the config dir, never the content area (shipped 2026-09-29).** Everything
   Onyx-managed — deck lens/aims JSON, parse profile, and **AI-skill files** (a flow's interlocutor/grader
   prompt; the coach augmentation) — lives under `_onyx/` (per-deck `_onyx/decks/<id>/`, flat for now), read
   via `readMeta`, and **excluded from the card index** (extends ADR-0019's config/content split). *A skill is
   config, not a card* — you never study it — so it must not sit in the content area, where the permissive
   parser would turn it into a card (exactly the bug the H1-drop exposed: `loadFlowSkill` moved from `readCard`
   → `readMeta`, and the korean fixture's skill moved into `_onyx/`). This makes a **flat content folder just
   work** (`cs/*.md` = cards; `cs/_onyx/…` = config+skills), keeps skills **editable + shareable** (they travel
   with the deck on push, ADR-0021), and unifies with `coach.md`. **Arbitrary source locations are import
   sources only:** a chosen skill (our library, file-picker, AI-authored, upstream bundle) is **copied/written
   into the deck's config dir** (canonical) — mirroring ADR-0022's local-vs-share identity philosophy (embed at
   share). A bring-your-own skill left inline is a fallback (the flow config *names* its path → declared-skill
   exclusion), but the app steers everything into `_onyx/`.

**Byte-identical for the shipped SWE vault** is the invariant to hold: the default deck's lens is
`Everything`; over the SWE vault (flat content + config in `_onyx/`/`_meta/`), that reproduces exactly today's
card set (every shipped card has a `type:` and an H1; config/skills are in the config dir). Proven by the
suite (1277 green); if any stray note over-indexes, narrow the default lens (to a directory / the type-union)
or add an exclude — never by re-introducing a `type:` or H1 requirement.

## Alternatives considered

- **Opt-in per-file flag** (`publish: true`, or a `#flashcards` tag, as the card-ness gate) — the road *most*
  Obsidian tools took (digital-garden's `dg-publish: true` is the clean example). Rejected: it **reintroduces
  a per-file card-ness gate beneath the lens** — the exact second knob decision 1 removes — and defeats the
  zero-frontmatter goal. (Two research corrections worth recording: Obsidian *Publish* is **not** strict
  opt-in — it also publishes via included-folder filters with no frontmatter; and OSR is **not** a pure-tag
  counterexample — it has a **folder mode**, so it *corroborates* directory-as-membership.)
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
- **Blacklist ("everything is a card except …")** instead of whitelist-first (lens = inclusion) + floor +
  subtract-exclusions. Rejected: a blacklist must enumerate all non-card content indefinitely; the
  whitelist-first + subtract shape is the industry-validated one (ObsidianHtml, Hugo mounts, npm `files`).

## Consequences

- **Positive:** the zero-frontmatter vault fully works ("point at a directory → cards"); **one** grouping
  mental model (the lens), matching `deck_creation.md` and mainstream prior art; directories, booleans, and
  folder/tag excludes come for free from the existing language; `type:`/`id:` are pure opt-in overrides.
- **Negative / trade-offs:**
  - The exclusion + structural floor is now **load-bearing** (a mixed folder needs excludes). Onyx's floor is
    **more permissive than SSG prior art** — Jekyll/Hugo gate on *front-matter presence* (no front matter →
    not content), which hands the problem to the user; Onyx deliberately does *not* require frontmatter, so
    its risk is **over-inclusion** (a stray README with an H1 could pass the floor), the *opposite* of the
    SSGs' under-inclusion. This is why byte-identical-for-SWE + the "narrow the lens or tighten the floor,
    never re-add `type:`" escape valve matter.
  - The **indexer must load deck lenses** to gate card-ness (bootstrap: parse candidates → filter by the lens
    union — no circularity, lenses are pure queries; a fresh vault always has the default deck, so card-ness
    is never empty by construction). The byte-identical-for-SWE proof must be kept green.
- **Follow-ups (build order):** (1) `directory:` alias — **shipped**; (2) **card-ness = lens union** +
  permissive parser — **shipped** (2a indexer lens gate + `IndexResult.unlensed`; 2b `card_parser` resolves
  only the flow via `DeckTemplate.defaultFlow`); (2c) **H1 optional + skills-as-config** — **shipped**
  (title → filename fallback; `malformed` = broken frontmatter; `loadFlowSkill` via `readMeta` from `_onyx/`;
  decision 7). **The zero-frontmatter vault works end-to-end**: a plain Markdown note in a lens-covered folder
  is a card — no `type:`, no H1, no frontmatter. SWE byte-identical, 1277 green. Remaining: (3) glob/dotfile
  exclude leaf (pre-parse, tier-pinned, additive); (4) the **authoring/deck-creation UX** — baseline lens +
  optional per-deck flow enrichment + skill sourcing (**#162**; folded into `deck_creation.md`), which subsumes
  the folder-picker + labeled combinator + live count (overlaps **#82**, onboarding). The engine is complete;
  what's left is UX.
- **Forward-guidance (not day-one): incremental re-index.** The indexer currently **deletes + rebuilds**
  `card_cache`/`card_links` wholesale each reindex (`vault_indexer.dart`). Fine at Onyx's file-per-card,
  hundreds-of-cards scale, but the thing to evolve toward as vaults grow (esp. mobile) is Dataview's model:
  **event-driven, per-file, mtime-keyed incremental re-parse behind a monotonic revision counter** (Dataview
  degrades ~4–6k notes and is unusable ~9.8k on mobile when a *full* re-parse fires; Hugo's rebuild-every-time
  is viable only with in-RAM parallelism — the wrong model for a mobile vault walker). Tracked, not required
  here.

## Open questions

- **Multi-match denominators.** Membership is non-exclusive (a card in N decks). Confirmed intended — but
  Browse/readiness must **dedupe a card counted once** across decks ("how many cards" ≠ "how many deck
  memberships"). Write the dedupe rule down.
- **Template tie-break.** A card in two decks with **different templates**: template is strictly path-derived
  (`registry.templateIdForPath`, deck-independent) — confirm that's the final rule even when that path's
  template lacks a flow the *other* deck's users expect, and record the tie-break.
- **Glob tier + `!` in v1.** Which exact subset ships, and does v1 support `!` re-includes at all? If yes, the
  `dir/*` parent-prune rule + library-validation gate become mandatory; if no, they defer. Decide now to size
  the glob work.
- **Non-recursive primitive.** `SWE/*` glob vs an exact-parent match leaf (Dataview `file.folder ==`) vs an
  "include subfolders" toggle — `FolderUnder` is prefix-only today, so a new leaf is required either way.
- **Folder-note default exclude.** Make "file name == parent-folder name" a default exclude, an optional
  toggle, or leave it to the floor? Depends on whether index/MOC notes reliably carry an H1 (which would slip
  past the floor).
- **Un-decked well-formed notes.** *Invisible* (not a card) or a *candidate* surfaced in Browse with "add to
  a deck?" (leans invisible, per the over-index argument — revisit with Browse).
- **Incremental-reindex threshold.** At what vault size does wholesale delete+rebuild need to become
  incremental — a tracked follow-up, or explicitly out of scope for this ADR?

## Validation

- Indexer/parser tests (**shipped**): a zero-frontmatter note under a deck whose lens is `directory:X` indexes
  as a card; the same note with no deck matching it does **not** (`unlensed`); a no-H1 note gets a **filename
  title** (not skipped, not malformed); **broken frontmatter** (unparseable / non-map YAML) → `malformed`; a
  flow-skill file in `_onyx/` never enters the card set.
- Byte-identical test (**shipped, 1277 green**): over the SWE fixture vault, the card set + counts are unchanged
  vs the `type:`-gated baseline.
- Exclude test (deferred with the glob leaf, slice 3): a `.`-prefixed / excluded-glob stray file under a card
  folder is dropped **and the card count is unchanged** — a *negative* fixture, not only the positive baseline.

## References (primary sources from the research pass)

- [Anki — filtered decks](https://docs.ankiweb.net/filtered-decks.html) · [Anki — decks vs tags](https://docs.ankiweb.net/editing.html):
  saved-query membership + state-on-item; deck-proliferation is a documented failure mode.
- [Obsidian SR — decks (tag *and* folder mode)](https://stephenmwangi.com/obsidian-spaced-repetition/flashcards/decks/) ·
  [Mochi — custom views](https://mochi.cards/docs/decks/custom-views/) ·
  [RemNote — practicing specific flashcards](https://help.remnote.com/en/articles/6904503-practicing-specific-flashcards) ·
  [org-drill](https://orgmode.org/worg/org-contrib/org-drill.html): inline-marker card-ness beneath a folder/tag scope.
- [git — gitignore](https://git-scm.com/docs/gitignore) · [ripgrep GUIDE](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md) ·
  [glob-gitignore](https://www.npmjs.com/package/glob-gitignore) · [ignore-file survey](https://nesbitt.io/2026/02/12/the-many-flavors-of-ignore-files.html):
  recursive-by-default, dotfile skip, filter-during-descent, last-match-wins, parent-prune/negation edge, no glob-tier convergence.
- [Jekyll front matter](https://jekyllrb.com/docs/front-matter/) · [ObsidianHtml — filtering](https://obsidian-html.github.io/configurations/modes/filtering-notes.html):
  SSG front-matter-presence gate (the lighter gate Onyx departs from); whitelist-first + subtract-exclusions shape.
- [GeodeMd PR #32](https://github.com/T1Fleming/GeodeMd/pull/32): conflict-copy exclude + asymmetric-risk rationale + report-the-drop (matches Onyx's `isConflictCopy`).
- [Dataview index](https://github.com/blacksmithgu/obsidian-dataview/blob/master/src/data-index/index.ts): mtime-keyed incremental re-index blueprint.
- [Yanki — folder-note exclusion](https://github.com/kitschpatrol/yanki-obsidian) · [Filtering UX — live counts](https://smart-interface-design-patterns.com/articles/filtering-ux/) ·
  [Apple — smart playlists (labeled any/all)](https://support.apple.com/guide/itunes/create-delete-and-use-smart-playlists-itns3001/windows): folder-note over-index; live-count + labeled-combinator UX.
