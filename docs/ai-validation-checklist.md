# AI validation checklist (on-device, real key)

Every AI feature is unit-tested only against a mocked API. This is the one thing
those tests can't cover: whether the actual generated **output quality and tone**
are good. Work through this once with a real key; screenshot or paste anything
that feels off and we'll fix the prompt.

All calls are on your own Anthropic key. Rough cost per step is tiny — the report
and the Sonnet chats are the priciest, and the whole pass is a handful of calls.

---

## Pre-flight

1. **Add your key**: Settings → **"Anthropic API key"** row → paste (`sk-ant-…`) →
   Save. The row should then show the key is set.
2. **Have some data**: make sure a target is set and you have some study history
   (study/review a few cards, or use the dev "seed sample data" so readiness and
   domains are non-empty). The AI reasons about real numbers — empty data makes
   its output hard to judge.

For each feature below: **is the output useful, accurate, and right-toned?** Note
anything in the "🚩 watch for" lists — those are the specific failure modes.

---

## 1. Readiness report  (Sonnet — the priciest call)

**Get there:** Home → coach badge at the bottom → **"Full readiness report"**.

**What good looks like:**
- Leads with **learning gaps** — topics you *have* but haven't mastered — not a
  shopping list of cards to create.
- Content/scope gaps are **secondary and soft** ("as you build the deck, consider
  …"), and it names likely scope gaps the readiness score can't see.
- Honest and specific, anchored to your actual domains/numbers. Prioritised next
  steps.

**🚩 Watch for:** generic praise / ego-boosting; hallucinated topics not in your
deck; telling you to lower your study load with no basis; ignoring your target.

**Also validate the caching (the thing we just built):**
- Open the report, then leave and reopen → should appear **instantly, no spinner**
  (reused, free).
- Now study/review one card, go back and open the report → it should
  **auto-regenerate** (spinner, fresh call). That's the data-changed path working.

---

## 2. Interview planner  (Sonnet)

**Get there:** Home → **"Upcoming interviews"** → **"Plan an interview"** (FAB).
(Also from Home → tap the target → "Plan for a specific interview".)

**Try:** something realistic but slightly underspecified, e.g.
> "Google, senior backend, Maps team, in about 2 weeks."

**What good looks like:**
- Asks a **clarifying question** when detail is missing, instead of guessing.
- Produces a plan card: prioritised **domains/concepts that exist in your deck**,
  an interview date, and — if relevant — an **"Onyx doesn't cover X — prep that
  elsewhere"** flag.
- **Advisory** about company specifics ("correct me if I'm off"), not stated as
  fact. Accepts your corrections when you push back.
- "Save & activate" creates a goal; study should then re-bias toward it.

**🚩 Watch for:** inventing company/interviewer "facts" with false confidence;
weighting topics **not** in your deck; steamrolling past missing info without
asking; ignoring a correction you give it.

---

## 3. Themed practice mock  (Haiku — the interviewer)

**Get there:** Home → "Upcoming interviews" → tap a goal → **"Practice for this
interview"**. Then, on a card, tap **"Answer the coach"** (before revealing).

**What good looks like:**
- Behaves like an **interviewer**: ONE focused question at a time, makes *you*
  do the thinking.
- **Does not reveal the answer** while it's hidden — climbs a hint ladder
  (smallest useful nudge first) and won't confirm/deny a value you propose.
- Probes **transfer** ("what if the input were sorted / streaming / 10× larger?").
- Difficulty/emphasis is pitched to the role you're prepping (e.g. senior
  backend), but it stays **grounded in the card** — no ungrounded company trivia.
- Only after you reveal + respond does it offer an **advisory** grade (highlights
  a button; never grades for you).

**🚩 Watch for:** spoiling the answer while hidden; lecturing / answering its own
question; grading you before reveal; drifting off the card into generic company
chat.

---

## 4. Interview debrief  (Sonnet — the just-hardened one)

**Get there:** Home → "Upcoming interviews" → tap a goal → **"Debrief — how did
it go?"**.

**Try two scenarios:**
- **A weak spot:** "Coding round went fine, but I blanked on a dynamic-programming
  question and ran out of time."
- **A rare/unfair question:** "They asked me some obscure segment-tree thing I've
  never seen."

**What good looks like:**
- Asks how it went **one question at a time**; probes whether a weakness is a
  **recurring pattern** before adjusting anything.
- Separates a **learnable content gap** from nerves / time / luck.
- Proposes **small, few** reweights (or **none** if you passed / nothing recurs) —
  and says empty is fine.
- For the rare question: tells you **not to over-drill it**, points to the
  underlying concept instead.
- "Apply to my plan" records the outcome and nudges study; it should feel like a
  gentle adjustment, **not an overhaul**.

**🚩 Watch for:** big reweights off a single bad question; treating your
self-report as gospel; reweighting nerves/luck as if they were knowledge gaps;
over-drilling a genuinely rare topic.

---

## 5. Coach in a normal study session  (Haiku — the tutor)

**Get there:** Home → "Review" / "Learn" → on a card, tap **"Answer the coach"**
or the app-bar coach icon.

**What good looks like:**
- **Tutor**, not interviewer: Socratic, builds understanding, refers to the card
  on screen rather than re-explaining, one question at a time.
- Won't dump the answer; if you say "just tell me" it responds with a hint.

**🚩 Watch for:** dumping full answers/code; behaving like a graded interviewer in
Learn mode; ignoring what's already on the card.

---

## What to send back

For anything that felt off: a screenshot or pasted transcript + one line on what
was wrong (tone? accuracy? spoiled the answer? overreacted?). That's enough for me
to tune the specific prompt. If it all feels good, that's the signal the AI layer
is validated and we can build on it with confidence.
