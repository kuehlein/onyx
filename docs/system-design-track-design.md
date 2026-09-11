# Design: the System-Design practice track (flow 3)

**Status:** draft for sign-off · **Date:** 2026-09-10

## Goal

Give system design the same treatment the Algorithms track gave coding: a
**paced practice loop with real retention**, without pretending a design
interview is a flashcard. System design is an open-ended, *conversational*
skill — you drive a ~40-minute discussion (requirements → estimation → API →
data model → high-level design → deep dives → trade-offs) and are judged on how
you reason, not on one memorised diagram. So Onyx is the **mock-interview
scheduler and reflection layer**: it decides *which* problem to work, plays the
interviewer, grades you on a rubric, and feeds that into readiness.

This is the direct analogue of the algo track's "solve on your machine → reflect
in Onyx" and the SQL decision (productive skills are practised, not carded). The
concept cards (caching, sharding, consistent-hashing, CAP, message-queues…) are
the *vocabulary*; this track is *applying it under interview conditions*.

## Why this shape (research + product consistency)

- System-design ability is **transfer**, not recall — the readiness model already
  gates the system-design domain on applied evidence (Phase B), and that evidence
  has to come from somewhere. This track is the source.
- **Deliberate practice with feedback** beats passive review for productive skills;
  the AI interviewer + adversarial critic supply the feedback loop.
- **System-design weight rises with seniority** in the readiness target
  (`tierWeightsFor`), so for a senior/staff backend goal this track carries a large
  share of "are you ready" — it's the highest-leverage flow left to build.
- **Alex Xu "System Design Interview" Vol 1 & 2** is the canonical curriculum
  (already referenced in `docs/curriculum.md`); we author paraphrased reference
  cards, never Xu-verbatim (copyright-safe, ships as a reference profile).

## Core model: two modes per problem

Chosen: **mock-first, with a scaffold** (mirrors the algo track's execution +
recognition two-clock idea, adapted to system design).

| Mode | What it is | Where | Feeds | State |
|---|---|---|---|---|
| **Mock** (primary) | Full conversational AI interview: the coach gives the prompt, drives phases, probes "why X over Y?", pushes trade-offs; graded on an SD rubric (self + AI critic) | phone or desktop (talking/typing) | **applied-transfer → readiness** (the real signal) | an `AppliedAttempts` row (`source: 'sd-practice'`) |
| **Scaffold** (first exposure / upkeep) | Phase-by-phase checklist you fill (requirements/estimation/API/data/design/deep-dive/trade-offs), then reveal the reference and self-grade | phone, low-friction | lightweight recognition upkeep, **not** readiness | recognition clock (`3/7/16/35/90d`), reused |

**Guardrail (same discipline as the algo track): the scaffold never satisfies the
mock clock.** Filling a checklist is upkeep between real mocks; it does not stand
in for talking through the design, and it carries no readiness weight — only the
mock does. This keeps the readiness signal honest.

## Card structure (Decision 1 — a new card type in the vault)

Cards live in the vault as markdown, consistent with the rest of the app. New
card **`type: system-design`**:

- **Card = one canonical problem** (e.g. *Design a Rate Limiter*). One file per
  problem, tagged domain `system-design` with `tiers`.
- **Sections = the interview phases**, which double as the reference solution and
  the rubric checklist:
  - `## Problem & Requirements` (functional + non-functional, scope-narrowing)
  - `## Estimation` (back-of-envelope: QPS, storage, bandwidth)
  - `## API Design`
  - `## Data Model & Storage`
  - `## High-Level Design`
  - `## Deep Dives` (the 1-2 hard parts the interviewer drills)
  - `## Trade-offs & Bottlenecks`
  - `## Related` ([[wikilinks]] to the concept cards this problem exercises)
