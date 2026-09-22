# Browse

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.

**Purpose.** Browse the cards in the current deck (query lens) — search, filter, open a card,
spot broken links.
**Scope.** Deck level (whole-vault browse is an open scope question — below).
**Personas.** All.
**Reached from.** The app bar (per-deck). Possibly deck creation (if whole-vault browse exists).

## What it does
- **Filter / search** — by title, contents, tags, coverage (studied / not). [MVP: title +
  tag + coverage]
- **Author a card** from here — a "+" that enters the shared authoring flow. [MVP-light]
- **Surface broken links** — cards that need authoring, or links to fix/delete — e.g. an
  include-stubs filter; tapping a stub opens the authoring flow. [MVP-ish; overlaps `#20`]

## Open questions → recommendations
- **Deck-only vs whole-vault browse** (the second-brain tension).
  **Rec.** Agree with your instinct — **don't add a general whole-vault Browse** (it drifts toward
  second-brain). The one justified use — authoring/refining a lens — gets a **scoped card-explorer
  inside [deck creation](deck_creation.md)**, with live "N included / M excluded" counts, *not* a
  Browse mode. Browse stays **deck-scoped**; I couldn't find a stronger reason to widen it.
  **Status.** Accepted (Browse deck-scoped; whole-vault card-explorer lives in deck creation only).
- **How advanced should search be — is `tags:foo tier:2` too much?**
  **Rec.** MVP = simple filters (title / tag / coverage). A small **query mini-language**
  (`tags:` / `tier:` / `!`) is powerful *and* is literally the deck-lens language — so design
  **one query API** shared by Browse filters and lens creation, and expose the advanced form as
  a power option, not the default.
  **Status.** Accepted
- **Does the filter API overlap deck authoring?**
  **Rec.** Yes — same engine. A saved Browse query *is* a candidate deck lens; wiring them
  together lets "browse → save this filter as a deck" fall out for free.
  **Status.** Accepted

## Cross-refs
[deck_creation](deck_creation.md) (shared query API) · [card](card.md) (stubs) · older:
`#18`/`#19` (search/filters), `#20` (unresolved links).
