# ADR 0011 — Load control: the engine auto-adjusts the MIX; it PROPOSES the SIZE

- **Status:** Accepted
- **Date:** 2026-09-24
- **Deciders:** Kyle Uehlein
- **Related:** **Amends [ADR-0010](0010-workload-budget-and-proportions.md)** (workload = budget + proportions, engine-derived mix). Also ADR-0007 (daily-plan allocation / feasibility-urgency), ADR-0008 (cram-vs-durable), ADR-0009 (aims-surface, "warn-not-bad" pace copy). SoT: `docs/user_stories/scheduler.md`, `settings.md`, `home.md`, `index.md`; `docs/learning-science.md` §"Study cadence". Tasks: **#114** (workload model), **#106** (retention floor), **#32** (state-aware est-minutes), **#110** (notification-fatigue / evidence base). Code: `lib/core/coach/coach_update.dart`, `lib/shared/coach_settings.dart`, `lib/features/home/{coach_badge,load_checkin_sheet,coach_chat_sheet}.dart`, `lib/core/ai/coach_update_chat.dart`, `lib/core/plan/daily_plan.dart`.

## Context

ADR-0010 removed the manual per-flow workload knobs (new/day, algo min/max) and split load into a
**user-owned SIZE** (the vault daily budget + each deck's proportion) and an **engine-derived MIX**
(review vs new vs practice, plus one automatic new-material ceiling). A natural next question — raised as
a product vision — was: *should the engine adjust load itself as the learner performs, and notify them,
with the user keeping the autonomy to override?* The intuition (two forces in tension: an engine that
adapts to pace/retention/load, and a user who keeps final say) is exactly the "ease-in → ramp → adjust
on performance" model already implied by the SoT.

A four-front investigation (motivation science · competitive UX · SoT conformance · code reality) plus a
three-lens adversarial critique (incl. a devil's-advocate steelmanning "keep it manual" / "adjust
silently" / "do nothing") converged on a **correction** to the literal vision, and on one urgent bug:

- **The literal headline over-reaches for SIZE.** "The engine adjusts load itself and notifies" is
  correct **only for the MIX** (invisible; already shipped: reviews-first cap #106, feasibility-urgency
  allocation). Applied to the day's **SIZE** — the budget/proportion the user owns — it re-creates the
  autonomy erosion ADR-0010 was written to kill: the engine would be inferring **real-world time
  capacity** (which it provably cannot observe — the "grandparent is dying" case in `deck_selection.md`)
  from in-app behavior, and would trip the most-repeated invariant in the SoT (**coach never overrides**;
  ADR-0008 §D4, ADR-0009 §D4, `deck_selection.md`, `index.md`) plus ADR-0010 §D1/§D4 ("the budget is the
  one quantity only the user can honestly self-assess"; "the user's set share always wins").
- **Silence is the null hypothesis for notifications.** The MIX already adjusts silently and nothing
  broke. A "we changed your load" message *is feedback*, and ~1/3 of feedback interventions **reduce**
  performance — worst in self-directed framing (Kluger & DeNisi 1996, 607 effects). Duolingo's cautionary
  case is the same shape: their adaptive *difficulty* works; the backlash came from **removing a
  user-facing control and auto-setting it**. Notification-fatigue is un-formalized (#110) and the only
  SoT-sanctioned coach surface is a single in-app Home nudge (`home.md`).
- **Provisional-apply-then-undo on a user dial is an override in disguise.** Silently lowering a budget
  the user set and offering "undo" is still a fait-accompli. (Dietvorst 2018: people trust an algorithm
  they can modify *before* it acts — an argument for **propose**, not act-then-undo.)
- **The urgent bug (independent of any of the above).** The just-shipped ADR-0010 says the new/day + algo
  min/max knobs are removed — but the **coach still reads/writes them** across six surfaces
  (`coach_badge`, `coach_chat_sheet`, `load_checkin_sheet`, `coach_update`, `coach_update_chat`,
  `coach_settings`), e.g. the check-in writes `CoachSetting.newCardsPerDay` and `readyToPush` offers
  "Add 3 new/day". Docs and code **disagree in `main` today**. This must be repointed regardless of the
  vision's fate.

## Decision

**Load control follows the SIZE-vs-MIX split. The engine auto-adjusts the MIX (silently); it may PROPOSE
the SIZE but never writes a user dial. The user always wins; the coach mediates, never overrides.**

1. **Engine — owns the MIX + the automatic ceiling, silently.** Derives review-vs-new-vs-practice from
   `{budget − FSRS due-load, aims/feasibility-urgency, coverage}` (reviews first, over the per-aim
   retention floor — ADR-0007/0010, #106; shipped). Enforces **one automatic ceiling** on high-cost
   *novel* work — **flow-aware, not card-centric**: it governs whatever the deck's flows treat as the
   costly-new unit (new sections, first-time mocks), sized by `estMinutes` per `PracticeUnit`
   (ADR-0007), so it generalizes past the CS deck. Runs the ease-in → ramp (gated on adherence). **No
   notification** for a MIX change.
2. **Size (budget + per-deck proportion) — user-owned; engine/coach may PROPOSE, never auto-write.** A
   change to a value the user has set is a **proposal**: it takes effect only on an explicit tap.
   **Provisional-apply** (pre-apply + undo) is legal **only for values the user has never touched** (the
   automatic ceiling, an untouched ramp default) — never for the budget/proportion. Up- and
   down-proposals are symmetric in mechanism (propose → apply-on-tap); a down-proposal is held to a
   *stricter, longer* fused-signal threshold (a false "you should do less" is an ego hit; Kluger-DeNisi).
3. **Coach — proposes and applies-on-request; never autonomously changes a user dial.** It surfaces a
   size proposal as a `CoachProposal` (one-line purpose + apply); it **applies a change the user asks
   for** ("ease off" → done, with consent); it runs the opt-in check-in. It has **no private knobs** —
   everything routes through the user's budget + proportion + high-level **intents** (push / steady /
   ease-off). Research FOUNDATION always; an optional vault `CoachSkill` augments tone, never the limits.
4. **Notifications — silence is the default; the only sanctioned surface is the ambient Home nudge.**
   Say nothing when on track. No OS/push channel (out of scope; gated on #110). **No persisted
   change-log** (a dashboard by another name — `home.md`: "one honest nudge, never a dashboard";
   build-when-consumed). Single-step undo carries only the previous value.
5. **User override — honored immediately, informed, never demotivating.** An explicit request ("I'm
   burned out", an "ease off" intent, a dial move) is honored **at once, regardless of data** (autonomy
   > data). At the moment of a dial move, show an **in-the-moment informed readout** — a zone band
   (ambitious / sustainable / likely-to-burn-out) + a **neutral forward date shift** ("finish ~Apr 18
   instead of Apr 14; speed up anytime") from the existing forecast — **off Home**, never a red
   behind-countdown (reuses ADR-0009 §D4's "warn-not-bad" template). The **already-low → lower further**
   case is **silence + honor**; brainstorming ("talk through a lighter setup", with chain-preserving
   options + auto-resume) is available **on-pull**, never pushed after a downward move, and **never a
   gating "are you sure?"** (reactance; violates "the user's set share always wins").
6. **Engine-initiated changes gate on FUSED signals** (adherence + retrieval accuracy + self-report),
   never self-report alone, never preemptively (`learning-science.md`). An **unelicited** "I feel burned
   out" is honored as a *user request* — it does not license the coach to treat it as sufficient evidence
   to itself re-plan. Copy for any load message: task/plan-framed, purpose-first, **subject-neutral via
   the Vocabulary seam**, no praise/ego, and a lighter load framed as **legitimate** (it protects recall),
   never as failure. `deload/taper/strain/consolidation` are **internal rationale only** — never surfaced.

**Sequencing.**
- **Now (this slice — correctness + safe, autonomy-preserving feedback):** repoint the coach off the
  three removed dials onto budget + intents (retire `CoachSetting.newCardsPerDay/algoMin/algoMax`; fix
  `backlogThreshold`/`readyToPush`; neutralize the "lower your new-cards/day in Settings" copy + the
  SWE-specific `study_load_help.dart`); add a **Vocabulary-leak guard test**; add the **user-pulled
  dial-move readout**. Ship this ADR + the story edits with it.
- **Deferred (Phase B / later):** engine-*derived* quantities + the flow-aware automatic ceiling (Phase
  B, gated on **#32** state-aware est-minutes + **#106** retention floor). The engine-*initiated* size
  proposal + any notify/propose surface is a **Phase C hypothesis** gated on #32/#106 **and** real usage
  evidence **and** the #110 notification decision — with its fusion / hysteresis / multi-deck-attribution
  math in its own later ADR (do not ADR an unbuilt algorithm). **Proactive pre-deadline taper is
  deferred** and, if ever built, is subordinate to ADR-0007 urgency (a *behind* aim never tapers).

## Alternatives considered

- **Take the vision literally (engine changes SIZE + notifies).** Rejected — re-creates ADR-0010's
  autonomy erosion (inferring real-world time from in-app behavior) and the Duolingo remove-a-control
  backlash; breaks coach-never-overrides.
- **Do nothing new (fix the bug, then stop).** The devil's-advocate steelman: the mix half is shipped and
  the marginal *notice* often hurts, so build only the repoint and instrument. **Partly adopted** — the
  entire *proactive/notify* layer is deferred and gated on real evidence. We still ship the **user-pulled**
  readout now: it is a pure projection at the user's own action (no engine authority), on-brand for calm +
  autonomy, and low-risk.
- **Auto-adjust silently with an on-demand change-log, zero messages.** Adopted for MIX (silent). For
  SIZE we keep the *pulled* readout and defer proactive messages; the persisted log is dropped
  (build-when-consumed).
- **Provisional-apply the down-proposal with undo.** Rejected — an override with a consolation prize on a
  user-set value; propose-then-apply-on-tap instead.

## Consequences

- **Positive:** resolves the live docs/code contradiction; keeps the calm/autonomy identity (the engine
  adapts the invisible mix; the user pulls size with honest feedback); evidence-faithful (silence-default,
  feedback-as-feedback, reactance-safe); generalizes (flow-aware ceiling, subject-neutral copy). Records
  the auto-vs-propose invariant so implementers can't "adjust the user's dial and notify" by drift.
- **Trade-offs / risk:** the literal "adaptive load engine" is narrowed to "engine adapts the mix; coach
  proposes the size (later)". The proactive value is unproven and deliberately deferred behind
  instrumentation. **Guarded invariants:** no auto-write to a user-set dial; silence-default; per-aim
  weakest-link not a masking average (invariant #6); single-aim byte-identical (invariant #8); no
  Vocabulary leak (guard test).

## Validation

- The repoint: **no code references `newCardLimitProvider`/`algoDailyMinProvider`/`algoDailyMaxProvider`
  outside the engine's internal guardrails + the settings migration**; the coach's load agency routes only
  through budget + intents; the daily plan stays byte-identical (ADR-0010 Phase A hold).
- The pulled readout: moving the budget/proportion shows a zone + neutral date shift, off Home, no red
  countdown; lowering an already-low load is honored silently (no gating prompt).
- A guard test asserts no `{algo, LeetCode, mock-interview, deload, taper, strain, rep}` literal leaks
  through the Vocabulary seam in any load string.
- Deferred (Phase B/C): engine-derived quantities capped by the flow-aware ceiling; any engine-initiated
  size proposal is propose-then-apply-on-tap, fused-gated, down-conservative, and never notifies beyond
  the ambient badge.