- **Quizzability:** unlike algo cards, sections are **not** independently
  FSRS-scheduled. The unit of practice is the *whole problem* (a mock). Sections
  are the reference/rubric scaffold. (Parser: `system-design` cards contribute no
  `srs_state` sections; they schedule via the track's own logic.)

This gives a clean reference solution, a scaffold, and the rubric structure from
one authored artifact — and the `## Related` links wire each problem back into the
concept graph ([[generalization-vision]], the second-brain direction).

## The SD rubric (reuse Phase B, new dimensions)

The `AppliedAssessment` model is domain-agnostic (`Map<String,int>` rubric). The
SWE-coding rubric is `[communication, approach, correctness, complexity,
edgeCases, independence]`. System design uses its own dimensions:

`[requirements, estimation, highLevelDesign, dataModeling, deepDive,
tradeoffReasoning, communication]`

Each 1-5; the mock produces an `appliedScore` (0-100) via the same mapping the
algo track uses, plus the **critic** (adversarial second grader) for variance
reduction. Stored as an `AppliedAttempts` row with `source: 'sd-practice'`.

## Scheduling & pacing

System-design problems are a **small set practised less often than algos** (a
mock is 30-45 min; you won't do several a day). The track is a **separate queue**,
excluded from review/learn/gym and from the algo queue:

1. Surface the **weakest / least-recently-mocked** problem first (weakest-link,
   like the readiness dashboard).
2. A light cadence goal — **"system-design mocks per week"** (default ~1-2), not
   per-day — so it never nags daily but keeps the domain warm.
3. The **scaffold** is the phone-doable upkeep option on days you won't do a full
   mock; its recognition clock decides which problems' *approach* to refresh.

## Interaction flows

- **Mock:** pick/continue a problem → "Start the mock" → interviewer persona
  (seeded with the problem + phase plan) drives the conversation, one phase at a
  time, probing trade-offs → at the end you self-assess, the critic grades, and an
  `AppliedAttempts` row is written → next problem surfaces weakest-first.
- **Scaffold:** "Warm up / review approach" → phase checklist, you fill each →
  reveal the reference section → self-grade recognition (solid/shaky/lost) →
  recognition clock advances. No readiness weight.

## Shorter mocks (future — two axes; scoped-problem is primary)

A full mock is ~40 min, which won't always fit. There are **two ways to make a
shorter session**, and the better one for real practice is a narrower *problem*,
not fewer *phases*:

1. **Scoped sub-problem (PRIMARY).** Instead of "design YouTube," practise a
   focused component that still goes through the *full depth* of an interview
   (requirements → estimation → API → data → design → deep-dive → trade-offs) on a
   smaller surface — e.g. "design YouTube's **live-streaming** ingest/fan-out," or
   "design **just the notification fan-out** for a feed." You get the complete
   interview *shape* and senior signal in ~10-15 min because there's simply less
   to design. This is realistic — interviewers routinely scope down or zoom into
   one component — and it's the highest-value short format.
   - Modelled as its own `system-design` card, tagged as a *scoped/component*
     variant with an `estMinutes` hint and (optionally) a `parent:` link to the
     full problem it's carved from. The scheduler offers "short (~15m)" vs
     "full (~40m)" simply by which card it surfaces. No new mechanics — just more
     cards, some full-scope, some component-scope.
2. **Partial coverage (secondary).** Drill a single phase of a full problem
   (estimation-only, one deep-dive curveball). Useful for hammering a specific
   weak *dimension*, but it does NOT give the full interview shape.

**Clock/readiness rule (applies to both):** the **full-problem mock clock is
cleared only by a full session of that problem.** A scoped variant is its *own*
schedulable item (its own clock); a partial-coverage session of a full problem
leaves that problem still due. Every session logs honest, coverage-weighted,
dimension-scoped evidence — the transfer math shrinks toward a pessimistic prior,
so short sessions contribute *some* signal without letting easy reps game "ready."

**Phase-1 hook:** the `AppliedAttempts` row records a `coverage` descriptor (which
phases/dimensions were graded) from day one. Authoring scoped-variant cards and
the short/full picker is a later phase; no schema/clock rewrite is needed to add
either. (Research the exact scoped-problem catalogue when we build phase 5 — good
component-level prompts matter as much as the full ones.)

## Timing the answer (a real need — STT hides it)

Practice is done by *talking* (speech-to-text), so the AI interviewer can't
reliably know how long the candidate took. A visible **count-up stopwatch** on the
mock screen lets the candidate see/record elapsed time (and compare against the
card's `estMinutes`). Build this by **generalising the existing gym `RestTimer`**
(`lib/features/quiz/rest_timer.dart`, currently count-*down*) into a shared timer
widget supporting both count-down (gym rest) and count-**up** (elapsed) modes —
reused by the SD mock and, optionally, the algo session. This DRY/generalisation
also serves the hardening goal (#51). The elapsed time can be stored on the
attempt as soft metadata (not a hard grade input).

## The AI interviewer — the highest-bar component (research-heavy)

The mock interviewer is the part of the app that most depends on AI quality. It is
an **in-app system prompt / persona** (sent to the Claude API via
`claude_service.dart`, like the existing coach personas) — NOT a Claude Code
"skill." Getting it right is a *prompt-engineering + interaction-design* problem,
and it must be researched thoroughly before writing. The interviewer must be
competent at:
- **Conducting** a senior/staff SD interview: opening prompt, letting the
  candidate drive, time-boxing phases, when to zoom in vs move on, not leading.
- **Probing** like a strong interviewer: "why this over X?", pushing on
  bottlenecks/failure modes/scale, injecting curveballs and changed constraints,
  detecting hand-waving and asking for specifics, following the candidate's design
  rather than a fixed script.
- **Subject-matter depth**: knowing the canonical solutions, the real trade-offs,
  the numbers, and the common candidate mistakes for each problem — enough to
  evaluate correctness and to challenge convincingly.
- **Calibration**: grading to a real rubric and seniority bar (what separates a
  mid from a staff answer), staying firm but never hostile, and giving a useful
  debrief.

**Plan:** a dedicated deep-research pass (how top companies run + evaluate SD
interviews; interviewer playbooks; rubrics; probing techniques; per-problem
gotchas) feeds a rigorous, layered system prompt (persona + conduct rules +
per-phase guidance + the specific problem's reference/rubric/pitfalls injected
from the card). Reuse the coach chat framework; the *prompt* is the hard part.

## Readiness & insights (Decision — yes, mocks feed readiness)

- Mock attempts feed `appliedTransferProvider` for the **system-design domain**,
  gating that domain's readiness exactly like algo solves do for their domains.
  This is the whole point — it turns "I've studied caching" into "I can *design*
  with it."
- `system-design` cards are **excluded from concept-coverage** (separate track),
  so they don't distort the deck's coverage denominator (same rule as algo cards).
- Insights: a **"System-design problems practised"** section (problems mocked,
  weakest dimensions across attempts — e.g. "estimation" consistently low), and
  the coach can nudge "you haven't mocked a design in N days."

## Content (Decision 2 — starter set first)

Author a **starter set of ~6-8 highest-frequency Xu problems**, validate the loop,
then expand to the full Vol 1+2 set:

1. Rate limiter
2. URL shortener / TinyURL
3. Key-value store (distributed)
4. Unique ID generator
5. News feed / timeline
6. Chat system
7. Search autocomplete / typeahead
8. Notification system

Each authored via the generate → independent-audit workflow (paraphrased, not
Xu-verbatim), with `## Related` links to existing concept cards.

## Phasing

1. **Core:** `system-design` card type + parser/schema + routing (exclude from
   main queues/gym/algo); seed the ~6-8 starter problems; the SD queue +
   weakest-first + per-week cadence.
2. **Mock mode:** the interviewer session UI + SD system prompt (phase-driven,
   trade-off-forcing; **research-heavy — see above**) + SD rubric + critic →
   `AppliedAttempts`. Includes the **count-up stopwatch** (generalised `RestTimer`)
   and the `coverage` hook on the attempt.
3. **Scaffold mode:** phase checklist + reveal + recognition clock upkeep.
4. **Readiness & insights:** wire applied-transfer for system-design; the
   Insights section + coach nudge; expand content toward full Xu Vol 1+2.
5. **Variable-length mocks (future):** the shorter-session picker (choose which
   phase(s) to drill); coverage-weighted partial evidence; full clock stays due
   until a full-coverage session. Hooks (`coverage` on the attempt, clock cleared
   on full coverage) are laid in phase 1-2; this phase adds the picker + UX.

## Reuse map (what already exists — see the infra survey)

| Need | Reuse | Change |
|---|---|---|
| Interviewer AI | `core/ai/coach.dart` (has SD guidance) | SD session/phase prompt |
| Second-opinion grade | `core/interview/critic.dart` | none |
| Assessment + transfer math | `core/interview/{assessment,transfer,applied_repository}.dart`, `AppliedAttempts` table | SD rubric dims, `source: 'sd-practice'` |
| Chat session state | `shared/providers/explain_chat.dart` pattern | clone for SD mock |
| Recognition clock | `core/srs/recognition.dart` | reuse for scaffold upkeep |
| Queue + session notifier | `core/srs/algo_queue.dart`, `shared/providers/algo.dart` pattern | SD-typed filter, per-week cadence |
| Card type + parser | `shared/models/card.dart`, `core/vault/card_parser.dart` | add `systemDesign` case + quizzability rule |
| Readiness wiring | `core/readiness/*` | system-design domain already weighted |

## Open questions / risks

- **New card-type ripples** through parser, indexer, schema doc, and tests —
  scoped but real (same as the algo track's card-type addition).
- **Mock length vs. mobile:** a 40-min conversation is long for a phone; the
  scaffold mode + resumable mock mitigate this. Confirm resumability is needed in
  phase 2.
- **Grading a whole design is noisier than grading one coding problem** — lean on
  the critic + rubric decomposition; don't over-trust a single mock's score
  (the transfer math already shrinks toward a pessimistic prior).
- **Not a `Track` enum value.** System design is a *domain* practised within the
  chosen career track (backend/etc.), not a career track itself — no `Track`
  change; it feeds the `system-design` domain readiness.
- **Content drift / copyright** — paraphrase Xu, cite; ship as vault data.
```
