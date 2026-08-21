# Learning Science — Research Synthesis

This document summarizes what the research actually supports for flashcard-based
SWE interview preparation, and what the evidence-based design implications are
for Onyx's card schema and quiz architecture. Claims are graded by their
evidentiary basis.

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

## The Three Knowledge Types — and Why Conditional Knowledge Is the Priority

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
well-structured card. Use Onyx to build the pattern library; supplement with
novel problem practice for transfer.
