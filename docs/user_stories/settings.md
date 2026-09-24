# Settings

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.

**Purpose.** Configure the app and each deck.
**Scope.** A split: **vault/app-level** vs **deck-level** (this is the recurring tension — see
below).
**Personas.** All.
**Reached from.** The app bar.

## What it does
- **App / vault-level settings:** account (email, password, payment, phone — all optional, only
  for sync/paid tiers), AI provider + keys/tier, backup/restore, theme + font size, the **daily
  study budget** (the shared day across decks), **gym mode** (a between-sets rest timer, orthogonal
  to decks), dev tools (dev clock, wipe vault, test connection). [MVP: keys, backup, theme, budget,
  dev]
- **Deck-level config:** parsing rules, aim defaults, the deck's **proportion** of the daily budget
  (its share of the day), and any **flow-declared knobs** (config-driven — shown only for the flows
  a deck runs). **Workload is NOT hand-tuned:** the engine derives the study mix from the budget +
  aims + FSRS + urgency; the old manual new-sections/day + algo min/max knobs are removed
  ([ADR-0010](../adr/0010-workload-budget-and-proportions.md)).
- **Parsing preferences** — accommodate how users structure files: `##` = a card, maybe `###`
  too, `---` as a separator, ignore `//` lines, render ```` ``` ```` blocks specially. [MVP:
  read-only explainer + a small preset picker; fully custom markers = later, `#84`]

## Open questions → recommendations
- **Split whole-vault settings from current-deck settings?**
  **Rec.** **Yes.** Vault/app settings (account, AI, backup, theme, dev, the **daily budget**, gym)
  live at the **vault level** (from deck selection); deck config (parsing, aim defaults, the deck's
  **proportion**, flow-declared knobs) lives **inside the deck** (from its Home). This split is also
  the answer to the app-bar unease below.
  **Status.** Accepted. On your note — the deck-config header reads **"This deck only"** with a
  **"Vault settings →"** link. **Workload is engine-derived, not a per-deck knob**
  ([ADR-0010](../adr/0010-workload-budget-and-proportions.md), superseding the earlier "pace/load per
  deck" framing): the user sets the vault daily budget + each deck's proportion; the daily plan
  derives the mix.
- **Should parsing be per-vault or per-deck? On the settings page or the deck's home?**
  **Rec.** **Per-deck with a vault default** (a deck may be a different domain that parses
  differently). Edit it from the deck (a "how cards are read" entry), not a global page.
  **Status.** Accepted. On your note — the parsing config gets a **"Set as default for all decks"**
  action (writes the vault default); low-cost, good UX.
- **App-bar placement feels off — why?**
  **Rec.** Because Settings is two things at two scopes. It feels wrong to pin one "Settings"
  when half of it is vault-wide and half is deck-specific. Resolve by **scope, not placement**:
  vault-Settings at the vault level, deck-config inside the deck. Then whether a top-level tab
  is right becomes clear per scope (the generic "never burn a tab on settings" advice doesn't
  cleanly apply to a config+data-stewardship app — see `settings-ux.md §1`).
  **Status.** Accepted
- **Trim / add / broken settings?**
  **Rec.** Decide trims *after* the vault/deck split. Known bug to verify: the **dev clock**
  reportedly isn't advancing correctly — check when we resume.
  **Status.** Accepted

## Cross-refs
[deck_selection](deck_selection.md) (vault-level home) · [home](home.md) (deck config) ·
[card](card.md) (parsing → sections) · [ADR-0010](../adr/0010-workload-budget-and-proportions.md)
(workload = budget + proportions, engine-derived mix) · older: `settings-ux.md`, `#66`/`#84`
(parsing), `#85` (settings IA), `#67`.
