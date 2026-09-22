# Onyx — Roadmap

> **Derived from [`user_stories/`](user_stories/index.md)** (the source of truth) — sequenced work
> only; intent lives in the stories. Every item cites the story it serves. The previous roadmap
> was the pre-reframe (subject/goal) model; it was mined for orphan goals then archived, and where
> it disagreed with the stories **the stories won** (contradictions noted below).

## How to read this
- Phases run in order (the author's priority): **backbone → docs → conform the code → polish →
  finish MVP → ship → stretch.** Each item is independently shippable and keeps the app green
  (analyze + suite + custom_lint).
- **[MVP]** = needed for the first real release · **[stretch]** = after. `(→ story)` = the story it
  serves. `#NN` = the granular backlog task.

## Phase 0 — Re-grounding ✅ (2026-09-22)
Backbone (`user_stories/`) established as the source of truth with the anti-drift contract; docs
consolidated to the lean spine (`user_stories`, `roadmap`, `architecture`, `design-system`,
`learning-science`) with 25 historical docs archived; roadmap re-baselined (this doc).

## Phase 1 — Conform the code to the backbone *(the big one)*
The engine is solid; the app's **structure + surface** must move onto the vault → deck → aims
model before we add features, so we build on the right shape.
- **1a · Model + vocabulary** (→ index): reframe code "subject/goal/target" into **deck (query
  lens)** + **a set of aims** (difficulty/emphasis/durability/date); readiness weakest-link *across*
  aims; daily plan allocates *across* aims. Retire the single-target assumption. *Absorbs the rest
  of G7 (a–f done, #88) and enforces invariant #2 — the #92 no-type-branch burn-down + a lint guard.*
  - *Landed:* invariant #2 (**#92 done**) — the genuine card-type branches are config now
    (`isApproachType`/`isApproachCard`, `FlowSpec.prereqSource`) and the `no_card_type_branch`
    lint guards against new ones; the shared `buildConceptComfort` helper (**#87** comfort-dedup).
  - *The reframe* (planned 2026-09-22 from a 4-agent code map; decisions: name → **`DeckTemplate`**,
    order → **rename-first then structural**). Model mapping: `StudyGoal`=deck, `InterviewAim`=aim
    (already a *list*), `SubjectConfig`=the per-directory *template*, `ReadinessTarget`=the 4 knobs.
    - **① Rename — ✅ DONE (2026-09-22):** byte-identical, layered green commits. **R1** `SubjectConfig→DeckTemplate`
      (+ `core/subject/→core/template/`, `activeSubject→activeTemplate`, `Card.subjectId→templateId`;
      keep on-disk `onyx-subject.yaml` + built-in ids); **R2** `InterviewAim→Aim`; **R3**
      `StudyGoal→Deck` (providers / `/debrief/:deckId` / `_GoalLane`; keep `study-goals.json`);
      **R4** user-facing copy (goal→deck; interview/target→aim via the existing `Vocabulary` seam).
    - **② Structural (behavior):** **S1** lift the 4 knobs onto each `Aim` (today shared on the deck);
      **S2** readiness **weakest-link across aims** (today a mean across domains, one target); **S3**
      daily-plan **allocation across aims** (today one nearest-date + merged weights); **S4** per-aim
      pace/forecast; **S5** the unified **Aims surface** (merges Your Target + scheduler + interview
      list; wires/retires #90 debrief — *subsumes 1c*).
    - *Invariant to hold throughout:* difficulty (level) affects readiness **only** via tier-depth,
      never a domain-weight swing (a documented past inversion).
    - *Competing aims* (e.g. backend general aim + frontend interviews): weakest-link readiness (never
      averaged, per-aim shown) + urgency/deadline-weighted allocation + the user's pause lever; the
      coach may gently flag low-overlap tension, never auto-override. Shape agreed; mechanism in
      **S2** (rollup) + **S3** (allocation) + a coach nudge. See the Open decision in `user_stories/index.md`.
- **1b · IA: vault → deck → home** (→ deck_selection, home): deck-selection as the vault-level hub
  (landing when >1 deck); single-deck degradation **with an escape hatch** (fixes the pause-strands
  bug); deck-scoped Home ("Home" stays the name).
- **1c · The Aims surface** (→ your_target, scheduler): unify Your Target + Scheduler + the
  interview list into **one per-deck Aims surface** (knobs + dates + status + zone-calendar); fix
  reachability (#90 debrief; the buried calendar); decouple aims from deck creation.
- **1d · Deck/vault scope split** (→ browse, analytics, settings): deck-scoped Browse / Analytics /
  deck-settings *inside* a deck; vault Settings + a light cross-deck glance at the vault level.
  *Absorbs settings-IA #85.*
- **1e · Onboarding** (→ onboarding): folder → deck; cloud capabilities absent (not disabled).
  *Resolves #86.*
- **1f · Card model** (→ card): the multi-modal card (view / study / authoring / stub), collapsible
  + mastered-badged sections, per-deck `neverQuizzed` + per-card `quizzable`, stub cards for broken
  links.
- **1g · Shared authoring + query API** (→ deck_creation, browse): one card-authoring entry API and
  one query/lens API (Browse filters == the lens language); the scoped card-explorer for building a
  lens.
- **1h · Engine conformance + bugs** (→ architecture invariants): #91 practice-content author-or-
  retire; #58 overflow; #87 hygiene (CardCache, flow_access, recall-predicate, SD hardcode,
  stem-fn); verify #90 / calendar / dev-clock fixed.
- **Dropped here (contradicts the guardrail):** **#50 second-brain S2/S3** — Onyx is *not* a second
  brain. The shipped card-links backlinks stay as a minor feature; the notes/graph expansion is out.

## Phase 2 — Polish (look & feel + UX)
- Apply the design system across the re-architected surfaces; motion; empty/loading states.
- **Design tooling — Figma + UI/UX agents [new, your ask].** Wire a solid design workflow so quality
  isn't gated on hand-crafting: a **Figma source-of-truth** for components/screens + an **agent loop**
  that turns designs into Flutter widgets *against the design system*, plus a **design-review agent**.
  Needs a short research spike on the robust integration (Figma API / MCP + a UX-review agent).
- a11y pass (large-text, tap-targets, semantics — carry the #78–#81 discipline forward).

## Phase 3 — Finish the MVP
The MVP-tagged stories, cloud still absent:
- The daily loop + Aims + readiness end-to-end for one deck *and* several; the three on-ramps
  (existing lens / create cards / pull); light authoring; deck-scoped Browse/Analytics/Settings.
- Feature calls (decide per story — some may slip to stretch): #22 quiz customization, #26 reader
  comprehension, #25 AI study suggestions.
- The AI **scoping / curriculum research** for deck creation (→ deck_creation) so authoring works
  for any subject, not just SWE.

## Phase 4 — Ship (app store) *(needs macOS/Xcode)*
- iOS/Android **mobile folder picking** (#82: security-scoped bookmark / SAF); on-device UX pass;
  TestFlight → release. #61 speech-to-text for the mock/explain flows (optional).

## Phase 5 — Stretch (after launch)
- **Cloud / registry track — gated on the parked *sync & source-of-truth decision*** (see Open
  decisions in `user_stories/index.md`): #83 registry server + accounts + class-code (P1/P5/P6
  publish/pull), read-only + auto-sync decks and local-edit handling, managed **Onyx AI**
  (billing/quota), #63 authoring-kit distribution, #84 parse-profile editor. **Defer-hard:** the
  public deck tier (moderation/takedown), managed AI for minors (COPPA/FERPA).
- QR class/org quick-setup (→ onboarding, merge-not-overwrite); PDF/camera card authoring
  (→ deck_creation).

## Old-backlog mapping (#NN)
- **Reframed into Phase 1:** #30 / #88 / G7 (→ 1a), #85 (→ 1d), #86 (resolved → 1e), #68 (aims),
  #57 (daily plan), #90 / #91 / #87 / #92 (→ 1c/1h).
- **Kept as-is:** #32 (FSRS engine tuning), #82 / #61 (ship), #83 / #63 / #84 (stretch/cloud),
  #22 / #25 / #26 / #58 (features).
- **Dropped / parked (contradicts the direction):** #50 second-brain expansion.
- **Done arcs, re-shaped onto decks/aims in Phase 1:** #33 / #54 / #59 (practice tracks),
  #51 / #62 (hardening), #64 (multi-subject), #28 (authoring).
