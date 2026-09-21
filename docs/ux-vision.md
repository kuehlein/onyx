# Onyx — Ideal UI/UX & App Layout (North-Star Spec)

> **Build-state note (2026-09-20):** this doc predates parts of the implementation. For the authoritative what's-built-vs-next, see [roadmap.md](roadmap.md). Corrections: the coach de-privilege (§3.3) and the engine-generalization (§6 / "Phase 5") are DELIVERED — see #30 in roadmap.md.

> Produced by the `onyx-ux-vision` research+design workflow (18 agents: internal
> learning-science/dataviz/as-is mining + external learning/PKM UX research → 8
> per-surface designs → adversarial coherence + calm/over-engineering critique →
> synthesis). Opinionated and decisive; `[principle]` tags mark research-grounded
> choices. Locked constraints (lanes hub, query-lens goals, anti-gamification,
> dataviz principles) are non-negotiable.

Status: north-star flow/layout spec. Opinionated and decisive. Where a choice is grounded in research it is tagged `[principle]`. Locked constraints (A1–A8 UX, B1–B9 dataviz, learning-science rules) are treated as non-negotiable.

---

## 1. Product vision & committed UX principles

**Vision.** Onyx is a calm, local-first study client over a plain markdown folder (an Obsidian vault works as-is, but Obsidian is never required). Cards are a *query-lens* over your notes, not a parallel store. **The product is general and education-first** — its audience is learners and teachers across every subject (K→grad, self-learners); SWE-interview prep is one configuration among many, not a privileged default. Many subjects live at once in one folder, sharing one daily budget; the common case (a single active goal) must feel like a single-purpose study app. Motivation comes from **honest information about your own progress toward your own goal** — never points, badges, streaks-as-score, or guilt.

**The ten principles Onyx commits to (and enforces in code review):**

1. **Time-to-first-review is the metric.** Two taps to a real review session; zero deck-building. `[Anki/RemNote friction research]`
2. **Bounded, finishable sessions with an honest "done for today."** A backlog can never render as an avalanche; the ramp/taper budget caps intake. `[Anki pile-up dread]`
3. **Recall, principle-first.** Card backs lead with the generative "why" and the recognition trigger, expanded + accented; the specific fact is derivable. `[rule-based encoding; conditional-knowledge priority]`
4. **Spacing is FSRS's job.** Never expose cramming or off-schedule reviews; the only overload lever is *cutting NEW intake*, never chasing retention above ~95%. `[FSRS; retention 80–95%]`
5. **Honest readiness.** Weakest-link caps readiness; show a band that widens with thin evidence; say "can't judge yet," never a fabricated 0%; readiness must be able to fall. `[conjunctive aggregation; uncertainty viz; "a number that can't fall carries no info"]`
6. **Under-notify.** Coach is silent when on-track (≤1–2/day); every nudge = goal + current signal + the ONE next action, task-level never ego. `[>1/3 of feedback interventions reduce performance; d≈0.99 vs 0.24]`
7. **Autonomy, not control.** Nudges are informational + a choice (Apply / Not-now / Undo); nothing mutates silently; flows are user-chosen, not force-sequenced. `[SDT]`
8. **Calm visual restraint.** Off-white on dark-gray (no halation), one accent hue, hierarchy from weight/opacity, bars for comparison, ring only for a single completion %. `[Cleveland–McGill; Tufte/Few; 6-color overload finding]`
9. **Per-goal truth.** Every metric is computed per-goal through that goal's query + template. No single global number across subjects; no re-coupling to `Card.subjectId`. `[locked A3/A4]`
10. **No privileged subject; the engine is genuinely general.** Dimensions/tracks/rubrics/terminology route through the template; render only what the active goal declares. There is **no shipped default subject** — SWE-interview config is authored content like any other (the built-in `softwareInterviewsConfig` is a de-privileged fallback/example, not a baked-in identity). The generalization is the product thesis, targeted at all learning use cases, not a retrofit. `[locked A6; de-SWE correction 2026-09-17]`

**Explicitly rejected (do not "helpfully" re-add):** **required** accounts/login (accounts are now optional-but-real, capability-gated — rendered only when a backend capability is reachable; see §3.7, §9, and `registry-and-sync.md`), light/system theme, XP/badges/levels/leaderboards, streak-freeze/loss-aversion, **comparative/competitive** mechanics (leaderboards, cross-student ranking, any per-student comparison) — but note **aggregate/belonging cues are allowed via the class config** (relatedness is not gamification; `product-direction §9`), a full-vault graph on any daily surface, in-body tap-navigating wikilinks.

---

