# Design: the unified Study Plan — daily queue, meta-scheduler & data model (task #57)

**Status:** built (task #57) · **Date:** 2026-09-11 · builds on
`docs/study-cadence-design.md` (dosages/evidence) and reuses `docs/…` readiness.

The vision (from the user, 2026-09-11): replace the row of "go to a flow" buttons
on Home with a **prioritized daily queue** that tells you *what to do today and how
much* across the four flows (Learn, Review, Algorithms, System Design), sized to a
sustainable time budget, ramped up as the habit forms, gated so foundations come
first, aware of your level, and wired into the front-page **coach**. Underneath,
the four flows should share a **standardized data model** so all of this — the
queue, the coach, Home, and Insights — can be built once.

This doc structures that into research-grounded decisions + a **foundation-first**
roadmap, and flags the choices to settle before building.

---

## 1. What the research supports (and where I push back)

Grounded in the cadence research (`study-cadence-design.md`) + the interviewer
research + Onyx's existing readiness model.

- **Bounded daily budget, ramped.** Effective practice is ~2–4h/day (quality ≫
  volume); starting *small* and building a daily habit is sound (habit-formation:
  succeed at a tiny consistent dose, then grow). ✅ Your "start slow, ramp up"
  instinct matches both the fatigue evidence and habit research. The **time budget
  is the master knob**; the queue never exceeds it (exhausted study is low-value —
  don't even show it).

- **Proportions shift by level.** SD weight rises with seniority; algos are
  proportionally heavier for junior/new-grad loops; concepts underpin all. ✅ Your
  intuition matches the evidence *and* Onyx already encodes it: `targeting.
  weightForDomain` / `tierRelevance` give a level×domain weighting. **Decision:
  derive the flow proportions from the existing readiness weights** rather than a
  new hand-tuned per-level table (DRY; one source of truth).

- **Dependency gating (your tier intuition) — strongly supported.** You can't
  design a system without the building blocks; worked-example/cognitive-load
  research says novices must learn from references before unaided application, and
  every SD source says **fundamentals first**. ✅ So **gate SD on foundational
  comfort**, and — this is the good idea you flagged — **gate each SD *problem* on
  its own prerequisites**: every SD card already lists `## Related` concept cards,
  so we can unlock a problem only once you have enough coverage/strength in *its*
  prerequisites. This also makes "slow start" automatic: early on only Learn +
  Review + basic algos are available; SD problems light up as the relevant concepts
  mature.

- **Calendar-delaying SD — I push back.** You asked me to confirm that starting SD
  "too early" is *definitely* wasted. It isn't clear-cut: sources **disagree**
  (a daily-mock-from-early camp vs. a mocks-in-the-final-2-weeks camp), and the one
  robust point is that **most people start SD too *late***. So I recommend
  **dependency gating (comfort-based), NOT a calendar delay**. That honors your
  stronger intuition (prerequisites) and rejects the weaker one (time-based delay),
  and it's the safer read of mixed evidence. SD simply becomes available when your
  foundations are ready — which for a junior target may be "rarely/never" (correct:
  their loops are algo-heavy), and for senior/staff "soon and often."

- **Interleave flows within a day — supported, with one exception.** Mixing
  Algorithms + SD + Review in a day is good (interleaving ≈2× retention when the
  skill is *choosing an approach*). **Exception: first-exposure Learn stays
  "blocked"** (worked-example effect) — learning a brand-new concept shouldn't be
  interleaved with unrelated retrieval.

- **Meta-scheduling reviews — a real nuance / mild pushback.** Your "meta-FSRS that
  dispenses only a subset of due reviews to fit the time limit" is reasonable, but
  with a caveat: **capping reviews defers due cards (they get more overdue)** —
  unlike capping *new* cards, which safely controls future load. Standard practice
  (Anki) is: cap new intake hard; when reviews overflow the budget, surface the
  **most-overdue / highest-value subset today and let the rest roll to tomorrow**,
  accepting a little backlog. The right design: the meta-layer **budgets time and
  picks the highest-value subset to surface**, but the underlying FSRS still owns
  correctness — and the **coach flags** if the review backlog is trending up
  (signal: add time, or cap new intake). We layer over FSRS; we don't reinvent it.

---

## 2. The core abstraction — a unified "practice task" model (the foundation)

Today the four flows have parallel-but-separate providers (`reviewQueue`,
`learnQueue` + `dailyNewRemaining`, `algoQueue` + `algoTodayCount`,
`systemDesignProblems` + `sdAutoSupportMode`) and separate stats
(`mockSkills`, `algoStats`, retention). The daily queue, the coach, Home, and
Insights all need to treat them **uniformly**. So the foundation is a common
interface each flow implements:

```
abstract class PracticeTrack {
  TrackId get id;                       // learn | review | algorithms | systemDesign
  String get label;

  /// Work available now + its shape, for the meta-scheduler.
  Future<TrackAvailability> availability(); // { dueCount, newAvailable, unlocked,
                                            //   estMinutesPerUnit, ... }

  /// Research-/readiness-derived base importance (0..1) for this user+target.
  double baseWeight(TargetContext ctx);

  /// Recency / variety signal (how much done lately) for anti-monotony.
  Future<double> recencyLoad();

  /// Prerequisite gate: is this track (or item) unlocked yet?
  Future<GateStatus> gate();

  /// Uniform per-track stats for Home + Insights.
  Future<TrackStats> stats();
}
```

- This is an **additive layer**: each flow's existing scheduler (FSRS `srs_state`,
  recognition clock, applied attempts) stays exactly as-is and correct — we just
  expose a uniform *view* over it. No risky big-bang rewrite.
- The meta-scheduler, coach, Home queue, and Insights all consume `PracticeTrack`s,
  so each is written **once** over N tracks instead of N times.
- **Scope note / pushback:** you asked to "go through every route and DRY it all
  up." I'd do the **minimal unification the plan needs** here (the `PracticeTrack`
  interface + standardized availability/stats), and fold the *deeper* route/layer
  formalization into the release-hardening task (#51) so we don't formalize twice
  or stall the feature on a full refactor. (Design-system + architecture doc live
  in #51; this foundation is the slice #57 actually requires.)

---

## 3. The meta-scheduler (the daily queue engine)

A pure function: `buildDailyPlan(tracks, budgetMinutes, ctx) -> DailyPlan`.

**Inputs per track:** availability (due/new counts, est-minutes/unit, unlocked?),
`baseWeight` (from readiness/level), competence gap (weakest-domain / low
transfer), due pressure (FSRS overdue), and `recencyLoad` (down-weight a flow done
a lot recently — your example: Learn bumped for SD because SD hasn't run this week).

**Priority score per track** (tunable, all reusing existing signals):
```
priority = baseWeight(level,target)          // research × level × domain weights
         × competenceGap                     // weakest / lowest-transfer first
         × duePressure                       // FSRS overdue, cadence-due (SD ~2–3/wk)
         × varietyBoost(recencyLoad)         // ↑ if neglected lately, ↓ if overdone
         × gate(unlocked ? 1 : 0)            // prerequisites
```

**Time-budgeting (the key UX behavior you described):**
1. Order tracks by priority.
2. Greedily fill the day's **budget** (which ramps up over time — see §4). Each
   track contributes a right-sized chunk (e.g. reviews = as many due cards as fit;
   algos = N problems; one SD mock ≈ 40 min).
3. **Oversized flows get a subset:** if due reviews exceed the remaining budget,
   surface the **highest-value subset** that fits (most-overdue first) and note the
   rest roll over. (This is the "meta-FSRS over the sub-FSRSs" — but a *time budget
   allocator*, not a second scheduler.)
4. **Drop what doesn't fit:** low-priority tracks beyond the budget are **not
   shown** (don't invite exhausted, low-value work). A "if you have extra time…"
   affordance can reveal them optionally.
5. **Short-on-time:** the plan marks the **non-negotiables** (e.g. Review + 1 algo)
   so a rushed day still does the highest-value core.

**Estimating time:** rough per-unit estimates (review ≈ X s/card, algo ≈ Y min,
mock ≈ 40 min, learn ≈ Z/card) — imperfect is fine; used only to size the day.

All pure + unit-tested; it reads the `PracticeTrack` views, owns no scheduling.

---

## 4. Ramp-up, gating & level (the "sensible defaults")

- **Ramp:** the daily **budget** starts small (build the habit — a tiny reliable
  dose) and grows with sustained consistency (streak/adherence) toward the user's
  cap (research ceiling ~2–4h). Never auto-grow past the cap; the coach can suggest
  "ready for more?" (respecting autonomy).
- **Gating:** tracks/problems unlock on prerequisite coverage/strength (SD gated on
  foundational domains; per-problem via `## Related`). Early days: Learn + Review +
  basic algos only.
- **Level/target:** `baseWeight` comes from the readiness target's domain/tier
  weights — so a junior-FAANG target naturally weights algos up and SD down (often
  gated off), a staff target weights SD + deep concepts up. One source of truth.
- **Taper:** as a prep date nears, reduce *new*-card intake, keep reviews +
  mocks + light re-solves (the plan reads the prep date we already store).

---

## 5. Home redesign (info architecture)

Principle (HCI/dashboard norms): **lead with one clear "what now," progressive
disclosure, don't clutter.** Proposed Home, top → bottom:
1. **Slim progress header** — a condensed readiness/pace strip (the current box,
   trimmed to the one headline number + a thin bar; details on tap → the report).
2. **Today** — the daily queue (the primary content + actions). Checkable,
   priority-ordered rows with per-task est-time + "why" (due/weak/neglected); a
   "short on time → do these" marker; completed rows recede. This **replaces the
   flow buttons**.
3. **Coach** — KEEP the existing front-page coach (not removed); make it
   plan-aware (see §6). It stays a first-class element of Home.

(A light research pass on home information-density/overload is worth doing before
finalizing the exact layout — offered below.)

---

## 6. Coach integration (make it aware of everything)

The front-page coach becomes the **meta-awareness layer**. Feed its context the
plan state: today's queue + what you completed/skipped, budget vs. done, review
backlog trend, per-domain competence gaps, streak/adherence, and the ramp state.
Then it can converse about **load** ("you've hit your budget 5 days straight —
want to ramp up?" / "reviews are piling up — cap new cards or add 15 min?"),
**pace/readiness**, **weak areas**, and **adherence**. Reuse the existing
coach-update machinery (`docs/coach-personas.md`, coach-feedback-design) — the plan
just gives it richer, structured inputs. This is a first-class requirement, not a
bolt-on.

---

## 7. Analytics unification

Home's progress header and the Insights page should read the **same
standardized per-track stats** (`TrackStats`) — so numbers agree and each chart is
written once. Folds into the design-system/analytics consolidation in #51.

---

## 8. Roadmap (foundation-first)

0. **Align** (this doc) — settle the decisions in §9.
1. **Foundation — `PracticeTrack` model + standardized availability/stats.**
   Introduce the interface; refactor the four flows to expose uniform views over
   their existing schedulers; standardize per-track stats. (Additive; no scheduler
   changes.) *Everything else builds on this.*
2. **Meta-scheduler engine** (pure `buildDailyPlan` + priority scoring + time
   budgeting + subset-dispensing). Unit-tested hard.
3. **Gating + level proportions** — prerequisite unlock (track + per-SD-problem via
   `## Related`); proportions from readiness weights; SD weekly cadence.
4. **Ramp + budget** — the growing daily budget + taper from prep dates.
5. **Home redesign** — slim header + Today queue (replaces buttons).
6. **Coach integration** — plan-aware context + load/pace/weak-area conversations.
7. **Analytics unification** — Home + Insights on the shared stats.
8. Deeper route/architecture/design-system formalization → **#51**.

Each phase is shippable and testable; 1–2 are the load-bearing foundation.

---

## 9. Decisions to settle before building

1. **Foundation scope:** minimal `PracticeTrack` unification now + defer deep
   route/DRY cleanup to #51 (**my recommendation** — ships the feature without a
   giant upfront refactor), *or* do the full architecture formalization first
   (cleaner once, but slower and risks stalling this).
2. **Proportions source:** derive from existing readiness weights (**my rec**, DRY)
   vs. a new explicit per-level proportion table (more direct control, more to
   maintain / another source of truth).
3. **SD gating:** dependency/comfort-gated, not calendar-delayed (**my rec**, per
   §1). Confirm.
4. **Review overflow:** budget-and-surface-a-subset + roll the rest over + coach
   flags backlog (**my rec**) vs. never capping reviews (risk: walls of reviews).
5. **Ramp mechanism:** budget grows with consistency + coach suggests increases
   (**my rec**) vs. manual only vs. fixed.
6. **Gate strictness:** hard-lock a track until prerequisites met, or show it
   greyed with a "unlocks when you're comfortable with X" hint (**my rec** — softer,
   explains itself).
7. **More research?** A targeted pass on (a) home-screen information density /
   cognitive overload and (b) habit-formation ramp curves would sharpen §4–§5;
   worth it, or proceed on established principles and refine in build?

---

## 10. Refinements from discussion (2026-09-11) — CONFIRMED

**Per-flow time allocation (the "capping" clarified).** The meta-scheduler splits
the day's budget *across* flows (e.g. "~1h each") rather than draining it on the
single most-overdue flow. If 2h of reviews are due but the flow's allotment is 1h,
surface ~1h of the highest-value reviews and roll the rest over — likewise trim
algos/SD to their allotments. This deliberately **limits per-domain exposure per
day** to avoid going overboard on one at the expense of others (aligns with
interleaving + the fatigue ceiling). Deferred reviews get marginally more overdue;
the coach flags a growing backlog. Allotments come from the priority weights
(§3) normalized to the budget.

**Per-item time estimates + priority bin-packing (the "box" problem).** Problems
aren't uniform (implementing a BST ≪ knapsack), so you can't allot "30 min" to a
40-min problem. Fix:
- **`estMinutes` on the card** (frontmatter), used by the scheduler. Algos vary
  widely → per-problem estimates matter most; Learn → optional per-card override
  over a default (some concepts are genuinely harder); Review → a small default
  per card (× due count); **System design → time-boxed by format (~40 min full, or
  a ~15-min scoped drill), so SD is the *flexible* flow that absorbs leftover
  time.** Sensible type/tier defaults when a card omits it.
- **Bin-pack by priority within each flow's allotment:** take highest-priority
  items that *fit* the remaining minutes; if the top item (e.g. knapsack, 40m)
  doesn't fit today, schedule the next that fits (e.g. isPalindrome, 10m). The
  bumped item stays due and the FSRS/priority signal **elevates it further**, so
  it's #1 the next day and won't be bumped again. (No half-problems; important
  long problems aren't permanently squeezed out.)

**Prerequisite gating for the algo track too (not just SD).** Advanced algo groups
gate on their concept prerequisites; foundational groups are ungated from day 1
(you can do string/array problems immediately without "mastering strings" first).
Proposed mapping (a `requires:` frontmatter list on the `algo-*` card, or a
group→concept map; ungated if empty):
- **Ungated (day 1):** arrays-and-hashing, two-pointers, sliding-window, stack,
  binary-search, linked-list.
- **Gated on concept comfort:** trees ← binary-tree/bst; tries ← trie; heap ← heap;
  backtracking ← backtracking/recursion; graphs ← graphs/bfs/dfs; advanced-graphs ←
  dijkstra/mst/union-find; 1-D DP ← dynamic-programming-1d; 2-D DP ←
  dynamic-programming-2d; greedy ← greedy; intervals ← intervals. (math-and-geometry,
  bit-manipulation: ungated or lightly gated — no strong concept-card prereq.)
This generalizes the gate: a track/item unlocks when the prerequisite concept(s)
reach a comfort threshold (coverage/strength), same mechanism as SD.

**Show the time budget + a pausable stopwatch (inform, don't enforce).** Surface
each problem's expected time (e.g. "~40 min") where the user can see it, and give
the count-up `SessionTimer` a **pause** (not just start/reset). The app/AI never
*enforces* the limit — it just makes the intended dedication visible so the user
can self-manage.

**Keep the coach on Home.** Confirmed — the front-page coach stays; it's made
plan-aware (§6), not removed.
