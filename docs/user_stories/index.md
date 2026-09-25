# Onyx — user stories (the backbone)

> Drafted rough by the author; cleaned + filled in 2026-09-22. **This directory is the
> emerging source of truth** for what Onyx is and how it's used. The older docs
> (`product-direction`, `ux-vision`, `personas-and-stories`, `roadmap`, `registry-and-sync`,
> the `g7-*` plan, …) are deeper detail + history and will be reconciled to point here; where
> they disagree with these stories, **these win**. Open questions in each file carry
> a **Rec:** — my recommendation, to accept, reject, or edit.

## What Onyx is
A local-first, cross-platform study app over a plain folder of markdown you own. It runs the
daily spaced-repetition loop and — once you've mastered the foundations — the *applied*
practice that memory alone can't cover. **General by design:** software-interview prep is one
worked example, not the product.

## The core model
- **Vault** — the file tree; the single source of truth. *Content* lives in **user-land** (you
  edit it in any tool). *Configuration* (aims, scheduled tests, settings) lives in an
  **untouchable `_meta/`** area the app owns. Anything derivable (time-to-ready, coverage) is
  computed.
- **Deck = a query lens over the vault** — a saved folder path or tag expression (`korean/`,
  `tags:music && !tags:done`) selecting a subset of the vault. **The primary unit you work
  in.** Decks may overlap; one card can belong to several. A deck is *not* a separate pile of
  cards — it's a view.
- **Foundation → contingent flows.** Inside a deck, foundational cards are learned + reviewed
  (FSRS). Mastering them **gates/unlocks contingent flows** built on that foundation, which
  come in kinds: **conversational** (a system-design mock, a language conversation),
  **re-solve / execution** (algorithms), **redirective** (CS: "solve this leetcode problem",
  music: "go take this listening test," do it outside the app, return with a result).
- **Aims — a set, not one target.** On top of a deck sit one or more concurrent **aims** — the
  things you're pointing at (a dated test/interview, or open-ended mastery). Each aim carries
  four knobs: **difficulty/depth**, **domain emphasis**, a **durability bar** (how locked-in
  recall must be), and a **date or open-ended**. A music-theory deck can hold a composition
  test, an improv jury, and general fluency at once, overlapping the same cards + flows.
  **Readiness rolls up weakest-link across the active aims**; the **daily plan allocates study
  across them.** The old single "senior · backend · FAANG" target is just *one* aim with those
  knobs set — the CS/FAANG path stays first-class, it's no longer a special case.

