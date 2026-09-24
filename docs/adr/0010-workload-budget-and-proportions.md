# ADR 0010 — Study workload: user sets budget + proportions; the engine derives the mix

- **Status:** Accepted
- **Date:** 2026-09-24
- **Deciders:** Kyle Uehlein
- **Related:** ADR-0006 (deck/aims model), ADR-0007 (daily-plan allocation across aims), ADR-0008
  (cram-vs-durable / FSRS-safe deadlines); `docs/user_stories/settings.md`, `home.md`, `scheduler.md`,
  `index.md`; `docs/learning-science.md` §"Study cadence"; tasks **#114** (this — reframed), **#32**
  (state-aware est-minutes / FSRS), **#106** (capped per-aim retention floor), **#85** (settings IA),
  **#57** (cadence system). Code: `lib/shared/providers/settings.dart`, `daily_plan.dart`, `learn.dart`,
  `algo.dart`; `lib/core/plan/daily_plan.dart`; `lib/core/deck/deck.dart` (`budgetWeight`).

## Context

Three study-**workload** settings are GLOBAL, manually-tuned knobs in the app preferences table:
new-sections/day (`newCardLimit`, default 8), algorithm problems/day (`algoDailyMin`/`Max`, 1–2), and
the daily time budget (`dailyTargetMinutes`, 150, with an ease-in ramp). #114 first proposed making
these **per-deck**. On review the author observed the fine-grained workload knobs are a
first-implementation **holdover**: the allocation engine (ADR-0007) already derives the study **mix**
across aims/domains→tracks by feasibility-urgency, and the manual per-flow caps are guardrails bolted
on top. The intent: don't hand-tune workload — set only what the engine *can't* know (how much time you
have, and how to split it across decks) and let the engine derive the rest.

A three-front investigation (engine map + a cited learning-science/app-design research pass + a SoT
conformance read) converged:

- **SoT already says this.** `learning-science.md` §Study cadence: *"the ramp/coach set the **size** of
  the day; aims set the **mix** within it… urgency = feasibility."* `index.md`: *"the daily plan
  allocates study across [aims]."* `scheduler.md`: *"pacing is a **shared daily budget across
  decks**."* The model is the documented design; the manual caps are the drift.
- **Research.** Classic SRS (Anki, SuperMemo) keep the new-rate a manual knob and let the algorithm
  control only timing. The strongest goal-driven models — **RemNote's exam scheduler** and
  **Duolingo** — **auto-derive** the daily amount from `{time budget + deadline + due-load}` and expose
  one dose knob (time). The rule that falls out: *reviews first, then spend the remaining budget on
  new/practice, skewed toward the nearest deadline.*
- **The one hard finding (engine + research agree).** New-material intake has its **own cognitive /
  working-memory ceiling** and generates future review-debt (~10:1). A pure time-budget bin-pack with
  the caps removed would overload novelty on light days and spike review-debt in ~2 weeks. So the
  manual new-cap cannot simply be **deleted** — it must be **replaced by an automatic, research-backed
  ceiling**, not a user dial.

## Decision

**Study workload is set by TWO user controls; the engine derives everything else.**

1. **The only workload dials the user touches:**
   - **Daily time budget** — vault-level (the shared day: how much time/day, with the ease-in ramp).
     The one quantity only the user can honestly self-assess. (`dailyTargetMinutes`, kept, reframed as
     the *vault daily budget*.)
   - **Per-deck proportion** — each deck's share of that budget (e.g. 60% CS / 40% Korean). This is the
     existing `Deck.budgetWeight` (already read by `allocateBudget`), surfaced at the **deck** level as
     its slice of the day.
