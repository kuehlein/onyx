# Deck creation

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.

**Purpose.** Add a new query lens to the vault — over cards that already exist, or over cards
created as part of the flow.
**Scope.** Vault → a new deck.
**Personas.** P4 (knows the lens); P2/P3 (create cards); P1/P5/P6 (pull/publish).
**Reached from.** Deck selection; onboarding; possibly Browse (contingent on scope).
**MVP.** Known-lens over existing cards · AI-conversation card creation · pull-from-upstream.
**Non-MVP:** card-picking UI, PDF/file extraction, camera capture.

## What it does
**Use existing cards** (the file tree may already hold them — a lens is all that's added):
- **Name the lens directly** — `korean/`, `tags:korean && !tags:hangul`. [MVP]
- **Pick cards** (browse-select) — [non-MVP]. **Rec:** card-by-card picking is fiddly and few
  will want it. Instead **suggest lenses from commonalities**: all under `foo/` → "make a deck
  of `foo/`?"; shared `tag:CS` → "a deck around `tag:CS`?"; surface related tags (via the card
  graph) to add/exclude. A live **"N cards included / M excluded"** count as the query is
  refined is good, cheap UX; a full card-level diff is overkill.

**Create new cards:**
- **AI conversation** about scope / content / source. [MVP] — driven by a research-grounded
  authoring skill (already drafted in `examples/vault/_meta/authoring-method.md`).
- **Upload a complete file tree** (a ready-made group of cards). [MVP-ish]
- **Upload files / PDFs** to convert into cards. [later]
- **Camera capture** (e.g. a textbook page) → cards. [later — hardest: OCR + page ordering +
  region selection].

**Pull from upstream** — import a shared deck (a file tree) into the vault. [depends on the
registry / cloud track]

## Open questions → recommendations
- **Which authoring approaches; are the hard ones low value (camera)?**
  **Rec.** MVP = **known-lens + AI-conversation + upload-tree + pull**. Defer PDF and camera
  (high effort, niche); revisit only if an off-the-shelf package makes them cheap.
  **Status.** Accepted
- **What goes into the AI skill(s)?**
  **Rec.** A research-grounded authoring skill: retrieval practice, spacing, desirable
  difficulty, the minimum-information principle, FSRS-aware card shape, the parse contract, plus
  the deck's domain profile. This exists (`examples/vault/_meta/authoring-method.md`); the flow
  should load + apply it rather than reinvent it.
  **Status.** Accepted. On your note — yes, we need more: an AI-led **scoping conversation** up
  front (subject, target aims/level, curriculum outline, depth) encoded into the deck's
  skill/config, grounded by a deep-research pass on curriculum + scope design. Tracked as a
  roadmap research task.
- **The in-app editor gap** ("I want to steer clear of an authoring tool but not leave a weird
  hole").
  **Rec.** Keep a **light** editor (title / body / tags / live preview) plus AI-chat card
  creation — enough to fix a typo or draft a card, not a studio (stays orthogonal to a second
  brain). Standardize **one** card-authoring entry API reused by onboarding, Browse, and deck
  creation, so the surfaces don't drift.
  **Status.** Accepted

## View accessed from
Deck selection · onboarding · Browse (only if we adopt a whole-vault Browse — see
[browse](browse.md)) · a first-deck shortcut from onboarding when there's no deck-selection page
yet (single-deck case).

## Cross-refs
[deck_selection](deck_selection.md) · [card](card.md) (authoring mode) · [browse](browse.md) ·
older: `content-creation.md`, `registry-and-sync.md` (pull), `#46`/`#63` (authoring kit).
