# ADR 0009 — The Aims surface (S5e): design + the target-writer flip

- **Status:** Accepted; implemented in **S5e** (#101). **Amended 2026-09-24** (live-aim routing — see the Amendment at the end).
- **Date:** 2026-09-23
- **Deciders:** Kyle Uehlein
- **Related:** ADR-0006 (deck/aims model), ADR-0007 (allocation), ADR-0008 (cram-vs-durable);
  `docs/user_stories/your_target.md`, `scheduler.md`, `home.md`, `personas.md`;
  `docs/learning-science.md` (Study cadence), `docs/product-direction.md` §9 (anti-gamification),
  `docs/design-system.md`; code `lib/features/home/target_sheet.dart`,
  `lib/features/interview/{upcoming_interviews_screen,interview_card,interview_sheet}.dart`,
  `lib/features/home/readiness_panel.dart`; tasks #101, #90, #88.

## Context

S5a–d moved the readiness target onto the aim and left one deck-slot **writer**:
`target_sheet`'s "Save target". S5e must flip that writer (so the deck slots can be
deleted in S5f) AND deliver the user_stories' **1c "Aims surface"**: merge "Your
Target" + "Scheduler" + the interview list into **one per-deck surface** (a list of
aims, each with its knobs + date + status + feasibility + ready-by; a calendar of the
dated ones; a coverage readout for open-ended ones; weakest-link headline).

This is the app's **highest-stakes emotional surface** — the "am I ready / behind /
infeasible?" moment. A 3-front investigation (SoT fidelity + design-system/widget
inventory + learning-science UI principles) plus web research grounded the design.
Key findings: (a) the learning-science ethos forbids countdowns / red-alarm / streaks
and requires honest bands + feasibility-as-options-not-punishment + a coach that is
silent-when-on-track and proposes-never-overrides; (b) **~80% of the UI already
exists** — the aim editor is essentially today's `target_sheet` body repurposed to
edit an aim, the aim row an evolved `InterviewCard` + `_TickedBar`, feasibility a
`StatusPill`; so S5e is mostly *re-composition around the corrected model*, not a
from-scratch build.

## Decision

**A per-deck "Your aims" surface**, shaped by calm/honest/autonomy-supporting
principles:

1. **Form: a full screen** (a route/destination), with the per-aim **editor as a
   sheet** on top (avoids nested sheets; matches the current Interviews screen).
2. **Layout (critical-few + progressive disclosure):** an honest **weakest-link
   headline band** (e.g. "72–78% ready · aiming 85% · weakest of 2 aims", never a
   false-precise single number), then a **list of aim rows**. Each row shows only the
   critical few: name (+ `Vocabulary` assessment noun), a status glyph, the readiness
   bar (dated) OR coverage bar (open-ended), a **feasibility `StatusPill`** (✓ on
   track / ◐ behind / ▲ too soon — color+shape+label, never color-alone), and the
   date-or-"Open-ended". The **calendar** (dated aims) and **Past** (ended aims) are
   collapsed by default.
3. **The aim editor = the repurposed `target_sheet` body** (pickers + `_ForecastBlock`
   + `_ZoneCalendar`) editing ONE aim's knobs + date; **Save → `upsertAim`** (the
   writer flip). Knob TITLES are subject-neutral (**Difficulty / Emphasis /
   Durability**) via the `Vocabulary` seam; values come from the template; the
   assessment noun reads naturally per deck (interview / exam / target).
   *(Amended 2026-09-24 — the row tap opens this editor only for a **bare target
   aim**; a **scheduled interview** opens the interview sheet, which gains an "Edit
   aim" action back to this editor. See the Amendment at the end.)*
4. **Feasibility is informational + actionable, never punitive.** A behind/infeasible
   aim shows a quiet inline line ("~14/day would make it; you're at 8") and, in the
   editor, real options — **Move the date · Lower durability · Cram** — propose-with-
   rationale; **pause is the user's lever**; nothing auto-overrides. No countdowns, no
   red-alarm; `warn` (not `bad`) for "behind".
5. **Open-ended aims render as coverage** (a coverage bar + "steady pace"), NOT a
   ready-by; a **0-aim deck** shows a "Building coverage" state (coverage vs template
   fallbacks) + an "Add an aim" CTA — never a phantom empty "interview".
6. **Merge:** `target_sheet` + `upcoming_interviews` fold into this surface (aims ARE
   the interviews). **#90 debrief** wired as an action on an ended aim. Home's "target"
   card → an "aims" card that pushes here. Deck-creation stays decoupled from
   aim-setting.

**Scope (faithful MVP, reuse widgets):** reuse `StatusPill` / `_TickedBar` /
`_ZoneCalendar` / `_ForecastBlock` / the pickers + one small reusable aim row. Hold
**invariant #8** (single-aim behaves as today — same data/readiness; the UI itself is
intentionally new) and **#6** (weakest-link). Keep aims **round-shaped** — do NOT
build past the parked `rounds → milestones` decision.

