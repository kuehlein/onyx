# ADR 0018 — Cross-deck study allocation: priority tiers, engine-derived split, per-deck floor

- **Status:** Accepted
- **Date:** 2026-09-27
- **Deciders:** Kyle Uehlein
- **Related:** **Amends [ADR-0010](0010-workload-budget-and-proportions.md)** (the per-deck proportion changes
  from a numeric `budgetWeight` dial to a priority TIER + engine-derived split). **Extends
  [ADR-0007](0007-daily-plan-allocation-across-aims.md)** (urgency allocation — now across decks, not just
  within one) and **generalizes [ADR-0017](0017-per-aim-importance-allocation.md)** (per-aim importance —
  the same coarse tier now drives the cross-deck split too). Honors [ADR-0011](0011-load-control-auto-mix-propose-size.md)
  (engine proposes, user owns; proactive notify deferred) and depends on the B2 budget-native forecast
  ([ADR-0016](0016-derived-new-material-ceiling.md)) — which forces the cycle constraint below. Tasks:
  **#137** (this), **#116** (recommended deck proportions — subsumed), **#110** (notification gate).
  Backed by the 2026-09-27 deep-research pass (findings folded into `docs/learning-science.md`
  §"Cross-goal prioritization"). Code: `lib/core/deck/{deck,aim,budget}.dart`,
  `lib/shared/providers/daily_plan.dart` (`deckBudgets`), the vault-level allocation view.

## Context

