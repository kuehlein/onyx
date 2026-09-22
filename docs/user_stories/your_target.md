# Your Target → the deck's Aims

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.
> **Reframe:** in the new model this isn't one "target" — it's the surface for managing a
> deck's **set of aims**. I'd rename it **"Aims"** (or "Goals") and merge the
> [Scheduler](scheduler.md) + interview-list into it (see below).

**Purpose.** Set and manage what a deck is pointing at — one or more concurrent **aims**, each
with its own difficulty, emphasis, durability bar, and date (or open-ended). These shape the
readiness roll-up and the daily plan's allocation.
**Scope.** Deck level.
**Personas.** P2/P4 (dated aims — an exam, an interview loop); P3 (open-ended mastery).
**Reached from.** Home (the aims summary card).
**MVP.** Create/edit **one** aim (difficulty + emphasis + durability + optional date). Multiple
concurrent aims: MVP-ish → full.

## What it does
- **Per aim, set the four knobs:** [MVP for one aim]
  - **difficulty / depth** — how far into advanced material you're held to (was "seniority"),
  - **domain emphasis** — which parts of the deck weigh more (was "track"),
  - **durability bar** — how locked-in recall must be (was "company tier"),
  - **date** — a target date, or open-ended.
- **Manage the set** — add / edit / pause / remove aims; a deck can hold several at once (the
  music deck's composition test + improv jury + general fluency). [full]
- **Pace + readiness follow from the aims** — readiness is **weakest-link across the active
  aims**; the daily plan allocates study across them and their gated flows.

## Open questions → recommendations
- **"Did we break anything? Where did the calendar go?"**
  **Rec.** Nothing's deleted — but it's buried. The zone-calendar + scheduled list currently
  live *inside* the target sheet (`showTargetSheet` → `_ZoneCalendar` / `_ScheduledSection`),
  reached from the Home target card (→ `/interview-prep`) and the readiness panel. The
  aim-unification (#68) + G7 work moved things, which is why it feels lost. The fix is the
  unification below (make Aims a first-class surface, not a buried sheet).
  **Status.** Accepted
- **"The old version was nicer but needed work to generalize."**
  **Rec.** Keep its strengths — the zone calendar, the ready-by forecast, the scheduled list —
  but reframe from a single target to the **aim set**: the calendar becomes a view over the
  *dated* aims, and the forecast becomes per-aim + a weakest-link overall.
  **Status.** Accepted
- **"Deck authoring seems tied to goal selection?"**
  **Rec.** Decouple them. Creating a deck (a lens + cards) is separate from setting its aims; a
  new deck starts with zero or one default aim, and the user sets aims afterward. The coupling
  is an artifact of the old goal-editor sheet.
  **Status.** Accepted
- **Should this be one holistic view with the Scheduler + interview list?**
  **Rec.** **Yes.** "Set difficulty/emphasis/durability" (here), "schedule dates/tests"
  ([Scheduler](scheduler.md)), and "manage the interview/test list" are three facets of the same
  thing — the deck's aim set. Merge into **one per-deck Aims surface**: a list of aims (each
  with its knobs, date, and status) plus a calendar view of the dated ones.
  **Status.** Accepted

## View accessed from
Home. (Post-merge: the single entry point for aims, scheduling, and the test/interview list.)

## Cross-refs
[scheduler](scheduler.md) · [home](home.md) · [analytics](analytics.md) · older:
`readiness-dashboard.md`, `interview-*` memories, `#68` aim-unification, `#88` (G7 target-card).
