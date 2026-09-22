# Home

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.
> (Name: "Home" is fine; "Today" is a good alternative since it's the today-queue — see below.)

**Purpose.** The top-level view for a single deck — today's study, the deck's aims, progress,
readiness, and the coach.
**Scope.** Deck level.
**Personas.** All (per-deck).
**Reached from.** Deck selection (or straight here as the app landing when there's only one
deck).
**MVP.** Today's assignments + progress + aims summary + coach. Readiness report (AI): partial.

## What it does
- **Today's study assignments** — the daily plan for *this* deck, allocated across its active
  aims: [MVP]
  - learn / review (the foundational cards),
  - re-solve / **redirect** flows (e.g. algorithms; music "go take this listening test"),
  - **conversational** flows (e.g. system design, a language conversation).
- **Aims summary** (was "target") — shows the deck's active aims and links to
  [Your Target / Aims](your_target.md). A single aim like "Senior · Backend · FAANG" is the
  common case; a deck may show several. [MVP]
- **Today's progress** — e.g. "53% done · 31 min left." [MVP]
- **Readiness** — the weakest-link roll-up across active aims, with a link to the fuller AI
  **readiness report**. [core MVP: the number; report: partial]
- **AI coach** — one honest, actionable nudge (never a dashboard or guilt). [MVP]

## Open questions → recommendations
- **The "extra study" overflow when all tasks are done — better way? bad to have? still working?**
  **Rec.** Keep an **optional** overflow, framed honestly (more reviews / new cards / a gated
  flow — never a guilt loop). But its current implementation routes to interview-question
  content that **doesn't exist** (empty), so it renders "no material" — decide author-vs-retire
  before relying on it (tracked as #58/#91). For a non-assessment deck, overflow = more
  foundation, not the empty interview path.
  **Status.** Accepted
- **Did recent changes break it?**
  **Rec.** Partially likely — the aim-unification (#68) and the G7 churn moved the target /
  interview surfaces around. When we resume, verify the daily-plan assembly + the overflow
  end-to-end for both an assessment deck and a neutral one.
  **Status.** Accepted
- **Better name than "Home"?**
  **Rec.** Keep **Home** as the per-deck top view. If decks become prominent in the IA, **"Today"**
  reads well(it *is* the today-queue). Low stakes; revisit alongside the deck-selection IA.
  **Rec (resolved).** Your concern is right — "Today" at the deck level can mislead a single-deck
  user. Keep **Home** for the deck view; reserve **"Today"** for a possible **vault-level**
  cross-deck daily view, where it isn't ambiguous.
  **Status.** Accepted (Home = deck view; "Today" reserved for a vault-level view).

## View accessed from
The app bar (per-deck tabs) · deck selection · the app landing (single-deck case).

## Cross-refs
[your_target](your_target.md) · [scheduler](scheduler.md) · [analytics](analytics.md)
(readiness detail) · [card](card.md) · older: `study-cadence-design.md` (daily plan),
`readiness-dashboard.md`, `coach-*`.
