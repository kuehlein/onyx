# ADR 0005 — The `focusedGoalProvider` spine

- **Status:** Accepted
- **Date:** 2026-09-17
- **Deciders:** Kyle Uehlein (+ AI-assisted scaffolding)
- **Related:** `docs/ux-vision.md` §2 (the one spine), `docs/ux-rework-stage1.md`
  (Critique 1 §A). Code: `lib/shared/providers/study_goals.dart`,
  `lib/features/home/home_screen.dart`. Phase-0 of `docs/roadmap.md`.

## Context

"Which goal am I looking at" was tracked in **two** places that had to be hand-kept
in sync:

- `home_screen`'s local `String? _focused` setState — the hub-vs-lane UI altitude
  (null = hub).
- `SelectedStudyGoalId` (a keepAlive provider, non-null, default `defaultGoalId`) —
  the "effective scoping goal" that readiness/pace/the daily plan compute against.

`_enter`/`_backToHub` wrote both. This is the hidden coupling Stage-1 flagged
(Critique 1 §A): two sources of one truth that can disagree, and no single value a
route/deep-link could set to drive every surface. Degradation (hub vs single-goal)
was also driven by `live.length` (non-graduated), which **counts paused goals**, so
"1 active + 1 paused" wrongly showed the hub instead of a single-goal Home.

## Decision

**One nullable spine: `focusedGoalProvider` (`String?`).** `null` = the all-goals
hub altitude (only reachable with ≥2 *active* goals, before a lane is entered); a
goal id = that goal is focused. It replaces both `_focused` and
`SelectedStudyGoalId`:

- `home_screen` drops `_focused`/`setState` and the manual `SelectedStudyGoalId`
  writes; `_enter(id)`→`focus(id)`, `_backToHub()`→`focus(null)`, and `build` reads
  the provider. The route is the entry, the provider is the runtime truth, so they
  cannot disagree.
- `activeStudyGoal` reads `focusedGoal ?? defaultGoalId` — behaviour-identical
  (null → default id → the existing `orElse` maps to the first live goal).

**One degradation helper: `activeGoalCountProvider`** = count of goals with
`state == active` (**paused and graduated excluded**). Every degradation check reads
it, so "1 active + N paused" behaves like a single-goal app everywhere. `home_screen`
now computes hub-vs-single from the active goals, not `live` (the deliberate,
spec-mandated fix to the paused-counted-as-a-lane bug).

## Alternatives considered

- **Keep two values, sync more carefully.** Rejected — the whole point is to remove
  the disagreement class, not police it.
- **Make the spine non-null (default id) like the old provider.** Rejected — the hub
  altitude genuinely *is* "no single goal in focus"; a nullable value models that
  honestly and lets the hub be a real state rather than a magic default id.
- **Keep `live` (paused-counted) for degradation.** Rejected — it's the bug Stage-1
  named; `activeGoalCount` is the fix and the spec's explicit helper.

## Consequences

- **Positive:** one value drives Home/Browse/Insights/readiness/pace/plan; a
  route/deep-link can set focus; single-goal degradation is byte-identical for the
  common case; "1 active + N paused" now correctly reads as single-goal. Small,
  contained diff (one reader + two writers + one test).
- **Trade-offs:** a paused goal no longer appears on the hub when only one goal is
  active (it's dormant until re-activated or a second active goal returns) — the
  intended behaviour. Browse/Insights already read the effective goal via
  `activeStudyGoal`, so they inherit the spine without change; explicitly wiring
  their route params to set `focusedGoalProvider` is a later UI unit.

## Amendment (2026-09-24) — the escape hatch (1b)

The "1 active + N paused" degradation (above) is retained, but its **trade-off**
("a paused goal no longer appears on the hub when only one goal is active") stranded
the user: with the hub only reachable at ≥2 active, a paused deck couldn't be
resumed (`deck_selection.md` "Known bugs"). Resolved **without changing the
degradation**: a persistent secondary **"Decks"** affordance on Home opens a
vault-level `/decks` deck-selection screen on demand (reusing the lanes hub), so
paused decks stay reachable with one active deck. The degradation still governs the
*auto-landing* (≥2 active → hub); the escape hatch is the manual path. The old
prominent hub back-arrow is replaced by this secondary affordance.

## Validation

- `test/unit/focused_goal_spine_test.dart`: the spine defaults to `null` and
  `focus`/clear round-trip.
- `test/unit/readiness_flow_test.dart` (updated): switching focus via
  `focusedGoalProvider` re-scopes readiness to the focused lens — the end-to-end
  proof the spine drives scoping.
- Full suite green: the home widget tests + `multi_goal_acceptance_test` exercise
  the hub/single-goal degradation through the new spine.
