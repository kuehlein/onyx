# Design: study load, cadence & the "Today" plan (task #57)

**Status:** built — cross-track daily plan shipped (task #57) · **Date:** 2026-09-11 (built 2026-09-20)

Onyx now has four practice modes — **learn** new concept cards, **review** them
(FSRS-scheduled), the **algorithms** track (solve + explain), and **system-design
mocks** — plus long-running goals (readiness, prep dates). The open problem: how
much of each to do per day/week so a user with ~2–3 focused hours makes real
progress without overload, and how the app should surface *what to do today*.

## Evidence base

Grounded in a verified deep-research pass (run wj1s0r2np; its search + adversarial
verify phases completed — the claims below are the confirmed ones — but the final
write-up step overflowed, so this doc is synthesized from the recovered claims).
Canonical sources named inline.

**Sustainable volume (deliberate practice).**
- Effective deliberate practice tops out at ~**2–4 hours/day**; benefit beyond
  4h is essentially nil and beyond ~2h is reduced. Some estimates put the truly
  effective window near **1h/day** (Baddeley & Longman 1978: one 1-hour typing
  session/day beat two 2-hour sessions). (Ericsson et al. 1993.)
- **Quality > duration**: 2 focused hours beat 4 half-focused. Each intense
  session consumes reserves; **full recovery is essential** or you risk burnout.
  Practicing fatigued/sleep-deprived is largely wasted.
- Diminishing returns are real: in violin-expertise replications, accumulated
  solitary practice explained only ~26% of skill variance (vs ~48% originally) —
  volume alone isn't the lever at higher skill.

**Spacing.**
- Distributed practice beats massed by **~15% on delayed recall**, robust across
  **317 experiments** (Cepeda et al. 2006). But the gap is an **inverted-U** —
  *too* long a lag hurts too. (FSRS already rides this for reviews.)

**Interleaving (mixing problem types).**
- Interleaved practice **roughly doubled** delayed-test scores vs blocked in
  controlled math studies (Rohrer & Taylor 2007; d≈1.0–1.2). Mechanism:
  interleaving forces you to **choose the strategy** (discriminate among
  confusable options), not just execute it — it cut discrimination errors ~46%→10%.
- **Caveats (where it doesn't apply):** interleaving helps most for **confusable**
  skills where picking the approach is the hard part; **blocking is better when the
  goal is to extract the commonality within one topic** (i.e. first exposure to a
  brand-new concept). It also **hurts in-session performance** even as it boosts
  retention (a "desirable difficulty" — learners feel worse, do better), so users
  won't intuit its value.

**Learning new material (worked examples).**
- For a **novice** on a new topic, **studying a worked example beats unaided
  problem-solving** (worked-example effect, d≈0.52; Sweller, cognitive load).
  Implication: first exposure = learn from the reference (our Learn mode / the SD
  card's reference solution), *then* interleave retrieval.

**Algorithms dosage.**
- A **finishable ~150-problem list (NeetCode-150) beats grinding 500+**; spaced
  **re-solves** (harder problems at shorter intervals) concentrate effort on
  weak spots. A realistic pace is ~one pattern-group/week at ~2h/day (≈5–7 weeks
  for the tree).

**System-design dosage (sources DISAGREE — flag this).**
- Practitioners split on frequency: some strong candidates do a **full mock daily**
  during active prep (one guide cites an interviewer doing one/day → ~15 offers);
  others (e.g. Exponent's 8-week plan) put **mocks in the last ~2 weeks** after
  fundamentals, ~2+ before the interview. Consensus points: **fundamentals first**
  (networking, DBs, caching, concurrency, distributed systems); a **small core set**
  practiced repeatedly (chat, URL shortener, news feed, search, notifications, file
  storage); **go deep on 1–2 components**, not broad-and-shallow; mocks' unique
  value is **communication under pressure** + reflection/debrief; and most people
  **start mocks too late** — pull them earlier.

**Concept review caps (Anki/FSRS community).**
- New-card intake drives steady-state review load: ~**20 new/day → ~200 reviews/
  day** once mature. Time→cap mapping used in practice: 20 min ≈ 5–8 new / ~100
  reviews; 40 min ≈ 12–15 new / ~180 reviews; 60 min ≈ 20–25 new / ~250 reviews.

**Taper near the interview.** Reduce *new* load before the event; preserve
high-value retrieval, confidence, pacing, and routine so fatigue drops without
skill decaying.

## Translating to Onyx's four tracks (proposed dosages)

For a user targeting ~2–3 focused hrs/day (adjust proportionally):

| Track | Cadence | Notes |
|---|---|---|
| **Concept review** (FSRS) | **daily, non-negotiable** | Whatever's due; this is the spacing engine. Cap the queue (see below) so it never becomes a wall. |
| **Learn new concepts** | **daily, capped** (~10–15 new/day at ~2–3h; scale with time budget) | Blocked/worked-example first exposure. New intake is the main dial on future review load — cap it. |
| **Algorithms** | **daily, ~2–4 problems** (solve or explain) | Spaced re-solves + explains; interleave patterns (don't block one pattern). |
| **System-design mocks** | **~2–3 full mocks/week** + optional short **scoped drills** on off-days | NOT daily full mocks (40 min each + fatigue). Fundamentals (the concept cards) carry the daily load; mocks are the weekly applied test. Pull earlier than instinct suggests. |

**Interleave across tracks within a day** (algos + SD + review mixed), because the
skills are confusable-adjacent and choosing the approach is the point — *except*
first-exposure Learn, which stays blocked (worked-example/commonality-extraction).

**Example week (~2–3 hrs/day):**
- **Every day:** clear due concept reviews (~20–40 min) + 2–3 algo problems (~30–45
  min) + a few new concept cards.
- **~3 days/week:** add a **full SD mock** (~40 min) instead of extra algos.
- **Off-mock days:** optional 10–15 min SD **scoped drill** (one component) or extra
  review.
- **As the interview nears (taper):** cut new-card intake; keep reviews + a couple
  of mocks/week + light algo re-solves; protect sleep.

## UX proposal — the "Today" plan

The core need: one place that answers *"what should I do right now, and how much?"*
without decision fatigue or a demotivating wall. Three directions:

**Option A — a "Today" card on Home (recommended).** A compact plan at the top of
Home listing the day's targets as checkable rows, each linking into its flow:
```
  Today                                   ~1h 40m
  ● Reviews          18 due          →   (FSRS)
  ● Learn            5 new           →
  ● Algorithms       3 problems      →
  ○ System design    mock due (2/wk) →   [weekly]
  ─────────────────────────────────────
  “Short on time? Reviews + 1 algo are the non-negotiables.”
```
- Per-type **quotas** derived from the dosages above (scaled to the user's time
  budget + taper). Reviews show the real due count; Learn/algos show today's
  target; SD shows "mock due" only on scheduled days (weekly cadence), else a
  quiet "scoped drill (optional)".
- A **"short on time" line** names the daily non-negotiables (reviews + 1 algo),
  respecting autonomy (SDT) rather than nagging.
- Rows gray out as completed; the whole card is a calm checklist, not a countdown.

**Option B — keep the current per-track Home buttons, add a "Today" summary
strip.** Lower-lift: a one-line "Today: 18 reviews · 3 algos · mock due" above the
existing buttons. Less prescriptive.

**Option C — a dedicated Plan screen** (own tab/route) with the week laid out.
Most powerful, most build; probably overkill before A proves useful.

**Recommendation:** build **A** — it directly answers "what today," encodes the
research dosages, degrades gracefully when short on time, and reuses the existing
flows (each row is just an entry point). It also gives SD its natural home
(weekly, surfaced only when due) — resolving the "should it move to the next mock"
question: the *plan* paces SD (≈2–3/wk), so the track itself just hands you one
mock at a time and you return when the plan says another is due.

## How this settles open questions

- **SD "next mock" cadence:** the Today plan owns it — SD surfaces ~2–3×/week, not
  back-to-back. The track stays "one mock, then Home"; the plan decides when the
  next is due.
- **Load control** already has pieces (coach load nudges, pace models, #49
  workload) — the Today plan is the *surface* that unifies them; reuse
  `computePace` / readiness rather than inventing new math.

## Open decisions (for discussion before building)

1. **Which UX** (A / B / C)?
2. **Are the dosages right** for you specifically (SD 2–3/wk? algos/day? new-cards
   cap)? Should they be **user-adjustable** (a "time budget" setting → auto-scales
   quotas) or fixed defaults?
3. **SD daily-mock disagreement:** default to ~2–3/wk (my read of the evidence +
   fatigue), with an option to do more if you want — agree?
4. **Taper:** auto-taper as a prep date nears (we have the dates), or manual?
5. Should the plan **hard-gate** (hide a track once its quota's done) or just
   **soft-track** (show progress, never block)? (SDT says soft.)
