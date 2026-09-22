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
  interviews). **Rec (shape agreed 2026-09-22; refine the mechanism in S2/S3):** readiness **never
  averages** — score each aim on its own terms, show per-aim, deck headline = **weakest-link**; the
  daily plan **allocates by urgency/deadline** (dated aims nearing their date pull more; open-ended
  aims hold a baseline) — not a naive split, not an automatic override; **pause is the user's lever**
  (the existing active/mute toggle) — no auto-override (preserves autonomy, avoids silently abandoning
  a goal); the **coach may detect low emphasis-overlap and gently suggest** focusing one, never
  auto-pause. Mechanism deferred → S2 (rollup) + S3 (allocation) + a coach nudge slice.
- Per-file **Pending / New** questions: onboarding (QR quick-setup), home ("Today" naming), browse
  (whole-vault), scheduler (vault-level calendar), card (editing already-learned cards; per-section
  test exclusion), plus the refinements noted in deck_selection / deck_creation / settings.

## Implementation mapping (today's code → this model — descriptive only)
The stories drive the target; this is just how the current code lines up, so we know what to
re-shape vs reuse.
- **Deck (query lens)** ≈ `StudyGoal` + its `MembershipQuery` (AllCards / TagMembership /
  FolderMembership).
- **Aim** ≈ `InterviewAim` (already a *list* on a goal) generalized to carry the four knobs,
  which today are split across `ReadinessTarget` (difficulty/emphasis/durability/date) + the
  interview loop.
- **"Subject" / `SubjectConfig`** ≈ the per-deck/vault template (flows, parse rules,
  vocabulary) that lives in `_meta`.
- **Flow** ≈ `FlowSpec` (scheduling: `recall` / `twoClock` / `mock`).
- Gaps this model exposes (to resolve during re-planning): "one target per goal" → "many aims
  per deck"; readiness weakest-link *across aims*; daily-plan allocation *across aims*.

## Files
[onboarding](onboarding.md) · [deck_selection](deck_selection.md) · [deck_creation](deck_creation.md)
· [home](home.md) · [your_target](your_target.md) · [scheduler](scheduler.md) · [card](card.md)
· [browse](browse.md) · [analytics](analytics.md) · [settings](settings.md) · [personas](personas.md)
