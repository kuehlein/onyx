# Design: the Algorithms track (task #33)

**Status:** draft for sign-off · **Date:** 2026-09-04

## Goal

Guarantee daily algorithm practice with real retention, without turning Onyx into
a code editor. You solve problems on **NeetCode** (your chosen platform); Onyx is
the **spaced-practice scheduler and reflection layer** around that — it decides
*which* problems to (re)work each day and *how* (solve vs. explain), so patterns
stick instead of fading.

## Why this shape (research)

- Spaced re-solving beats grinding: engineers land offers with ~150–175 problems
  and out-perform 500+ grinders, because they *retain patterns* rather than
  memorise solutions. The validated loop is **solve → wait → re-solve from
  scratch → explain the pattern in your own words**, at expanding intervals.
- Goal is **pattern recognition**, and you should *count patterns mastered, not
  problems solved*.
- **NeetCode 150** is the right curriculum: it contains Blind 75, is grouped by
  pattern, and is sized for deep prep. Rule: pick one list, go deep — don't grind
  several (redundant). LeetCode stays for *extra reps on weak patterns*, not a
  second curriculum.

(Sources captured in the leetcode-neetcode-cards memory / chat of 2026-09-04.)

## Core model: two clocks per problem

Each problem carries two independently-decaying memories. **The guardrail that
makes this effective rather than falsely reassuring: explaining never satisfies
the re-solve clock** — you can't explain your way out of actually coding it.

| Memory | Refreshed by | Where | Cadence | State |
|---|---|---|---|---|
| **Execution** | a full **re-solve**, self-reported | computer (NeetCode) | FSRS-scheduled, the backbone | the problem's `srs_state` (reused) |
| **Recognition** | **explain** the approach to the coach | phone, no code | lighter, keeps recognition warm *between* re-solves | a separate lightweight "last-explained" signal, NOT a second FSRS state |

Re-solving drives the real schedule; explaining is daily-doable upkeep that lets
you stay consistent on a phone-only day and never stands in for execution.

## Card structure (Decision 1 — generate into the vault)

Cards live in the vault as markdown (consistent with the rest of the app,
editable, yours). New card **`type: algorithm`**:

- **Card = a NeetCode pattern** (e.g. *Arrays & Hashing*, *Two Pointers*, *Stack*,
  *Sliding Window*, *Binary Search*, *Linked List*, *Trees*, *Heap / Priority
  Queue*, *Backtracking*, *Graphs*, *1-D DP*, *2-D DP*, *Greedy*, *Intervals*,
  *Bit Manipulation*, *Math* — the ~15 NeetCode 150 groups).
- **Section = one problem.** Heading = problem name; body = the NeetCode
  `practice_url` + difficulty + (optionally) a one-line recognition cue. Bodies
  are deliberately **light** — the solution lives on NeetCode; Onyx schedules the
  practice. Each section is an independent scheduling unit (reuses the existing
  per-`(cardId, sectionSlug)` `srs_state`).

This maps cleanly onto NeetCode 150 and gives a pattern-level view for free
(blocking a new pattern, then interleaving for review — as the research prescribes).

### Decision 2 — the existing 5 fold in

`two-sum`, `contains-duplicate`, `product-of-array-except-self` → *Arrays &
Hashing*; `valid-parentheses` → *Stack*; `best-time-to-buy-sell-stock` → *Sliding
Window*. Each becomes a **pre-enriched section** under its pattern card, carrying
its authored Approach/insight content (a head-start; the other ~145 start as
pointers you can enrich over time). Their old standalone `interview-question`
cards are retired in the migration.

## Scheduling & the daily goal (fixes the pacing worry)

The Algorithms track is a **separate queue**: `type: algorithm` cards are
**excluded** from the main review/learn queues and from **gym mode** (algos are
20–45 min, not quick-recall-while-you-train). A new setting **"Algorithms per
day"** (default ~3) paces it:

1. Fill with **due re-solves** (execution) first, most-overdue first.
2. If under goal, add **explain** reviews of solved-but-not-due problems
   (recognition upkeep).
3. If still under, introduce **new** problems in NeetCode 150 order (block the
   current pattern, interleave older ones for review).
4. If *over* goal (many due), cap and defer the rest — never a wall.

So: never 0, never a pile, always a computer-or-phone option to hit the day.

## Interaction flows

- **Re-solve:** problem shows "Open on NeetCode" (`practice_url`) → you solve on
  your machine → **Log a solve** (the capture sheet already built: outcome +
  optional insight) → outcome maps to an FSRS grade → next re-solve scheduled.
- **Explain:** "Answer the coach" (interviewer persona, seeded with the pattern)
  → you talk through approach / complexity / edge cases, no coding → self-grade
  recognition. Advances the recognition signal only.

## Readiness & insights (Decision 3 — yes, solves feed readiness)

- Algo re-solves feed applied-transfer / readiness (real solves are the truest
  transfer evidence; the capture loop already routes `source: external` there).
- Algo cards are **excluded from concept-coverage** (separate track) so they
  don't distort the deck's coverage denominator.
- New Insights view (v2): **patterns mastered** (count patterns, not problems) +
  per-pattern progress.

## FSRS integrity

Reuse the per-section `srs_state` for the execution clock; the recognition layer
is a separate lightweight signal. Never mutate fitted FSRS state; new problems
enter via the track's own "new" flow. Consistent with the fsrs-exam-targeting
discipline (keep the fitted curve pure).

## Phasing

1. **Core:** `algorithm` card type + routing (exclude from main queues/gym);
   seed the NeetCode 150 into the vault (fold in the 5); the algo queue + daily
   goal; the **re-solve** flow (reusing the capture loop) + FSRS scheduling.
2. **Explain mode:** the recognition clock + coach wiring; phone-doable daily.
3. **Insights:** patterns-mastered view; readiness wiring polish.

## Open questions / risks

- **New card type ripples** through parser, indexer, schema doc, and some tests —
  scoped but real.
- **Recognition clock**: keep it a simple "last-explained + target interval"; do
  NOT build a second full FSRS (over-engineering risk).
- **NeetCode 150 list** has no API — it's a static list I compile (problem name +
  difficulty + link); may drift as NeetCode updates. Ship as vault data.
- **The 5 reformat** from card-per-problem to section-under-pattern (one-time
  migration).
- **Coexistence**: once migrated, "algorithms" live in exactly one place (the
  track), avoiding two competing systems.
