# Readiness Dashboard — Design (for sign-off)

Status: **proposed** — research synthesized, awaiting decisions before implementation.

The dashboard is the app's *progress compass*: how ready you are, whether you're
ahead or behind toward a goal, and where to focus next. This document is the
research-backed design; it does not describe shipped code yet.

Grounded in three research passes (interview leveling standards, mastery metrics
from SRS data, and gamification/sense-of-progress) plus the existing
`docs/learning-science.md`. Key sources are cited inline.

---

## 1. Principles (what the research forces on us)

1. **Recall ≠ readiness.** Retrieval practice reliably builds *declarative*
   recall but shows little/no transfer to *novel problem-solving*
   ([PMC9987560](https://pmc.ncbi.nlm.nih.gov/articles/PMC9987560/)); this is our
   own established finding too (`docs/learning-science.md`). So a readiness number
   built only on flashcard recall **structurally overstates** true interview
   readiness. The transfer caveat is load-bearing, not decoration.
2. **Multi-dimensional, not one average.** Readiness has four dimensions (below);
   recall is the lowest-ceiling one.
3. **Per-target.** "Ready" for junior/typical-company is a very different bar than
   senior/FAANG. The model is parameterized by **level × company tier × track**.
4. **Honest over impressive.** Report a **band, not a point**; show the
   decomposition; let the number **go down** when knowledge decays; state plainly
   when we *can't* yet judge a dimension. Honesty is what makes it trustworthy
   (and is itself a competence signal).
5. **Mastery-framed, no dark patterns.** Motivate via genuine progress toward a
   self-chosen goal (autonomy + competence, per Self-Determination Theory), not
   points/badges/leaderboards/guilt. Every signal must map to something real.

---

## 2. The readiness model

### 2.1 Four dimensions (each 0–100 per domain)

| Dimension | Source | Notes |
|---|---|---|
| **Recall** (knowledge base) | FSRS stability + retrievability | Necessary, low ceiling; **saturates** (LeetCode data shows returns plateau ~500 problems, [interviewing.io](https://interviewing.io/blog/how-well-do-leetcode-ratings-predict-interview-performance)). A *gate*, not a driver. |
| **Applied problem-solving** | timed/novel solves; interview-mode grades | The **transfer proxy** — the thing recall can't measure. Highest DS&A weight. |
| **System design** | coverage of canonical problems + rubric depth | Weight **rises with level** (≈0 new-grad → dominant staff, [AlgoMaster](https://algomaster.io/learn/system-design-interviews/expectations-by-level)). |
| **Communication / mock** | interview-mode ("Answer the coach") + mock self-reports | Strong predictor; **volatile** — average over ≥3–5 sessions (single-interview R²≈0.41, [interviewing.io](https://interviewing.io/blog/after-a-lot-more-data-technical-interview-performance-really-is-kind-of-arbitrary)). |

### 2.2 Within a dimension, per domain: Coverage × Strength × Transfer

```
Coverage_d = required items started / required items in domain     # multiplicative → anti-inflation
Strength_d = tier-weighted mean of item strength, with a p20 floor  # weakest-link, so an average can't hide a gap
Transfer_d = novel-problem success, Bayesian-shrunk toward a pessimistic prior when sparse

Readiness_d = Coverage_d^γ · Strength_d · (τ + (1-τ)·Transfer_d)    # γ≈0.7 softens; τ≈0.5 caps recall-only
```

- **Item strength** from FSRS: retrievability `R(now)` for "can I recall it today"
  and a stability-anchored `durable = clamp(log S / log S_target, 0, 1)` for "is
  it locked in" (S_target ≈ 90–180 days). Use **stability**, not just R (R is
  trivially reset by cramming).
- **Never-studied vs struggling** are different: struggling items count as *low
  strength*; never-studied items count against *coverage* and are **not** dropped
  from the denominator (dropping them is the classic coverage-inflation trick).
- **Multiplicative** factors mean you can't reach "ready" by grinding a small
  subset to 99% while half the domain is untouched — the anti-Goodhart move.

### 2.3 Aggregate → overall

Combine `Readiness_d` across in-scope domains with **per-target weights**, and
**always show the weakest domain alongside the aggregate** (one weak domain is
disqualifying; averaging it away would be dishonest).

### 2.4 Report a band, not a point

Show e.g. **"62% (55–70%)"**. The band **widens** with low coverage, few novel
problems/mocks, and high lapse volatility; it **narrows** as real evidence
accumulates. Never show "Ready" from recall alone — **gate "Ready" on applied +
mock evidence** at the target's difficulty.

---

## 3. Dynamic targets (level × company × track)

The user picks a target; it sets **which domains are in scope** and **how the
four dimensions are weighted**. Illustrative weights (tune later):

| Target | Recall | Applied | System design | Comms/mock |
|---|---|---|---|---|
| New-grad · typical | 25% | 55% | 0–5% | 15–20% |
| New-grad · FAANG | 20% | 55% | 5% | 20% |
| Mid · FAANG | 10% | 45% | 25% | 20% |
| Senior · FAANG | 5% | 30% | 40% | 25% |
| Staff · FAANG | 5% | 20% | 45% | 30% |

- **Track** changes which domains count and their flavor: frontend → product/UI
  system design, lighter DS&A; backend → DBs/caching/queues; ML → +ML-system-
  design; mobile → platform design. Maps onto the existing domain tags + tiers.
- **Company tier** changes thresholds and difficulty: FAANG credits hard-tier
  solves and demands more mocks; typical companies accept fluent mediums.
- **TIER (1–4)** sets foundation-gating and the difficulty of generated novel
  problems within a domain.

---

## 4. Data we need to record

Today we store review rows (grade 1–4, S, D, elapsedDays, timestamp) and
`srs_state`. To judge readiness honestly we should add:

- **On each review:** `first_attempt_correct` (bool), `hint_level_used` (int),
  `response_ms` (int), optional `self_confidence` (1–5). First-attempt accuracy
  and hint-reliance are the cleanest "did they actually know it" signals; time is
  a fluency covariate; confidence is a **calibration check, not a score input**
  (low performers are the most overconfident).
- **A novel-problem / mock table:** `(domain, source, timestamp,
  unassisted_correct, hint_level, difficulty, novel_flag, note)` — the only
  source of the Transfer and applied signals. The **interview-mode coach**
  ("Answer the coach" + its advisory grade) is a natural feeder here, and the
  `practice_url` redirect can prompt a quick self-report after external practice.
- **Per (domain,tier) materialized stats** for fast dashboard render: coverage,
  strength mean + p20, counts, lapse rate, novel attempts/correct.

Everything else derives from data we already collect.

---

## 5. Progress & motivation UX (what to build, what to avoid)

**Adopt (evidence-backed):**
- **Headline readiness** (0–100 + band) toward the chosen target, able to decay.
- **Per-domain rows** with a bar + state (Strong / Developing / Needs work / Not
  started) and a **"Focus here next"** flag on the weakest 2–3 (autonomy-
  supporting guidance). Each domain is a sub-goal → keeps the goal-gradient pull.
- **Pace to a target date:** user sets an interview date; show calm status
  (On track / Slightly behind / Ahead) + the actionable rate to hit it. Time-
  bound goals amplify motivation ([goal-gradient](https://journals.sagepub.com/doi/abs/10.1509/jmkr.43.1.39)).
- **Earned baseline** via a short diagnostic so the bar starts non-zero (ethical
  endowed-progress — real, not fabricated).
- **Retention/mastery trend** ("what you'll still remember in 30 days"), not
  activity vanity counts.
- **Forgiving habit widget:** "5 of last 7 days" ring with auto-freeze/grace,
  **secondary** to readiness, neutral copy, never guilt.

**Avoid (dark patterns / overjustification):** XP/points currency, badge walls,
competitive or absolute leaderboards, guilt notifications, fake/decorative bars,
countdown urgency, any metric that rises from mere activity. Extrinsic reward
layers risk crowding out the strong intrinsic/job motivation the user already has
([Deci/Koestner/Ryan 1999](https://home.ubalt.edu/tmitch/642/articles%20syllabus/Deci%20Koestner%20Ryan%20meta%20IM%20psy%20bull%2099.pdf)).

---

## 6. Honesty mechanisms (non-negotiable)

- Band, not a point; widen when evidence is thin.
- Show the **decomposition** (Coverage / Strength / Applied / Design / Mock per
  domain) behind the headline.
- **Explicit transfer caveat** when novel-problem/mock count is low: *"Your
  recall is strong, but you haven't solved enough novel problems / done enough
  mocks to call this interview-ready."*
- Surface the **calibration gap** (self-confidence − measured accuracy).
- Let readiness **decrease** as knowledge decays.

---

## 7. Proposed phased implementation

The highest-signal dimensions (applied solving, system design, mock/comms) are
**not derivable from card reviews** — they need new instrumentation. So build
incrementally, but architect for the full model from day one.

- **Phase A (v1) — honest knowledge-base dashboard.**
  Per-domain **Recall** readiness (Coverage × Strength with the p20 floor) from
  FSRS; target selection (level × company × track) shaping in-scope domains +
  weights; pace-to-target-date; per-domain "focus here" rows; band + decomposition;
  the transfer caveat front-and-center. **Headline is labeled "Knowledge-base
  readiness," not "Interview readiness,"** because we can't yet measure the other
  three dimensions. The Recall dimension uses data we already store (`srs_state`
  stability + card tiers/domains), so **Phase A needs no migration** — the
  extra-signal columns + mock table land in Phase B, where interview mode is what
  actually produces those signals (there's no objective "correctness" or hint in
  the reveal-then-self-grade recall quiz).
  - *Status (implemented):* the panel, per-target recall weighting (system
    design rises with level; FAANG raises the durability bar to S≈120d), and
    coverage-pace-to-date are live. The target (level/company/track + date)
    persists to its own synced vault file `_meta/onyx-target.json` (kept
    separate from the DB-derived progress snapshot `onyx-state.json`), with a
    device-local preferences mirror. Pace is scoped to **coverage** ("cover
    your material by the date"), not interview-readiness, and reads recent
    new-section throughput from the local `activity_log`.
  - *Status (implemented):* a **current-level gauge**. The same recall model is
    re-scored against every rung of a level×company ladder; the longest cleared
    prefix (≥0.7 overall) is the inferred current level. A horizontal gauge
    shows a "you are here" pin against a "goal" flag so the user can recalibrate
    (aim Senior·FAANG, discover they're at Mid·FAANG today, apply accordingly).
    Recall-only, same honesty caveat — it's a knowledge-base level, not a
    mock-validated interview level.
- **Phase B — applied + mock dimensions (interview mode is the instrument).**
  The interview-mode coach (STT answer → AI probing/follow-ups → advisory grade)
  already resembles a real interview, so make it the *instrument* that captures
  the signals FSRS can't. Per attempt the coach emits a STRUCTURED assessment —
  a rubric (communication, problem-solving approach, correctness, complexity,
  edge cases, independence/hint-reliance), whether the probe was novel/transfer,
  and a 0–100 applied score — logged to the mock/novel-problem table. These feed
  the Applied + Comms dimensions and the Transfer factor; system design gets a
  coverage + rubric pass. Headline then graduates to true "Interview readiness."
  - **Grade reliability:** LLM grades are noisy, so (a) keep the AI's
    applied-assessment SEPARATE from the human's FSRS self-grade — the human tap
    still drives scheduling; the AI score only feeds readiness; (b) run a
    *bounded* adversarial second-opinion (a critic pass or a small self-
    consistency vote) on the applied score to catch mis-grades; (c) aggregate
    over many attempts and always present as a band — never trust a single grade.
  - *Status (implemented, increments 1–4):* applied_attempts table + coach
    structured assessment (rubric/appliedScore/novel/hintLevel) + the transfer
    factor are live. `Transfer_d` is a research-backed estimate (see
    [[phase-b-readiness-math]] / memory): weighted (novelty × recency-decay)
    applied mean, **shrunk toward a pessimistic prior** (M=0.4, k=3
    pseudo-attempts), with a **Beta credible band** (∝1/√n_eff — never Wald/CLT),
    folded in conjunctively via `τ+(1-τ)·Transfer_d` (τ=0.5) so weak/unproven
    applied performance caps a high-recall domain. The headline **graduates**
    from "Knowledge-base" to "Interview readiness" once any applied evidence
    exists; evidence-less domains are capped at the prior.
  - *Status (implemented, increment 3):* a bounded **adversarial second
    opinion**. After the coach logs an attempt, a separate skeptical grader
    (core/interview/critic.dart) independently re-scores the candidate's answers
    WITHOUT seeing the coach's grade (no anchoring); its `verifierScore` and a
    `verified` corroboration flag are stored on the attempt. The readiness
    signal uses the **mean** of coach + critic (variance reduction, per the
    LLM-judge-noise finding). Best-effort: a critic failure never disrupts the
    coaching turn.
  - *Status (implemented, increments 5–6):* applied_attempts now **sync to the
    vault snapshot** (v2; older v1 snapshots still restore) so mock evidence
    follows the user across devices like their progress. The dashboard shows the
    per-domain **decomposition** — transfer %, mock count, and any **contested**
    grades (where the critic disagreed) — an honest evidence-strength readout.
    **Phase B is functionally complete** (structured assessment → adversarial
    reconciliation → shrinkage/transfer-gating → graduated readiness, synced and
    surfaced).
- **Phase C — AI layer (tasks #23/#24).** Weak-area report + qualitative AI
  readiness assessment on top of the same data.

---

## 8. Open questions for sign-off

1. **v1 scope** — start with Phase A (honest recall-based dashboard + targets +
   pace), capturing extra signals for later? (Recommended.)
2. **Honesty label** — OK to call v1 "Knowledge-base readiness" (not "Interview
   readiness") until applied/mock exist? (Recommended — avoids overclaiming.)
3. **Targets in v1** — ship target selection (level × company × track) now, even
   with some dimensions stubbed, so the framing is right from the start?
4. **Data capture** — approve the schema additions (review-signal columns + a
   mock/novel-problem table)? This is a drift migration.
5. **Diagnostic** — is an initial "earned baseline" diagnostic in scope for v1,
   or later?
6. **Streak** — include the forgiving "N of 7" habit ring in v1, or defer?

---

## 9. Testing implications — beyond FSRS recall

FSRS tests *recall* (declarative). Readiness needs *applied/transfer* testing too
— a different KIND of test, not just more flashcards:

- **Recall review (have):** FSRS-scheduled flashcards → the Recall dimension only.
- **Applied / mock (interview mode):** novel, think-aloud, probed answers with a
  rubric-scored result — the transfer proxy, and the instrument for the AI
  signal capture above.
- **Novel + timed DS&A:** the real transfer test is solving an *unseen* problem
  in time. Pragmatic bridge: the `practice_url` redirect + a quick self-report
  ("solved medium X unaided in 25 min"), and/or AI-generated novel variants.
- **System design:** rubric-scored design prompts (breadth/depth/trade-offs/…).
- **Behavioral:** STAR prompts (relevant at every level; weight rises with level).

Principle: keep **recall practice** and **applied testing** distinct — readiness
leans on the applied side, and *novel-not-reseen + timed + think-aloud* are what
make an applied test valid. This is why the interview-mode coach (not more
flashcards) is the right vehicle for the readiness-grade signal.
