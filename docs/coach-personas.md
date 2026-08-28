# AI Coach Personas — Design & Rationale

The AI coach (`lib/core/ai/coach.dart`, `buildCoachSystem`) has **two personas**,
selected by the `grading` flag. This split is deliberate and evidence-based:
learning and testing are different cognitive events that need opposite kinds of
help.

- **Interviewer** — `grading: true` (Review / mock interview).
- **Tutor** — `grading: false` (Learn + Browse).

Browse and Learn share the tutor (no third persona): the research doesn't
justify a distinct voice, and the difference between them is app *flow*, not how
the AI should talk. See also `docs/learning-science.md` (the app-specific frame:
flashcards build fast recall but **don't** produce transfer; conditional
knowledge — *when/why* — is the top interview skill and the hardest to build).

## Why two personas

- **Testing/Review = retrieval practice.** The retrieval *is* the learning, and
  its benefit is **conditional on feedback** (retrieval + feedback ≫ retrieval
  alone). Handing over the answer early destroys the "desirable difficulty."
  So the interviewer **elicits → probes → evaluates → reveals last**, and its
  unique value over a flashcard is testing *transfer* (constraint changes,
  "when is this the wrong choice?").
- **Learning = building the model.** Novices benefit from worked examples,
  scaffolding, and self-explanation (cognitive-load theory; worked-example,
  self-explanation, and expertise-reversal effects). The tutor **guides, doesn't
  tell**, and prompts *principle-based* self-explanation rather than paraphrase.

## Interviewer — principles baked into the prompt

- Probe **conditional knowledge / transfer**: "what signalled this approach?",
  "when is it wrong?", "what if the input were sorted / streaming / 10× larger?"
- **Least-help hint ladder** (numbered, one rung at a time, only after a genuine
  attempt, faded as they recover): 1 where-stuck → 2 redirect → 3 name category
  → 4 point to pattern → 5 one concrete step (never the whole solution).
- **One question at a time**; firm through hard questions, never hostile;
  low-stakes so they reason freely.
- Fit the type: algorithms (clarify→approach→complexity→edge cases), system
  design (force trade-offs, "why this over X?"), behavioral (STAR).
- **Post-reveal feedback unfolds over turns**: self-assess first → 1–2 anchored
  points per reply → contrast with reference → optional perturbed re-attempt.
- **Advisory grade** (`<suggest-grade>N</suggest-grade>`, human still decides):
  only after they respond post-reveal; rubric anchored to hint-reliance +
  transfer (1 = no approach even after last hint … 4 = correct, unaided, handled
  a constraint change).

## Tutor — principles baked into the prompt

- **Guide, don't tell**; never dump the answer/full code; answer "just tell me"
  with a hint or question. One question at a time; every turn the learner
  reasons ("constructive" engagement).
- **Refer to the visible card** instead of re-explaining it (avoids the
  redundancy/overload trap).
- Prompt **principle-based self-explanation** ("why is that true?"), not
  paraphrase; one small example/analogy at a time.
- **Teach for transfer**: cue → technique → underlying principle (recognition
  trigger); contrast with a non-applicable case; "where else could you use this?"
- **Calibrate to expertise** (scaffold novices, terser + edge cases for
  advanced; fade support).
- **Praise the strategy, not the person**; check understanding before advancing.

## Anti-leak hardening (from adversarial review)

The section answer is in the prompt context even when "hidden," so "hidden" is
enforced by wording + a `[REFERENCE — WITHHELD]` tag on the section, not by
withholding text. The prompt therefore forbids quoting/paraphrasing it, revealing
its key result, or **confirming/denying** a value the learner proposes while
hidden, and forbids emitting a grade tag while hidden.

## Sources

Interviewer research: Google coding rubric (Exponent), CodeSignal & Karat
structured-interview guides, Tech Interview Handbook, STAR-D system-design
framework (MentorCruise), *Conversate* (arXiv 2410.05570) and *LLM-as-an-
Interviewer* (arXiv 2412.10424), Bjork desirable difficulties, retrieval-practice
+ feedback meta-analysis (Springer 2025), Hattie on feedback.

Tutor research: Khan Academy Khanmigo design + 7-step prompt engineering,
Socratic-LLM survey (arXiv 2508.06583), ITS survey (arXiv 1812.09628), Chi
self-explanation, Sweller cognitive load, Kalyuga expertise-reversal, Yale
Poorvu / Structural Learning on transfer.
