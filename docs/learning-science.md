# Learning Science — Research Synthesis

This document summarizes what the research actually supports for flashcard-based
SWE interview preparation, and what the evidence-based design implications are
for Onyx's card schema and quiz architecture. Claims are graded by their
evidentiary basis.

**Scope & purpose (#110, 2026-09-25).** Onyx is now a general, multi-subject study
platform; the principles here are **subject-general** — SWE interview prep is the
running *worked example* (it's the built content today), not the boundary. This is
the app's **evidence base**: the load-bearing decisions (the ADRs, the coach, the
schedule, the flow taxonomy) trace back to principles below, so a reviewer can audit
*why* a choice was made and drift is harder to introduce. Citations are given inline;
where a source is established canon but not re-verified in a given pass, that's marked.
The **Foundational frames** section (next) is the top-level orientation; the detailed
card-formulation, presentation, and cadence sections follow.

---

## Foundational frames (what the whole app rests on)

Four cross-cutting frames orient every flow and schedule decision. The detailed,
card-level research follows in later sections.

### Miller's pyramid — the competence ladder the flows target

**Confidence: High** | Source: Miller GE, "The Assessment of Clinical
Skills/Competence/Performance," *Academic Medicine* 1990;65(9 Suppl):S63–7.

Competence rises through four levels — **Knows → Knows how → Shows how → Does** — and
each level needs a *different* assessment: the bottom two are tested in writing, "shows
how" in a simulation, "does" only by observing real independent performance. Onyx's flow
taxonomy is deliberately a Miller ladder:

| Level | What it is | Onyx surface |
|---|---|---|
| **Knows** | facts / declarative recall | a card's declarative sections; first exposure in **Learn** |
| **Knows how** | apply the knowledge; recognition | **Review** retrieval (recall the principle + recognition triggers) — where flashcards top out |
| **Shows how** | perform in a simulated setting | the **practice/mock tracks** (algo re-solve, system-design mock, behavioral mock, `/practice`) |
| **Does** | independent real-world performance | the actual interview / on-the-job — **outside the app** (the "glue/next-steps" layer, #109); Onyx *logs* outcomes but can't administer "does" |

**Design implication:** flashcards alone reach **knows / knows-how**; "shows how" needs
the practice tracks (this is *why* the app pairs a card library with mock flows, and why
readiness must reflect where you are on the ladder, not just recall %). It is the same
boundary the transfer gap names below — Miller is the vocabulary for it.

### Performance ≠ learning (the knowing–doing gap)

**Confidence: High** | Source: Soderstrom NC, Bjork RA, "Learning versus performance:
An integrative review," *Perspectives on Psychological Science* 2015;10(2):176–199
(doi:10.1177/1745691615569000).

*Performance* (what you can do **during** a session) is an unreliable index of *learning*
(durable, later-retrievable change). Performance can spike while learning doesn't — and
desirable difficulties depress performance while **improving** learning. So in-the-moment
ease must never be trusted as evidence of durable mastery. This directly grounds:

- **Guarded Learn-Easy** ([[fsrs-exam-targeting]]; ADR-0014 / n0014): a single "Easy" on a
  just-seen card is *performance*, not proof of durable learning — so its first interval is
  capped rather than believed (`core/srs/srs_scheduler.dart`).
- **Mastered auto-collapse** needs `stability ≥ 21d` **and** `R ≥ 0.9` — not one good grade —
  because durable learning shows as retained stability *across spacing*, not a lucky rep
  (`core/srs/mastery.dart`, 1f.1b).
- **The coach distrusts self-report**, fusing it with adherence + retrieval accuracy (cadence
  section) — self-rated ease is performance-flavored and biased.

### Transfer of learning — near vs far

**Confidence: High** | Source: Barnett SM, Ceci SJ, "When and where do we apply what we
learn? A taxonomy for far transfer," *Psychological Bulletin* 2002;128(4):612–637
(PMID 12081085).

Transfer is applying what you learned in a *new* context; it runs on a **near ↔ far**
continuum (Barnett & Ceci give 9 dimensions across *content* — what transfers — and
*context* — when/where: knowledge domain, physical/temporal/functional/social setting,
modality). **Near** transfer (a trained pattern, lightly varied) is reachable by retrieval
practice; **far** transfer (a genuinely novel problem/domain) is hard and needs *varied*
practice, not more reps of the same. This formalizes the "transfer gap" (§2 below): Onyx's
cards build the **near** substrate (fast, reliable pattern recall); the **far** skill —
recognizing which pattern a novel problem wants — is trained by the practice tracks +
real problems, and the app is honest that flashcards can't manufacture it alone.

### Implementation intentions — the basis for action nudges

**Confidence: High** | Sources: Gollwitzer PM, "Implementation intentions: Strong effects
of simple plans," *American Psychologist* 1999;54(7):493–503; Gollwitzer PM, Sheeran P,
"Implementation intentions and goal achievement: A meta-analysis of effects and
processes," *Advances in Experimental Social Psychology* 2006;38:69–119.

A goal intention ("study more") is far weaker than an **implementation intention** — a
concrete *if-then* plan ("**when** it's after dinner, **then** I do today's plan"). The
2006 meta-analysis (94 tests, N > 8,000) found a **medium-to-large effect (d = .65)** on
goal attainment; if-then plans help initiate action, shield ongoing pursuit, and enable
disengagement from failing courses. This grounds:

- **The daily plan is an implementation intention made concrete** — "today = *these* flows,
  *this* budget," not a vague "review some cards."
- **Action-oriented, specific nudges** over generic ones (the behavioral "about ready" nudge
  should say *what to do next*, not just a status — #107); the one-tap adaptive-load nudge.
- **"Two taps to first review"** onboarding — collapse the gap between intent and first action.

### Notification fatigue — the basis for silence-by-default

**Confidence: High** | Source: Ancker JS et al., "Effects of workload, work complexity, and
repeated alerts on alert fatigue in a clinical decision support system," *BMC Medical
Informatics and Decision Making* 2017;17:36 (doi:10.1186/s12911-017-0430-8); the broader
healthcare **alarm-fatigue** canon (e.g. Joint Commission Sentinel Event Alert 50, 2013)
generalizes.

More alerts → **worse** response: acceptance dropped ~**30% for each additional reminder**
per encounter, via desensitization from repeated exposure (clinicians override 49–96% of
interruptive alerts). A study app that pushes notifications to "drive engagement" trains the
user to ignore it. This grounds [[coach-feedback-design]] and **ADR-0011's silence-default**:
the engine adjusts the invisible *mix* silently; it **proposes only on a real signal**, is
**pull-based** (surfaces when the user opens the app) and **one-tap**; proactive/ambient
notify is **deferred** (#110 / ADR-0011 Phase C) precisely because notification volume erodes
the response it depends on.

---

## AI-mediated learning: elicit, don't explain

Onyx uses AI as a coach/tutor (today's study coach; the planned **first-exposure tutor**, #26).
The evidence on AI tutoring is sharply **double-edged**, so the design principle here is
load-bearing: **the AI's job is to make the *learner* do the thinking — ask, don't tell.**

### The dominant risk: an AI that *explains* manufactures an illusion of competence
**Confidence: High** (converging 2024–25 evidence). When a learner lets AI generate the answer
or explanation, short-term *performance* rises but durable *learning* does not — the
**performance ≠ learning** gap (above) in its most acute form. Studies report AI-assisted
learners producing better immediate work with **no gain on delayed tests**, plus **less
self-correction and reflection** ("metacognitive laziness" / cognitive offloading). Sources:
[KQED — metacognitive laziness](https://www.kqed.org/mindshift/65511/university-students-offload-critical-thinking-other-hard-work-to-ai);
[OECD, "fast AI"](https://www.thesify.ai/blog/impact-generative-ai-student-learning-oecd);
[distinguishing performance gains from learning (2026)](https://arxiv.org/pdf/2605.13731).
**Implication:** an AI that *lectures the concept at* the learner is the *worst* version of a
tutor — avoid it.

### The fix: the AI asks; the learner generates
**Confidence: Medium–High.** Socratic, question-driven tutoring (the AI elicits reasoning) beats
didactic AI for reflection and critical thinking; a purpose-tuned Socratic model outperformed
GPT-4 on teaching quality by ~12% ([SocraticLM, NeurIPS 2024](https://proceedings.neurips.cc/paper_files/paper/2024/hash/9bae399d1f34b8650351c1bd3692aeae-Abstract-Conference.html);
[ChatGPT vs. human tutors for critical thinking, Frontiers 2025](https://www.frontiersin.org/journals/education/articles/10.3389/feduc.2025.1528603/full)).
The mechanism is our own principles: a well-aimed question forces **active recall / generation**
and **self-explanation**, keeping the cognitive work with the learner. **Design rule:** the
tutor's move is *a question that makes the learner explain*, never a mini-lecture.

### But questioning has moderators — scaffold it at first exposure
**Confidence: Medium.** Elaborative interrogation ("why is that true?") and self-explanation are
**moderate-utility** — real, but below retrieval practice / spacing — and their benefit **shrinks
when prior knowledge is low** and grows when elaborations are **self-generated and precise**
([Dunlosky et al. 2013](https://pubmed.ncbi.nlm.nih.gov/26173288/)). First exposure is *exactly*
low-prior-knowledge, so a **cold** interrogation is weak and frustrating. Scaffold it: let the
learner engage the **source material** first, then ask questions grounded in what they just read
(self-explain it), rather than quizzing a blank slate.

### A productive guess *before* the answer helps
**Confidence: High.** The **pretesting effect**: an *unsuccessful* retrieval attempt before seeing
the material improves later retention (with feedback) versus errorless study
([Richland, Kornell & Kao 2009](https://pubmed.ncbi.nlm.nih.gov/19751074/)). So "guess first, then
read/discuss" is well-founded — and Onyx's Learn already does mental-attempt → reveal for cue
sections.

### Guardrail: LLM tutors leak the answer
**Confidence: High** (engineering finding). Told to "tutor," off-the-shelf LLMs readily give the
answer away; staying Socratic needs an explicit **answer-withholding** discipline (a supervisor /
withholding layer) ([Teaching an LLM tutor to withhold the answer, 2026](https://arxiv.org/pdf/2608.12292)).
Onyx's coach persona (`grading:false`, hint-laddered) already leans this way; a first-exposure
tutor needs the same in its prompt + behavior.

**Net for the #26 tutor:** ask questions that make the learner **explain the content**, **grounded
in the source** (not a cold quiz), ideally after a **guess**, with the AI **withholding answers**
and **never lecturing** — short, learner-generated exchanges (effort helps only on *success*; don't
let the AI do the thinking).

---

## What the Research Confirms

### 1. Rule-based encoding produces more durable retention than rote memorization

**Confidence: High** | Sources: PMC12108632, PMC11461721

A controlled study (N=292, two-session design) found memorization-based
performance dropped significantly between sessions while rule-based performance
showed no significant time effect (F=0.84, p=0.841). The mechanism is that
rules provide a generative schema — you can reconstruct the specific answer from
the principle, so the trace doesn't decay as fast.

**Card design implication:** Every card should lead with the underlying pattern
or rule, not the specific instance. Don't write: "BFS uses a queue." Write:
"BFS works by exploring all neighbors at the current depth before going deeper —
the queue enforces this level-by-level property."

The goal is for the reader to be able to *derive* specific facts from the
principle, not merely recognize them.

---

### 2. Retrieval practice, spaced repetition, and interleaving outperform passive study — but retrieval practice does not consistently produce transfer to novel problems

**Confidence: High** | Sources: Brown/Roediger/McDaniel (Make It Stick), Springer 2023

The three pillars of evidence-based learning:

- **Retrieval practice** (actively recalling, not re-reading) strengthens memory
- **Spaced repetition** (FSRS) optimizes when to review for maximum retention
- **Interleaving** (mixing topics) produces more durable learning than blocking

However: a 2023 multi-experiment study (Psychonomic Bulletin & Review) found
retrieval practice improves memory for *trained* problem types but was
"insufficient to produce differential transfer of learning among the training
conditions on the posttest." Problem-solving practice and passive restudy
produced statistically equivalent transfer to novel analogous problems.

**The critical implication:** Flashcards alone will NOT make you good at
applying patterns to problems you haven't seen. They build a stable,
quickly-accessible library of known patterns — which is valuable and necessary,
but not sufficient. This is not a failure of the flashcard medium; it is a
feature: Onyx builds the library; you still need to practice with novel
problems (LeetCode, mock interviews) to develop the transfer skill.

This also clarifies the correct objective for card design: **optimize for
fast, reliable pattern recall** (which flashcards can do), not for interview
simulation (which they cannot do).

---

### 3. Interleaving topics within sessions produces more durable retention than blocking

**Confidence: Medium** | Source: Make It Stick (secondary); Frontiers in Psychology 2023

Doing "graph week" and then "DP week" is less effective than mixing topics
within sessions. The desirable difficulty of having to re-orient between topics
strengthens encoding.

**Nuance:** A 2023 study found that executive function moderates the benefit.
Novice learners or those under high cognitive load may benefit from some
blocking first before transitioning to interleaving. Practical implication:
block early (when first learning a topic from scratch), then switch to
interleaving for review.

**Architecture implication:** The quiz scheduler must reorder FSRS-selected
items to interleave tags within sessions. See architecture.md.

---

### 4. Popular flashcard heuristics lack strong empirical support

**Confidence: Medium** (confirmation of absence)

The following were killed in adversarial verification:

| Heuristic | Vote | Assessment |
|---|---|---|
| Minimum Information Principle (one fact per card) | 0-3 killed | Not empirically validated |
| Cloze deletion > Q&A | 0-3 killed (twice) | Not empirically validated |
| Sets > 5 items are unlearnable | 1-2 killed | Not empirically validated |
| Atomic cards produce better retention | 0-3 killed | Not empirically validated |

**What this means in practice:** These heuristics are practitioner wisdom from
Wozniak's self-experimentation and Anki community consensus. They may still be
reasonable *defaults*, but you should not follow them rigidly. For SWE
interview content, a card with a rich multi-part back (e.g. a complexity table,
a "when to use" section, an invariant list) is *not* empirically worse than
splitting it into six atomic cards. Use your judgment.

---

## 5. Evidence-based formulation rules (verified research pass, 2026-09-08)

A second adversarial research pass (25 sources, 23/25 claims confirmed) revisited
card *formulation* against primary sources. It **reconciles** — not overturns — §4.

### Active recall beats recognition; effort helps *only on success*
**Confidence: High** | Roediger & Karpicke 2006 (primary RCT).
Producing an answer (short-answer recall) beats choosing one (recognition), and
repeated successful retrieval compounds. Crucial nuance: **effortful retrieval
helps only when it *succeeds*.** A card so overloaded or ambiguous that the reader
fails the recall gives no benefit — and, in FSRS terms, a failing card lapses and
churns instead of building stability.
**Rule:** each quizzed section must be *answerable from its cue* — challenging but
winnable, not a wall of facts that guarantees failure.

### Interference is the leading cause of forgetting — disambiguate siblings
**Confidence: High** | Wozniak (SuperMemo 20 Rules); McGeoch 1932.
For a maturing deck, confusion *between similar items* is the single biggest cause
of forgetting — more than any single card's difficulty. Onyx's deck is dense with
confusable siblings (TCP/gRPC/GraphQL/WebSockets; consensus vs. consistency
models; the whole caching family; 2PC vs. saga).
**Rule (net-new, highest-value):** when a card is near-adjacent to others, add an
explicit *contrast cue* — a "vs. X" line or a comparison row that names the
distinguishing signal — so the two never blur. Prefer precise, unambiguous prompts
over generic ones ("When to reach for a *heap* over a sorted array" beats "When to
use").

### Minimum-information — as a *soft* default, applied within sections
**Confidence: Medium (doctrine, not RCT).** The new pass confirms the minimum-
information principle *as expert doctrine*; §4 correctly notes no RCT shows atomic
cards retain *better*, and Matuschak warns over-atomizing yields shallower
understanding. Reconciliation for Onyx: keep the rich, principle-based card, but
make **each quizzed section target one coherent idea with the shortest sufficient
answer.** Split a section that secretly bundles several independent facts; don't
shatter a coherent idea into trivia.

### Don't make rote enumeration the recall target
**Confidence: Medium.** Long *unordered* lists resist recall. (The popular fix
"turn lists into narratives" was **killed 0-3** — do not do that.) Instead, make
the recall target the **principle that generates the list**, or group/structure a
long list so it's reconstructable, not memorized by brute force.

### Spacing/timing is the scheduler's job
**Confidence: High** | Cepeda 2006/2008; Karpicke & Roediger 2007.
No single optimal gap exists and delaying the first retrieval is the key desirable
difficulty — but FSRS already handles all of this. **Nothing to author here**;
just don't fight the scheduler (no cramming semantics baked into cards).

---

## The Three Knowledge Types — and Why Conditional Knowledge Is the Priority

This is a *complementary* lens to Miller's pyramid above: Miller ranks the **level of
competence** (knows → does); this ranks the **kind of knowledge**. They meet at the top —
*conditional* knowledge (when/why) is what powers "knows how / shows how."

Research on knowledge types distinguishes:

| Type | Example | Stability | Importance for interviews |
|---|---|---|---|
| **Declarative** | "What is a min-heap?" | High | Medium — foundation |
| **Procedural** | "How do you heapify an array?" | Medium | Medium — implementation |
| **Conditional** | "When should I use a heap vs. a sorted array?" | Low (hardest to learn) | **Highest** — what interviewers test |

Interviewers do not ask "what is BFS." They give you a novel problem and watch
whether you recognize which technique applies. **Conditional knowledge —
knowing when and why — is the primary interview skill and the hardest to build
via flashcards.** This maps directly onto the transfer gap above: retrieval
practice builds recall of trained patterns, but the transfer bottleneck is
pattern recognition in novel contexts.

### Implication for card section design

Every SWE interview card should explicitly train all three types, with the
highest emphasis on conditional knowledge:

- **Declarative:** "What is X / Key Properties" section
- **Procedural:** "Implementation Notes" section  
- **Conditional:** "When to Use / Recognition Triggers" section — **this is the
  most important section and should be the one that gets reviewed most often**

The "Recognition Triggers" section should encode *problem characteristics* that
signal when to reach for this pattern — not abstract rules, but concrete signals
a reader can look for when reading a problem statement.

---

## Recognition Triggers — The Key Concept

A Recognition Trigger section encodes conditional knowledge as observable
problem signals. The format should be:

```
**Problem signals that suggest this approach:**
- You see "find minimum/maximum of a dynamic, changing set"
- You need O(log n) inserts with O(1) minimum access
- Keywords in the problem: "top K", "kth largest/smallest", "median of stream",
  "merge K sorted lists"
- You need to process elements in priority order

**Prefer this over alternatives when:**
- Over sorted array: when you also need inserts (not just reads)
- Over BST: when you only need min/max, not arbitrary range queries
```

This format trains both the "when does this pattern apply" skill and the
"why this over the alternatives" comparative reasoning skill — both of which
are what interviewers are actually testing.

---

## App Usage Guidance (to inform onboarding copy)

Based on the research, the correct mental model for Onyx users:

1. **Onyx builds your pattern library.** It ensures you can rapidly recall
   algorithm patterns, complexity, invariants, and — most importantly — the
   recognition signals that tell you when a pattern applies.

2. **Flashcards do not replace problem practice.** The transfer gap is real.
   After building a solid pattern library in Onyx, you must also practice novel
   problems (LeetCode, mock interviews) to develop the ability to apply patterns
   flexibly. Onyx and problem practice are complementary.

3. **Interleave topics.** When Onyx mixes BST, graph, and DP cards in the same
   session, that is intentional — it is more effective than reviewing all
   tree-related cards before moving to graphs.

4. **Cards encode principles, not answers.** A card's back should teach the
   rule that generates the answer, not just the answer itself. If you can
   reconstruct a specific answer from the principle on the back, the card is
   well-designed.

---

## Open Research Questions (for intellectual honesty)

These questions were not resolved in the verified evidence:

1. Does the rule-based encoding advantage generalize from abstract categorization
   tasks to algorithmic pattern recognition specifically?

2. Does retrieval practice improve the *recognition* bottleneck for
   programming problems, or only the *execution* memory?

3. What is the optimal interleaving granularity — topic level (trees vs.
   graphs), pattern level (BFS vs. DFS), or difficulty level?

4. How should procedural knowledge (implement X) be encoded differently from
   declarative and conditional knowledge to maximize both retention and transfer?

---

## Summary for Practitioners

Design cards to encode **rules and recognition triggers**, not rote facts.
Trust the FSRS scheduler for timing. Trust interleaving for session ordering.
Do not obsess over card atomicity — there is no peer-reviewed evidence that
splitting every card into six mini-cards produces better results than one
well-structured card. **Do** make each quizzed section answerable from its cue
(effort helps only on success) and **actively disambiguate confusable sibling
cards** (interference is the top cause of forgetting). Use Onyx to build the
pattern library; supplement with novel problem practice for transfer.

---

## Presentation & Visual Design

The sections above concern *content*. This one concerns how a card is *shown* —
grounded in cognitive load theory, Mayer's multimedia principles, WCAG, and the
readability literature. (Synthesized from a research pass; the named works are
established but exact citations weren't live-verified.)

### Typography & contrast

**Confidence: High.** On dark themes, pure white on pure black causes *halation*
(glyphs bloom into the dark field) and reads as an undifferentiated wall. Use
**off-white text on a dark-gray surface**, never `#FFF` on `#000`. Body prose at
**~16px, line-height 1.5**, with generous spacing between blocks. Cap line length
to a **readable measure (~66 characters)** even on wide screens — long lines hurt
comprehension. Build hierarchy from **weight, opacity tiers, and a single accent
hue** (Mayer's *signaling* principle), not a riot of colors; over-cueing cancels
the benefit.

### Segmentation & progressive disclosure

**Confidence: Medium-High.** Mayer's *segmenting* principle (learner-paced chunks)
reliably helps, most for complex material and novices. But hiding content behind
a click has a cost: collapsed sections are under-explored ("out of sight, out of
mind"). Reconciliation: **always chunk; collapse selectively.** Keep the card's
*core teaching* visible; collapse only supplementary/long/already-known material,
and **label collapsed sections** so the reader can decide to expand. In Onyx the
core ≈ the quizzable (scheduled) sections — these stay expanded and accented; the
rest collapse by default.

### Syntax highlighting

**Confidence: Medium.** Sarkar (2015) found syntax colouring reduces code
comprehension time, with the benefit **larger for novices** and shrinking with
expertise. Use a **restrained palette** and — critically for a learning tool —
keep **comments legible** (many dark themes render them below 4.5:1; lift them).

### Inline links vs. a deferred "Related" section

**Confidence: High (that inline links raise load).** DeStefano & LeFevre (2007)
reviewed hypertext reading and found embedded links generally **increase
cognitive load and often decrease comprehension** — each inline link forces a
"click or not?" decision and invites disorientation. This is the *seductive
details* / *coherence* problem applied to navigation.

**Design implication for Onyx:** keep the study passage **linear and link-free**;
surface concept connections in a **deferred "Related" section** after the
content, curated to a few high-value links. This is the evidence-based default
and the one Onyx follows. If in-body concept links are ever added (the
"Wikipedia-style" idea), make them **low-cost and deferred** — subtly marked, no
navigation on a stray tap, connection revealed on explicit long-press/expand —
rather than bright inline jumps. (Note: card wikilinks currently render as inert
`[[slug]]` text in the body; making them interactive is exactly this decision.)

---

## Study cadence, deadlines & the coach (research pass, 2026-09-22)

Confirms the **ease-in → ramp → coach-adjusts** model and the **per-aim, deadline-weighted
allocation** are compatible and evidence-based. They are orthogonal: the ramp/coach set the *size*
of the day; aims set the *mix* within it.

### Ease in, then ramp up — SUPPORTED
Habit strength builds along an asymptotic curve and simpler behaviors automate faster (Lally 2010,
ejsp.674) — argue for a small starting load. Early **consistency** predicts long-term adherence far
more than early **volume** (large beginner-app cohort: first-28-day consistency the strongest
predictor of retention; longer sessions not protective without frequency — PMC13500638). Overloading
a novice raises cognitive load and drops engagement (Sweller). **Implication:** the ramp's job is to
keep the daily target *completable every day*; escalate gently (≈10%/wk-style), gated on adherence.

### Deadline-weighted allocation across concurrent aims — WORKABLE, with two guardrails
- **Interleaving related aims over one deck is a *desirable difficulty*** (Taylor & Rohrer 2010 —
  mixing roughly doubled delayed-test scores), *provided* the material is similar/confusable (it is —
  one deck). Don't force-mix unrelated content just to interleave.
- **Prioritizing by deadline is legitimate self-regulation** — agenda-based regulation (deadlines/
  constraints override pure difficulty selection) + region-of-proximal-learning (spend effort on
  not-yet-known-but-reachable items; diminishing returns on mastered or too-far items). This is why
  urgency = **feasibility** (required-vs-actual pace), not a naive time-ramp: it's the "weakest-link
  that's still reachable."
- **Guardrail 1 — spacing scales with the horizon, so a nearer deadline legitimately compresses
  spacing, but never to massing.** Distributed practice beats cramming for durable retention (Cepeda
  2006, 317 experiments); optimal gap ≈ 10–20% of the retention interval. Honor a deadline the
  **FSRS-safe way** (raise desired retention toward the date + a final pre-date review; don't hack the
  schedule) — [[fsrs-exam-targeting]].
- **Guardrail 2 — a per-aim retention floor.** De-prioritized material decays below its spacing
  cadence (forgetting curve). Urgency reallocates *new-learning emphasis* above a **minimum due-review
  floor** per active dated aim; it must not starve one to zero.
- Multiple goals are fine when they don't compete incoherently (goal-setting theory: conflicting
  goals hurt) — a single shared time budget + explicit feasibility-weighted allocation is the coherence
  mechanism.

### Coach adjusting load from data + self-report — SUPPORTED, with guardrails
- **Preserve autonomy** (SDT autonomy-support meta-analysis, 378 effect sizes): propose changes *with
  rationale* + real choice; avoid controlling tone and performance-contingent pressure. Structure and
  autonomy are complements — a clear recommended load offered supportively is pro-autonomy.
- **Fuse three signals; distrust self-report alone** — adherence/completion + retrieval-practice
  accuracy (the reliable competence signal — testing-effect g≈0.5–0.6) + self-reported load.
  Self-monitoring is biased, worst for at-risk learners (calibration/overconfidence research).
- **Adjust gently; don't over-guide.** Trigger on a data signal, not preemptively; small steps;
  avoid over-scaffolding + always-accept defaults that invite gaming (assistance-dilemma research).
  Onyx's one-tap-nudge + conversational-apply shape already matches.

**Net:** the cadence model holds up unchanged in shape; aims layer beneath it. The two things the
research *adds* to the build are the **retention floor** and the **FSRS-safe cram** (with an honest
coach warning when an aim is infeasible / the cram is incoherent).
