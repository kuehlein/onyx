> **Stage 1 of the UI/UX rework** — decision-ready critique & architecture produced by the
> `onyx-ux-critique-architect` workflow (15 agents: 6 understand + 8 adversarial critique + 1 synthesis),
> grounded in the 2026-09-17 product direction. This is the input to Stage 2 (design + synthesis of the
> updated/new docs). Reviewed with the user; see the decisions log at the end once settled.

# Onyx UX Rework — Critique & Architecture (Stage 1)

*Decision-ready synthesis for the human. Consolidates the grounding digest (5 sources) + 8 lens critiques against the authoritative 2026-09-17 product direction. This is the architecture and plan to review before authorizing the Stage-2 rewrite. It is NOT final per-surface design prose.*

---

## 1. EXECUTIVE SUMMARY — the decisions that gate everything

Ranked by leverage. Each is defended in the body.

1. **The front door lies, and the direction lives nowhere durable.** `README.md:7-8` still says "there is **no** hosted server, API, or database — everything runs on-device," and it points readers at `architecture.md` (stale since Aug 21: "flashcard app backed by an Obsidian vault… No intermediary server"). The 2026-09-17 direction exists only in prompts, and is *contradicted* across README, `ux-vision §1`, and `settings-ux §6`. **P0: create `docs/product-direction.md` as the new top-of-stack, fix README + architecture.md, before any surface work.** Nothing downstream is trustworthy until the canonical statement exists. (Critique 7)

2. **ONE "Draft/Review gate" is the highest-leverage primitive in the whole rework — and it exists in no doc and no code.** A `draft`/`unreviewed` card status that FSRS *and* readiness both exclude, shared by **three inflows**: AI-generated cards, imported decks, and upstream deck-updates. This single mechanism makes the new content pillars obey honest-readiness + FSRS-owns-spacing *by construction* — it neutralizes the generation-effect risk, the hallucination risk, the "scheduling-stripped import" law, and silent readiness inflation, all at once. `Card` has no such field (confirmed); the write-path (`VaultSource.writeFile`) already exists and is proven by `story_repository.dart:31`. **P0: reserve the card-status seam this pass, even though generation ships later.** (Critiques 1, 2, 5, 6, 8 — unanimous)

3. **Accounts are rejected in 4 places and must be reframed to optional-but-real.** `ux-vision §1` lists "accounts/login" under "Explicitly rejected"; `§3.7`/`settings-ux §1.2` call an account section "a dark pattern"; `§9` defers as "only when forced." The dark-pattern objection was *conditional on there being nothing to sign into* — the new direction creates real accounts (they gate sync, managed AI, deck sharing). **P0: reframe to opt-in, never-required, seams-reserved-now, and render the Account UI ONLY when a backend capability is actually reachable** (shipping an empty Sign-in row re-creates the exact dark pattern). One account concept, three capability flags. (Critiques 1, 5, 7, 8 — unanimous; Critique 5 supplies the guard)

4. **Onboarding gates on ARTIFACT (a folder) instead of INTENT — wrong for 3 of the 4 real personas, and it doesn't exist in code at all.** There is zero onboarding/welcome/first-run code (`vaultSourceProvider` returns `null` on any real device — the app literally cannot obtain a vault on an iPhone today). The one *designed* path (`§3.8` folder hard-gate) serves only the SWE power user. **P0: replace the folder-gate with an intent-gate** ("What do you want to do?" → make-cards-from-my-material / I-have-a-class-code / point-me-at-my-folder); the folder becomes a silent consequence of intent for 2 of 3 paths. This is a genuine reversal of a doc decision and the #1 build gap. (Critique 4, corroborated by 1, 8)

5. **Sync already ships — badly — and corrupts progress today.** `snapshot.dart` writes the entire review history to `_meta/onyx-state.json` in the vault (debounced ~2s post-review); folder-sync via iCloud/git therefore *already* syncs progress, but reconciliation is **last-write-wins on a monolithic blob** (`restore()` = `DELETE *` + bulk insert; only fires on empty DB). Two devices → one clobbers the other or they diverge forever. **This is a present bug that violates honest-readiness, not a future concern.** The decisive reframe: **sync ≠ server ≠ accounts.** 80% of sync value ships with a *merge-correct snapshot over folder-sync and zero server* (P1); accounts are driven by managed-AI + restricted-deck-pull, **not** by sync. (Critique 5 — this is its signature finding)

6. **AI is BYO-key-only across every surface, hardcoded into shipping strings 9× ("Add your Anthropic API key in Settings").** No managed-tier seam, no provider abstraction, no quota concept. The seam is trivial — `ClaudeService` is a URL + `x-api-key` string; managed tier = inject `baseUrl` + swap auth header (one file). **P1: parameterize `ClaudeService`, add an `AiProvider{off, managed, byoKey}` enum, and route all 9 hardcoded call sites through a single 3-state affordance**, with the just-in-time 3-way choice firing at *first AI use*, never at onboarding. Rename user-facing "CLAUDE (AI)" → provider-neutral **"AI"** (leaking "Claude" re-privileges a vendor the way "vault" leaked Obsidian). (Critiques 1, 4, 5, 6)

7. **The corpus contradicts itself 3 ways on the streak, and the live code ships a loss-aversion violation right now.** `readiness_panel.dart:328-357` renders `_StreakChip` with the exact condemned copy ("Study today to keep your N-day streak") + an at-risk amber state; `gamification-stance.md` says *keep it*, `design-system §4.10` says *delete it*, `readiness-dashboard §5` says *replace with a forgiving N-of-7 ring*. **P1: delete the consecutive-day loss-aversion streak, replace with a non-consecutive "N of last 7 days" no-loss consistency indicator, kill `StreakInfo.best` (a can-only-rise vanity metric), and correct the stale memory.** This matters *more* for the new K-12 audience (guilt/equity). (Critique 3 — its signature finding)

8. **The classroom pillar unlocks relatedness (g≈1.78) — the single largest motivational lever in the entire evidence base — and no doc noticed.** The anti-gamification stance was explicitly scoped to "a motivated adult, learning solo… which a solo app lacks [relatedness]." The deck registry + classes delete that premise. Relatedness is a *core SDT need, not gamification* — supporting it touches no FORBID. **P1: add a bounded, teacher/peer-mediated relatedness pillar (class config only); split the too-coarse "reject social/competitive mechanics" into "reject competitive/comparative" (keep) vs "collaboration/belonging is allowed" (new carve-out).** Honest-info-only is *calibrated to adults*; K-12 needs a research pass before any reward-adjacent chrome. (Critique 3)

**Meta-finding threading all 8 critiques:** the docs consistently describe an *aspirational* app as if built. `focusedGoalProvider` (the "one spine") has **zero code hits**. `showApiKeySheet`, `VsSiblingRow`, principle-first reveal, the entire design-primitive catalog (`StatusPill`/`CoverageBar`/`showOnyxSheet`) — all **specced, unbuilt**. Stage 2 must audit "design" vs "proposed" or it will mis-plan against a phantom foundation.

