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
    - **② Structural (behavior) — "target lives on the aim"** (the model is [ADR-0006](adr/0006-deck-and-aims-model.md)).
      **Status: S1–S4 ✅ (readers now honor per-aim, byte-identical; suite 969→981); S5 (writer-flip) is
      the one remaining slice.** Key finding (2026-09-22 investigation,
      3-agent map): the system is consistent *today* only because every aim inherits the deck's slots.
      So the safe order is **make every reader honor per-aim first (while aims still inherit →
      byte-identical), then flip the writers + migrate + delete the deck slots.** Deck-slot removal
      therefore lands in **S5**, not earlier. "S2b" as a standalone slice dissolved into S3/S4/S5.
      - **S1 ✅** aims carry the 4 knobs (`Aim.levelId/contextId/trackId` + date via rounds) +
        `ReadinessTarget.forAim`.
      - **S2 ✅** readiness rolls up **weakest-link across active aims** (per-aim via forAim, headline =
        the binding aim; single-aim byte-identical). Aim knobs fall back to deck slots transitionally.
      - **S4 ✅ (sequenced BEFORE S3)** per-aim **pace / forecast / ladder + the FEASIBILITY signal**.
        Delivered: a shared **binding-aim resolver** (`_bindingTarget`, from `deckReadiness`) so the
        **forecast (S4b)** and **ladder (S4c)** follow the binding (weakest-link) aim → agree with the
        headline; **`deckAimFeasibility` (S4b)** — per aim, **required-pace vs actual-pace** ("can you
        be ready by its date?"): ready/onTrack/behind/infeasible + **open-ended → coverage, no
        ready-by** (the substrate S3 allocates on); SWE **2-contexts-per-level hardcode fixed** —
        milestone chips are config-driven (`LadderPosition.levelLabels`/`contextsPerLevel`). All
        byte-identical single-aim (#8). *Deferred (YAGNI):* the **weakest-link (latest) ready-by**
        roll-up + **per-dated-aim coverage-pace breakdown** have no consumer before the **S5** Aims
        surface, and coverage-pace stays a deck-level "seen-it" lens on Home (nearest-date
        `governingDate` — pace-models) rather than merging with the forecast; both fold into **S5**.
        Each per-aim `readyBy` is already exposed on `deckAimFeasibility`, so the roll-up is a one-liner
        when S5 needs it. *(The `activeTargeting`→per-aim fix for learn-ordering/plan-weights/retention
        stays in S3, below.)*
      - **S3 ✅** (delivered S3a urgency core · S3b plan emphasis · S3c retention floor [structural] ·
        S3d learn ordering) daily-plan **allocation by FEASIBILITY** (not a naive time-ramp): an aim's urgency =
        how far behind it is (required-vs-actual pace, from S4) + date proximity — behind+soon pulls
        more, comfortably-ahead less even if its date is sooner, **open-ended = baseline** — kept
        **above a per-aim retention floor** (never starve a dated aim's due reviews; met *structurally*
        via (a) averaging + review's urgency-independence — the stronger capped floor is follow-up
        (iii)). **+ the
        `activeTargeting`→per-aim fix** (learn-ordering, plan weights, per-card retention drop the one
        blended track/durability). Byte-identical single-aim. **Mechanism (decided — see
        [ADR-0007](adr/0007-daily-plan-allocation-across-aims.md)):** urgency-weighted *emphasis* fed
        into the existing weighted-fair-queuing packer (**A**), NOT hard per-aim budget slices (**B**) —
        because indivisible lumpy units (a 40-min SD problem) break hard partitions; soft fair-queuing
        absorbs that and routes leftover time to the behind aim's *divisible* work.
        - *Follow-ups surfaced 2026-09-22 (separable from S3, don't fold in):*
          **(i) time-estimate fidelity** — `PracticeUnit.estMinutes` is flat-per-type (review 1.5 /
          learn 3 / SD 40 / mock 20, with an optional `est_minutes` per-card override), NOT state-aware;
          make it reflect item state (mature review ≈ 0.5, first-time algo ≈ 45, familiar re-solve ≈ 15)
          so bin-packing is tighter for *any* allocation — near **#32**.
          **(ii) leftover-budget backfill** — big blocky chunks that don't fit defer, and review/learn
          (small, divisible) naturally soak up the remainder; backfilling with *extra* re-exposure
          beyond due when the day under-fills is **#58** (overflow) + **#104** (cram session) territory.
          **(iii) capped retention floor (#106)** — S3's retention floor is met *structurally* today
          (urgency touches only practice-track domain weights, never review's fixed weight + `reserved`;
          and (a) averaging keeps weights bounded so review's ~fair share holds even as urgent aims
          pull — see ADR-0007). The *stronger* guarantee — **clear due reviews first, up to a cap**, so
          heavy-review days never let retention drift (nor let reviews eat the whole day) — is NOT
          byte-identical (it rewrites the packer's fair-queuing for the single deck too) and is
          pre-existing (not aims-caused), so it's a deliberate daily-plan improvement done *with* (i)
          est-minutes fidelity (the cap needs accurate due-queue sizing). Near **#32/#57**.
      - **Cram-vs-durable + feasibility coaching (cross-cutting, added 2026-09-22; see
        [ADR-0008](adr/0008-cram-vs-durable-fsrs-safe-deadlines.md)).** "How long you
        need it" = the **durability-bar knob** (S1 field; S5 frames/edits it as cram↔durable). Honor
        deadlines the **FSRS-safe way** (raise desired retention toward the date — overlaps **#32**),
        never schedule-hack. A **coach cram-coherence nudge** warns when an aim is infeasible / the cram
        is incoherent (move the date / cut scope / lower the bar / accept it fades) —
        propose-with-rationale, no auto-override. Research-confirmed (learning-science.md "Study
        cadence"): does NOT contradict the ease-in→ramp→coach model — it's orthogonal (the ramp sizes
        the day; aims slice it).
        - *How a cram surfaces cards (design note):* FSRS won't minutes-space a MATURE card (by
          design — that's massing). A cram uses (a) raised desired-retention toward the date (pulls
          intervals in, days→sooner) **+** (b) a dedicated **cram / final-review session** that
          rapidly re-exposes the aim's due + at-risk cards **without writing FSRS reviews**
          (non-rescheduling — fsrs-exam-targeting), reusing the existing non-grading session infra
          (gym / practice). This is how "see them again and again today" is served FSRS-safely.
          Not built yet; lands with the cram-vs-durable work (S5 + #103).
      - **S5 — the writer-flip (in progress; the biggest, most coupled slice).** Surface + coupling
        re-mapped 2026-09-23 (3-agent deep investigation). **S5a ✅** (migration `foldDeckSlotsIntoAims`,
        byte-identical) + **S5b ✅** (readers resolve per-aim; deck slots UNREAD) · **S5c ✅** (`deadline`
        round-arg sweep) · **S5d ✅** (peripheral writers + label-readers) · **S5e-1 ✅** (read-only
        Aims screen `/aims`) · **S5e-2 ✅** (per-aim editor + `upsertAim` writer flip + neutral axis-title
        seam) · **S5e-3 ✅** (merge/retire old surfaces; last deck-slot writer gone) · **S5f ✅** (deleted
        `Deck.{level,context,track,deadline}` + `toTarget`; fold-at-parse migration; the **deck is now a
        pure lens**; suite 989). **#101/S5 substantively DONE** — the deck/aims model is fully realized in
        code. `readiness.dart` split ✅ (583 → 262 hub + 222 forecast + 141 feasibility). **S5e-4 ✅**
        (honest 0-aim coverage readout). **#101 / S5 is fully COMPLETE** — the deck/aims model is realized
        end-to-end and every sub-slice (S1–S5f) has shipped green.
        **Architecture verdict
        (arch-health audit):** the reframe is **net-cleaner** — S5b *deleted* the `_aimTarget` inheritance
        bridge; the readiness engine is fully off deck slots; new coupling (binding-aim resolver,
        feasibility→urgency→plan) is narrow, ADR-pinned, pure-cored, tested. The "recurring couplings"
        are OLD-model debt surfacing under the readers-first discipline (expected), not new debt. Watch:
        `readiness.dart` **split ✅** (S5f) into hub + `readiness_forecast` + `readiness_feasibility` via a
        re-export hub (importers unchanged);
        `templateTarget`-on-`ReadinessTarget` is a minor leak → defer.
        - **Coupling reality:** the deletion blast-radius is ~400–500 lines but **mostly parameter
          sweeps + call-site updates — no algorithmic change** (readiness/plan already read from aims).
          The real work is (a) `target_sheet.dart` is a **959-line god-widget** (pickers + calendar +
          interview list + Save-writer + planner) = the exact S5e merge target, so its Save-writer flips
          **inside** the merge (rebuild, not throwaway); and (b) the target-but-no-interview → open-ended
          aim must render on the new surface (else a phantom "interview"), so **deletion lands AFTER the
          merge**.
        - **Refined order (writer lives in the merge target → merge before delete):**
          **S5c** the **`deadline` round-arg sweep** — drop `(deckId, deadline)` from the aim round
          methods + `Targeting`; the deadline-synthesis is dead post-migration (mechanical,
          byte-identical, ~9 files). **S5d** the **peripheral writers + label-readers** — deck-editor
          drops the `deadline` field; the planner stops seeding deck slots (just appends the aim);
          `interview_card/sheet/debrief` use `ReadinessTarget.forAim` not `goal.toTarget()` (leaves only
          `target_sheet`'s Save on the slots). **S5e** the **Aims surface** (your_target + scheduler +
          interview list → one per-deck surface, *subsumes 1c*; design locked in
          [ADR-0009](adr/0009-aims-surface-design.md) after a 3-front investigation + web research):
          a **full screen** — weakest-link headline band + a list of calm **aim rows** (name · status ·
          readiness/coverage bar · feasibility `StatusPill` · date) + collapsed calendar/past; the
          per-aim **editor is a sheet** = today's `target_sheet` body repurposed, **Save → `upsertAim`**
          (the writer flip). Open-ended aims render as **coverage** (not a ready-by); a 0-aim deck shows a
          "building coverage" state (no phantom interview). **Faithful-MVP reuse** (`StatusPill` /
          `_TickedBar` / `_ZoneCalendar` / `_ForecastBlock` / pickers + one aim row) — defer new dataviz
          (`CoverageBar`/`ForecastBand`), the multi-aim zone overlay, and the cram↔durable slider.
          **Neutral knob titles** (Difficulty/Emphasis/Durability) via the `Vocabulary` seam. Feasibility
          = informational + options (move date / lower durability / cram), never a countdown or red-alarm
          (learning-science). Merge `upcoming_interviews`; wire **#90** debrief (route param mis-named
          `:deckId` for an aim id); Home "target" card → "aims" card. Build order: **S5e-1 ✅** screen +
          aim rows (additive, read-only; `aims_screen.dart` + route + 4 widget tests) → **S5e-2 ✅** the
          editor + Save→`upsertAim` (the writer flip; `showAimEditorSheet` co-located in `target_sheet`,
          wired to the Aims screen) + **neutral terminology** (S5e-2a: `Vocabulary` axis titles, SWE keeps
          Level/Company/Track) → **S5e-3 ✅** merge/retire old surfaces (Home readiness-chip + interview-prep
          hub tiles → `/aims`; `/aims` gains the planner FAB; deleted `_TargetSheet`+`_ScheduledSection`
          +`showTargetSheet` and `upcoming_interviews`+its route — the LAST deck-slot writer is gone,
          `target_sheet` 1150→765 lines, suite 989. Home target card kept → the prep hub UNCHANGED so
          behavioral's entry stays reversible pending its design pass; **#90 debrief deferred** to that
          pass) → **S5e-4 ✅** 0-aim coverage (honest sections-studied readout) + open-ended polish. Hold #8 (single-aim same *data*;
          the UI is intentionally new).
        - **S5f — the slot deletion ✅ (done 2026-09-24; the deck is now a pure lens).** **S5f-1** flipped
          the last live slot readers to aims (`lanes_hub` countdown → soonest active-aim date;
          `activeTargetIsSet` → "the deck has an active aim"). **S5f-2** deleted
          `Deck.{levelId,contextId,trackId,deadline}` + `toTarget` and moved the migration to **parse time**:
          `Deck.fromJson` folds any legacy slot keys into the aims via `foldSlotsIntoAims` (idempotent —
          proven for the post-S5a residual-slots+`target`-aim shape), `toJson` drops the keys (old files
          self-clean on next save), `migratedDefaultDeck` folds via the same helper, and the standalone
          `foldDeckSlotsIntoAims` + the `decks.dart` on-load re-fold/write-through are gone. **0-aim =
          coverage-only** already held (readiness scores `ReadinessTarget.forAim(const Aim(), template)`).
          Suite 989. Data-safe: old JSON slots are read-and-folded, never lost.
          - **`readiness.dart` split ✅** (583 → **262 hub + 222 `readiness_forecast` + 141
            `readiness_feasibility`**). No behavior change: the hub keeps the name + re-exports the two
            derived layers, so all 32 importers are unchanged; `_pick`→public `pickDeck`, `_bindingTarget`
            moved into forecast. Suite 989.
        - **Fidelity guardrails (from the SoT audit):** keep aims **round-shaped** — do NOT build past
          the parked `rounds → milestones` decision; terminology via `Vocabulary` (no hardcoded
          "interview"); hold **invariant #8** (single-aim byte-identical) and **#6** (weakest-link)
          every slice; deck stays a **pure lens** (decouple deck-creation from aim-setting, Accepted).
      - **Behavioral & readiness model — design pass (2026-09-23, 4-agent + adversary investigation).**
        **Conclusion — decided, don't re-litigate:** the behavioral flow stays **as-is** (a separate
        last-mile coverage×freshness readout in the interview-prep hub; task #59). We **rejected** —
        readiness-gated flows, a gated "interview-readiness" **aim**, and **splitting** readiness into two
        top-level numbers. Reasons (all independently reached): (a) *math* — the split rolls recall + transfer
        into two cross-domain aggregates then re-combines, which **inflates** the number (worked example:
        0.71 vs the honest per-domain-conjunctive 0.55) and re-introduces the cross-domain masking that
        weakest-link (#6) exists to prevent; (b) *generality* — the gate/latch is SWE-shaped (native only to
        P4; fails "serve all six with equal dignity"); (c) *SoT cost* — it would rewrite ADR-0006/0009, the
        glossary Aim, and break #8, for a worse number; (d) *research* — a **soft** floor is fine but a **hard
        lock demotivates**; two numbers only help if computed honestly (the two-tone recall/proven bar already
        shows the distinction). The genuine need ("behavioral prep needs runway") is a **nudge**, not a model
        change — and that nudge **already exists** (`coach_update.behavioralDue`, forecast-driven, task #60).
        - **Follow-ups (small, non-blocking):**
          - **Behavioral nudge refinement (③):** de-hardcode the SWE constants `behavioralForecastDays=35` /
            `behavioralWindowDays=28` from `coach_update.dart` → the SWE template (optional, assessment-only,
            default-absent, reusing the `hasAssessment` seam); enrich the "about ready" nudge copy with the
            apply-orientation ("start applying — résumé, LinkedIn, portfolio"). Content = template data.
          - **Behavioral hygiene:** `Story.lastRehearsed` is **dead** (parsed/serialized, never written/read)
            — delete it, or wire it (a mock stamps the story it exercised; today the mock is competency-keyed
            and never records which story, so freshness is competency-level only). Fold into #87.
          - **Glue / career-coach layer:** deferred by decision — only the safe-kernel **in-app** apply nudge
            (above); the fuller out-of-app career/next-steps coach is a **separate identity decision**, not now
            (SoT currently fences it: "not a second brain / authoring studio", anti-guilt).
          - **Artifact-flow seam (Pending, build-when-consumed):** STAR story bank is the only flow that
            produces a durable user **bank** (coverage×freshness lifecycle, vault user-land markdown, non-FSRS);
            n=1 + internally unsettled, so **don't** generalize now — document the seam (a `FlowSpec` could one
            day declare `produces: ArtifactSpec`) and generalize when a 2nd artifact-flow appears.
      - **P0 ✅ (#102) deck-editor data-loss bug** — `deck_editor_sheet._save` rebuilt `Deck(...)` from
        scratch, silently dropping `aims` + target slots on every edit; fixed to `existing.copyWith(...)`.
      - *Open decision before S5:* **rounds → milestones** (scheduler.md Rec, not yet Accepted) — keep
        aims round-shaped until decided; don't build ahead.
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
- **Foundations & evidence-base doc [new, your ask].** Dig up + formalize the learning-science
  principles the app rests on, **with citations**, so design decisions are grounded + auditable (and
  drift is harder to introduce). Cover at least: **Miller's pyramid** (knows → knows how → shows how →
  does), **retrieval practice / the testing effect**, **spaced repetition / FSRS**, **desirable
  difficulties**, the **knowing-doing & performance≠learning gap**, **transfer of learning** (near/far),
  **implementation intentions** (the basis for action nudges), and **notification-fatigue** limits.
  Expand `docs/learning-science.md` into (or beside) a cited foundations doc; link it from the
  user-stories backbone so it's discoverable. Seed citations were already gathered in the S5/behavioral
  design investigation (2026-09-23) — pull from there rather than starting cold. Can be pulled earlier
  than Phase 2 since it grounds decisions we're making now.

## Phase 3 — Finish the MVP
The MVP-tagged stories, cloud still absent:
- The daily loop + Aims + readiness end-to-end for one deck *and* several; the three on-ramps
  (existing lens / create cards / pull); light authoring; deck-scoped Browse/Analytics/Settings.
- Feature calls (decide per story — some may slip to stretch): #22 quiz customization, #26 reader
  comprehension, #25 AI study suggestions.
- The AI **scoping / curriculum research** for deck creation (→ deck_creation) so authoring works
  for any subject, not just SWE.
- **Cram / final-review session** *(pre-publish nice-to-have, not MVP-blocking)* — a dedicated
  **non-rescheduling** rapid re-exposure of a dated aim's due + at-risk cards ("test tomorrow, see
  them again and again today") — FSRS-safe (writes no reviews; see ② cram-vs-durable), reusing the
  gym/practice non-grading session infra, fed by the durability bar + feasibility. Keep the
  non-grading session path reusable in S4/S5 so this drops in cleanly later. (#104)

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
- **Focus / Do-Not-Disturb while studying** (opt-in, Settings toggle) — trigger the OS Focus/DND for
  the duration of a study session to cut distractions, restore on exit. Platform-specific (iOS Focus
  filters / Android DND access, permission-gated); a post-MVP nicety, capability-gated where absent.

## Old-backlog mapping (#NN)
- **Reframed into Phase 1:** #30 / #88 / G7 (→ 1a), #85 (→ 1d), #86 (resolved → 1e), #68 (aims),
  #57 (daily plan), #90 / #91 / #87 / #92 (→ 1c/1h).
- **Kept as-is:** #32 (FSRS engine tuning), #82 / #61 (ship), #83 / #63 / #84 (stretch/cloud),
  #22 / #25 / #26 / #58 (features).
- **Dropped / parked (contradicts the direction):** #50 second-brain expansion.
- **Done arcs, re-shaped onto decks/aims in Phase 1:** #33 / #54 / #59 (practice tracks),
  #51 / #62 (hardening), #64 (multi-subject), #28 (authoring).
