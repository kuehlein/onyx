# Onyx — Personas, Jobs-to-be-Done & User Stories

> **Stage 2 of the UI/UX rework** — the persona / JTBD / user-story layer. Expands
> `docs/ux-rework-stage1.md` §2 (the seed) and reconciles it with the settled
> 2026-09-17 product direction (see that doc's *Decisions* section). Companion to
> `docs/ux-vision.md`, `docs/design-system.md`, `docs/settings-ux.md`.
>
> **Purpose: this doc is decision-anchoring.** Anyone designing or reviewing a flow
> must be able to name *which persona and which JTBD it serves* — and, when two
> personas want opposite things, point to the collision below and confirm it is
> resolved **as config, not as a global default**. If a proposed surface serves no
> persona here, that is a signal to cut it, not to invent an audience for it.

---

## 0. The one framing that governs every persona: Onyx is a REVIEWING app

Read this before the personas, because it re-weights all of them.

**Every persona below is, first and above all, a *reviewer*.** The load-bearing loop
for all six is the same: *pull up today's due cards → recall → reveal → self-grade →
honest "done."* That loop (`docs/ux-vision.md` §4) is the product's center of gravity
and it is already well-built. `[locked: "time-to-first-review is the metric"]`

**Content acquisition — import, AI-generate, point-at-a-folder, light manual
create/edit — is an *on-ramp to that loop, never the destination.*** The substrate
is *always just a folder of files*; a "deck" is a user-facing grouping over those
files that a user can **import** (many), **generate**, **create**, or **author**.
The three on-ramps are **co-equal** — none is "the hero," and in particular
AI-generation is **not** elevated to the default (this corrects the Stage-1
architecture, where AI-gen was drawn as the default path; the settled decision makes
the three co-equal). `[settled 2026-09-17 #1]`

Two consequences for how you read the personas:

1. **Onboarding is an intent-gate, not a folder-gate** — "What do you want to do?"
   with three co-equal answers (*make from my material* / *I have a class code* /
   *point me at my folder*), because 3 of the 6 personas arrive with **no markdown
   folder at all**. `[settled 2026-09-17 #1; Stage-1 P0-4]`
2. **A full manual authoring studio does NOT exist and must not be built.** A minimal
   *create-a-deck / edit-a-card* capability exists (principle #1 restated: "zero
   *manual* deck-building friction," not "zero deck-building"). When a persona's JTBD
   sounds like authoring (P5), it is *lightweight* authoring on a reviewing app — not
   a mandate to grow an editor. `[settled 2026-09-17 #1; Stage-1 P2-2/P2-3]`

The engine is **general and education-first** — no privileged/default subject; SWE is
one authored config among many. `[locked ux-vision principle #10]` Wherever a persona
below is drawn as SWE-flavored (P4), that flavor is *configuration*, and the same
mechanism must serve a 7th-grader on WW1 causes with equal dignity.

---

## 1. The six personas

Five active + one latent. Each carries: **who / context / constraints / devices /
core JTBD / how they primarily REVIEW / which assumptions they break.** The three
north-star docs today model essentially **one** of these (P4); naming the other five
is the point of this document.

> **Reading note.** These are numbered P1–P6 to match Stage-1 §2. The numbers are
> *identifiers, not a priority ranking* — P1 (K-12) is not "the most important"
> persona, and P4 (SWE) is not privileged despite being the one the codebase grew up
> serving. Priority is set by the phasing in `docs/ux-rework-stage1.md` §9, not here.

### P1 — K-12 assigned student (~9–17)

- **Context.** Given a class join-code by a teacher; studies an assigned deck toward
  a class rhythm (a quiz Friday, a unit test). Little pre-existing intrinsic
  motivation; motivation comes from **the teacher's presence and belonging to the
  class**, not solo grit.
- **Constraints.** Cannot BYO an Anthropic key (no card, no account of their own,
  often a minor → COPPA/FERPA territory). Cannot reason about "a markdown folder" or
  "a vault." Needs the *relatedness* channel a solo app structurally lacks. Equity- &
  guilt-sensitive: a loss-aversion streak lands hardest here.
- **Devices.** School/shared iPad or Chromebook; frequently **projector-mirrored or
  low-quality displays** → accessibility (contrast, text-scale, never-color-only) is
  not optional for this persona, it is the primary case.
- **Core JTBD.** *"When my teacher assigns a deck, help me pull it and get through
  today's cards without getting lost or feeling dumb."*
- **How they REVIEW.** Pulls a restricted deck by class-code (an *import* on-ramp),
  then lives in the daily loop. When the teacher pushes a correction, changed cards
  arrive **quietly as drafts** and are re-earned through one recall pass before they
  count (S6). They almost never create content.
- **Breaks the most assumptions:** folder-gate onboarding, honest-info-only
  motivation (needs a *relatedness* pillar + present-tense competence framing),
  BYO-key AI, and "cards are a lens over *your* notes" (the notes are the teacher's).
- **Motivation default → scaffolded + relational** (opposite of P4). See §3.1.
- **Gate:** any K-12 reward-adjacent chrome is **deferred behind a research pass**;
  the honest core is the floor, never leaderboards/streaks/points.
  `[settled 2026-09-17 #3; Stage-1 §7]`

### P2 — College / grad / professional-exam student (self-directed, deadline-driven)

- **Context.** A real dated target — an exam, a board/cert, a quiz, an assignment
  due date. Owns messy source material (PDFs, lecture notes, whiteboard photos) and
  wants cards *fast*; tolerates light editing but will not hand-author a deck.
- **Constraints.** Deadline pressure makes *honest* "will I be ready by the date?" the
  killer feature — and makes a *lying* readiness number actively harmful. Cost-aware
  about AI. Studies across **laptop + phone → wants sync** (S9).
- **Devices.** Laptop (capture/generate) + phone (review on the go). Tablet common.
- **Core JTBD.** *"Turn my messy source material into a study deck and tell me
  honestly if I'll be ready by the exam."*
- **How they REVIEW.** The daily loop toward a **dated target** ("milestone," never
  "Interview" — the name is subject-neutral). `[Stage-1 P2-1; ux-vision §5]` The AI
  *generate-from-material* on-ramp is most valuable to P2 — but each generated card
  enters as a **draft** and is promoted by one self-test pass (S2), so generation is
  the *first retrieval rep*, not a wall of unvetted facts. `[settled 2026-09-17 #4]`
- **Breaks:** "authoring lives in the vault" (P2 has raw material, not a curated
  vault — light editing must be **in-app**); the SWE-centric name "Interview"; the
  assumption that progress lives on one device.
- **Motivation default → honest-readiness core, as-is.** Well-served by the locked
  motivation model; the dated-target forecast is the hero for this persona.

### P3 — Self-directed adult hobbyist (the second caller that already exists)

- **Context.** Languages, theology, trivia, history — the **Korean folder that
  exists in the app today** is this persona. **No deadline; an open-ended coverage
  goal.** Learning for its own sake, indefinitely.
- **Constraints.** Nagging is repellent (will churn instantly). No exam to anchor
  readiness → the honest signal is *coverage* + "keep making steady progress," not a
  ready-by date. Wants to start with **zero authoring**.
- **Devices.** Personal phone + maybe a laptop. Self-provisioned; may or may not have
  an Anthropic key.
- **Core JTBD.** *"Keep me making steady, durable progress on a subject I chose,
  forever, without nagging me."*
- **How they REVIEW.** Mostly the current calm/honest core already serves P3. The key
  on-ramp is **import a ready-made shared deck** (S3) so they never touch authoring;
  AI-generate is a nice-to-have, not a need.
- **Breaks:** the deadline-centric framing (open-ended goals must never see interview
  chrome or a fabricated readiness %); the assumption that everyone authors.
- **Motivation default → honest-readiness core + coverage framing + under-notify.**
  The *proof* that under-notify is right lives with this persona.

### P4 — SWE / power user (the CURRENTLY-MODELED persona)

- **Context.** Obsidian vault, markdown-fluent, git, **BYO Anthropic key**. Drilling
  toward a job-change interview loop. This is who the three north-star docs describe.
- **Constraints.** Will *not* have anything dumbed down; wants depth, keyboard-fast
  flows, and control. Comfortable pointing the app at a folder and reasoning about
  files, snapshots, and sync-as-folder-sync.
- **Devices.** Mac + iPhone; iCloud/git folder-sync already in play (and today
  **buggy** — LWW blob, Stage-1 P0-6/S9).
- **Core JTBD.** *"Point Onyx at my vault, drill toward an interview, and don't dumb
  anything down."*
- **How they REVIEW.** The full daily loop + mocks + coach, over an *existing* folder
  (the *point-at-folder* on-ramp — the only on-ramp that names "folder" out loud).
  The only persona for whom "authoring lives in the vault" is *true* — and even here
  it is the power path, not the app's center. `[Stage-1 P2-3]`
- **Breaks nothing itself — the risk is the inverse:** P4's assumptions were baked in
  as **universal** (folder-first onboarding, BYO-key-only AI, "the vault is the
  authoring studio," SWE vocabulary in the coach hot-path). The whole rework is
  largely *un-baking P4-as-default* while keeping P4 first-class.
- **Motivation default → honest-readiness core, as-is** (the model was calibrated to
  exactly this "motivated adult learning solo" case).

### P5 — Teacher-as-pusher (the distribution persona)

- **Context.** Curates or generates a deck and **pushes it to a class**; controls who
  can pull it; pushes corrections over time; wants students to keep up. The producer
  in a room full of consumers.
- **Constraints.** Not a developer — must never see "git remotes" as user-facing IA
  (`RegistryRemoteRow` is rejected; model remotes internally). `[Stage-1 §5]`
  Legitimately needs to **notify a class** (an assignment push) — which collides with
  the solo "under-notify / no notifications" cut and must be reconciled, not ignored.
  Minors' data → **FERPA/COPPA is a prerequisite** to marketing the managed tier to
  teachers. Wants *minimal* engagement signal — **never a gradebook or per-student
  ranking**.
- **Devices.** Laptop (authoring/curation, class management) as the **primary**
  device — so **tablet/wide-screen layout is this persona's home turf** and the
  locked ~66ch measure must not break there. `[Stage-1 §10.15]` Phone secondary.
- **Core JTBD.** *"Publish my deck to my class, control access, push corrections, and
  see minimally that they're engaging — without building a gradebook."*
- **How they REVIEW (yes, even P5 reviews):** a teacher still runs the daily loop on
  their own deck to vet it, and the **draft-review gate is their QA pass** — pushing
  is downstream of reviewing. P5's *distinctive* sub-jobs sit *around* the review
  core, they do not replace it:
  - **Author/curate** (overlaps P2's AI-gen + the minimal manual create/edit) — *not*
    a full studio.
  - **Publish + authorize** — the **group/class is the permission unit**; two roles
    only (maintainer / subscriber); visibility `local → restricted → public`
    (public deferred hardest, behind moderation). `[Stage-1 §5, §9]`
  - **Maintain** — push an update that flows to subscribers **through the same Draft
    gate**, never auto-applied into FSRS (S6). `[settled 2026-09-17 #4]`
- **Breaks:** `StudyGoal` models only *consumption* (a local query + template +
  target) — it has **zero** authoring/publishing/provenance state. The producer role
  needs a provenance seam reserved now (`source`/`sharedDeckId`/`accessControl`),
  orthogonal to both membership and the focus spine. `[Stage-1 §5, P2-5]`
- **Motivation:** P5 is a *source* of the relatedness pillar for P1 (teacher
  recognition, teacher-set proximal goals) — see §3.1. Their own motivation is
  seeing a class engage, expressed only as **aggregate/anonymous** cues, never
  per-student comparison. `[settled 2026-09-17 #3]`

### P6 — Institution / admin (LATENT — reserve the seam, do NOT design)

- **Context.** A school/department: roster provisioning, license seats, a private
  landing, group-of-groups. The buyer above the teacher.
- **Stance.** **Reserve the seam only** — an account may carry optional org/group
  membership; do not design admin surfaces now. Naming P6 keeps the account/group
  model from being drawn too narrowly (a class is one kind of group; an org is
  another). `[Stage-1 §2 P6, §9 "defer hard"]`
- **JTBD (recorded, not built):** *"Provision my teachers and students, manage seats
  and access, keep it private and compliant."* Depends on accounts + restricted
  registry, both of which are themselves deferred/seamed.

---

## 2. Top user stories

Building directly on Stage-1 §2's S1–S10 (kept stable so the two docs cross-reference
cleanly), plus the additions the review-focused framing surfaces (S11–S14). Each is
tagged for build state and mapped to the persona + JTBD it serves, so a flow designer
can name its owner.

**Legend.** `[exists]` = built & direction-compatible · `[partial]` = client/core built,
a server-backed or polish piece remains · `[specced-only]` = designed in a doc, unbuilt ·
`[UNDESIGNED]` = no doc, no code. "Owner" names the primary persona; "also serves" names
secondaries. **Build-state refreshed 2026-09-20** — many stories below shipped since the
original snapshot; anything server-backed is built against a fake registry (task #83). See
[roadmap.md](roadmap.md) for the authoritative build-state.

| # | Story | Owner | State |
|---|---|---|---|
| **S1** | *Enter a class code → land on my teacher's cards → start today's review.* | P1 | **[partial]** — deck import/pull built against the fake registry; the class-code *auth* is server-side (#83) |
| **S2** | *Paste a PDF/notes/topic → AI generates a starter deck → I self-test each draft → it counts.* | P2 | **[exists]** — AI-generate (BYO-key) + `status: draft` + the `/draft-review` self-test-then-promote gate all built; managed tier deferred |
| **S3** | *Browse the library → preview a ready-made deck → import it → study.* | P3 | **[exists]** against the fake registry (real server deferred — #83) |
| **S4** | *Point at my existing Obsidian folder and go.* | P4 | **[exists]** on desktop (persisted `VaultRef`, ADR-0002); iOS/Android on-device folder-picking deferred (#82) |
| **S5** | *Try the whole app with no sign-in and no AI key — the core just works.* | all | **[exists]** as a principle; must extend to **accounts** (render account UI only when a backend capability is reachable) |
| **S6** | *Teacher/upstream updates the deck → I get the changes quietly, re-earned before they count.* | P1, P5 | **[exists]** — content reconciliation through the Draft gate (`reconcileDeckUpdate`/`applyDeckUpdate`); server *propagation* deferred (#83) |
| **S7** | *Publish my deck → choose restricted/public → authorize a class.* | P5 | **[partial]** — folder-lens publish built against the fake; restricted/public tiers + class authorization are server (#83; public behind moderation) |
| **S8** | *Import law: a "90%-mastered" deck shows MY readiness = fresh; scheduling never travels.* | P2, P3, P4 | **[exists]** — enforced by construction (deck payloads carry content only; import resets every card to `draft`) |
| **S9** | *Second device → my progress syncs, no card silently lost.* | P2, P4 | **[exists, BUGGY]** — LWW blob clobbers/diverges (present bug, Stage-1 P0-6; still open) |
| **S10** | *Offline / over AI quota / not authorized → an honest, non-scolding state that says the core still works.* | all | **[partial]** — keyless-core + capability-gated SHARING are honest today; quota-exhausted / not-authorized states land with the managed tier + server (#83) |
| **S11** | *Create a deck and add/edit a card by hand — lightly, without a studio.* | P4, P5 | **[exists]** (#28 — light in-app create/edit; principle #1: zero *manual* deck-building **friction**, not zero capability) |
| **S12** | *Just-in-time at first AI use, choose: Onyx AI (coming soon) · my Anthropic key · not now — never at onboarding.* | P2, P4 | **[partial]** — BYO-key inline built; the managed tier is an honest "coming soon" until a server exists (#83) |
| **S13** | *A dated target ("milestone") on my open-ended-or-not goal drives an honest ready-by forecast — no SWE "Interview" chrome unless my config declares it.* | P2, P4 | **[exists]** — forecast generalized (`effectiveDeadline`); terminology is per-subject config (`Vocabulary`, #30); progressive-disclosure polish pending |
| **S14** | *Consistency without loss: an "N of last 7 days" indicator, never a consecutive-day streak I can break.* | all (esp. P1) | **[exists]** — `_ConsistencyChip` ("N of last 7 days"); the loss-aversion `_StreakChip` was deleted `[settled 2026-09-17 #3]` |

**Story clusters, by on-ramp** (so a designer sees which JTBD a flow feeds):

- **Import / pull cluster** (S1, S3, S6, S8) — the *import* on-ramp. Owners P1/P3/P5.
  The **Draft gate** (S2/S6) + **scheduling-never-travels** (S8) are the two
  invariants that make imported content obey honest-readiness *by construction*.
- **Generate cluster** (S2, S12) — the *AI-generate* on-ramp. Owner P2. BYO-key first;
  managed tier seamed. Self-test-then-promote is the default. `[settled #2, #4]`
- **Point-at-folder / manual cluster** (S4, S11) — the *folder* + *light manual*
  on-ramps. Owner P4 (also P5 for S11). The only cluster that names "folder."
- **Solo-core-always-works cluster** (S5, S9, S10) — the local-first floor under
  *every* persona. This is the shippable foundation the cloud layer *layers on*, and
  the airplane-mode full loop is a **CI invariant**, not a nicety. `[Stage-1 P0-3]`
- **Review-forever cluster** (the daily loop, S13, S14) — the center of gravity for
  all six. Everything above only exists to feed this.

---

## 3. Persona collisions — resolve as CONFIG, not as a global default

These are the crux of the document. Stage-1 §2 names three collisions; the settled
direction adds a fourth and sharpens all of them. **In every case the wrong move is to
pick one persona's preference and hard-code it globally** (which is exactly how the
docs came to model only P4). The right move is a *config axis* whose default is chosen
by *context* (solo vs class, deadline vs open-ended), never forked into parallel apps.

### 3.1 Opposite motivation defaults (P1/P5-class ⇄ P2/P3/P4-solo)

- **The collision.** P4 (and P2/P3) want **pure honest information** — a readiness
  band that can fall, "focus here next," and *silence when on-track*. P1 wants
  **scaffolding and relatedness** — teacher presence, belonging, present-tense
  "you can now do X" competence framing. The docs hard-code P4's model as universal.
- **Why it's real.** The anti-gamification stance was explicitly calibrated to *"a
  motivated adult learning solo"* — which *lacks* relatedness. A classroom *supplies*
  relatedness (a core SDT need, g≈1.78 in the evidence base — the single largest
  motivational lever), so the premise that justified honest-info-*only* does not hold
  for P1. `[Stage-1 §1.8, §7]`
- **Resolution (config, not global):**
  - **Default = honest-information** for the solo core (P2/P3/P4). Unchanged. This is
    the floor and it ships first.
  - **The class config *adds* a bounded relatedness pillar** (P1/P5): teacher
    recognition via the existing one-line coach channel; **aggregate/anonymous**
    belonging cues ("your class is on deck X," "N studied today"); teacher-set
    proximal goals. **Hard line, codified:** *aggregate/belonging cues are allowed;
    ANY per-student comparison or ranking is forbidden.* `[settled 2026-09-17 #3]`
  - **Present-tense competence rendering** ("you can now do X") is a *per-config
    presentation option over the same honest engine* — it must not drift into a
    fabricated point-estimate; the band-that-can-fall math is untouched.
    `[Stage-1 §10.14]`
  - **Both still REJECT** (more strongly for kids): points/XP, badges, levels,
    leaderboards, consecutive-day streaks, streak-freeze/loss-aversion, confetti,
    countdown urgency, guilt notifications, any metric that only rises. The dividing
    line is **comparative/controlling/extrinsic-reward**, *not* "social" categorically
    (belonging is now in-scope). `[settled 2026-09-17 #3; Stage-1 §7]`
  - **Gate:** the reward-adjacent K-12 layer beyond the honest ring is **not built
    blind** — it waits on a child-development/classroom-motivation research pass, and
    is gated behind the (deferred) accounts/class layer so it *cannot leak into the
    solo core.* `[settled 2026-09-17 #3]`
- **Design test:** if a motivational element would render identically for a solo adult
  and a supervised child, it belongs in the core. If it only makes sense with a
  teacher present, it belongs in the class config, gated — never globally on.

### 3.2 No-folder arrival (P1/P2/P3 ⇄ P4)

- **The collision.** The one *designed* onboarding path hard-gates on choosing a
  **markdown folder** — which serves **only P4**. P1 arrives with a **class code**,
  P2 with **raw material** (a PDF, a topic), P3 with a **wish to import** — none of
  them has, or can reason about, a folder. And on a real iPhone today the app
  *literally cannot obtain a folder* (`vaultSourceProvider` returns `null`).
- **Resolution (config, not global): the intent-gate.** `/welcome` asks *"What do
  you want to do?"* with **three co-equal answers** — *make from my material* /
  *I have a class code* / *point me at my folder* — and the **folder becomes a silent
  consequence** of the first two (Onyx scaffolds a folder under the blessed container;
  the user never sees the word). Only the third answer names "folder," for P4.
  `[settled 2026-09-17 #1; Stage-1 P0-4]`
- **Co-equality is the settled correction.** Do **not** elevate AI-generation to the
  default just because P2 is a large audience; the three on-ramps stay co-equal
  (Stage-1 had drawn AI-gen as default — superseded). `[settled 2026-09-17 #1]`
- **Blocker it forces:** an on-device, **content-origin-agnostic writable card store**
  serving all three producers (AI drafts, pulled decks, chosen folder) — Phase 0,
  ahead of any content UI. `[Stage-1 P0-4, §9 Phase 0]`
- **The one genuine tension inside this:** *does a class-code pull require an
  account?* Restricted decks are group-gated, but first-run must never gate on
  accounts. **Resolution:** code-as-credential + lightweight/anonymous device
  identity for **pull-only**; a real account is deferred to sync/publish.
  `[Stage-1 §10.3]`
- **Design test:** every onboarding branch must reach a first review **without** the
  user ever typing "folder," creating an account, or adding an AI key — unless *they*
  chose the folder path.

### 3.3 Producer vs consumer (P5 ⇄ P1/P2/P3/P4)

- **The collision.** P1–P4 *consume* content; P5 *produces and distributes* it.
  `StudyGoal` models consumption only (membership = a local query, + template +
  target). It has no concept of authoring, publishing, access control, or upstream
  provenance — so a pulled deck (a *discrete unit*, not a folder query) and a pushed
  deck have nowhere to live.
- **Resolution (seam, reserved now; build deferred):**
  - Reserve a **provenance seam** distinct from both membership *and* the
    `focusedGoalProvider` focus spine — `source` / `sharedDeckId` / `accessControl` on
    the relevant models; a `deckId` namespace so the join key becomes
    `(deckId, cardId, sectionSlug)` (also the unit of pull/update/attribution/
    license/access). Never overload one seam to carry another. `[Stage-1 P0-5, P2-5]`
  - **Distribution is a permissioned push/pull registry:** anyone can push/pull;
    **group/class is the permission unit**; two roles (maintainer / subscriber);
    visibility `local (default) → restricted → public`. **Restricted-first; public
    deferred behind moderation.** `[settled direction; Stage-1 §5, §9]`
  - **Two invariants protect consumers from producers:** (1) **scheduling never
    travels with a deck** (S8 — a "90%" deck shows *your* readiness = fresh); (2)
    **upstream updates flow through the Draft gate** (S6), never auto-applied — which
    also honors "nothing mutates silently." `[settled #4; Stage-1 P2-4]`
- **P5's notify need vs the solo under-notify cut** is a sub-collision: a class
  assignment push is *not* the guilt/streak nag the solo core forbids. **Resolution:**
  reframe the blanket notification cut to *"no guilt/streak/nag; opt-in, off-by-
  default, due/plan-tied reminders allowed,"* and route P5's pushes through the *same*
  non-guilt, bounded, ~1–2/day rules. `[Stage-1 P1-6, §7]`
- **Producer surfaces stay lightweight** — the reviewing-app framing (§0) means P5
  gets *publish/authorize/maintain* + *minimal manual create/edit*, **not** an
  authoring studio. `[settled 2026-09-17 #1]`
- **Design test:** any producer surface must (a) leave the four-tab IA intact (no
  "Classes" tab; publish is a per-deck action + a Settings→SHARING group), (b) never
  ship a "git remote" as user IA, and (c) be **`focusedGoal`-invariant** (creating/
  importing/publishing may *offer* "add to current goal" but must never *require* a
  focus — protecting single-goal degradation). `[Stage-1 §5]`

### 3.4 Hosted-AI expectation vs BYO-key reality (P1/P2 ⇄ present capability)

- **The collision (the settled framing adds this one).** P1 *cannot* BYO a key and P2
  *expects* frictionless "just generate it" — both imply a **managed/hosted "Onyx
  AI."** But no server exists yet, and v1 ships **BYO-Anthropic-key first.** If the
  managed tier is drawn as if present, P1's whole flow collapses to "get an Anthropic
  key" — the exact old-audience wall. `[settled 2026-09-17 #2; Stage-1 §10.8]`
- **Resolution (seam, honestly labeled):** AI is **hybrid but *seamed*** — a
  three-state affordance `off · managed · byoKey`, with the JIT choice at **first AI
  use** (never onboarding). **BYO-key is real in v1; the managed "Onyx AI" tier is an
  honest "coming soon" / disabled row until the server lands.** The fully key-less
  core always works (S5/S10). User-facing name is **"AI," never "Claude."**
  `[settled #2; Stage-1 P1-1]`
- **Consequence for the personas:** until the managed tier ships, **P1's realistic v1
  path is import (S1) + teacher-provisioned content**, not self-serve AI generation;
  P2's realistic v1 path is **BYO-key generation** (S2) or import. Do not design P1's
  v1 around an AI tier that isn't reachable. `[settled #2]`
- **Design test:** every AI entry point must degrade to an honest state with no key
  and no server, and must never render "Onyx AI" as *available* until a backend
  capability is actually reachable (the same rule as the account UI — an empty
  affordance for a nonexistent capability is the dark pattern we reject).

---

## 4. How to use this document (the decision-anchor contract)

When you design or review any Stage-2 surface:

1. **Name the persona and JTBD it serves.** If you cannot, either the surface is
   miscategorized or it should be cut. "It's nice to have" is not a persona.
2. **State the review-focus relationship.** Is this surface *the review loop*, or an
   *on-ramp to it*? On-ramps stay lightweight and co-equal; none becomes the hero.
   `[settled 2026-09-17 #1]`
3. **Check the collisions.** If your surface touches motivation, onboarding arrival,
   producer/consumer, or AI availability, confirm you resolved it **as a config axis
   defaulted by context**, not as a new global default. Point to §3.
4. **Honor the invariants that protect one persona from another:** Draft gate for all
   inflows (S2/S6); scheduling-never-travels (S8); `focusedGoal`-invariant acquisition
   surfaces; account/AI UI rendered only when the capability is reachable (S5/S10/S12);
   airplane-mode full loop as a CI invariant.
5. **Serve P4 without privileging P4.** Depth and power are fine; baking P4's
   folder-first / BYO-key-only / vault-is-the-studio / SWE-vocabulary assumptions in
   as *universal* is the exact regression this rework exists to undo.

---

*Grounded in `docs/ux-rework-stage1.md` (§2 seed, §5 IA, §6 flows, §7 motivation, §9
phasing, and the settled Decisions) and the locked companions. Where the Stage-1
architecture and the 2026-09-17 decisions differ (AI-gen-as-default → co-equal +
review-focused; accounts-rejected → optional-but-real; blanket-notification-cut →
reframed), **the decisions win** and are marked inline. The two items explicitly
gated behind fresh research remain gated here: K-12 reward-adjacent motivation, and
classroom/teacher-push notification specifics.*
