# ADR 0016 — Derived new-material count: the sustainable ceiling (Phase B)

- **Status:** Accepted
- **Date:** 2026-09-26
- **Deciders:** Kyle Uehlein
- **Related:** **Implements the Phase B half of [ADR-0010](0010-workload-budget-and-proportions.md)** (workload =
  user SIZE + engine-derived MIX; §Decision 3 "one automatic guardrail — a sustainable new-material ceiling",
  Phase B §86–89) and **[ADR-0011](0011-load-control-auto-mix-propose-size.md) §Decision 1** (flow-aware
  ceiling sized by `estMinutes`), and **unblocks its §Decision 5** budget→ready-by "warn-not-bad" readout.
  Also ADR-0007 (allocation / feasibility-urgency), ADR-0008 (cram-vs-durable — deadline pressure routes to
  cram, not a higher new-rate). Depends on the two prerequisites 0010 named: **#133** (state-aware
  est-minutes — done) + **#106** (capped retention floor — done). SoT: `docs/learning-science.md`
  §"Study cadence", `docs/user_stories/scheduler.md`, `settings.md`. Tasks: **#114** (this — Phase B B1),
  **#122** (telemetry to validate the calibration), **#136/#137** (weighted aims / dynamic allocation —
  future consumers of the same seam). Code: `lib/core/plan/practice_plan.dart` (`sustainableNewCount`),
  `lib/shared/providers/learn.dart` (`dailyNewAllowance` / `dailyNewRemaining`),
  `lib/shared/providers/settings.dart` (`NewCardLimit` retired).

## Context

