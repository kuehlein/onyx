# ADR 0015 — AI-tutor first exposure: a learner-invited, grounding-only Socratic step in Learn

- **Status:** Accepted (design; build sliced — not yet implemented)
- **Date:** 2026-09-25
- **Deciders:** Kyle Uehlein
- **Related:** task #26; ADR-0004 (AI provider seam), ADR-0008 (FSRS integrity), ADR-0011
  (load control / silence-default / minimize-knobs), ADR-0012 (card model shared components),
  ADR-0003 (card status / draft choke point), ADR-0014 (guarded self-grade, n0014);
  `docs/learning-science.md` ("AI-mediated learning: elicit, don't explain" + "Foundational
  frames" / Miller); stories `docs/user_stories/card.md` + `home.md` (+ the taxonomy line in
  `index.md`); code `lib/core/ai/coach.dart`, `lib/shared/providers/coach.dart`,
  `lib/shared/widgets/coach_sheet.dart`, `lib/features/learn/learn_screen.dart`,
  `lib/core/srs/learn_queue.dart`, `lib/core/ai/claude_service.dart`,
  `lib/core/database/tables.dart`.

## Context

#26 (reframed): at **first exposure** — the Learn stage, before a concept enters FSRS spaced
repetition — help the learner actually **grasp** the concept, not just recognize it. The
user-confirmed intent is a **tutor that asks the learner questions** to build understanding, not a
test-administrator and not a lecturer.

The dominant risk is documented in `learning-science.md` ("AI-mediated learning"): an AI that
**explains at** the learner raises short-term performance but not durable learning — the
performance ≠ learning gap in its acute form (over-reliance / "metacognitive laziness"). So the
load-bearing principle is **ask, don't tell**: the AI elicits; the learner generates.

This decision follows a design spike — an adversarial workflow (2026-09-25, 12 agents: research →
synthesize → 5 critics → harden) — whose critics **verified their claims against the code and
vault**. The load-bearing verified facts:

- `isPretestSection(heading)` matches **127/155 concept cards** but **0/19 algorithm cards** and
  **0 headings on a non-English deck** — it is monolingual + CS-tuned, so it is **not** a
  subject-neutral firing gate (simultaneously too broad and too narrow).
- `source:` frontmatter is used by **0 cards** — the on-screen **section text (+ card overview)**
  is the only reliable grounding today.
- The current coach `grading:false && revealed` branch instructs "discuss it deeply, referring to
  it directly" — the **opposite** of answer-withholding. The withholding-post-reveal contract is
  the real prompt change.
- Coach chats are keyed `(cardId, sectionSlug)` and `clearTestCoachConversations` is **key-blind**
  (`sectionSlug.isNotNull()`), run at both Learn and Review session start — so a first-exposure
  tutor and the Review examiner would **collide** on the same rows.
- `Coach.send` hard-returns on empty input and always persists a user turn first, so "the AI
  speaks first / auto-opens" has **no seam** and would need net-new synthetic-seed machinery
  fighting `autoDispose`.

## Decision

1. **It is an enhancement to the LEARN step's internal pedagogy — NOT a flow.** It is not one of
   the contingent flow kinds (conversational / re-solve / redirective) that a foundation *gates*;
   it never enters `FlowSpec`, and it neither gates nor is gated. (SoT taxonomy line added to
   `index.md`.)
2. **Learner-invited; never auto-open.** After **reveal**, a subtle non-modal **"Talk it through"**
   affordance appears on *substantial* sections; the AI **never speaks unrequested**. The first
   tutor turn is generated on the learner's tap. (Silence-default, ADR-0011; BYO-key cost; and
   there is no seam for an unprompted AI turn.)
3. **Grounding-only, self-explanation rung; withhold the synthesis.** One question per turn,
   anchored to the visible section (+ card overview). It stays at "what is this / why is it true?"
   and does **not** escalate to transfer / "when would it break?" (that belongs to Review). It does
   **not** give counter-examples or state why an answer is wrong — it asks the learner to *test
   their own claim*. On a stall it climbs one hint rung (never re-asks); on "I don't know" at the
   opener it switches to **scaffolded reading**. Budget **2 learner turns soft / 3 hard**. It ends
   by asking the *learner* to summarize. It emits **no grade and no "grade-when-ready" nudge** —
   the FSRS self-grade is untouched (n0014).
4. **FSRS integrity (ADR-0008).** Non-blocking: the grade bar is live and uncovered throughout;
   `LearnSession.grade()` is untouched; a legitimate Good/Easy always graduates; no coverage state
   is persisted into `srs_state`.