## Personas (P1–P6 — details in [personas.md](personas.md))
- **P1** — K-12 class student (studies a teacher's deck via a class code).
- **P2** — exam / deadline student (a dated test drives the pace).
- **P3** — open-ended hobbyist (Korean, music theory; often no fixed date).
- **P4** — SWE interviewee (the built-in worked example).
- **P5** — teacher / pusher (authors a deck, publishes it to others).
- **P6** — professional (onboarding for new employees to an organization).

## The views (map)
**Onboarding** → **Deck selection** (vault level; the landing page when >1 deck, skipped for
one) → **Home** (one deck: today's study, aims, progress, readiness, coach) → **Browse ·
Analytics · Your Target · Scheduler · Card · Settings**.

A recurring, still-open tension flagged per view: **deck-level scope vs vault-level scope**
(does Browse/Analytics/Settings act on the current deck or the whole vault?).

## Stance / guardrails
- **Not a second brain, not an authoring studio.** Onyx *reviews and applies*; it's orthogonal
  to a knowledge base and never requires one. Authoring is a **light on-ramp**, not a feature we
  deepen. Whole-vault features (browse-all, cross-deck analytics) are considered only where
  cheap *and* clearly valuable.
- **Evidence-based motivation.** Honest signals; no gamification / streaks / guilt (see the
  learning-science + gamification research).
- **MVP discipline.** Each story tags MVP vs later; hard, low-value flows are deferred.

## How we use this (the anti-drift contract)
This directory is the **single source of truth** for intent. To stop code and docs drifting
apart the way they did before, five rules:
1. **One source.** Intent lives *here*, nowhere else — no other design doc claims authority; the
   older docs are historical reference, being consolidated behind this backbone.
2. **Change here first.** To change what we build, edit the story (and its decision) *before*
   touching code. A behavior change not reflected in a story is drift.
3. **Build only what's Accepted.** Each open question carries a **Status** — `Accepted` (build it),
   `Pending` / `New` (blocked until decided). Don't build ahead of a decision.
4. **Cite the story.** Every task + commit references the story file + decision it serves, so
   code ↔ intent stays traceable.
5. **Keep it lean.** New intent goes *into* the relevant story, never a new doc — this backbone
   stays small enough to hold in context, and that smallness *is* the anti-drift mechanism.

Per milestone we run one cheap **conformance check**: *does the code match these stories?* — a
single-source pass, not the multi-doc reconciliations that used to eat whole sessions.

## Open decisions (parked — don't build until resolved)
- **Sync & source-of-truth** (the big one): when a deck is pulled from upstream, who owns truth
  (publisher vs puller)? read-only decks to stay in sync, or free local edits? auto-sync + how to
  handle new/modified upstream content? And — if vaults are backed up to a server — is plain-text
  storage of *app data* (not content) still worth its cost? → **resolve before the cloud/registry
  track.**
- **Competing aims** (tension between concurrent aims — e.g. a general *backend* aim + two *frontend*
  interviews). **Rec (shape agreed 2026-09-22; refined 2026-09-22):**
  - **Readiness never averages** — score each aim on its own knobs, show per-aim, deck headline =
    **weakest-link** (done, S2).
  - **Allocation is by FEASIBILITY, not a naive time-ramp.** An aim's urgency = how far behind it is
    relative to what it needs: **required-pace (remaining work ÷ time left, where work scales with
    content volume × the durability bar) vs actual-pace.** Behind + soon pulls more; comfortably-ahead
    pulls less *even if its date is sooner*; **open-ended aims hold a baseline** (steady coverage).
    (Region-of-proximal-learning + agenda-based regulation — see learning-science.md.) Urgency is a
    per-aim **forecast** output ⇒ **S4 (feasibility) sequences before S3 (allocation).**
  - **Retention floor (anti-starvation).** Urgency reallocates *new-learning emphasis* above a
    minimum; it **never drops a dated aim's due-review cadence** (else the de-prioritized aim rots).
  - **Cram vs durable = the durability-bar knob** (already modelled) + the FSRS-safe deadline ramp
    (raise desired retention toward the date; **never** hack the schedule / mass-practice —
    fsrs-exam-targeting). A crammer sets a low durability bar; the app keeps them honest.
  - **Coach warns on infeasibility / incoherent cram** — "at your pace you won't be durably ready
    for [aim] by [date]; move the date, narrow scope, lower the durability bar, or accept it fades."
    Propose-with-rationale; **pause is the user's lever**; no auto-override.
  - Mechanism: **S4** (per-aim feasibility) → **S3** (urgency allocation + retention floor) → **S5**
    (cram-vs-durable UI) + a **coach cram-coherence nudge**; the FSRS-safe deadline ramp overlaps #32.
- Per-file **Pending / New** questions: onboarding (QR quick-setup), home ("Today" naming), browse
  (whole-vault), scheduler (vault-level calendar), card (editing already-learned cards; per-section
  test exclusion), plus the refinements noted in deck_selection / deck_creation / settings.

## Implementation mapping (today's code → this model — descriptive only)
The stories drive the target; this maps the model onto the code so navigation stays easy. The
2026-09 re-shape (the R1–R4 renames, S1–S5 aim unification, and the unified query lens) is **done**,
so this is now a straight description, not a to-reshape list.
- **Deck (query lens)** = `Deck` — a name + template + a `CardQuery` membership (the boolean
  lens/filter tree shared with Browse; ADR-0013).
- **Aim** = `Aim`, a *list* on the deck (`Deck.aims`); each aim OWNS its four knobs
  (difficulty / emphasis / durability / date) — unified (ADR-0006). (`ReadinessTarget` is derived
  from an aim for scoring.)
- **Deck template** = `DeckTemplate` — the per-deck/vault template (flows, parse rules,
  vocabulary) in `_meta` (formerly `SubjectConfig`).
- **Flow** = `FlowSpec` (scheduling: `recall` / `twoClock` / `mock`).
- Resolved (were the "gaps to re-shape", now shipped): many aims per deck; readiness weakest-link
  *across aims* (#6); daily-plan allocation *across aims* (ADR-0007).

## Files
[onboarding](onboarding.md) · [deck_selection](deck_selection.md) · [deck_creation](deck_creation.md)
· [home](home.md) · [your_target](your_target.md) · [scheduler](scheduler.md) · [card](card.md)
· [browse](browse.md) · [analytics](analytics.md) · [settings](settings.md) · [personas](personas.md)