ADR-0010 removed the manual new-sections/day knob and shipped a **FIXED** guardrail for Phase A
(`newCardLimit = 8`, byte-identical to prior behaviour), explicitly deferring the **derived** ceiling to
Phase B once state-aware est-minutes (#133) and the capped retention floor (#106) landed. Both are now
done, so this ADR specifies the derivation ADR-0010 §D3 / ADR-0011 §D1 committed to but left unspecified.

Two things sharpened the design during scoping:

- **The 10:1 figure in ADR-0010 §36 was uncited** ("generates future review-debt (~10:1)", framed as
  "engine + research agree"). A verified web-research pass (sources below) grounds it: it is **Anki's
  documented practitioner heuristic** — a tool-vendor rule of thumb, widely corroborated, not a
  peer-reviewed constant. This ADR cites it honestly and carries the number as a *tunable*, not a law.
- **A flat "backstop that only lowers" would defeat Phase B's own premise.** The conservative reading —
  keep the ceiling pinned at today's 8 and let the derivation only *shed* below it on heavy days — makes
  the new-count **flat in budget**. But ADR-0011 §D5's readout ("finish ~Apr 18 instead of Apr 14; speed
  up anytime") requires new-count to *rise* with budget: if more time never buys more coverage, the
  ready-by line is flat and B2/B3 are pointless. So the ceiling must **scale with budget up to a
  research-sustainable maximum**, not sit at a flat floor.

The needle to thread (the SoT framing): learn enough new material to make progress, but never so much that
you out-run the review capacity that new material creates — different for simple vs complex content.

## Verified evidence (fetched + checked this pass; graded)

- **Review-debt ratio ~10:1 (Anki).** Anki's deck-options docs: a sustained new-card rate produces roughly
  **ten times** as many daily reviews at steady state (their worked figure: ~20 new/day → ~200
  reviews/day). The ratio drifts with desired-retention and lapse rate.
  `https://docs.ankiweb.net/deck-options.html` — **confidence: medium** (tool-vendor heuristic, not
  peer-reviewed, but the dominant field number and mechanically sound: each new card seeds a decaying
  series of future reviews).
- **Cognitive Load Theory — element interactivity + expertise reversal (Sweller et al.).** Learning cost
  scales with how many elements must be held in working memory *simultaneously*: **low-interactivity**
  material (isolated facts/vocab) is learnable in bulk; **high-interactivity** material (interdependent
  concepts) must be sequenced simple→complex and tolerates a *lower* intake rate; support that helps
  novices *hurts* experts (expertise reversal). **confidence: high** (peer-reviewed, replicated).
  Implication: the ceiling should let cheap/simple decks intake more and expensive/complex decks fewer —
  which falls out for free if the cost lever is per-unit `estMinutes` (#133), since complex cards cost more.
- **Deadline pressure → complement, not a higher new-rate (RemNote / SRS practice).** Goal-driven SRS
  (RemNote's exam scheduler) absorbs a near deadline with a **final-review / re-exposure pass over
  already-seen material**, leaving the new-introduction rate at its sustainable level. **confidence:
  medium.** This is why deadline pressure routes to cram (ADR-0008), *not* to inflating this ceiling.

(A prior delegated research run fabricated citations; every source above was fetched and read directly.
The numbers are carried as tunables validated by telemetry — #122 — not as fixed truths.)

## Decision

**The daily new-material count is DERIVED, not fixed — the minimum of three research-backed bounds, over
the retention floor. Reviews come first; new material gets a share of what remains, capped so it cannot
out-run the review capacity it creates. Calibrated so a default day lands at ≈8 (the Phase-A hold) and
scales up to a sustainable maximum as the budget grows.**

The pure helper `sustainableNewCount({budgetMinutes, dueReviewMinutes, …})` returns
`min(byTime, byDebt, hardMax)`:

1. **Time bound** — `floor(kNewShare × postReviewMinutes / kLearnMinutes)`, where
   `postReviewMinutes = budget − min(dueReviewMinutes, kRetentionFloorCap × budget)` (reviews take their
   retention-floor share first, #106). New material claims `kNewShare` of the *remainder*. A heavy-review
   day sheds new automatically (reviews eat the remainder); a light day and a bigger budget allow more —
   this is the "more budget → sooner" lever, and it is review-debt-aware **by construction**.
2. **Review-debt bound** — `floor(budget / kSustainableMinutesPerNew)`. Each new item sustained per day
   eventually costs ~`kSustainableMinutesPerNew` minutes of daily review (the ~10:1 ratio at ~1 min a
   mature review). You cannot sustainably learn faster than you can review what you learn; this caps
   front-loading on a light / brand-new-deck day, and it scales *with* the budget (a bigger day supports a
   higher sustainable rate).
3. **Cognitive bound** — a hard `kNewHardMax`/day regardless of time, from the CLT/dropout evidence (a
   firehose of novelty degrades retention and motivation even when minutes allow it). This is the ultimate
   cap on cheap-card decks, where the time bound alone would permit dozens.

**Calibration (v1).** `kNewShare = 0.32`, `kSustainableMinutesPerNew = 12`, `kNewHardMax = 20`,
`kLearnMinutes = 3` (existing). On a default day (~150 min, reviews ≈ half the day in steady state) these
land the count at **8** (`floor(0.32·75/3) = 8`) — the Phase-A value — with the *time* bound binding; a
bigger budget scales it up until the *debt* bound (≈ budget/12) or the *hard-max* (20) binds; a
heavy-review or ease-in day sheds it toward a couple. The default floats ~6–9 as a deck's real review load
varies around half the day — that variation *is* the intended budget/debt responsiveness. The constants are the **initial calibration**, to be validated against real due-curves via
telemetry (#122); the *shape* (three bounds, reviews-first, budget-scaling to a sustainable max) is the
load-bearing decision, the exact numbers are tunables.

**Retire the `newCardLimit` setting.** It had no user dial (ADR-0010 removed it; only the engine guardrail
+ the dev-sim read it) and its docstring already named this replacement. The derived allowance replaces it;
`kDefaultDailyNew = 8` carries the gentle default as the calibration anchor + the fallback when no budget
is known. This satisfies ADR-0011 §Validation ("no code references `newCardLimitProvider` outside the
engine guardrail").

**Scope of B1 (this slice).** Only the **section** new-count (the dominant new-material lever) is derived.
The Algorithms track keeps its existing `algoDailyMin/Max` range (≤2 solves) for now — the daily-plan
bin-packer already time-budgets algo work into the day, so no balloon; a **shared new-material pool**
across sections + first-time solves is a later refinement. The **dynamic backlog-responsive governor**
(shrink further when the *upcoming* due-wave is building, not just today's) is deferred — the static
review-debt bound already provides the steady-state safety; the governor smooths the sawtooth. Deadline
pressure is **not** absorbed here (it does not inflate this ceiling): it routes to cram + desired-retention
(ADR-0008) and a feasibility conversation (#103/#104).

## Alternatives considered

- **Flat backstop pinned at 8 that only lowers.** Rejected — makes new-count flat in budget, which makes
  the budget→ready-by readout (ADR-0011 §D5) a flat line and B2/B3 pointless. The verified research
  supports a *higher* sustainable maximum (~10–20 depending on budget), so the ceiling scales up to it.
- **Delete the cap outright (pure time-budget pack).** Rejected by ADR-0010 already — overloads novelty on
  light days and spikes review-debt; kept the three bounds instead of none.
- **Single review-debt bound only (`budget / ratio`), no time/reviews-first coupling.** Rejected — ignores
  today's actual due-load, so a heavy backlog day would still schedule the full sustainable count on top of
  the reviews. The time bound (reviews-first remainder) is what makes it responsive day-to-day.
- **Shared new-material pool across sections + solves now.** Deferred — cleaner in theory but the packer's
  time-budgeting already prevents a balloon; deriving the section count first is the smaller, verifiable
  slice.
- **Ship the dynamic backlog governor now.** Deferred — needs an upcoming-due-wave forecast and hysteresis
  math; the static debt bound is the safety net for v1 (a later ADR if built, per ADR-0011 §Sequencing).
- **Expose the ceiling as an expert dial.** Rejected by ADR-0010/0011 — it stays automatic; a coach nudge
  ("ready for more?") is the autonomy-preserving surface.

## Consequences

- **Positive:** unblocks the budget→ready-by readout (B2/B3) — more budget now genuinely buys sooner
  coverage, up to a sustainable ceiling, then honestly flattens. CLT-faithful without a special case:
  cheap/simple decks intake more (units cost less → time bound permits more, hard-max caps the firehose),
  complex decks fewer (units cost more). Self-limiting (can't out-run review capacity). Removes the last
  vestigial workload setting. Generalizes (any subject: est-minutes + the ratio, no SWE shape).
- **Trade-offs / risk:** the constants are a heuristic calibration, not measured — the default day may
  float 7–10 depending on a deck's real steady-state review load (this variation *is* the intended
  budget/debt responsiveness, not a bug). Without the dynamic governor, the count can sawtooth day-to-day
  with due-load; bounded by the debt cap so it can't run away. Validate with telemetry (#122) before
  trusting the exact numbers; the retention floor (#106) and coach (#103) backstop it.
- **SoT:** `learning-science.md` §"Study cadence" gains the verified review-debt + CLT evidence (closing
  the citation gap ADR-0010 §36 left); the derived-ceiling behaviour is the documented model.

## Validation

- Unit tests on `sustainableNewCount` (pure): a default day ≈8; a heavy-review day sheds toward a couple; a
  light / brand-new-deck day rises but is capped by the debt bound; a bigger budget rises monotonically
  then flattens at the hard-max; a cheap-card deck is capped by the hard-max, not ballooned by time.
- The default single-deck daily plan stays ≈byte-identical to Phase A (the default day still lands ≈8+≤2
  solves) — no regression for today's user.
- No code references `newCardLimitProvider`; the derived allowance is the only new-count source (ADR-0011
  §Validation).
- Deferred to B2/B3: the readiness forecast reads the derived, budget-aware count (not a fixed spread), and
  moving the budget shows a neutral ready-by date shift (ADR-0011 §D5).