5. **Reuse the coach seam.** A new `firstExposure` flag on the existing `grading:false` persona in
   `buildCoachSystem`, selecting a **post-reveal-but-still-withholding** contract distinct from
   both existing `grading:false` branches. The **skill is authored by extending `_meta/coach.md`**
   (a `## First exposure` tone block + reuse of the per-card `## vs. Confusable Siblings` for
   misconceptions) — **not** a new `_meta/tutor.md` (one parser, one provider).
6. **One schema change.** Add a `kind` discriminator (`tutor | examiner`) to `CoachMessages` and
   scope `clearTestCoachConversations` by kind, fixing the verified collision. No other new tables.
7. **Prerequisites / guardrails.** (a) prompt **caching** (`cache_control`) on the system block;
   (b) a **red-team eval fixture** across 3 dissimilar subjects proving the tutor never leaks the
   key synthesis; (c) a **delayed-retention durability metric** (below).
8. **Subject-generality.** `isPretestSection` is **not** the gate; a subject-neutral **substance
   floor** (≥ 2 paragraphs / list-items) suppresses the chip on stubs. Grounding = section +
   overview; `card.source` per-section grounding is deferred (0 cards use it).
9. **Consent / kill-switch — [Decision #1, recommended]:** **no new per-behavior toggle**; consent
   is *key present + the tap* (identical to today's coach). At most **one shared "AI coaching"**
   switch, never a per-flow dial (ADR-0011). *(Under human review.)*
10. **Rollout — [Decision #4, recommended]:** ship **opt-in** (learner-invited, off the happy path
    by construction) + instrument the retention join, and **hard-gate any default-on / broader
    rollout** on a non-negative delayed-retention signal vs. untutored first exposures.
    *(Under human review.)*

## Alternatives considered

- **Hard gate before FSRS** (must "pass" to graduate): rejected — schedule-hacking-adjacent
  (ADR-0008), and it traps/demotivates exactly at the thinnest-knowledge moment.
- **Detached parallel unit** (a separate optional tutor activity): rejected — loses the
  reveal-first grounding, is out-of-sight (low adoption), and adds a whole new surface.
- **Auto-open on a "smart subset"** (the pre-critique synthesis): rejected by the adversarial pass
  — violates silence-default, has no seam, covers the grade bar, fires Socratic drilling at low
  prior knowledge, and the `isPretestSection` subset is 82% of concept cards yet 0% of algo /
  non-English decks.
- **A new `_meta/tutor.md` skill file**: rejected — forks the parser/provider/loader → drift; the
  three-layer prompt architecture already lives in `buildCoachSystem`.
- **AI-mandatory on every new card**: rejected — cost (BYO-key, ~20 cards/session) + the
  over-reliance risk.

## Consequences

- **Positive:** evidence-based (ask-don't-tell; grounded, withholding); ADR-conformant (FSRS
  integrity, silence-default, minimize-knobs, subject-neutral); reuses the coach seam; degrades
  gracefully (no key → Learn identical to today); small blast radius; and it is **measurable**
  (the durability metric), directly confronting the performance≠learning risk.
- **Negative / trade-offs:** a schema migration (the `kind` column); a real prompt-engineering +
  eval investment to enforce withholding; adoption depends on the learner choosing to engage
  (pull-based); the deepest value (misconception-driven tutoring) is **Phase 2** — v1 ships
  generic-scaffold-solid.
- **Known limitations & follow-ups:** per-section `card.source` grounding deferred; Phase-2
  misconception depth; any auto-open experiment gated on the durability evidence; caching fully
  pays off only off the Haiku default.

## Validation

- **Invariant #8 (byte-identical):** characterization tests pin `buildCoachSystem(grading:true)`
  and `(grading:false, firstExposure:false)` unchanged; the no-key Learn path is byte-identical.
- **Red-team eval fixture** (3 dissimilar subjects): under "just tell me" / repeated stalls the
  reply never contains the section's key synthesis, asks one question per turn, emits
  `<tutor-done/>`, and never emits a grade. (Prompt rules are necessary-not-sufficient; this is the
  acceptance gate for the withholding discipline.)
- **`kind`-discriminator migration test:** opening Review does not clear tutor rows and vice-versa;
  a section learned-then-reviewed keeps two separate transcripts.
- **FSRS integrity widget test:** the grade bar is tappable and `grade()` seeds FSRS while the
  tutor is mid-conversation.
- **Rollout gate:** the pre-registered delayed-retention join (tutored vs. untutored first
  exposures; stability / lapse at reviews 1–3) must be non-negative before any default-on rollout.