## 2. Information architecture & navigation

**Decision: 4-tab bottom nav as the app frame; "hub-first" lives *inside* the Home tab as its top altitude.** Tabs win because Home/Browse/Insights/Settings are co-equal, cross-cutting, revisited across sessions (3–5 tab sweet spot). Hub-first wins *within* a study session because a session is single-branch. These don't compete: the lanes hub is Home's zoomed-out state. `[NN/g hub-vs-tabs; UXPin 3–5 tabs]`

**The one spine: `focusedGoalProvider` (nullable).** One explicit piece of app state = "which goal am I looking at," `null` = all-subjects/hub altitude. It replaces both the `_focused` setState and the side-effect `selectedStudyGoalIdProvider` (Seam D's hidden coupling). Home, Browse, Insights all read it. Deep-link route params (`/insights/:goalId`) *set* it — the route is the entry, the provider is the runtime truth, so they cannot disagree. `[resolves Critique 1 §A]`

- **`null` vs a goal id is defined once:** single active goal ⇒ `focusedGoal = that goal's id` (never null-when-single); `null` occurs only in the ≥2-goal hub before a lane is entered.
- **One `activeGoalCount` helper (paused excluded)** drives *every* degradation check across surfaces, so 1-active+1-paused behaves identically everywhere. `[resolves Critique 1 §G]`

```
┌──────────────────────────────────────────────┐
│   (per-screen AppBar / SheetHeader sheets)     │
│                                                │
│                ACTIVE SCREEN BODY              │
│                                                │
├──────────────────────────────────────────────┤
│  [ Home ]   [ Browse ]  [ Insights ]  [ ⚙ ]   │  4 tabs, IndexedStack
└──────────────────────────────────────────────┘

focusedGoal = null (all)            focusedGoal = id (one goal)
──────────────────────────          ──────────────────────────
Home     Today's mix (lanes hub) ◄──enter lane──►  Goal's Today Home
Browse   All-vault search         ──scopes to──►   goal-lens pre-selected
Insights small-multiples overview ──drill in──►    goal's 4-group detail
Settings (altitude-agnostic)                       (altitude-agnostic)

Movement:
  hub ──tap lane──► set focusedGoal=id ──► goal Home
  goal Home ──"‹ Today's mix"──► clear focus ──► hub
  goal Home ──tap flow──► /quiz /learn /algorithms … (focus carried)
  finish ──► goal Home ("done for today")
```

**No 5th "Goals/Aim" tab.** Enshrining the aim in the IA would enshrine the three-aim confusion. Goal management is a SheetHeader sheet reachable from the hub and Settings; milestones (dated targets) live inside the goal editor (§5).

---

## 3. Surface designs

### 3.1 Home — altitude 0: "Today's mix" (≥2 active goals, focus=null)

Calm lane list. Per Critique 2 §7, the lane is **trimmed** to the critical few: name · one status verb · deadline-or-none · minutes. No per-lane due-count token (avoids the shared-FSRS double-count landmine — §7 below), no per-lane pause chrome (moved into adjust-mix).

```
┌─────────────────────────── Onyx ──────────────────────────┐
│  Today's mix                                               │
│  Your goals share the day. Tap one to study it.           │
│                                                           │
│  ▓▓▓▓▓▓▓░░░░░▒▒▒▒▒░░░░  ~45 min today · 3 goals           │  ONE read-only
│  ■ Algorithms 22m  ■ Backend 14m  ■ Korean 9m            │  SharedBudgetBar
│                                                           │
│  ┌───────────────────────────────────────────┐          │
│  │ Algorithms            78% ready · 12d   ~22m › │       │  trimmed lane
│  ├───────────────────────────────────────────┤          │
│  │ Backend               can't judge yet · 40d ~14m › │   │  honest verb
│  ├───────────────────────────────────────────┤          │
│  │ Korean                coverage 40% · —  ~9m › │       │  no fake %/countdown
│  └───────────────────────────────────────────┘          │
│                                                           │
│  ⏸ Calculus · paused                                      │
│                                                           │
│  [ + New goal ]                        [ Adjust mix ]     │  no Filled button
└───────────────────────────────────────────────────────────┘
```

- Status verb is **template-derived**: dated-target (milestone) goal → readiness %; open-ended → coverage %; thin evidence → "can't judge yet." `[A6; honesty]`
- Budget = one read-only `SharedBudgetBar` (stacked, single hue at graded opacity, per-segment Semantics label). Bars not rings. `[Cleveland–McGill; B8]`
- No Filled button on the hub — choosing a lane *is* the primary act. `[M3 emphasis B7]`
- Empty (0 goals): one centered card → goal editor. Loading: 2 skeleton lane rows.

### 3.2 Home — altitude 1: one goal's Home (1 active goal, or a lane entered)

Byte-identical to the pre-multi-goal Home when only one goal exists (`‹` back and all "mix" chrome invisible). `[locked A2]` The daily loop lives here (§4).

```
┌── ‹ Algorithms                              Ready 78% ──┐  chip = goal-aware
│  Tuesday, September 16                                  │
│  ┌──────────────────────────────────────────────┐      │
│  │ ⚑ Your target            Senior·BigTech  12d › │      │  _TargetCard,
│  └──────────────────────────────────────────────┘      │  GOAL-AWARE (§5)
│                                                        │
│                    ╭───────────╮                       │
│                   │    62%      │  today's queue       │  ONE ring =
│                   │ ~14 min left│                      │  single completion %
│                    ╰───────────╯                       │
│                    [  Continue  ]                      │  ONE Filled, plan-driven
│  Today                                                 │
│   ● Review        6 due          ~6 min           ›    │  TodayFlows,
│   ● Algorithms    2 problems     ~8 min           ›    │  template-filtered
│   ○ System design not scheduled today                  │  segment-always
│                                                        │
│  ⓘ Again-rate on graphs jumped — drill these 3.       │  CoachBadge ≤1/day
└──────────────────────────────────────────────────────────┘
```

- Ring = the one legitimate radial (single completion %); the *small quantity* (today's wins) is the hero, readiness is a chip. `[Koo–Fishbach small-area; Cleveland–McGill]`
- Flows render from the active goal's `SubjectConfig.flows`, not the hardcoded `TrackId` set. Non-declared tracks show dimmed "not scheduled," never hidden. `[A6; segment-always]` **Caveat: this is only honest once the engine is generalized — see §6 and §9.**

### 3.3 Study / session (Learn, Review, mocks)

> **Delivered (2026-09-20):** research-backed coach foundation + vault CoachSkill augmentation; critic/report/nudge neutralized. See [roadmap.md](roadmap.md).

Two archetypes only: the **card-turn loop** (cue → reveal → grade) and the **conversation loop** (turns → End → grade). Keep both current shapes; two changes now, one deferred.

**Card-turn (Learn/Review) — do now:**
```
┌─────────────────────────────────────────────┐
│ ✕ Review              [🎤 in coach] [Coach]   │
│ ▓▓▓▓▓▓▓▓░░░░░░  (linear progress — bounded)  │
│ 4/18   domain   🟡 confidence                │
│  ┌─ WHEN TO USE / RECOGNITION ─────────────┐ │  conditional-knowledge
│  │ (the cue — trigger, not the fact)        │ │  section leads, accented,
│  └──────────────────────────────────────────┘ │  expanded by default
│  ── after reveal ─────────────────────────── │
│  Principle / "why" first (dominant)          │  rule-based encoding
│  then the instance;  [vs. sibling X]         │  interference contrast row
│  before: [Answer the coach] [Reveal]         │  one Filled per state
│  after:  [Again][Hard][Good][Easy]           │
└─────────────────────────────────────────────┘
```
- Move `isInterview`/`card.type` branching behind `FlowSpec.cuePolicy` (approach-led vs section-led cue). Reveal leads with principle; recognition section expanded. `[rule-based; conditional-knowledge]`
- `ConfidenceBadge` on every meta row; auto-surface Resources link on low-confidence. `[per-card confidence]`
- `vs. X` contrast row on near-adjacent confusable siblings. `[interference]`
- **Required companion fix — de-privilege the coach hot-path (Stage-1 P1-3, "no privileged subject").** `buildCoachSystem` (`coach.dart:40-131`) today opens *every* recall conversation as "a spaced-repetition app for software-engineering interview prep… an interviewer from a strong engineering org," with SWE topic routing, and the grade persona label is "Interviewer" (`coach_sheet.dart`). For a 7th-grader on WW1 causes this is a de-privilege violation mid-recall. Take the persona + domain vocabulary from the active goal's `SubjectConfig` (the seam `flow_prompt.dart` already uses); SWE wording moves into `software_interviews.dart`. This is a hard dependency of principle #10, tracked with the §6 engine-generalization workstream. `[Stage-1 P1-3; principle 10]`

**Conversation loop (mocks):** keep `SdMockScreen`/`mock_session.dart` as-is for v1. Do only the **bug-shaped** fixes: replace the `"I'm ready"` string-prefix kickoff hack with an explicit `isKickoff` flag; reuse the already-parameterized `MockGradeSummary` (rubric **bars**, template dims). **Defer** the unified `FlowRunnerScreen` + calibration-axes model until a real non-SWE flow is authored — building it now is abstraction-before-second-caller. `[Critique 2 §4; generalization is task #30, not this pass]`

**Speech-to-text:** promote the existing `CoachSheet` mic (graceful-degrade already handled) into the shared `chat_view.dart` composer so coach/mocks share one implementation. Mic stays *out* of the card-turn grade bar (dictation is friction in a tap-and-grade loop). Full STT-first conversation UX is a **future task**.

### 3.4 Goal management + the unified "aim" model

**One primitive: `StudyGoal` owns what-I-study AND what-I-aim-at. Milestones (dated targets) are a goal's optional dated sub-targets.** (User-facing term is **"milestone" / "dated target,"** never "interview"; the underlying entity — code type `Interview`, re-parented from `PrepGoal` — is unchanged, and the mechanics are already generalized via `effectiveDeadline`.)

```
StudyGoal  (the ONE aim)
├── name, templateId, membership query      what cards (the lens)
├── target: level/context/track             what bar (template dims)
├── deadline?                               distal date (null = open-ended)
├── budgetWeight, state
└── interviews: List<Interview>             optional dated sub-targets (milestones)
                (today's PrepGoal, re-parented under the goal)

effectiveDeadline = earliest(active milestone round) ?? deadline
   → the ONE date every surface reads (lane, target card, plan taper)
```

**Goal editor** = one SheetHeader sheet, progressive disclosure so open-ended goals never see milestone chrome:

```
╭─ ⚑ New study goal ─────────────────────── ✕ ╮
│ Name            [ Korean ]                    │
│ Which cards     ▐Whole vault▌ Tag  Folder     │
│ ── Aiming at ──                               │
│  Target   Level/Context/Track  (template chips)│  render only what template
│  Deadline [ 📅 No deadline           Set ]    │  declares; else collapse block
│  ▸ Milestones (0)             [+ Plan]        │  shown ONLY if template
│  Share of daily time   1.0×  ●───○────        │  declares a dated-target context
│  [ Create goal ]   (edit: ✓Graduate  🗑Delete)│  one Filled button
╰───────────────────────────────────────────────╯
```

**Adjust-mix sheet** (the sole budget *editor*; sliders show live minutes, persist on drag-end, no Save — a dial not a form). `[Readwise per-source weighting; Notion global control; SDT autonomy]`

### 3.5 Browse / second-brain

**Do now (cheap, honest per-goal):** a goal-lens `SegmentedButton` `[This goal · All cards]` re-scopes the existing search pipeline via `membership.matches`. Hidden entirely when `activeGoalCount <= 1` (single-goal degradation). Reads `focusedGoalProvider` — no competing local picker. Card detail: add **"Referenced by" (linked backlinks only)**, rendered only when non-empty — nearly free from existing `card_links`. `[cards-as-lens; A2; A3]`

**Defer (Critique 1/2 agree — scope creep before #50 write-path exists):** the "Related concepts" neighborhood, the "Source note" pane, unlinked-mention suggestions, and the entire **Gaps / Vault-health** view (unresolved-links table + screen). These serve *authoring/curriculum-build*, not studying; authoring lives in the vault. Full-vault graph is never a daily surface. `[PKM: graph is an audit tool, not a dashboard]` → **future task #50.**

### 3.6 Insights — two altitudes (mirrors Home)

**Prerequisite, not optional:** convert the analytics providers (`retentionByDomain`, `dueForecast`, `strugglingCards`, `studyConsistency`, `mockSkills`, `patternMastery`) to `goalId` `.family` keyed on membership. Today only readiness is goal-scoped; the other panels read the whole vault — the "per-goal" page is a hybrid lie under multi-goal. This must land before the overview ships. `[Seam D]`

```
Altitude 1 — All goals (≥2 active)          Altitude 2 — one goal (drill/single)
─────────────────────────────────          ──────────────────────────────────
small-multiples grid (identical scale)      [41%][62%][55][4/7]  summary strip
 ┌ Backend 41% ▁▃▅↓ weakest:Caching 22%┐    ▸ Readiness (band, weakest-link,
 ┌ Algo    78% ▅▅▆→ weakest:Graphs 61% ┐        ladder, coverage bar) ← expanded
 ┌ Korean  — not enough data yet        ┐    ▸ Memory & recall
 sorted "needs attention" first             ▸ Applied (template dims only)
 ⚠ one action line: "focus Caching"         ▸ Habits
```

- Small multiples, same scale, sorted most-off-track; weakest domain named on each tile; thin evidence → "not enough data yet." `[Tufte small multiples; weakest-link; uncertainty]`
- **No cross-goal aggregate number, no leaderboard, no combined streak** — averaging different templates is dishonest. `[A3; vanity-metric research]`
- Add a **Coverage** bar to the Readiness group (the cheapest "what's next" signal). Add a **Pace group** here so the relocated pace-planner has a home (`/insights?focus=pace`). `[Pace-Models: forecast owns ready-by, belongs in Details tier]`
- **One** stacked budget bar total across the app (Home hub, read-only). Insights uses small-multiples for cross-goal comparison — **no second stacked bar** there. `[Critique 2 §6, redundant ink]`
- `ReadinessPanel` must be parameterized by goal (stop reading the legacy global controller) before reuse in the per-goal detail — hard dependency of §5's aim surgery. `[Seam C/A]`

### 3.7 Settings — 6 calm groups

Anything you tune to change *today* lives where you study; anything configured once lives here. Config that changes *what becomes a card* lives here (rare, app-wide, dangerous-if-wrong); config that changes *what you study today* lives where you study. **Full spec: `docs/settings-ux.md`** (placement, per-row copy, and the directory-agnostic source flow).

```
SOURCE          Folder ›   Cards (N) ↻   Card parsing (Headings H2 · .md) ›
STUDY LOAD      Daily study time [−+]   New per day [−+]
                Weekly check-in [ ● ]   ⓘ How much should I study? ›
STUDY GOALS     Manage goals (3 active) ›   → per-goal template levers
DATA & BACKUP   Back up now (2h ago) ›   Restore ›
CLAUDE (AI)     API key (Saved on this device) ›   Test connection ›
ABOUT           Version, licenses, privacy, restore-defaults ›
▸ Developer     (dev builds only, collapsed — the sole collapsed group)
```

- **Settings stays the 4th bottom-tab** (reject gear/drawer/profile — each breaks a locked constraint: altitude-agnostic spine, no-account principle, hidden-menu engagement loss). `[settings-ux §1]`
- **SOURCE** (renamed from VAULT): user-facing noun is **"folder" / "study folder," never "vault"** (Obsidian-compatible, never required). The **Card parsing** row is a *read-only* explainer (`HowCardsAreReadSheet`) reserving the future configurable-parser seam — **not** a live control, **not** an "Advanced" group (advanced lives one-layer-down via a sheet). `[settings-ux §2/§4]`
- **STUDY LOAD stays here** — its levers are config-once; merging them into `AdjustMixSheet` would collide with §4.6 (sole budget editor) and §7 (no duplicate editors). `[settings-ux §2]`
- **Move the Pace planner out** to Insights (it's a forecast dashboard, not a setting). `[Pace-Models; B3]`
- **Demote Algorithms/Gym mode** from top-level into per-goal template drill-downs, rendered only when the goal's template declares the track. Interim honest state: render under the default goal labeled "Algorithms track," not fake per-goal independence. `[A6; B4]`
- **No theme row** (dark-locked, principled). **No Advanced group** (one stub doesn't earn a header). **Account UI is capability-gated, not blanket-rejected:** the ACCOUNT group renders **only when a backend capability is actually reachable** (a server endpoint configured + health-reachable, or a class code has bound this device) — with no reachable backend it is **absent, not disabled** (an empty account section is the dark pattern we reject; the same reachable-capability guard as the AI-tier "coming soon" row and SYNC). **Notifications:** not a blanket cut — **one opt-in, off-by-default, due/plan-tied, non-guilt reminder** (backlog is the dominant SRS failure; a due-reminder is retention infrastructure, never a streak/guilt crutch; ~1–2/day cap). `[registry-and-sync.md §1.1; product-direction §7/§9; settings-ux §6]`
- Goal target editing routes to §5's goal editor — never the legacy global `showTargetSheet`. `[Seam C]`
- Restore + Reset-progress are real `DestructiveRow`s (error color + outlined shape + text label + confirm — all four, never color-only). `[B8; design-system §4.9]`

### 3.8 Onboarding

First-run is a **redirect gate**, not a wizard tab — an **intent-gate ("What do you want to do?"), not a folder-first gate.** `[time-to-first-review; autonomy; product-direction §5]`

```
launch → needsSetup? → /welcome  ← the intent-gate: "What do you want to do?"
      three CO-EQUAL tonal choices (ordered by audience size, none the hero):
        1 Make cards from my material  → paste/topic → AI-generate (→ Draft gate)
        2 I have a class code          → pull a restricted, teacher-pushed deck
        3 Point me at my folder        → the only path that names "folder" (power path);
                                          Onyx can also CREATE a folder + seed a
                                          subject-neutral sample deck for a user with no notes
      → the folder is a SILENT CONSEQUENCE of paths 1–2, never a gate in front of them
      → index (plain "Indexing…", then land)
      → auto-create default all-cards goal (single-goal degradation)
      → land on single-goal Home with due cards
      → dismissible "add key" banner; key requested inline at first AI flow
```

- `/welcome`: the **intent-gate** — a pre-shell page presenting the three co-equal on-ramps (**Make cards from my material** · **I have a class code** · **Point me at my folder** + light manual create/edit) as tonal, equal-weight choices; **AI-generate is NOT the hero.** Only path 3 names "folder" out loud: it renders the shared `showFolderSourceSheet` body — **"Choose a folder"** (existing folder or Obsidian vault, read as-is) + **"Create a study folder"** (app scaffolds a dir + a subject-neutral sample deck for users with no notes) — with the local-first contract line ("nothing leaves it") and an on-request **"What can I point it at?"** in-place expander (replaces the old "What's a vault?" gate). No account row, no carousel, no tutorial. `[product-direction §5; content-creation §2/§5; NN/g no-tutorial; UXPin progressive disclosure; settings-ux §3]`
- Key sheet is shared (`showApiKeySheet`, extracted from Settings), "Not now"-able; review works fully key-less. Store in Keychain with **`ThisDeviceOnly`** accessibility (one-line security fix, do it regardless). `[HackerOne BYOK]`
- First goal defaults to `AllMembership` ("deck = query"); explicit scoping is deferred/progressive. Folder-but-no-cards → calm empty state, one action, no scold.

---

## 4. The daily study loop, end-to-end

```
Open app
  1 active goal ─────────────────► single-goal Home
  ≥2 active goals ───────────────► Today's mix hub ──tap lane──► goal Home

Goal Home: ONE Filled button, label = pure function of dailyPlan
  ┌ nothing scheduled → ring "—"/"All caught up", NO button (full stop)
  ┌ work waiting      → "Start"    → first non-empty track
  ┌ partway           → "Continue" → next non-empty track (ring %, ~min left)
  └ all done          → ring "✓"/"Done for today", Filled button GONE

Session (card-turn):  cue → recall → Answer-coach OR Reveal → grade (FSRS)
  bounded by ramp/taper budget — backlog never dumps as an avalanche
  interleaved by design (one-time inline "mixing is intentional" hint)

Finish → back to goal Home → "done for today" signaled by ABSENCE of Filled button
```

- One "Study Now"-style entry; honest counts; bounded + completable. `[Anki loop]`
- "Done" is a **full stop.** Caught-up state does **not** carry a standing "study ahead / learn more" button — that softly reintroduces off-schedule intake against FSRS. If new intake is available, surface it *once* contextually, never as a persistent nudge that turns "done" into "done, but…". `[Critique 2 §8; spacing is FSRS's job]`
- No confetti, no XP; competence = visible completion + honest readiness delta.

---

## 5. The three-"aim" consolidation (resolved)

**Canonical end-state (Design 5 model):** `StudyGoal` is the single aim owner; `PrepGoal`→`Interview` re-parented under the goal; base `ReadinessTarget` folded into the default goal (kill the `defaultGoalId` short-circuit at `readiness.dart:232`); `effectiveDeadline` is the one date resolver; `/interview-prep` route deleted; `target_sheet.dart` retired into the goal editor.

**But sequence it as two steps (Critique 2 §5 — this is a multi-week refactor five other designs disclaim owning):**

- **Step 1 (ship first, cheap): the visible-bug micro-fix.** Add `effectiveDeadline`; make `_TargetCard` read `activeTargetProvider` + `activeStudyGoalProvider` with a template-driven label; route its tap to the goal editor sheet (not `/interview-prep`). This kills the visible "three dates disagree" and "chip-vs-card describe different aims" bugs (Seam C) at low blast radius. Single-goal degradation stays byte-identical (the default goal resolves identically to the legacy target).
- **Step 2 (own task): the storage unification.** Re-parent interviews, rename `PrepGoal`→`Interview`, kill the short-circuit, migrate `onyx-target.json`, delete `/interview-prep`, retire `target_sheet`, parameterize `ReadinessPanel` by goal, fold each goal's interviews into `targetingForGoal` (fixing the non-default-goal biasing drop). Do **not** delete the route + retire the sheet + add a new sheet in one PR (max blast radius).

Milestones (dated targets) live in **one** home: the goal editor's Milestones section (consistent with "StudyGoal owns the aim"), not a sheet-in-Insights. (User-facing "milestone / dated target"; the code type stays `Interview`.)

---

## 6. Engine generalization — the product thesis, first-class (reframed 2026-09-17)

> **Delivered (2026-09-20):** #30 G1–G6 — SubjectConfig (from _meta/onyx-subject.yaml) drives the daily plan, prerequisite gating, readiness, coach voice, terminology, and the card parser; the Korean reference subject is acceptance-tested end-to-end.

**Corrected stance (supersedes the earlier "keep SWE-default, generalize only when pulled" framing):** genuine generalization is *the product* — Onyx is general and education-first, and SWE-interview prep is one authored configuration, not a privileged default. The earlier YAGNI deferral was wrong on its own terms: the second caller **already exists** (a Korean vault today; theology/college/stats intended), so the abstraction is pulled, not built-on-spec. The engine-generalization workstream is therefore **near-term and first-class, not deferred behind a hypothetical second subject.**

What still holds: **do not ship a UI that *lies* about being general** — six surfaces hiding SWE rows over a scheduler that still weights `ds-a`, tapers on `prepGoalsProvider`, and reserves system-design mock cadence is worse than honest-but-ugly. `[Critique 1 §C]` The resolution to that incoherence is to **do the generalization**, not to defer it and hide rows.

**Direction (concrete sequencing lives in a dedicated re-plan — see note below):**
1. **The daily-plan/template generalization is the real owner** (unrepresented in the 8 original designs): `TrackId` → template-declared track set; `weightForDomain` keys from template; taper keyed off `effectiveDeadline` not `prepGoalsProvider`; mock cadence config-driven; `softwareInterviewsConfig` de-privileged to a fallback/example, not baked-in identity. `[Seam B]`
2. **No shipped default subject.** A folder with no config still needs *some* working behavior, but the built-in should read as a neutral example, and non-SWE goals must run a correct (not SWE-shaped) schedule — not a lying UI, and not a gated second-class path.
3. **One shared vocabulary** for `FlowSpec.cuePolicy` + rubric/calibration dimensions, consumed by both the plan generalization and Insights' Applied group. D4's "calibration axes," D7's "applied dimensions," D8's "template levers" are the same thing — unify the name.

> **Re-plan pending.** The full engine-generalization plan (phasing, what "no default subject" means for a config-less folder, how the current SWE-tied schedulers become template-driven with 1:1 parity) is to be worked out in a dedicated planning pass against the general/education-first target. This section records the corrected *stance*; it is not yet the implementation plan.

---

## 7. Cross-surface correctness rules (fold in the critiques)

- **Overlapping-membership aggregation, defined once** (shared helper both `goalBudgetsProvider` and the Insights `.family` providers call): *a shared card counts once toward total budget, credits completion to each lens, contributes retention to each lens.* Decide this **before** Browse advertises overlap and Insights aggregates it. `[Critique 1 §E]`
- **No per-lane due-count tokens** on the hub — they force the double-count problem for a nice-to-have. The lane's own Home is one tap away. `[Critique 2 §3]`
- **One `SharedBudgetBar` widget** (read-only, Home hub only); the adjust-mix sheet is the sole editor. No duplicate implementations. `[Critique 1 §D; Critique 2 §6]`
- **One `activeGoalCount` (paused-excluded)** for all degradation checks. `[Critique 1 §G]`
- **Route params set `focusedGoalProvider`; the provider is runtime truth** — never a parallel source. `[Critique 1 §A]`

---

## 8. Design system / component note

- **Material 3 emphasis = priority:** exactly one Filled per surface → tonal → outlined → text. "Done for today" is communicated by the *absence* of a Filled button, not a trophy. `[B7]`
- **SheetHeader everywhere:** every drill-down, editor, and "explain this metric" is a `shared/widgets/sheet_header.dart`-topped slide-up sheet — never a new full page. Only `/welcome` is a pre-shell full page (justified: the hard gate). `[A7]`
- **Calm dark theme (locked):** off-white on dark-gray, no #FFF-on-#000; body ~16px / line-height 1.5 / measure ~66ch; one accent hue, hierarchy from weight+opacity; syntax highlighting small-palette, comment contrast ≥4.5:1. `[presentation constraints]`
- **Charts:** bars for comparison/per-domain, lines/sparklines for trends, ring only for a single completion %, shaded band + verbal qualifier for forecasts. Every status pairs color + shape + number + Semantics label. `[Cleveland–McGill; B3; B8; uncertainty viz]`
- **Progressive disclosure:** teaching/quizzable sections expanded + accented; collapse only supplementary material and label it. No inline tap-navigating wikilinks in study passages. `[segment-always; link-free passage]`

> A dedicated design-system / visual-language / widget-library spec (tokens,
> theming, motion, the concrete widget catalog) is produced separately in
> `docs/design-system.md` (companion workflow), grounded in this layout.

---

## 9. Phased build roadmap (mapped to the current app)

**Phase 0 — Foundations (net-new spine + safe micro-fixes)**
- `focusedGoalProvider` (nullable) replacing `_focused` + `selectedStudyGoalIdProvider`; `activeGoalCount` helper. *(changes: home_screen, router, all goal-aware consumers)*
- Seam C micro-fix: `effectiveDeadline` resolver; `_TargetCard` → `activeTargetProvider` + template label; tap → goal editor. *(changes: home_screen, readiness, study_goal)*
- API key `ThisDeviceOnly` + shared `showApiKeySheet`. *(changes: api_key_store, settings_screen)*

**Phase 1 — Honest per-goal (cheap, high-value)**
- Goal-scoped Browse segment + "Referenced by" backlinks. *(changes: browse_screen, card_detail_screen — no new data)*
- Analytics providers → `goalId` `.family`; overlapping-membership helper. *(changes: analytics.dart)*
- One `SharedBudgetBar` (read-only) + one adjust-mix sheet. *(net-new: adjust_mix_sheet, shared_budget_bar; changes: lanes_hub)*

**Phase 2 — Home loop + Insights two-altitude**
- Single Filled plan-driven button; template-filtered TodayFlows (honest "not scheduled" rows); caught-up = full stop. *(changes: home_screen, today_flows)*
- Insights small-multiples overview + Coverage bar + Pace group; parameterize `ReadinessPanel` by goal. *(changes: insights_screen, readiness_panel; net-new overview)*

**Phase 3 — Onboarding + Settings IA**
- `/welcome` gate + `IosVaultSource` (security-scoped bookmark) + `VaultRef` persistence. *(net-new: welcome_screen, ios_vault_source, vault ref; changes: router, vault provider)* — **BLOCKER: no on-device vault source exists today.**
- Settings → 6 groups; move Pace planner to Insights; demote Algorithms/Gym to per-goal drill-downs. *(changes: settings_screen)*

**Phase 4 — Aim storage unification (dedicated task)**
- `PrepGoal`→`Interview` re-parented under `StudyGoal`; kill default-goal short-circuit; migrate `onyx-target.json`; delete `/interview-prep`; retire `target_sheet`; fold interviews into `targetingForGoal`. *(changes: prep_goal, readiness, study_goal, interview_prep_screen, target_sheet, daily_plan)*

**Phase 5 — Engine generalization (first-class workstream; own re-plan — see §6)**
- `TrackId`/`weightForDomain`/taper/mock-cadence → template-driven; `softwareInterviewsConfig` de-privileged to a fallback/example (no shipped default subject); unified cuePolicy/rubric-dimension vocabulary; 1:1 functional parity with today's SWE behavior. This is the product thesis, not a deferred nice-to-have — sequence it as its own planning pass, not "when a second subject pulls it." *(changes: practice_plan, daily_plan, flow_spec, subject)*

**Deferred / future tasks (explicitly not v1):**
- **Accounts/login/sync** — **optional, capability-gated, seams reserved now** (not "rejected," not "revisit only when forced"): `sync ≠ server ≠ accounts` — merge-correct folder-sync ships v1 (fixes a live LWW bug), account UI renders only when a backend capability is reachable, account-sync carries progress + goals only (never content), and the deck registry is restricted-first. The account/registry *server* build is deferred; the model + reachable-guard + join-key seams land now. **See `registry-and-sync.md`.**
- **STT-first conversation UX** + TTS interviewer replies.
- **`FlowRunnerScreen` + calibration-axes generalization** — wait for a real authored non-SWE flow.
- **Second-brain #50:** Related-concepts neighborhood, source-note pane, unlinked mentions, Gaps/Vault-health view, vault write-path (edit-card-updates-note). Requires indexing non-card notes + persisting unresolved links.
- **Light/system theme** — not in v1 (dark-locked by principle).

**Net principle for the whole roadmap:** never ship a UI that *lies* about being general (no hiding SWE rows over a SWE-only engine). Engine generalization is the product thesis and a **first-class near-term workstream** — its second caller already exists, so it is pulled, not built-on-spec. The **second-brain #50** write-path abstractions remain genuinely deferred (no write-path caller yet).
