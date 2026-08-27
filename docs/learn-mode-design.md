# Learn Mode — Design

A **Learn** phase that owns *first exposure* to new material, distinct from the
FSRS **Review** loop that *maintains* it. Synthesized from a research pass
(cognitive load theory, Mayer's pre-training + generation/pretesting, and how
Anki/SuperMemo/RemNote separate learning from review). See also
[`learning-science.md`](learning-science.md).

## Why a separate phase (confidence: high)

You cannot retrieve a trace that was never encoded. Before Learn mode, a new
section's *first appearance was a graded review it was guaranteed to fail* —
both a poor first encounter and a meaningless first data point for FSRS. Every
mature SRS separates "meeting" material from "maintaining" it. The core rule:

> **First exposure is an encoding event, not a retrieval event — the scheduler
> must not see it as a graded review.** And the best encoding isn't a passive
> read: it starts with an *attempt* (generation/pretesting), then reveals the
> answer to study.

This does **not** close the transfer gap (`learning-science.md` open Q#1–2):
Learn builds the pattern library faster and stickier; interview readiness still
needs novel-problem practice.

## The seam: Learn blocks, Review interleaves

- **Learn = the blocking phase.** New material is grouped by relatedness and
  studied together (block-first, for novices — `learning-science.md` §3).
- **Review = the interleaving phase.** The existing FSRS loop, unchanged,
  reorders due items across domains.
- **The join is `srs_state` seeding.** A section leaves Learn by *graduating*:
  we seed its initial FSRS state so it becomes a due item. The review path needs
  zero changes. A section is "new" iff it has no `srs_state` row — no schema
  change for v1.

## Decisions locked in (v1)

- **Attempt style: mental → reveal → self-grade.** Offline, low-friction. Typed
  + AI-coach is a later "deep mode" (task #11, needs the Claude integration).
  In both modes the FSRS grade stays a **human self-tap** — AI may *suggest* a
  grade and coach, but never grades the schedule (keeps FSRS honest + offline).
- **Graduation gate: Good/Easy graduates** a section (seeds state, enters
  review); **Again/Hard re-queues** it within the same session. Faithful to
  "block until it sticks"; relax if it proves naggy.
- **Daily budget: ~20 new sections** per session (≈4 cards; one card ≈ 4–6
  sections). Tunable later.
- **Interaction routing by section heading:** conditional/"why" sections
  (When to Use, Common Pitfalls, Trade-offs, Approach) use **guess-then-reveal**
  (errorful generation, always followed by the answer); dense declarative
  sections (Key Properties, Complexity, Syntax) are **read** (pre-training). No
  schema change — the heading is the signal.
- **Grouping:** un-seeded quizzable sections → cards clustered into **wikilink
  families** (graph connected components) → within a family, foundational-first
  (tier asc, then title) → most-foundational family first → capped at the daily
  budget.
- **Graduation writes `srs_state` but NOT a `reviews` row** (the forgetting
  curve fits from the first real review, i.e. the next encounter). Logged to
  `activity_log` as a `learn` event; `review_count` stays 0.

## What v1 ships (implemented)

- `core/srs/learn_queue.dart` — pure `buildLearnQueue` + `isPretestSection`.
- `core/srs/srs_repository.dart` — `seedState` (graduation).
- `shared/providers/learn.dart` — `learnQueue` + `LearnSession` controller.
- `features/learn/learn_screen.dart` — the flow; `/learn` full-screen route.
- Home surfaces **Review — N due** and **Learn — N new**.
- Review queue is now **due-only** (un-seeded sections belong to Learn).

## Deferred to v2

1. **Typed + AI-coach deep mode** (task #11) and voice input.
2. **Calendar-day** throttle (v1 caps per *session*, not per day) with
   tier-then-frequency priority and *staged section birth* (lead with
   `## When to Use`, admit the rest over days).
3. Richer grouping: in-degree prerequisite topo-sort, size-cap/merge of
   families. The prerequisite-direction heuristic is the **shakiest** piece
   (a card links *out* to a more-advanced remedy, not a prerequisite) — validate
   on real families before trusting it. v1 orders by tier only.
4. Per-section `learn_mode: pretest|study` frontmatter override.
5. A **cram / study-ahead** mode that provably writes nothing to
   `srs_state`/`reviews` (for night-before use).
6. Optional explicit `state` column on `srs_state` if branch-on-row-existence
   proves insufficient for a future readiness gauge.

## Open questions (revisit after using it)

- Is the Good-gate too much friction in practice, or right?
- Is ~20 sections/session the right pace for dense multi-section cards?
- Should freshly-graduated items get a brief *blocked* review grace period
  before full interleaving? (Ties to `learning-science.md` open Q#1 — block vs
  interleave for *algorithm-pattern* first exposure specifically is unresolved.)

## Evidence caveats

All numeric defaults (family size, ~20/day, Good-gate, initial intervals) are
Anki/SuperMemo practitioner heuristics, **not** peer-reviewed constants — shipped
as tunable, not law. Pretesting-with-feedback and Mayer pre-training are
high-confidence effects; the *routing* of section→mode is a medium-confidence
design inference on top of them.