---

## 2. PERSONAS & JOBS-TO-BE-DONE

The three north-star docs model **exactly one persona** (P4). The direction names five audiences; here is the refined, decision-ready set.

**P1 — K-12 student (assigned learner, ~9–17).** Given a class join-code; school/shared iPad; short horizon; little pre-existing intrinsic motivation; likely on a projector-mirrored/low-quality display (a11y-critical). Cannot BYO-key, cannot reason about "a markdown folder," needs *relatedness* (teacher presence) not solo grit.
- **JTBD:** *"When my teacher assigns a deck, help me pull it and get through today's cards without getting lost or feeling dumb."*
- Breaks the most assumptions: folder-gate onboarding, honest-info-only motivation, BYO-key AI, "cards are a lens over your notes."

**P2 — College/grad/professional-exam student (self-directed, deadline-driven).** Real exam/quiz/assignment date; owns PDFs/lecture notes/whiteboard photos; wants cards fast, tolerates light editing; laptop + phone (wants sync).
- **JTBD:** *"Turn my messy source material into a study deck and tell me honestly if I'll be ready by the exam."*
- The **primary buyer of in-app AI generation**; the reason `Interview` should be renamed to a subject-neutral dated milestone.

**P3 — Self-directed adult hobbyist (languages/theology/trivia; the Korean-vault "second caller" that already exists).** No deadline; open-ended coverage goal.
- **JTBD:** *"Keep me making steady durable progress on a subject I chose, forever, without nagging me."*
- Mostly served by the current calm/honest core — but wants **shared-deck import** to start with zero authoring.

**P4 — SWE / power user (the CURRENTLY-MODELED persona).** Obsidian vault, markdown-fluent, BYO Anthropic key, git.
- **JTBD:** *"Point Onyx at my vault, drill toward an interview, and don't dumb anything down."*
- The docs are *correct* for P4 — the risk is P4's assumptions baked in as **universal** (folder-first, BYO-key-only, "authoring lives in the vault").

