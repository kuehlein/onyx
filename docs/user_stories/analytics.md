# Analytics

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.

**Purpose.** Data-viz + numbers on how study is going — honest, never discouraging or gamified
(see the learning-science + gamification research).
**Scope.** Per-deck and/or whole-vault (open — below).
**Personas.** All.
**Reached from.** The app bar (per-deck).

## What it does
- **Display study data** honestly: retention by domain/tag, coverage, upcoming review load,
  applied performance (per the deck's *declared* flows — not five hardcoded SWE sections),
  consistency (the no-loss "N of last 7 days", never a breakable streak), and the weakest-link
  readiness roll-up. [MVP builds on the existing insights redesign, `#62`]

## Open questions → recommendations
- **A per-deck view? A whole-vault view? Both — and how?**
  **Rec.** **Per-deck is the MVP.** A vault-level view should be a **small summary strip** (one
  compact row per deck), **not a merged aggregate** — averaging readiness across decks/aims is
  dishonest (weakest-link, don't mean). So: rich analytics inside a deck; a light cross-deck
  glance at the vault level (deck selection). Reuse the same section widgets over the chosen
  scope.
  **Status.** Accepted
- **What data is important?**
  **Rec.** Lead with the *critical few* (readiness weakest-link, coverage, retention, review
  load, consistency), progressive-disclose the rest; bars for comparison, a band + verbal
  qualifier for forecasts, exactly one ring (completion). Applied-performance sections render
  only for flows the deck declares. Avoid any framing that reads as failure/guilt.
  **Status.** Accepted

## Cross-refs
[home](home.md) (readiness summary) · [your_target](your_target.md) (aims drive readiness) ·
older: `readiness-dashboard.md`, `dataviz-principles` memory, `#62` (Insights redesign), `#27`
(retention by tag/domain).