2. **The engine derives the workload MIX** — how much review vs. new vs. each contingent flow — from
   `{budget − FSRS due-load, aims (targets/dates → required-vs-actual pace + feasibility-urgency,
   ADR-0007), coverage-remaining}`. **Reviews first**; the remainder spent on new/practice, **skewed by
   urgency** toward the nearest deadline, **over a per-aim retention floor** (ADR-0007 §Decision 4 /
   #106).
3. **One automatic guardrail — NOT a user knob: a sustainable new-material ceiling.** Because a pure
   time budget permits novelty-overload (working-memory depletion; desirable-difficulties degradation;
   review-debt spikes), the engine caps new-material intake by a research-backed, review-debt-aware
   ceiling. This *replaces* the manual `newCardLimit` as an internal guardrail the user never tunes.
4. **The manual per-flow workload knobs are removed** as user settings: new-sections/day, algorithm
   min/max, and the pace-planner "what-if" slider. Budget + proportion + the engine + the ceiling
   replace them.
5. **Gym mode is a vault-level convenience toggle** (a between-sets rest timer), orthogonal to decks —
   not a deck or flow setting.
6. **Config-driven, per-deck flow settings** (the surviving thread of #114): a flow declared in the
   vault template may expose its own **non-load** knobs at the **deck** level, rendered only for decks
   whose template declares that flow — reuse `DeckTemplate.flows`/`FlowSpec`, never a hardcoded
   per-type section (invariant #2). Today **no flow declares a non-load knob** (the per-flow settings
   were all *load* knobs, now removed), so this is a **mechanism/scaffold** — it renders nothing until a
   flow declares a real knob. Per-deck **parsing profile** (per-deck with a vault default; settings.md
   Accepted, #84) is the first intended consumer.

**Scope split (settings.md conformance).** Vault-level Settings = account/AI/backup/theme/dev **+ the
daily budget + gym**; deck-level config (from Home) = parsing, aim defaults, the deck's **proportion**,
and any config-driven flow knobs. Per-deck settings persist in the deck's **`_meta/` JSON** (like
`budgetWeight`), never the app preferences table (index.md: config lives in `_meta`).

**Sequencing (two phases).**
- **Phase A (now):** deliver the user-facing model — remove the manual workload knobs + pace-planner
  from Settings; keep today's sane values as **FIXED automatic guardrails** so the plan is
  byte-identical (no regression); surface the daily budget (vault) + the per-deck proportion (deck);
  move gym to vault; regroup Settings **vault-vs-deck** (folds #85); scaffold the config-driven deck
  flow-settings surface.
- **Phase B (with/after #32 + #106):** replace the FIXED guardrails with **DERIVED** values —
  budget/urgency/deadline-aware new + practice quantities + the automatic cognitive ceiling. Sound
  derivation needs state-aware est-minutes (#32) for accurate bin-packing and the capped per-aim
  retention floor (#106); those are done together.

## Alternatives considered

- **Make the manual knobs per-deck (original #114).** Rejected — multiplies the hand-tuning the model
  removes; contradicts "aims set the mix" (learning-science.md). The engine derives the mix already.
- **Delete the new-cap outright (pure time-budget pack).** Rejected — engine + research agree it
  overloads novelty and spikes review-debt; new intake needs its own ceiling (the automatic guardrail).
- **Keep a manual "max reviews/day."** Rejected — capping reviews hides a backlog rather than shedding
  work; throttle at the *new* lever and let due reviews clear (Anki/FSRS field consensus).
- **Expose the sustainable ceiling as an expert knob.** Deferred — keep it automatic; a coach nudge
  (SDT-autonomy, learning-science.md) can offer "ready for more?" instead of a raw dial.

## Consequences

- **Positive:** one honest workload model — you set *time* and *split*, the engine (aims + FSRS +
  urgency) does the rest; fewer knobs, no guilt-config; SoT-faithful ("size vs mix"); it **generalizes**
  (a Korean deck needs no algo/pace knobs). The config-driven flow-settings mechanism keeps future
  per-flow knobs from hardening into SWE-shaped sections (invariant #2).
- **Trade-offs / risk:** power users lose the explicit new/day + algo dials (intended). Phase A ships
  **FIXED** guardrails (today's defaults) — a holding pattern until Phase B derives them; the derivation
  is genuinely coupled to **#32 + #106** and must be **verified** (sane plans, no light-day novelty
  balloon, no starved due-reviews) before it can be trusted. The automatic ceiling is a heuristic; the
  coach (#103/#60) and the retention floor (#106) backstop it.
- **SoT update (anti-drift rule 2 — landed with this ADR):** `settings.md` moves pace/load **out** of
  deck-level manual settings (→ engine-derived) and gym **out** of deck-level (→ vault), and names the
  daily-budget + per-deck-proportion controls + the config-driven flow-settings mechanism.

## Validation

- **Phase A:** the daily plan is **byte-identical** (the fixed guardrails equal today's default values,
  so removing the UI knobs changes no plan); Settings no longer exposes new/day or algo min/max; the
  deck surface shows the deck's proportion; gym reads at the vault level. (Hold: the plan/queue outputs
  unchanged for the default single-deck case.)
- **Phase B (later):** derived new-count = f(budget, due-load, required-pace) is capped by the cognitive
  ceiling; a light day does not balloon new material; a behind-and-soon aim pulls more new (up to the
  ceiling) **without** starving another aim's due reviews (retention floor, #106).