With concurrent decks (multi-subject, #30d), the shared daily budget is split across active decks. Today
that split is a **numeric `budgetWeight`** the user sets with a **share slider** (deck settings) — a
per-deck proportion (ADR-0010 §D1). Two problems, and a reframe:

- **Numeric proportions are opaque.** A learner — especially a student — can't calibrate "30% to Latin vs
  20% to chemistry." The verified research (below) is blunt: non-experts systematically mis-set
  fine-grained cardinal values; SuperMemo literally warns users cluster everything as high-priority when
  given raw numbers and *forces* a spread. Coarse **named tiers** are what people use reliably.
- **Deadline-urgency alone starves high-stakes goals.** There is a robust, replicated **"mere urgency
  effect"** (Zhu, Yang & Hsee 2018, JCR; replicated 2026): people irrationally chase soon-due tasks over
  higher-payoff ones. An engine that split time by deadline urgency alone would do the same — starve a
  low-urgency, high-stakes deck. **User-owned importance must be a first-class counterweight to urgency.**
- **The reframe (unifying #136 + #137).** The right model is not "set per-deck %s" but "express relative
  **priority**, let the **engine** derive the time split" — the same principle as ADR-0010 (user sets
  preferences, engine derives quantities) and the same importance×urgency machinery ADR-0017 already runs
  *within* a deck, now lifted *across* decks.

## Decision

**The user assigns a coarse PRIORITY TIER; the engine derives the cross-deck time split from it, over a
per-deck floor. The numeric `budgetWeight` share dial is retired.**

1. **Four ordinal priority tiers** — `highest · high · normal · low` (default `normal`) — carried **per
   aim** (ADR-0017's importance, widened 3→4 into a shared `PriorityTier`). The **aim is the allocation
   unit**, so aims from *different* decks interleave by their own priority — e.g. *Latin exam > chemistry
   test > Latin vocab quiz*, where a chem-deck aim wedges between two Latin-deck aims (a deck-level tier
   could not express this). A **deck-level** tier supplies the default for a coverage-only deck (no aims)
   and a one-tap "set all of this deck's aims" convenience. Four because: proven usable by non-experts
   (Todoist ships four), above the too-coarse 2–3, below the ~7 point where rating-scale reliability
   flattens, and enough to differentiate the 2–5 concurrent goals a real learner runs while allowing
   **ties**. Tiers carry engine-defined multipliers (starting `2.0 / 1.5 / 1.0 / 0.5`; calibration below),
   so **magnitude is engine-defined, not inferred from an ordering**.
2. **The engine derives each deck's share from a BUDGET-INDEPENDENT "need"** = `importanceMultiplier ×
   coarse-urgency`, aggregated over the deck's active aims (a coverage-only deck uses its deck tier ×
   baseline). Coarse-urgency here is **deadline proximity** — deliberately NOT the
   feasibility/forecast urgency used within a deck. *(**Coverage-remaining / fraction-unstudied** was
   scoped as a second budget-independent term but is **DEFERRED** — see Consequences: it is not
   implemented in v1.)* **Why (a load-bearing constraint):** the B2
   budget-native forecast reads `deckBudgets`; `deckAimFeasibility` reads the forecast; so if `deckBudgets`
   derived the split from feasibility it would form a cycle (`deckBudgets → feasibility → forecast →
   deckBudgets`). The cross-deck split therefore uses a coarser, budget-independent need; the fine
   forecast-urgency stays *within* a deck (ADR-0007), where it's downstream of the budget.
3. **A per-deck floor — no active deck starves.** Each active deck keeps at least an **engagement floor**
   of time (reuse `engagementFloor`, the existing "too little to learn or retain" threshold, ≈15 min) so a
   de-prioritized deck still progresses — the SuperMemo "deprioritize, never delete" model and the
   learning-science consistency finding (steady work across the whole window beats letting the nearest
   deadline crowd everything out). If the sum of floors exceeds the budget (too many active decks for the
   day), floors scale down proportionally and the existing too-little-time warning fires — no silent
   starvation.
4. **Legible by construction — the split is an OUTPUT, never an input.** A **vault-level allocation view**
   shows each deck's tier + the engine-**derived** result as concrete **minutes/day** (+ a proportion bar),
   updating live as tiers change. The user never types a percentage. This resolves the opacity problem:
   the black box is opened (you see the minutes your choices produce) without asking anyone to calibrate a
   number.
5. **Tiers, not ranking.** No drag-to-order and no numeric slider. The research is explicit: full ranking
   is least reliable exactly for middle items, forces false orderings (every item ends ranked even if one
   moved → the engine could starve a goal on a priority the user never set), and can't express ties.
   Tap-to-tier allows ties and is reliable.
6. **Engine proposes; user owns; silence stays default (ADR-0011).** The tier is the user's input and the
   derived split is a **pulled readout** on the vault view — not auto-written elsewhere, not pushed. A
   passive "your tiers imply a different split than before" indicator ON that view is fine (pulled); a
   **proactive** "your load changed" notification stays deferred behind **#110** + usage evidence
   (ADR-0011 §D4/D5 — Kluger-DeNisi: feedback can reduce performance).

**Calibration (to dogfood, not literature — the research validates the ingredients, not a formula).** Tier
multipliers `2.0/1.5/1.0/0.5`; floor = `engagementFloor`; coarse-urgency (v1) = a bounded function of
days-to-nearest-deadline (`deadlineFactor`, peak `1.5` over a `60`-day window). These are starting points
recorded here and tuned against real multi-deck use (#122), like ADR-0016's ceiling constants.

**Deferred: coverage-remaining (fraction-unstudied) as a second urgency term.** It is budget-independent
(so it would *not* reintroduce the cycle), but it depends on per-section studied state, which changes on
every graded card — folding it into `deckBudgets` would make the split (and the forecast that reads it)
churn on every review. It's also partly redundant: within-deck pacing + the readiness/forecast already
reflect how far along each deck is, so a cross-deck split driven by stable user intent (tier) + deadlines
is more predictable. Revisit with #122 if dogfooding shows an under-studied deck is starved of time.

## Alternatives considered

- **Keep the numeric `budgetWeight` slider.** Rejected — opaque to non-experts (research); the whole point
  of the reframe is that the user shouldn't calibrate percentages.
- **Drag-to-rank priority.** Rejected — unreliable middle positions, forced non-response, no ties (research).
- **Pairwise / AHP (cardinal magnitude judgments).** Rejected — asks for exactly the fine cardinal judgment
  novices are worst at; scales quadratically with deck count.
- **Use the feasibility/forecast urgency for the cross-deck split** (consistency with within-deck). Rejected
  — it cycles through the B2 budget-native forecast (constraint above). A budget-independent coarse need is
  required at this layer.
- **No floor — pure priority split.** Rejected — starves low-priority decks, contradicting the "deprioritize
  not delete" precedent and the consistency finding; a de-emphasized subject should slow, not stop.
- **Proactive "load changed" notification.** Deferred — ADR-0011 Phase C, gated on #110 + usage evidence.

## Consequences

- **Positive:** the split reflects what the learner *cares about* (importance) balanced against *deadlines*
  (urgency), with the engine — not the user — doing the arithmetic; legible (minutes shown), calm (pulled,
  no push), autonomy-preserving (tiers are a preference, fully overridable), and it **unifies** the within-
  and cross-deck allocation onto one importance×urgency model. Generalizes to any subject mix. Subsumes
  #116 (recommended proportions) and closes the numeric-dial opacity.
- **Trade-offs / risk:** a real architecture change (deck share moves from a stored number to a derived
  value) with a **migration** (existing `budgetWeight` → a tier; default everyone to `normal`, so a
  single-deck vault and an untouched multi-deck vault stay ≈equal-split). The cross-deck need is a coarse
  heuristic (budget-independent by necessity) and its formula is unvalidated by literature — dogfood before
  trusting the numbers. The floor + urgency interaction (many active decks vs a small budget) must be
  tested so nothing silently starves.

## Validation

- Cross-deck split is byte-identical to today for the **single active deck** case (it gets the whole
  budget) and for an **all-`normal`, no-deadline** multi-deck vault (≈equal split, as `budgetWeight=1.0`
  gave). Pure `allocateBudget` tests: higher tier → larger share; a soon deadline raises a deck's share; a
  low-priority deck never drops below the floor; Σfloors > budget scales floors + warns.
- No provider cycle: `deckBudgets` does not read `deckAimFeasibility`/the forecast (guarded by the
  budget-independent need); a test asserts the dependency direction.
- The vault view shows derived minutes/deck live from tiers, with no numeric input; changing a tier updates
  the split; the deck's minutes never fall below the floor while active.
- Migration: a persisted `budgetWeight` loads without error and maps to a tier; a re-save carries the tier.
- Deferred: the proactive notification (behind #110); the exact multiplier/urgency calibration (#122).
