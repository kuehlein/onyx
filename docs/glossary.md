# Onyx — glossary (canonical terms ↔ code)

The one place the vocabulary is pinned, so the concepts stay tight and don't drift
apart from the code again. The **model** itself lives in
[`user_stories/index.md`](user_stories/index.md); the **invariants** in
[`architecture.md`](architecture.md). This is the term → code-identifier → user-copy map.

## Core model

| Term | What it is | Code | User-facing copy |
|---|---|---|---|
| **Vault** | The plain folder of markdown you own; the single source of truth. Content in user-land, config in an untouchable `_meta/`. | `VaultSource`, `vaultIndex` | "study folder" / "folder" |
| **Deck** | **A query lens over the vault** — a saved folder path or tag expression selecting a card subset. The primary unit you work in. Decks may overlap. | `Deck` (+ `MembershipQuery`), `core/deck/` | **"deck"** |
| **Aim** | One of a **set** of things a deck points at — a dated assessment or open-ended mastery. Carries 4 knobs: difficulty, domain emphasis, durability bar, date-or-open. Readiness = weakest-link across active aims. | `Aim` (list on `Deck.aims`) | the deck's `Vocabulary.assessmentNoun` — **"interview"** (SWE), **"exam"/"test"/"target"** (others) |
| **DeckTemplate** | The per-directory **template** a deck is configured by (flows, parse rules, vocabulary, target dimensions). Lives in `_meta`; shared by many decks. Formerly "Subject". | `DeckTemplate`, `TemplateRegistry`, `core/template/` | (rarely surfaced) "template" |
| **Flow** | A study/practice mode, described as data and keyed to a card `type:`. Scheduling = recall / two-clock / mock. | `FlowSpec` | "Flashcard" / "Algorithm" / "System design" / … |
| **Card** | One parsed `.md` file. `type:` names its flow; behavior comes from the flow config, never an `if/else` on type. | `Card`, `CardSection` | "card" |

## Don't confuse these

- **Deck (lens) vs `Card.deckId`.** `Deck` is your study lens (was `StudyGoal`). `Card.deckId`
  is a *different* concept — the **registry import bundle** a card was pulled from (ADR-0003,
  reserved for the permissioned deck registry). Two "deck" meanings today; the Phase-5 registry
  work disambiguates. They never join in current logic.
- **Aim vs Deck.** A deck is the lens (the cards); an aim is a thing you point it at. A deck holds
  a *set* of aims (e.g. a music deck: a composition test + an improv jury + open-ended fluency).
- **DeckTemplate vs Deck.** The template is shared config (per vault subtree); the deck is your
  per-objective query + aims. N decks → 1 template.
- **"target" — being retired from user-facing copy (overloaded).** Three unrelated uses: (1) the
  **readiness target** = an aim's knobs; (2) the **daily-minutes target** (a study-time budget);
  (3) a **wiki-link target**. **Decision (2026-09-22):** user-facing copy drops bare "target" →
  **"aim"** for the concept, or the deck's `Vocabulary` assessment noun (*interview* / *exam* / *test*)
  for a dated aim (lands in S5; supersedes R4's interim "target" wording). Code: the `target*`
  *providers* de-"target" during S5's writer-flip; the **type `ReadinessTarget`** stays (internally
  precise — "what readiness scores against"; optional later rename to `AimTarget`). The daily-minutes
  "target" gets a disambiguating rename (low priority); the wiki-link "target" stays (unambiguous).
- **`goalLabel` / `goalLevel` / `goalFraction`** (readiness-ladder identifiers) mean *the aim you're
  pointing at*, **not** the deck — they resolve to *aim* vocabulary during the S-phase readiness
  rework, not to "deck".
- **Card `type:` vs Flow.** The frontmatter `type:` string is just the flow id; all behavior is
  `FlowSpec` config. Enforced by the `no_card_type_branch` lint (invariant #2).

## Code renamed, on-disk kept (vault back-compat)

The 2026-09 reframe renamed code to this vocabulary but **deliberately kept on-disk names** so
existing vaults keep working: the config file `onyx-subject.yaml`, the state file
`study-goals.json` (+ its `interviews` key), the legacy `onyx-target.json` / `onyx-goals.json`
(migration input), the `ReadinessTarget` JSON keys `level`/`company`/`track`, and the built-in
template ids `software-interviews` / `general`.