## Alternatives considered

- **Tall bottom sheet** (like today's target_sheet) instead of a screen. Rejected:
  the per-aim editor would stack a sheet on a sheet (awkward on mobile) and there's
  less room for list + calendar + past.
- **Build the calm dataviz now** (`CoverageBar`, `ForecastBand`, richer multi-aim
  zone calendar). Deferred: bigger surface area + more new (unbuilt) components + risk;
  the MVP reuse ships the model-correctness first. Polish is a follow-up.
- **Defer the neutral-terminology pass** to #88/G7. Rejected: the glossary decision
  says it "lands in S5"; doing it via `Vocabulary` keeps SWE copy natural for ~no cost.
- **A single blended "target" for the deck** (the old model). Rejected by ADR-0006.

## Consequences

- **Positive:** the last deck-slot writer flips (unblocks the S5f deletion); the
  surface is calm, honest, and autonomy-supporting by construction; ~80% widget reuse
  keeps the build tractable; open-ended/0-aim decks stop being phantom interviews.
- **Negative / trade-offs:** it's still the largest UI slice of the reframe; the UI is
  intentionally NOT pixel-identical to the old target_sheet (byte-identical applies to
  the model/readiness, not the pixels).
- **Deferred:** full multi-aim zone-calendar overlay (start with dated-round markers +
  the binding aim's zones); the continuous **cram↔durable slider** (the model has
  durability as a discrete slot today — use the picker, framed as durability; the
  slider needs model work — near #32/#104); new dataviz widgets; vault-level cross-deck
  calendar (SoT-deferred); rounds→milestones (parked).

## Validation

- Widget tests for the aims screen (rows render readiness/coverage + feasibility pill;
  open-ended → coverage not a ready-by; 0-aim → coverage state) and the editor (Save
  writes the aim via `upsertAim`, not deck slots).
- Invariant #8: a single-aim deck's readiness/plan/forecast outputs stay identical to
  pre-S5 (the model is unchanged; only the surface is new).
- After S5e, `target_sheet`'s deck-slot writer is gone → S5f deletes `Deck.{level,
  context,track,deadline}` + `toTarget` with no remaining reader/writer.

## Amendment (2026-09-24) — live-aim routing: interviews open the sheet

- **Decider:** Kyle Uehlein. **Related:** task #111 (found in the post-S5 adversarial review).

**Problem.** The shipped S5e wiring routed *every* live aim's row tap to the per-aim
**editor** (§3) and only an *ended* aim to the **interview sheet**. But the interview
sheet is the only surface with the interview lifecycle — log outcome, reschedule, add
a round, archive, and the study/pause toggle — and its whole live branch is gated
behind `isEnded`. Net: a live interview could never be advanced or ended (you can't
log an outcome to *reach* ended), and the sheet's live-handling code was dead. This is
a P1 that contradicted §3 in practice.

**Decision.** Route the Aims-screen row tap by aim **shape** (`Aim.isScheduledInterview`
— names a company, has >1 round, or has any resolved or explicitly-typed round: the
planner's output or an in-progress loop):
- a **scheduled interview** (and any **ended** aim) → the **interview sheet** (manage
  rounds + outcome). The sheet gains an **"Edit aim"** overflow action → the knob
  editor (pop-then-open — one sheet at a time, never stacked), so an interview's knobs
  stay editable.
- a **bare target aim** (knobs + an optional date, no interview loop) → the **knob
  editor**, unchanged.

This refines §3 ("a row taps into the per-aim editor (live aim)"): the editor is the
target-tuning surface; the interview sheet is the lifecycle surface. It restores the
sheet's built-but-orphaned live path and matches user mental models (tap an interview
→ see the interview; tap a target → tune it).

**Out of scope (unchanged):** the interview sheet's SWE-specific copy (round types,
"Offer / Didn't pass") stays #88/G7's subject-neutral-surface work; this amendment is
about *reachability* only. Deferred edge: a degenerate planner aim with no company AND
an untyped single round reads as a target (opens the editor) — acceptable; strengthen
the planner's round typing if it ever bites.
