# Scheduler (the dated facet of Aims)

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.
> **Reframe:** the Scheduler is the *dated* view of a deck's aims — I'd fold it into the one
> **Aims** surface ([your_target](your_target.md)) rather than keep it a separate feature.

**Purpose.** Schedule and track dated aims (tests / interviews), and project timelines from
FSRS — when, at the current pace, you'll be ready for each.
**Scope.** Deck level (with a possible vault-level cross-deck calendar — later).
**Personas.** P2 (exams), P4 (interview loops).
**Reached from.** The Aims surface (Your Target). App bar: a candidate, see below.
**MVP.** Add a dated aim + see its ready-by projection. Interview-loop rounds: partial.

## What it does
- **Schedule tests / interviews** — a dated aim. [MVP]
  - An **interview loop** (screen → onsite, follow-ups) is one aim with **ordered rounds**
    (already modelled: `InterviewAim.rounds`). An **exam** maps to a single-round aim.
    **Rec:** generalize "rounds" to **"milestones"** so non-interview domains (a jury, a
    multi-part exam) fit the same shape.
- **Project timelines on a calendar** — from readiness + FSRS, the ready-by date per aim, shown
  as the zone calendar (green = ready at pace, amber = needs faster, red = too soon). [MVP for
  one aim; the existing `_ZoneCalendar` is a strong basis]
- **Track in-progress tests/interviews** — a list with status. [partial]
- **Post-test report** — record how it went; feed that back to adjust the aim. [partial; the
  post-interview debrief exists but is currently unreachable — see bugs]

## Open questions → recommendations
- **Is a calendar the best UI? Multiple aims / decks on it?**
  **Rec.** A calendar is right for **dated** aims (the ready-by zones are genuinely useful).
  For several aims, show **per-aim ready-by markers + a weakest-link overall**. Don't force a
  calendar on **open-ended** aims (no date) — those get a pace/coverage readout instead. A
  cross-deck *vault* calendar is [later, tricky].
  **Status.** Accepted
- **One holistic view with the interview list + target-setting?**
  **Rec.** **Yes** — unify with [Your Target](your_target.md) into one per-deck **Aims**
  surface: the aim list (knobs + date + status) with a calendar view of the dated ones. Goal
  difficulty, scheduling, and management are the same object seen three ways.
  **Status.** Pending - I meant should we have one for the vault level with all dated aims? Seems useful, but tricky.
- **App-bar placement?**
  **Rec.** At the deck level, reach Aims from Home (the aims card) — a dedicated app-bar tab is
  optional. A **cross-deck calendar** at the *vault* level (deck selection) is the better
  home for an app-bar calendar entry, later.
  **Status.** Accepted

## Known bugs (audit-confirmed)
- **Interview scheduling + listing feels unreachable, and the calendar is hard to find.**
  Real: they're embedded in the target sheet (`showTargetSheet`), reached only indirectly (Home
  target card → `/interview-prep`, or the readiness panel), and the **post-interview debrief
  route (`/debrief`) has no caller at all** (tracked as #90). Fix: make Aims a first-class
  surface with a clear entry from Home, and wire (or retire) the debrief.

## View accessed from
Home ("Your target" / Aims). App bar: not today; a vault-level cross-deck calendar is the
stronger candidate for the bar (later).

## Cross-refs
[your_target](your_target.md) · [home](home.md) · [analytics](analytics.md) · older:
`readiness-dashboard.md` (forecast/pace), `interview-interaction-model` memory, `#90` (debrief).
