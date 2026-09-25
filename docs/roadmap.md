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
      **Status: S1–S5 ✅ DONE — the deck/aims model is fully realized in code (the deck is a pure lens;
      suite 969→1002). Every slice shipped byte-identical for a single aim (#8). Post-S5 review
      follow-ups #111–#113 are all ✅ done (below).** Key finding (2026-09-22 investigation,
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
      - **S5 — the writer-flip ✅ DONE (2026-09-24; the biggest, most coupled slice).** Surface + coupling
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
        - **Follow-ups** (surfaced prominently under **Behavioral flow — follow-ups & revisit** in Phase 3,
          tasks **#107–#109**): the nudge refinement (③ de-hardcode SWE timing + apply copy), the hygiene
          (`Story.lastRehearsed` + story↔mock link), and the deferred glue/next-steps + artifact-generalization
          design revisit.
      - **P0 ✅ (#102) deck-editor data-loss bug** — `deck_editor_sheet._save` rebuilt `Deck(...)` from
        scratch, silently dropping `aims` + target slots on every edit; fixed to `existing.copyWith(...)`.
      - **Post-S5 adversarial review ✅ (2026-09-24)** — a 4-lens review of the shipped reframe.
        *Fixed in the pass (5 commits, suite 996 green):* a **deck-list data-loss bug** (one corrupt
        `_meta` row made `DeckStore.load` return `[]` → wiped every deck; now per-entry-resilient +
        type-tolerant parse); a **past-dated pending round mis-classified `infeasible`** (→ open-ended,
        so a done-but-unlogged interview no longer hijacks the daily plan); the **Home / lanes / prep
        countdowns read the always-null `target.interviewDate`** (→ `Deck.soonestAimDate`); the aim
        editor's **date-clear dropped a typed round's type/notes**; **aim-row a11y**; and deleted dead
        code (`interview_card.dart`, `Aim.normalized`) + corrected stale deck/aims docs. *Follow-ups:*
        - **#111 (P1) ✅ DONE (2026-09-24) — live-interview outcome logging now reachable.** The aims
          row routed every live aim to the knob editor, orphaning the interview sheet's lifecycle (log
          outcome / advance rounds / archive / resume was gated behind `isEnded`) — a planned interview
          could never be advanced or ended. Fixed: route by `Aim.isScheduledInterview` (company / >1
          round / typed or resolved round → the interview sheet; bare target → the editor), and the
          sheet gains an **"Edit aim"** action back to the knob editor. Recorded in the
          **[ADR-0009] amendment** (2026-09-24). Interview-sheet copy-generality stays #88.
        - **#112 ✅ DONE (2026-09-24) — headline readiness now tier-weighted.** `deckReadiness.scoreFor`
          (and the post-session before-snapshot in `srs.dart`) omitted the `tierWeights` the
          ladder/forecast pass, so the headline band disagreed with the ladder (~15pt). Root cause: the
          targeting-layer refactor (n6535fd9, pre-S2) swapped `computeReadinessForTarget` for an inline
          `computeReadiness` and dropped the arg. Restored `tierWeights: tierWeightsFor(...)` in both the
          headline and the before-snapshot (they must move together — the session delta compares them);
          the headline now equals the canonical `computeReadinessForTarget` (S4's promise). + a
          provider test asserting agreement on a mixed-tier deck. Suite 1001.
        - **#113 ✅ DONE (2026-09-24) — readiness forecast threaded per-deck.** `readinessForecastFor`
          keyed on role only and always used the ACTIVE deck's cards, so a non-active lane's
          forecast/feasibility used the wrong card set. Added `deckId` to `ForecastDims` (memoised per
          deck+role) and resolve the deck via `pickDeck(dims.deckId)`; every caller (active forecast,
          aim editor, `deckAimFeasibility`) passes its deckId. + a multi-deck test (disjoint decks get
          distinct forecasts). Suite 1002.
      - *Open decision (parked; S5 shipped round-shaped):* **rounds → milestones** (scheduler.md Rec,
        not yet Accepted) — keep aims round-shaped until decided; don't build ahead.
    - *Invariant to hold throughout:* difficulty (level) affects readiness **only** via tier-depth,
      never a domain-weight swing (a documented past inversion).
    - *Competing aims* (e.g. backend general aim + frontend interviews): weakest-link readiness (never
      averaged, per-aim shown) + urgency/deadline-weighted allocation + the user's pause lever; the
      coach may gently flag low-overlap tension, never auto-override. Shape agreed; mechanism in
      **S2** (rollup) + **S3** (allocation) + a coach nudge. See the Open decision in `user_stories/index.md`.
- **1b · IA: vault → deck → home — ✅ escape hatch done (2026-09-24)** (→ deck_selection, home).
  The **pause-strands bug is fixed**: a persistent secondary **"Decks"** app-bar affordance on Home
  (always present, even single-deck) opens the new vault-level **`/decks`** deck-selection screen
  (reuses the lanes hub, header-suppressed), so paused decks stay **resumable** with only one active
  deck and single-deck users can add/switch. It **replaces the prominent hub back-arrow**
  (deck_selection.md: "secondary, not a back arrow that reads as leaving"). Kept ADR-0005's
  active-count **degradation** (the inline landing hub still needs ≥2 active) — the escape hatch is
  the on-demand path ADR-0005 flagged as a trade-off (see its 2026-09-24 amendment).
  *Remainder → 1d:* the full **vault-vs-deck scope split** (deck-scoped Browse/Analytics/Settings only
  *inside* a deck; the inline landing hub still carries the deck-scoped tabs — transitional).
- **1c · The Aims surface ✅ (delivered via S5e — see ②Structural)** (→ your_target, scheduler):
  Your Target + Scheduler + the interview list are now **one per-deck Aims surface** (knobs + dates +
  status + zone-calendar), with aims decoupled from deck creation. *(#111 live-aim routing + #90
  debrief reachability both ✅ fixed 2026-09-24 — see 1h.)*
- **1d · Deck/vault scope split — ✅ DONE (2026-09-24): Browse/Analytics + Settings/workload model
  shipped; only refinements remain (#114 Phase B/C, #115, #116)** (→ browse, analytics, settings). **Browse** is now **deck-scoped** — it filters by the active deck's
  membership (whole-vault default deck unchanged; a lens with no members gets its own empty state).
  **Analytics/Insights** was ALREADY deck-scoped: its top-level providers are active-deck wrappers over
  member-scoped `deckX(deckId)` (via `deckMemberCardIds` = `deck.select`); only `studyConsistency`
  stays vault-wide (a cross-deck habit — per-deck would need per-deck study-day tracking, a small
  follow-up). The **light cross-deck glance** at the vault level is served by the `/decks` lanes hub
  (per-deck readiness + budget + countdown). **Deferred → #114/#115 (user direction 2026-09-24):** the
  Settings vault/deck split + workload model. **#114 was REFRAMED — [ADR-0010](adr/0010-workload-budget-and-proportions.md):**
  workload is NOT hand-tuned/per-deck; the user sets only the **vault daily budget** + each deck's
  **proportion** (`budgetWeight`), and the engine derives the study mix (aims + FSRS + urgency), with one
  automatic new-material ceiling. The manual new/day + algo min/max knobs are **removed**; gym → vault;
  a **config-driven deck-flow-settings** scaffold exposes a flow's non-load knobs only when the deck
  declares it (none today). **Phase A ✅ (2026-09-24):** removed the manual knobs (fixed guardrails =
  today's defaults, byte-identical) + reframed the study-load help; added a **`/deck-settings` surface**
  from Home ("This deck only") — the deck's **share** of the budget (live minutes/% + a
  **too-little-time warning**: engagement floor or heaviest-flow unit cost, deck_selection.md) + the
  config-driven flow scaffold + a "Vault settings →" link; gym stays vault. **#85** demote is folded
  (Pace/Algo removed). **Remaining:** a vault-level **cross-deck** allocation view (all shares +
  warnings together — deck_selection.md) is optional/later; **recommended** shares → **#116**. **Settings
  prune + bug-fix → #115.**
  - **Load-control model — [ADR-0011](adr/0011-load-control-auto-mix-propose-size.md) ✅ (2026-09-24):**
    a design flow (research + 3 adversarial critics) reframed the "engine adjusts load + notifies" vision
    to the SoT's **size-vs-mix** line: the engine auto-adjusts the invisible **MIX** (silent); the user
    owns the **SIZE** (budget + proportion); the coach **proposes / applies-on-request, never
    auto-writes**; **silence is the default** (proactive notify deferred, #110). Shipped: **#106 slice 1**
    (reviews-first retention floor in the packer — due reviews clear first up to a cap); the **coach
    repoint** off the three removed dials onto the daily budget + intents (fixes a live docs/code
    contradiction; readyToPush is informational; check-in + chat propose a budget change); subject-neutral
    **study-load help** + a Vocabulary leak-guard test; the **budget sustainability-zone** readout on the
    daily-time dial (the user-pulled "informed override").
  - **Phase B (workload derivation) — sequenced with the #32 engine arc (Phase 3), NOT blocking.**
    Replace the FIXED guardrails with **DERIVED** quantities + the flow-aware automatic ceiling; add the
    precise **budget → ready-by date-shift** readout (moving the budget doesn't shift ready-by until it
    derives the new-count). Needs the **est-minutes fidelity** sliver of **#32** + **#106**. It's a
    *refinement*: Phase A already ships a sane, SoT-conformant plan (the engine derives the mix via the
    packer; the caps are fixed placeholders), so this waits behind the Phase 1 conformance items (1e–1g)
    and rides in with the FSRS-tuning work. Tracked on **#114** (+ #32/#106).
  - **Phase C (proactive proposal / notify) — later, gated on #110 + real usage evidence.** The
    engine-*initiated* size **proposal** + any ambient notify surface — only after the #110
    notification-fatigue foundations (Phase 2) land and instrumentation shows the pull-based model is
    insufficient. **Rejected outright:** the engine auto-writing/pushing SIZE (re-creates the autonomy
    erosion ADR-0010 removed — it can't see real-world urgency) and a proactive pre-deadline taper
    (fights ADR-0007 urgency). Tracked on **#114** (+ #110).
- **1e · Onboarding — ✅ DONE (verified 2026-09-24; the MVP was already built).** The `/welcome`
  router gate redirects until a study folder is configured (`router.dart`); `FolderSourceBody`
  (shared by `/welcome` + the Settings sheet) offers **Choose a folder** / **Create one for me** — the
  create path scaffolds + seeds a subject-neutral **starter deck** (`starter_deck.dart`, the "two taps
  to first review" non-negotiable); native-pick is capability-gated off on mobile; the **pull** on-ramp
  is correctly cloud-absent; deck creation exists (Settings → Decks). #86's folder-first-vs-three-choices
  tension is resolved in the SoT (folder first; on-ramps inside step 2). Tests: `onboarding_test.dart`,
  `vault_scaffold_test.dart`. *Resolves #86.* Parked non-MVP: QR class/org quick-setup (Phase 5).
- **1f · Card model — IN PROGRESS (S0–S4 ✅ + learn/quiz *adopt* ✅; only 1f.1/1f.2 remain); SCOPED [ADR-0012](adr/0012-card-model-shared-components.md) (2026-09-24)** (→ card).
  Scoped via a 10-agent workflow (SoT + code-map of all ~7 spread surfaces + arch + UX → plan → 3 adversarial
  critics). **Decision:** deliver a shared component **LAYER** (`CardScaffold` · `CardSection` (single section
  renderer) · `CardHead` · `CardMetaChip` · `CardLinks` · `sectionExpandDefault`), composed by each thin
  surface — **not** a `CardView(mode)` container (a mode-switch over disjoint bodies is its own smell + would
  funnel the study grade paths). **Study (learn/quiz) keep their own screens + schedulers**, just *adopt*
  `CardSection`; algo/SD/behavioral stay the invariant-#2-exempt engine screens. Fixes two live bugs: the
  hardcoded `'Interview question'`/`'Flashcard'` label (→ `FlowSpec.displayLabel`) and the FSRS **orphan** on
  heading rename (edit keeps history; keep-vs-reset only on a material slug-set change; rekey on the current
  `cardId::sectionSlug` key). **Slices:** **S0 ✅** characterization tests (real grade paths at the
  notifier + DB; study-view rendering contract) → **S1 ✅** shared component layer (`CardMetaChip` /
  `CardSectionPanel` / `CardLinks` / `flowIcon`→design) + VIEW rebuilt byte-identical + config-driven label →
  **S2 ✅** edit keep-vs-reset (FSRS orphan fixed: `sectionSlugDelta` + `renameSection`/`dropSection`) →
  **S3 ✅ (already satisfied)** authoring is a single entry (`showCardEditor` from browse `+` / card Edit /
  draft-review; S4 adds the stub CTA) and AI "make a card about X" ships as `card_generation` — so the
  authoring MVP is met; the in-editor **"update this card" AI edit-chat is deferred** (its coach-seam reuse
  keys on a real `cardId::sectionSlug` a draft lacks, and a fresh panel would fork a 3rd AI surface) → **1f.2**
  below → **S4 ✅** stub screen (`StubNoteScreen` off the unresolved-links target header; References from the
  unresolved graph filtered by target; a plain screen, not a synthetic Card, so no id-guards leak into study;
  "create" seeds the editor with `createSlug` == the raw target so `createCard` writes the stem **verbatim** and
  every `[[target]]` resolves on re-index — `humanizeSlug` + a pure round-trip test guard it).
    → learn/quiz **adopt ✅** the shared chrome — `CardMetaChip` (replaced both private `_Pill` copies,
    byte-identical) + a new shared `ViewFullCardButton` (the study→full-card link, was duplicated verbatim).
    The revealed body stays inline `CardMarkdown` (already the shared body renderer); the collapsible
    `CardSectionPanel` is view/stub-only by design — forcing it into study would double the cue heading (breaking
    S0) and add an unwanted collapse affordance (see ADR-0012 Amendment 2026-09-24). Notifiers/grade-sets/reveal
    gates untouched; S0 green.
  - **Remaining in 1f:** **1f.1** then **1f.2** (below). `CardScaffold`/`CardHead` stay the deferred layer pieces.
  - **1f.1 (engine gaps, each ADR-noted + off-switch + before/after golden):** mastered auto-collapse (retention
    threshold via core/srs `getCardRetrievability`, display-only) + per-card `quizzable:false` (pure DENY;
    precedence deny > allowlist > policy; `quizzable:true` a no-op for MVP). **neverQuizzed** stays read-only
    (per-card override covers MVP; user-editable per-deck set → **#84**, per settings.md).
  - **1f.2 (deferred): in-editor "update this card" AI edit-chat** — the one unbuilt card.md authoring mode.
    Needs a keying decision (an authoring draft/new card has no `cardId::sectionSlug` conversation key) and must
    reuse/extend the existing AI seam rather than fork a third surface (coach + generation already exist).
- **1g · Shared authoring + query API** (→ deck_creation, browse): one card-authoring entry API and
  one query/lens API (Browse filters == the lens language); the scoped card-explorer for building a
  lens.
- **1h · Engine conformance + bugs** (→ architecture invariants). *Mapped 2026-09-24 (Explore agent):*
  - **#90 debrief ✅ DONE (2026-09-24)** — the built-but-orphaned `/debrief` screen is now wired from
    the interview sheet: a live **occurred** interview gets an inline "Debrief with coach" button, an
    **ended** one gets a "Debrief" overflow item. Also fixed the roadmap-flagged mis-named route param
    (`/debrief/:deckId` → `:aimId`; it was always an `Aim.id`). + 2 entry-point tests.
  - **calendar + dev-clock ✅ verified** — both correct, no bugs (ZoneCalendar; the Settings time-travel
    dev clock is persisted + guarded).
  - **#91 (practice content) — DEFERRED (decision).** `/practice/:domain` is wired + reachable (Home
    extra-practice when clear · interview-sheet button · quiz-end) and degrades to concept re-exposure;
    only the *authored interview-question content* is thin. Authoring it (vault content) vs retiring is a
    product/content call, gates **#58**; left as-is (graceful).
  - **#58 (overflow) — DEFERRED**, gated by #91: the "day is clear → optional extra practice" affordance
    is built; the deeper under-fill backfill + effectiveness research is the unbuilt part (near #104).
  - **#87 hygiene — mostly done / #32-coupled.** CardCache, flow_access, the SD *constants*, and (the
    absent) "stem-fn" are all fine; the one residual — the `type == flashcard` concept predicate — is a
    type-branch that needs #32's concept-vs-applied model call (tracked TODO), so it stays with #32.
- **Dropped here (contradicts the guardrail):** **#50 second-brain S2/S3** — Onyx is *not* a second
  brain. The shipped card-links backlinks stay as a minor feature; the notes/graph expansion is out.

## Phase 2 — Polish (look & feel + UX)
- Apply the design system across the re-architected surfaces; motion; empty/loading states.
- **Design tooling — Figma + UI/UX agents [new, your ask].** Wire a solid design workflow so quality
  isn't gated on hand-crafting: a **Figma source-of-truth** for components/screens + an **agent loop**
  that turns designs into Flutter widgets *against the design system*, plus a **design-review agent**.
  Needs a short research spike on the robust integration (Figma API / MCP + a UX-review agent).
- a11y pass (large-text, tap-targets, semantics — carry the #78–#81 discipline forward).
- **Foundations & evidence-base doc [new, your ask; #110].** Dig up + formalize the learning-science
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
- **Behavioral flow — follow-ups & revisit** *(from the 2026-09-23/24 behavioral/readiness design pass;
  full record + rationale in Phase 1's S5 "Behavioral & readiness model" block).* The behavioral flow
  ships and works as-is; these are the agreed next touches — **important to revisit**:
  - **#107 — nudge refinement (③, near-term/small):** de-hardcode the SWE timing constants
    (`behavioralForecastDays=35` / `behavioralWindowDays=28`) out of `coach_update.dart` → the SWE
    template (optional, assessment-only, default-absent); enrich the "about ready" nudge with
    apply-orientation copy. Content = template data, mechanic stays general.
  - **#108 — hygiene (small):** `Story.lastRehearsed` is dead code; decide competency-level freshness
    (delete it) vs per-story (wire a mock to stamp the story it exercised).
  - **#109 — deferred design revisit (touches the SoT):** the **glue / real-world next-steps layer**
    (out-of-app apply/register orientation — a deliberate identity decision the SoT currently fences) and
    the **artifact-flow generalization** (the STAR "bank" is n=1; generalize `FlowSpec.produces` only
    when a 2nd artifact-flow appears).
- The daily loop + Aims + readiness end-to-end for one deck *and* several; the three on-ramps
  (existing lens / create cards / pull); light authoring; deck-scoped Browse/Analytics/Settings.
- Feature calls (decide per story — some may slip to stretch): #22 quiz customization, #26 reader
  comprehension, #25 AI study suggestions.
- The AI **scoping / curriculum research** for deck creation (→ deck_creation) so authoring works
  for any subject, not just SWE.
- **Engine tuning + workload derivation (#32 · #106 · #114 Phase B).** The FSRS-quality arc: state-aware
  **est-minutes** + optimizer-from-history + the desired-retention knob (#32), the **capped retention
  floor** est-minutes fidelity (#106, its reviews-first slice already shipped), then flip the workload
  guardrails from **fixed → derived** (budget/urgency-aware new + practice quantities under the flow-aware
  ceiling) and add the **budget → ready-by date-shift** readout (ADR-0011 Phase B). Not MVP-blocking — the
  shipped fixed guardrails already produce a sane, SoT-conformant plan — but this is where "the engine
  derives the quantities" becomes fully real. (**#114 Phase C** — engine-initiated proposals + notify —
  waits further, on #110 + usage evidence.)
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