**P5 — Teacher-as-pusher (the distribution persona).** Authors/curates a deck; pushes to a class; manages access (public vs restricted); pushes updates; wants students to keep up.
- **JTBD:** *"Publish my deck to my class, control access, push corrections, and see minimally that they're engaging — without building a gradebook."*
- **Entirely un-modeled.** Sub-jobs: *authoring* (overlaps P2's AI-gen), *publishing+authorizing* (group = permission unit), *maintaining* (push updates). Legitimately wants to *notify* a class — collides with the solo "no notifications" cut.

**P6 (latent) — Institution/admin.** Roster provisioning, license seats, private landing. **Reserve the seam** (an account has optional org/group membership); do not design now.

**Persona collisions the docs never reconcile (must resolve as config, not global):**
- **P1 and P4 want opposite motivation defaults** (scaffolded relatedness vs pure honest-info). The docs hard-code P4's.
- **P1/P2/P3 all arrive with no markdown folder.** The onboarding gate serves only P4.
- **P5 is a producer; P1–P4 are consumers.** `StudyGoal` models only consumption (local query + template + target) — zero authoring/publishing/provenance state.

**Top user stories (the load-bearing ones; full flow map in §6):**
| # | Story | Coverage |
|---|---|---|
| S1 | *P1: enter a class code → land on my teacher's cards → start.* | UNDESIGNED |
| S2 | *P2: paste a PDF → generate a starter deck → lightly edit → study.* | UNDESIGNED |
| S3 | *P3: browse the library → preview → import a ready-made deck.* | UNDESIGNED |
| S4 | *P4: point at my Obsidian folder and go.* | specced-only, unbuilt (no on-device VaultSource) |
| S5 | *All: try the app without signing in or adding a key.* | principle correct, must extend to accounts |
| S6 | *P1: teacher updates the deck → I get changes quietly, reviewed before they count.* | UNDESIGNED (shares Draft gate with S2) |
| S7 | *P5: publish → choose public/restricted → authorize a class.* | UNDESIGNED |
| S8 | *Import law: a "90%-mastered" deck shows MY readiness = fresh.* | must-enforce invariant |
| S9 | *P2/P4: second device → my progress syncs, no card lost silently.* | present bug (LWW blob) |
| S10 | *All: offline / over quota / not authorized → honest, non-scolding state.* | UNDESIGNED |

---

## 3. WHAT'S STRONG / KEEP — do not disturb in Stage 2

These already match the direction's locked list; the rework is **additive** around an intact core. Regressing any of these is a failure condition.

**Locked architecture (preserve verbatim):**
- **4-tab IA** (Home/Browse/Insights/Settings) via `StatefulShellRoute.indexedStack`. Every critique confirms it holds; **no 5th tab** under any pressure (Library/Create/Classes/Account/Aim all belong inside existing tabs).
- **Nullable `focusedGoalProvider` spine** + `activeGoalCount` degradation helper + **single-goal byte-identical degradation.** (Caveat: the spine is *unbuilt* — it's intended-contract, not real. New surfaces must be designed `focusedGoal`-invariant against that contract.)
- **SheetHeader-everywhere** — every drill-down/editor/explainer is a slide-up sheet; only `/welcome` is a pre-shell full page. (One deliberate carve-out proposed in §4/§5: the draft-review *session*.)
- Design-system tokens, dark-lock (off-white on dark-gray, never #FFF-on-#000), Material 3 emphasis (exactly one Filled per surface; "Done = absence of the Filled button, not a reward animation").

**The daily study loop (§4) — genuinely well-built, matches every learning-science rule:**
- Recall→reveal→self-grade gate is correctly implemented (`quiz_screen.dart:37,115` hides until revealed; coach refuses to leak the answer and climbs a 5-rung hint ladder).
- **Learn blocks / Review interleaves** is real in code (`learn_queue.dart` connected-components + foundational-first; `review_queue.dart:_interleaveByDomain`). Easy withheld in Learn. No same-day learning steps.
- Bounded finishable sessions; honest "done"; no confetti/XP; caught-up = full stop (Filled button *gone*).

**Honesty & dataviz rules (§5/§8) — complete and generalize to every new surface:**
- Uncertainty-first readiness *band that can fall*; weakest-link cap; "can't judge yet" honest-null; **bars > rings** (exactly one ring app-wide = today's completion %); sparklines for trends; forecast = graded band + verbal qualifier; **never color-only** (color+shape+number+Semantics); WCAG floors (`_ink55` 5.7:1 for meaningful state, 0.55 opacity bar floor, 48×48 targets, uncapped chrome scaling); no vanity metrics.

**Motivation core (keep; works for everyone):** honest readiness that can fall; "focus here next" weakest-area guidance; small-quantity-first Home ("today's wins" hero, readiness a chip); coach task-level/feed-forward/JITAI/quiet-when-on-track/≤1-2/day; per-card confidence display; autonomy (Apply/Not-now/Undo, nothing mutates silently).

**Engine generalization stance (§6):** "genuine generalization IS the product; SWE = one authored config; never ship a UI that lies about being general." Already de-SWE-correct; keep and extend.

**Already-correct code seams (reuse, don't rebuild):** `VaultSource.writeFile` (the AI-gen/import write-path — proven by story bank); AI graceful-degrade-to-null; vault = durable source of truth, DB = derived cache (makes sign-out cheap and "never required" achievable as a *test invariant*).

---

## 4. MUST-FIX GAPS & INCONSISTENCIES (prioritized)

**P0 = blocks a coherent rewrite or ships a live violation. P1 = required for the new direction, high leverage. P2 = real but lower blast radius / deferrable.**

### P0

**P0-1 — The front door contradicts the direction; the direction has no home.**
→ Create `docs/product-direction.md` (top-of-stack, authoritative). Fix `README.md:7-8` (kill "no server," repoint, fix the stale "Study" tab → "Insights", "flashcard app" → "study app"). Rewrite or explicitly stamp `architecture.md` ("describes the v1 offline core only; optional server layer specced in <infra doc>"). *Touches:* README, docs/architecture.md, new doc. (Critique 7)

**P0-2 — Reserve the `draft`/`unreviewed` card status now (the shared gate).**
→ Add a lifecycle state to `Card`/schema: `draft` (generated/imported/updated, not promoted) → `active` (in FSRS). `buildLearnQueue`/`buildReviewQueue` and all readiness denominators exclude `draft`. In Browse, a draft renders `StatusPill(muted, "Draft · not counted")` so non-inclusion is *visible*. *Touches:* `lib/shared/models/card.dart`, `card_parser.dart`, `learn_queue.dart`, `review_queue.dart`, readiness engine, Browse. (Critiques 1,2,5,6,8)

**P0-3 — Reframe accounts from rejected → optional-but-real, capability-gated.**
→ One account concept with three capability flags (sync / managed-AI / sharing). ACCOUNT group in Settings renders **only when a backend capability is reachable**. Airplane-mode full-loop integration test as a CI invariant ("never required"). *Touches:* `ux-vision §1/§3.7/§3.8/§9`, `settings-ux §1.2/§6`, new infra doc. (Critiques 1,5,7,8)

**P0-4 — Replace the folder-gate onboarding with an intent-gate; build the on-device VaultSource.**
→ `/welcome` (sole pre-shell page) asks "What do you want to do?" with three tonal choices ordered by audience size: **Make cards from my notes/topic** (P2, default emphasis) · **I have a class code** (P1) · **Point me at my folder** (P4, the only one naming "folder"). Folder scaffolds silently under the blessed container for paths 1–2. **Blocker:** no on-device `VaultSource` exists (`vaultSourceProvider` = `null` on device) — this is Phase 0, ahead of any content UI, and must now be a *content-origin-agnostic writable card store* serving three producers (AI drafts, pulled decks, chosen folder). *Touches:* `lib/app/router.dart` (no `/welcome`), `lib/shared/providers/vault.dart:16-24`, new `IosVaultSource`, `VaultRef` persistence. (Critique 4, corroborated 1,8)

**P0-5 — Deck identity: pulled decks share the local FSRS namespace (silent-corruption blocker).**
→ Everything joins on `cardId` (a frontmatter UUID). A pulled card's `cardId` can collide with a local one — and slug-ids (which the vault mixes in) *will* collide (`binary-search` local vs pulled) → the pulled card inherits the local card's schedule. **Decide: `deckId` namespace → join key `(deckId, cardId, sectionSlug)`** (recommended — also becomes the unit of pull/update/attribution/license/access), *or* UUID-only-with-import-time-collision-rejection. Also: `card-schema.md:42/585` mandates per-*device* UUID v4, which makes cross-device deck identity impossible and contradicts the Card-ID-Convention memory (normalize-to-slugs). *Touches:* `tables.dart`, `card.dart`, `card-schema.md`, `snapshot.dart` join keys, `vault_indexer.dart` (duplicate-UUID detection). (Critique 5; ID-scheme corroborated by 7)

**P0-6 — Fix the live LWW snapshot so folder-sync is honest (present bug).**
→ Change snapshot from one blob to **per-`(cardId,sectionSlug)` last-review-wins merge** keyed on `lastReview` timestamps (already stored); append-merge `reviews` by `(cardId,sectionSlug,reviewedAt)` (idempotent event log). Fold **goals** into the synced payload (today progress syncs but goals don't). *Touches:* `snapshot.dart`, `backup.dart`. (Critique 5)

### P1

**P1-1 — AI three-state model + provider-neutral rename + JIT choice.**
→ Parameterize `ClaudeService({baseUrl, authHeader})`; add `AiProvider{off, managed, byoKey}`. Route all 9 hardcoded "Add your Anthropic API key" strings through one shared 3-state affordance. Rename "CLAUDE (AI)" → "AI". The 3-way choice ("Onyx AI (free allowance)" · "Use my Anthropic key" · "Not now") fires at **first AI use**, not onboarding. Build `showApiKeySheet` (currently referenced but nonexistent — real entry is an inline `TextField`) as a tier chooser. *Touches:* `claude_service.dart`, `ai.dart`, `settings_screen.dart:223-256`, `home_screen.dart:170` + 8 siblings, `ux-vision §3.2/§3.3/§3.7/§3.8`. (Critiques 1,4,5,6)

**P1-2 — Delete the loss-aversion streak; replace with N-of-7 no-loss ring.**
→ Remove `_StreakChip` + at-risk state; replace with non-consecutive "N of last 7 days," no loss-state, neutral copy, secondary to readiness. Kill `StreakInfo.best`. Correct the stale `gamification-stance.md`. Resolves `readiness-dashboard` open-Q #6 and the 3-way contradiction. *Touches:* `readiness_panel.dart:328-357`, `stats/streak.dart`, `design-system §4.10`, `readiness-dashboard §5`, memory. (Critique 3)

**P1-3 — Coach is hardcoded to SWE interviews in the hot path.**
→ `buildCoachSystem` (`coach.dart:40-131`) opens *every* recall conversation as "a spaced-repetition app for software-engineering interview prep… an interviewer from a strong engineering org," with SWE topic routing; the grading persona label is "Interviewer" (`coach_sheet.dart:313,644`). For a 7th-grader on WW1 causes this is a de-privilege violation mid-recall. Take persona/domain vocabulary from the active `SubjectConfig` (the seam `flow_prompt.dart` already uses); SWE wording moves into `software_interviews.dart`. *Touches:* `coach.dart`, `coach_sheet.dart`. (Critique 2)

**P1-4 — Fix the shipped indeterminate-progress violation (22 files) before new surfaces multiply it.**
→ `CircularProgressIndicator` appears in 22 files; the *shared AI composer you're told to reuse* (`chat_view.dart:212-234` `_Thinking`) ships a spinner — a live violation of the §8 "no looping animation" / §4.9 "no spinner-on-empty" rules. Add a `progressPolicy` to §2.6/§5: bounded work → determinate `LinearProgressIndicator`; indeterminate (network/sync/streaming) → static status line (glyph+text+Semantics liveRegion) or `SkeletonBlock`, **never a spinning ring**; collapse under Reduce-Motion. Fix `_Thinking` first (its text label already exists). Add a 4th migration grep: `grep -rn 'CircularProgressIndicator' lib/`. *Touches:* `chat_view.dart`, `design-system §2.6/§8`, + the sync/AI-tier/import surfaces that would inherit it. (Critique 6 — its signature finding)

**P1-5 — Split the too-coarse "reject social/competitive mechanics"; add the relatedness carve-out.**
→ `ux-vision:31` as written forbids the collaboration layer the product is now built on. Split into: *reject competitive/comparative* (leaderboards, cross-student ranking, points currency — keep, and stronger for kids) vs *collaboration/belonging is allowed and encouraged in the class config* (new). *Touches:* `ux-vision §1 L31`, motivation doc. (Critique 3)

**P1-6 — Notifications: reframe the blanket cut from "no" to "no guilt/streak/nag; opt-in due/plan reminders allowed."**
→ The corpus itself names **backlog as the dominant SRS failure** and endorses if-then-planning + a daily reminder + JITAI cadence. A due-reminder is retention *infrastructure*; a blanket cut undermines FSRS (LS-6). Rewrite `ux-vision:242`/`settings-ux:270` from "streak-adjacent, cut" to "one opt-in, off-by-default, due-tied *plan* reminder (STUDY LOAD group when built); no streak/guilt/nag; ~1–2/day JITAI cap." *Touches:* `ux-vision §3.7`, `settings-ux §6`. (Critique 3)

**P1-7 — Content-creation & registry have no IA home in the docs.**
→ Reconciled in §5. Browse becomes "your library" with two altitudes; creation entry = `+` in Browse altitude-0 + empty-states; draft-review is a full-screen session (carve-out, §5). *Touches:* `ux-vision §3.5`, new content-creation doc. (Critiques 1,8)

**P1-8 — Managed-AI privacy, cost, and minors' data are unaddressed existential traps.**
→ (a) Managed tier must have a plain-language data disclosure at opt-in (card text/images → Onyx servers; no training; short retention). (b) Server-side per-account quota; heavier metering for PDF/photo ingest; capped chat-history tokens on managed (the growing-transcript cost trap). Upgrade prompt only at true exhaustion. (c) **No direct child accounts on the managed tier in v1** — teacher/guardian-provisioned only; FERPA/COPPA stance is a prerequisite to marketing to teachers. (d) **Public deck tier is the LAST thing to ship** — needs report/takedown + review queue; ship *local → restricted/group* first (teacher→known-students needs no open moderation). *Touches:* new infra doc; gates the managed launch. (Critique 5)

### P2

- **P2-1 — Rename `Interview` → subject-neutral "milestone/dated target."** Behavior is already generalized (`effectiveDeadline`); only the name centers P4. P2's deadline is an exam. (`ux-vision §5`; Critiques 1,8)
- **P2-2 — Restate principle #1 "zero deck-building" → "zero *manual* deck-building friction."** Otherwise the AI-draft-review flow reads as a principle violation when it's the principle's *fulfillment*. (`ux-vision §1`)
- **P2-3 — Re-scope "authoring lives in the vault" (×2 in §3.5, plus `practice-flow-plan.md:30`, all of `vault-structure.md`) to the P4/power path only.** Light editing of AI drafts now lives *in-app*. (Critique 7)
- **P2-4 — Auto-apply upstream deck updates contradicts "nothing mutates silently."** Route updates through the Draft gate; quiet Browse affordance ("3 cards updated upstream"); never auto-apply into FSRS. (Critiques 1,5)
- **P2-5 — Overlapping-membership aggregation + `StudyGoal` provenance seam.** `StudyGoal` (membership = local query) has no `source`/`remote`/`sharedDeckId`/`accessControl`. A pulled deck is a discrete unit, not a folder query. Reserve provenance seam distinct from both membership *and* `focusedGoalProvider`. (Critiques 1,5,8)
- **P2-6 — Dangling/stale cross-refs:** `settings-ux` header cites `ux-vision §16` (only 9 sections exist); `Card.type` enum (flashcard/algorithm/system-design/behavioral) is itself SWE-shaped (3 of 4 = interview flows) — reconcile with "no privileged subject." (Critique 7)
- **P2-7 — Empty state (0 goals) routes only to the goal-editor.** Must also offer import/generate for P1/P2/P3. (`ux-vision §3.1`; Critiques 1,4)
- **P2-8 — Missing primitives the new surfaces need:** a `Toast`/`SnackBar` (absent from catalog, needed by publish/import/sync — but *rare*, under-notify); auth/permission error states (`AiUnavailableState`, "not authorized"); tablet/landscape has **zero** doc coverage (see §10). (Critique 6)

---

## 5. NEW SURFACES → IA RECONCILIATION

**Verdict up front: the 4-tab IA holds. Every new surface fits into existing tabs + SheetHeader sheets + a small number of full-screen routes-outside-the-shell (the pattern the router *already* uses for `/learn`, `/report`). No 5th tab.** Where each lives, concretely:

### Browse becomes "your library" (two altitudes, mirroring Home's hub/goal)

The docs silently assign Browse **four different jobs** (search-my-cards / backlinks / deck-library / creation-entry) and never notice they're not one screen. Jobs 1–2 are *inward* (my existing cards); 3–4 are *acquisition*. Resolution — **split the concepts, keep the tab:**
- **Browse altitude 0 = library/collection:** your decks/subjects as a list (where a *pulled* or *AI-generated* deck lands), plus the existing search box as a cross-cutting filter. A **`+` action here is the single entry point to acquisition.**
- **Browse altitude 1 = card search/detail** (today's flat screen) reached by drilling into a deck or searching globally.
- This absorbs jobs 1,3,4 honestly; reserves job 2 (backlinks/second-brain) for #50. Zero new tab. **Do NOT** make the library a top-level route (it's a repeated, stateful destination = a tab-branch, not a one-shot flow), and **do NOT** let the library reuse the goal-lens `SegmentedButton` (that's for searching *your cards*, altitude 1 — a stale-audience "everything is a goal-scoped query" trap).

### Content creation (AI-generate / import)
- **Entry:** the `+` in Browse altitude-0, *also* surfaced in Home 0-goals empty state and `/welcome`. A `showOnyxSheet` chooser: **Generate from my material** (paste/topic/PDF/photo) · **Import a shared deck** (opens registry pull) · **From my folder** (already implicit via indexing).
- **The flow:** input *sheet* → **draft-review** → save. **Ratify one deliberate carve-out from "SheetHeader-everywhere":** the draft-review *session* is a **full-screen route** (`/draft-review`), like `/learn` and `/report` — it's a bounded, finishable, focused session (reuses `SessionScaffold` bounded bar, "3/12 drafts"), not a config drill-down. Router precedent already establishes "sessions are full-screen routes, tabs are sections." Sheets for pickers/config, full-screen for the review session.
- **Promotion is generative, not a rubber-stamp** (the anti-passive-acceptance law): per-card keep/edit/discard, no bulk "Accept all." **Recommended default promotion path: self-test-then-promote** — run each draft through the *existing recall→reveal gate* once (attempt recall → reveal AI's answer → promote), turning generation into the first retrieval rep and surfacing walls-of-facts. Do NOT copy `story_capture_screen.dart:222`'s one-tap "Save to bank" (the passive-acceptance anti-pattern already in the codebase).
- **`AiUnavailableState`** (offline/no-tier/quota-exhausted) as an `EmptyState` variant that states the core still works.

### Deck registry (library browse + pull + publish + access control)
- **Library browse + pull:** Browse altitude-0 for discovery; `DeckDetailSheet` (SheetHeader) for preview+import; import writes `.md` via `writeFile` (ties to SOURCE). **No download counts / ratings / "trending" / "N studying"** — order by relevance/recency/provenance; card-count IS allowed (size fact, not engagement metric).
- **Publish/push:** per-deck **`PublishSheet`** (SheetHeader) reachable *from the deck in Browse* (per-object action) **+** a Settings **SHARING** group (config-once "manage my shared decks / who has access"). Both coexist.
- **Access model:** group/class as the permission unit (not per-deck-per-user ACLs); exactly two roles — **maintainer** (push/approve) vs **subscriber** (pull/suggest). Three visibility tiers: `local` (default, offline) → `public` (defer past v1) → `restricted` (group-gated). **Scheduling never travels with a deck** (Anki law — a "90%" deck shows *your* readiness = fresh). Upstream updates flow through the **same Draft gate**.
- **Cut for v1:** the full AnkiHub suggestion-queue/merge/co-author/note-history system (defer); `RegistryRemoteRow` exposing "git remotes" as user-facing IA (developer-brained for teachers/kids — model remotes internally); a "Classes" tab (dead chrome for every solo user).

### Accounts / sign-in, sync, AI-tier — all in Settings (never a tab, never a profile screen)
- **ACCOUNT group** (new): `Not signed in` / `{email} · signed in` → `showAccountSheet`. **Render ONLY when a backend capability exists.** Enrollment via remembered join-code binds to the *account*, not the device.
- **AI group** (renamed from CLAUDE): tier chooser `Off · Onyx-hosted · My key`; **usage as a `CoverageBar`, never a ring**, with a `▲ near limit` label near quota (never color-only, never a countdown/interstitial). JIT choice at first AI use.
- **SYNC group** (new): `Off` / `On · last synced {t}` / `Sync error` → `showSyncSheet`; **decoupled from SOURCE** ("a synced folder is just a folder"); off by default. `SyncStatusIndicator` via `StatusPill`; the "Offline" state is `muted` (not `bad` — offline isn't an error in a local-first app).

### The spine invariant (protect the unbuilt contract)
**Content creation, library, registry, account, sync, AI-tier are all `focusedGoal`-INVARIANT.** None reads or sets `focusedGoalProvider`. The library shows *all* decks regardless of focus; sign-in/sync/AI-tier are app-global. Creating/importing *may offer* "add to current goal" but must not *require* a focus. This keeps single-goal degradation byte-identical. Deck-provenance seam is **orthogonal** to the focus seam — reserve both separately; never overload one to carry the other.

**Summary table:**
| Surface | Home | Rationale |
|---|---|---|
| AI-generate / import entry | `+` in Browse alt-0 + empty-states | acquisition, not search |
| Draft-review session | **full-screen `/draft-review`** (carve-out) | bounded finishable session; matches `/learn` |
| Deck library / registry | **Browse alt-0** (new library altitude) | content lands here; no 5th tab |
| Deck detail / pull | SheetHeader sheet | consistent |
| Publish this deck | `PublishSheet` from a deck | per-object action |
| Manage shared decks / access | **Settings → SHARING** | config-once, dangerous-if-wrong |
| Account / sign-in | **Settings → ACCOUNT** (backend-gated) | reverses stale "no account" |
| Sync on/off + status | **Settings → SYNC** (decoupled) | optional, off by default |
| AI tier + usage | **Settings → AI** + JIT at first use | 3-state, CoverageBar not ring |

---

## 6. COMPLETE FLOW INVENTORY

Tags: **[exists]** (built & direction-compatible) · **[specced]** (designed in docs, unbuilt) · **[UNDESIGNED]** (no doc, no code).

**Onboarding**
- Point-at-existing-folder (P4) — **[specced]** (unbuilt: no on-device VaultSource)
- Create-new-folder + subject-neutral sample deck — **[specced]** (unbuilt)
- Enter-class-code → pull restricted deck (P1) — **[UNDESIGNED]**
- Generate-from-material as first move (P2) — **[UNDESIGNED]**
- Import-from-library as first move (P3) — **[UNDESIGNED]**
- Optional sign-in during/after onboarding — **[UNDESIGNED]** (currently forbidden)
- *The onboarding router gate itself does not exist in code.*

**Create-via-AI**
- Source-ingest entry (paste/topic/PDF/photo picker) — **[UNDESIGNED]** (ship Paste+Topic first; PDF/photo deferred)
- Generate with conservative count control — **[UNDESIGNED]**
- Draft-review stack (bounded, per-card keep/edit/discard, generative gate) — **[UNDESIGNED]**
- Promote draft → live FSRS (status transition) — **[UNDESIGNED]** (status absent; write-path exists)
- Source-linkback per draft — **[UNDESIGNED]**

**Import / pull-from-library**
- Library/registry browser (Browse alt-0) — **[UNDESIGNED]**
- Deck card + access badge + install state — **[UNDESIGNED]**
- Deck-detail preview + Import — **[UNDESIGNED]**
- Import progress/result (no confetti) + conflict-on-import — **[UNDESIGNED]**
- Pulled-deck → becomes a goal's membership — **[UNDESIGNED]** (query-membership can't express a discrete deck)
- Upstream-update pull → Draft gate — **[UNDESIGNED]**
- Scheduling-stripped invariant — **[UNDESIGNED]** (must-enforce)

**Push / publish / authorize (P5)**
- Publish sheet (target + public/restricted) — **[UNDESIGNED]**
- Access-control editor (group = permission unit) — **[UNDESIGNED]**
- Maintainer push-update → propagate — **[UNDESIGNED]**
- Subscriber suggest-change → queue — **[UNDESIGNED]** (nice-to-have; reserve)
- `StudyGoal`/`Card` provenance seam — **[UNDESIGNED]** (absent; reserve now)

**Daily study / review / mock** *(the strong core)*
- Single-goal Home → one Filled → session → honest done — **[exists]** *preserve verbatim*
- Lanes hub (≥2 goals) → lane → goal Home — **[specced]** + partial code
- Card-turn loop (cue→reveal→grade, interleaved) — **[exists]**
- Conversation loop (mock → grade) — **[exists]** for P4-with-key; breaks without 3-state AI
- Answer-coach path — **[exists]**; same 3-state AI gap

**AI-access states** *(cross-cuts every AI flow)*
- Keyless core (AI off) — behavior **[exists]**; honest UI state **[UNDESIGNED]**
- BYO-key — **[exists]**
- Managed/hosted tier (proxy + account + quota) — **[UNDESIGNED]** (no server)
- JIT 3-way choice at first AI tap — **[UNDESIGNED]** (currently BYO-only banner)
- Usage/quota meter (CoverageBar) — **[UNDESIGNED]**

**Goal management / Insights**
- Goal editor sheet (progressive disclosure) — **[exists]**/specced (rename `Interview`)
- Adjust-mix (sole budget editor) — **[specced]**
- Insights two-altitude, per-goal `.family` — **[specced]** (`.family` unfinished = a per-goal lie until done)

**Settings**
- SOURCE / STUDY LOAD / STUDY GOALS / DATA&BACKUP / ABOUT / Developer — **[specced]**
- CLAUDE(AI) → 3-state "AI" group — **[UNDESIGNED]** (BYO-only today)
- ACCOUNT group (backend-gated) — **[UNDESIGNED]**
- SYNC group (decoupled) — **[UNDESIGNED]**
- SHARING/publishing seam — **[UNDESIGNED]**
- Notifications — correctly **cut for solo v1**; re-examine for P5/backlog (reframe, not blanket cut)

**Account / sync / migration**
- JIT sign-in (never a launch gate) — **[UNDESIGNED]** + currently forbidden
- Local→account migration (FK-ordering, reversible) — **[UNDESIGNED]** (design now)
- Sync on/off + status (never color-only) — **[UNDESIGNED]**
- Conflict resolution (two-mode, no silent loss) — **[UNDESIGNED]**
- Progress-sync via folder (LWW blob) — **[exists, BUGGY]** (P0-6)

**Error / empty / offline / edge** *(chronically under-covered)*
- Empty-vault calm state — **[specced]**
- 0-goals empty state — **[specced]** but routes only to goal-editor (must add import/generate)
- Offline / no-tier / quota-exhausted AI — **[UNDESIGNED]**
- Not-authorized-for-deck / sign-in-required — **[UNDESIGNED]**
- Import/publish/sync transient confirms — **[UNDESIGNED]** (Toast primitive absent)
- Remote-list skeletons — **[specced]** partial (extend existing)
- Sync-conflict artifact — **[UNDESIGNED]**
- Duplicate-UUID from folder-sync conflict file — **[UNDESIGNED]** (indexer must detect, not double-schedule)

---

## 7. MOTIVATION MODEL (spanning ages, anti-gamification)

A single model configured by *context*, not forked per audience.

**KEEP (locked, works for everyone — mostly built):** honest readiness band that can fall + weakest-link cap + "can't judge yet"; "focus here next"; small-quantity-first Home ("today's wins" hero — the primary channel for kids, per Amabile/Koo-Fishbach); coach task-level/feed-forward/JITAI/quiet-when-on-track; per-card confidence; "Done = absence of Filled," no confetti; **non-consecutive "N of last 7 days" no-loss consistency indicator** (replaces the deleted streak — the habit support the streak reached for, minus the condemned loss-aversion).

**ADD (new, all inside SDT):**
1. **Relatedness pillar (class/shared config only)** — the g≈1.78 lever the solo app lacked: teacher recognition of competence via the *existing coach one-line channel* (reuse `coach_update.dart`'s "goal + signal + one action"); **aggregate/anonymous belonging cues** ("your class is on deck X," "N studied today"); merged-suggestion contribution credit. **Hard line: aggregate belonging = allowed; any per-student comparison/ranking = forbidden.** No new subsystem — a framing + a permission model.
2. **Present-tense competence rendering for novices** — "you can now do X" mastery framing as a *config-level presentation option* over the same honest engine (a 9-year-old needs "you can do X," not a probabilistic band). Does not touch FSRS/readiness math.
3. **Opt-in, due-tied, non-guilt plan reminder** — STUDY LOAD · Daily reminder (time picker), JITAI-cadenced, ~1–2/day. The evidence-backed countermeasure to backlog (the dominant SRS failure). Task-framed ("12 reviews are due" / if-then cue), never "you'll lose your streak."
4. **Teacher-set proximal goals (class config)** — the teacher sets the this-week sub-goal the coach frames progress against (Bandura proximal sub-goals + a relatedness source). Autonomy-preserving: the *student* still chooses how/when.

**STILL REJECT (evidence-condemned; *stronger* for kids):** points/XP currency, badges, levels, **leaderboards / any cross-student ranking**, consecutive-day streaks, streak-freeze/loss-aversion, confetti/trophies, countdown urgency, guilt notifications, any metric that only rises. The line is **comparative/controlling/extrinsic-reward** — *not* "social" categorically (collaboration/belonging is now in-scope). A depleting AI quota must not become a loss-aversion countdown (CoverageBar, exhaustion-only prompt).

**Notifications verdict:** the blanket cut is over-stated and refuted by the corpus's own "backlog is the dominant SRS failure" finding. A due-reminder is retention infrastructure, not a streak crutch. Reframe to **honest, opt-in, off-by-default, under-frequency, non-guilt, due/plan-tied** reminders. P5 assignment pushes route through the *same* non-guilt bounded rules.

**Gated behind a research pass (do NOT build blind):** any *reward-adjacent* K-12 scaffold (completion/effort-recognition chrome beyond the honest ring). The corpus has **zero** child-development/classroom-motivation sources; honest-info-only is calibrated to adults. Keep honest-info-only as the *default*; permit a bounded, teacher-gated, SDT-safe competence/effort-recognition layer for the classroom config *only after* a dedicated pass — never with leaderboards/loss-aversion/currency. Any such acknowledgement reuses "Done = a quiet `StatusPill(good, 'Done')`," never a reward animation or points number, and is gated behind the (unbuilt) accounts/class layer so it cannot leak into the solo core.

---

## 8. RECOMMENDED DOC ARCHITECTURE

The current stack (`README → architecture.md [stale] + ux-vision.md [north-star] → {design-system, settings-ux}` + ~15 feature docs) is missing a **top layer** and **two cross-cutting docs**, and its front door + roadmap are broken. Minimal coherent target:

**CREATE:**
- **`docs/product-direction.md`** *(P0, top-of-stack)* — the authoritative "what Onyx is now": general/education-first; local-first solo core (byte-identical/offline/no-AI); the three content paths; hybrid-AI; optional accounts/sync; permissioned registry; the locked non-negotiables. ux-vision/design-system/settings-ux become companions *to it*.
- **`docs/content-creation.md`** *(cross-cutting)* — owns the three creation paths + **the Draft/Review gate** as the shared primitive (AI-gen + import + upstream-update), the `draft`/`unreviewed` status, the generation-effect design law ("automation reduces friction, not cognition"), the self-test-then-promote default. Its absence forces every surface to reinvent the gate.
- **`docs/registry-and-sync.md`** *(cross-cutting; or fold into a rewritten architecture.md)* — the account object + "one account / three capability flags," local→account migration + FK-ordering + reversibility, conflict UX (two-mode), **deck-identity/ID scheme** (the `deckId` decision), scheduling-never-travels-with-a-deck, visibility/role model, license/attribution seams. Reserve seams in writing; defer the build.
- **`docs/personas-and-stories.md`** — the five personas + JTBD + user stories (§2 of this doc is the seed). Anchors the K-12-motivation open question and the teacher-push/student-pull flows; without it the docs keep defaulting to P4 in the reader's head.
- **`docs/INDEX.md`** — 6-line reading order (product-direction → ux-vision → design-system/settings-ux → feature docs; historical/superseded: architecture[pending], vault-structure[power-path-only]). Prevents "README points at the stalest doc."
- **`docs/roadmap.md`** *(RESTORE — undo commit `453e5dc`)* — two-track phasing (§9). ux-vision §9 shrinks to a pointer.

**UPDATE:**
- **`README.md`** — kill "no server," repoint to product-direction, fix tab list ("Insights" not "Study"), "study app" not "flashcard app."
- **`docs/architecture.md`** — rewrite overview + system diagram to show local-first core + optional server-backed layer (as "reserved, not built"), or explicitly stamp "v1 offline core only."
- **`docs/ux-vision.md`** — reframe accounts (§1/§3.7/§3.8/§9); 3-state AI (§3.2/§3.3/§3.7/§3.8); intent-gate onboarding (§3.8); "zero *manual* deck-building" (§1); split "social/competitive" (§1 L31); notifications reframe (§3.7); rename `Interview` (§5); re-scope "authoring lives in the vault" (§3.5); fix §16 dangling ref; §9 → pointer. **Audit §3.3/§4.5 "design" claims against code — downgrade unbuilt (principle-first reveal, VsSiblingRow, numeric ConfidenceBadge) to "proposed" or build them.**
- **`docs/design-system.md`** — add `progressPolicy` (indeterminate/Reduce-Motion, §2.6/§8); bind new statuses (sync/AI-tier/access/import) to `StatusPill`; `UsageMeter` = CoverageBar not ring; registry-vanity-metric ban (§5); draft "not counted" honest-null; bottom-anchored action ergonomics + fixed review bar; add `Toast`/`SnackBar` (rare); tablet/66ch-cap rule. Trim Source-2's 26-widget list to ~6 new widgets + ~6 configs (avoid re-introducing the sprawl §6 rejects).
- **`docs/settings-ux.md`** — add ACCOUNT / SYNC / SHARING groups (backend-gated); AI group rename + 3-state; notifications reframe (§6); confront that progress-sync already ships.
- **`docs/card-schema.md`** — resolve UUID-vs-slug-vs-`deckId` (§C5/P0-5); add `draft` status, `deckId`, provenance/linkback, `confusable-with:` seams; add deck `visibility`/`author`/`license` fields.
- **`docs/readiness-dashboard.md`** — resolve open-Q #6 (N-of-7 ring, no consecutive streak).
- Correct **`gamification-stance.md`** memory (streak deleted; relatedness now available; audience K→grad+teachers).

---

## 9. REVISED PHASING

The core reframe: **the docs equate `sync == server == accounts == deferred`. Break it.** Sync is a local-first folder+merge problem (v1, no server); accounts are driven by managed-AI + restricted decks (deferred, seamed); the three optional layers are separable. ux-vision §9's UI-phasing (phases 0–5) **stays valid for the client** but structurally can't carry backend work — split into two tracks.

**PHASE 0 — Foundations & seams (mostly local-first; the true critical path).** Build the `focusedGoalProvider` spine + `activeGoalCount` (unbuilt today). **On-device `VaultSource` + `VaultRef` persistence** (the linchpin blocker; nothing works on-device without it). Reserve seams (cheap now, migration-nightmare later): `draft`/`active` card status; **`deckId` + `(deckId,cardId,sectionSlug)` join key**; duplicate-UUID detection in the indexer; `ClaudeService(baseUrl,authHeader)` + `AiProvider{off,managed,byoKey}`; deck `visibility`/`author`/`license` fields; one account concept + 3 capability flags. **Real fixes:** merge-correct snapshot (P0-6); fold goals into snapshot; delete the loss-aversion streak; `progressPolicy`/fix `_Thinking`. Docs: product-direction + README + architecture + roadmap.

**PHASE 1 — Client/UX debt (offline, direction-neutral, largely already planned).** Per-goal honesty (`.family` conversion + overlap helper); goal-scoped Browse segment + backlinks; one `SharedBudgetBar` + adjust-mix; Home single-Filled plan-driven loop; Insights two-altitude; parameterize `ReadinessPanel`; Settings 6-group IA; aim storage unification; de-privilege the coach (`SubjectConfig` persona). Build the base design primitives (`StatusPill`/`CoverageBar`/`showOnyxSheet`/`SkeletonBlock`/`EmptyState`) **so new surfaces are configs of them** — this is the strongest argument for base-first.

**PHASE 2 — Intent-gate onboarding + AI generation (BYO-key first, no account needed).** `/welcome` intent-gate; the three onboarding paths; the source-ingest sheet (Paste+Topic first); the **Draft/Review gate** + full-screen `/draft-review` + self-test-then-promote; the 3-state AI affordance + JIT choice + `showApiKeySheet` tier chooser (managed shown as an honest disabled row until the server lands). This ships real value *without* any backend — AI-gen works on BYO-key; import lands later.

**SEAMED-BUT-DEFERRED (build when audience/traffic + legal/moderation work justify the server):**
- **Managed-AI server** (proxy + per-account quota + billing + cost controls). Seam ready from Phase 0.
- **Accounts + account-sync of progress/goals** — deferred *because folder-sync + merge-correct snapshot covers solo/power*; accounts arrive driven by managed-AI + restricted-pull, migration designed now.
- **Restricted/group deck registry** (maintainer/subscriber, join-code, group-ACL, Draft-gated updates) — the classroom distribution MVP; needs accounts first.
- Browse library/registry browser UI.

**DEFER HARD (explicit gates):**
- **Public deck tier** — blocked on moderation/takedown infrastructure. Restricted-only first (teacher→known-students needs no open moderation).
- **Managed AI for minors / direct child accounts** — blocked on COPPA/FERPA stance + the unresearched K-12 motivation pass. Teacher-provisioned only, if at all, in the first managed release.
- AnkiHub-style suggestion-queue/merge; P6 institution/admin; full configurable parser; `FlowRunnerScreen`; second-brain #50.

---

## 10. OPEN SUB-DECISIONS FOR THE HUMAN

Each with a recommendation. Stage 2 needs these settled.

1. **Intent-gate vs folder-gate as `/welcome`.** → **Intent-gate.** Reverses `ux-vision §3.8`/`settings-ux §3`; everything downstream depends on it. *(P0)*
2. **Default emphasis among the three onboarding paths.** → **AI-generation default; folder demoted to third.** (It's the only path serving a user with material but no folder/code/markdown — the new median user.) Confirm the inversion.
3. **Does a class-code pull require an account?** → **Code-as-credential + lightweight/anonymous device identity for pull-only; real account deferred to sync/publish.** The one place "never gate first-run on accounts" genuinely tensions with "restricted decks are group-gated."
4. **Deck identity: `deckId`-namespaced join key vs UUID-only-with-collision-rejection.** → **`deckId` namespace** (more robust, enables future deck-difficulty analytics, becomes the pull/update/access unit) — but it touches every SRS query. This is *the* one schema decision to make before any data exists.
5. **SheetHeader-everywhere carve-out for the draft-review session.** → **Yes — full-screen `/draft-review`** (matches `/learn`/`/report`; a 12-card review stack in a bottom sheet fights bounded-session ergonomics). Sheets for pickers, full-screen for the session. Ratify the exception.
6. **Draft-promotion default: self-test-then-promote vs plain keep/edit/discard.** → **Self-test-then-promote as default** (first retrieval rep + surfaces bad drafts), plain edit/keep as the escape hatch.
7. **What ships in the scaffolded starter deck** for the no-content user. → **Subject-neutral** (SRS-mechanics cards, or empty-with-guidance) — *never* a SWE sample (would re-privilege SWE, violating principle 10).
8. **Managed-tier availability at launch** — the biggest sequencing risk. If the hosted server won't exist for v1, flow (a) collapses to "get an Anthropic key" — the exact OLD-audience wall. → **Ship v1 first-run on flows (b)+(c) + BYO-key AI-gen; gate the hosted path on the server; make the managed tier the seam, not the v1 dependency.**
9. **Changed-upstream-card FSRS policy** — genuinely hard, no clean default. → **Text tweak keeps the schedule; a section whose *meaning* changed becomes a new `sectionSlug` (re-enters learning); removed-upstream = tombstone, never delete history.** Flag as needing a heuristic-vs-maintainer-flag-vs-learner-choice decision.
10. **Is account-sync ever in the roadmap, or is folder-sync + merge-correct snapshot the permanent progress-sync answer?** → **Accounts never carry *content*; folder-sync is the content-sync story; account-sync (if built) carries progress+goals only.** Do not re-implement Obsidian Sync/git.
11. **Public registry: build it, or ship restricted-only indefinitely?** → **Restricted-only for the foreseeable future** (teacher→class covers the stated use case without the moderation burden a small maintainer may never justify).
12. **Streak replacement + comparison hard-line.** → **Confirm: delete consecutive streak + `best`; adopt N-of-7 no-loss ring; codify "aggregate/anonymous belonging = allowed, any per-student comparison = forbidden"** as the rule replacing the blanket "no social" line.
13. **Relatedness scope in v1 of the class config.** → **Recognition-only (minimal, safe) to start; teacher-set proximal goals as a fast-follow** (both SDT-safe).
14. **Present-tense competence rendering ("you can now do X") for novices** — acceptable config-level presentation over the honest engine, or does it risk overclaiming vs the band-that-can-fall? → **Acceptable as a per-config *rendering* of the same honest state** (it's mastery-of-a-thing, still honest), but write the guard so it can't drift into a fabricated point-estimate.
15. **Tablet/landscape scope.** The docs have **zero** coverage, and wide-screen actively *breaks* the locked ~66ch measure (a teacher's primary device). → **In scope, minimally:** one breakpoint (M3 medium/expanded), two rules only — cap content column at ~66ch (centered, inert margins) and allow list+detail two-pane for Browse/registry/review on expanded width. Confirm, or explicitly defer with the 66ch-cap as the interim guard.

---

*Grounded throughout in the locked non-negotiables (10 UX principles, dataviz rules, learning-science rules, 4-tab IA + nullable `focusedGoalProvider` spine + single-goal degradation, SheetHeader-everywhere, design tokens). Where critiques disagreed, the most-grounded position was chosen and justified inline. Nothing here relaxes a locked FORBID; the two items explicitly gated behind fresh research are K-12 reward-adjacent motivation and classroom/teacher-push notification specifics.*


---

## Decisions settled with the user (2026-09-17)

These four resolve the highest-stakes items in §10; the remaining §10 sub-decisions proceed on their documented recommendations unless overridden.

1. **Onboarding = intent-gate, paths CO-EQUAL** (refines §10.1/§10.2, rec #2/#4). Adopt the intent-gate (make-from-my-material / class-code / point-at-folder) but keep the three paths **co-equal** — do NOT elevate AI-generation to "the default/hero." Crucial framing the whole rework must carry: **the substrate is always just a folder of files**; "decks" are a user-facing grouping a user can import (many), create, or author. **Onyx is a REVIEWING app, not an authoring app** — creation/import are lightweight on-ramps, never the center of gravity (this is principle #1, "zero *manual* deck-building friction," fulfilled). A minimal create-a-deck / edit-a-card capability exists; a full manual authoring studio does not.
2. **Managed AI = seam now, BYO-key first** (§10.8). v1 ships import/library + BYO-key AI-generation; the hosted "Onyx AI" tier is an honest "coming soon" until the server exists. The managed tier is the seam, not a v1 dependency.
3. **Motivation = adopt in full** (§1.7, P1-2, §7, §10.12). Delete the consecutive-day streak + `StreakInfo.best`; add the no-loss "N of last 7 days" indicator; codify "aggregate/belonging cues allowed via the class config, any per-student comparison forbidden"; honest-information stays the default; any K-12 reward-adjacent chrome is gated behind a dedicated research pass.
4. **Draft promotion = self-test-then-promote** (§10.6). Each AI-generated or imported draft runs once through the recall→reveal gate before it counts (the first pass IS a retrieval rep); no bulk "Accept all."
