# Onyx — Product Direction

> **The top-of-stack canonical doc: "what Onyx is now."** This is the authoritative
> statement the rest of the design set is a companion *to* — `ux-vision.md` (north-star
> layout), `design-system.md` (tokens/widgets), `settings-ux.md` (settings IA),
> `personas-and-stories.md` (audience), `content-creation.md` and `registry-and-sync.md`
> (the cross-cutting on-ramps + optional cloud) all serve the direction fixed here.
> Where any older doc and this one disagree, **this one wins.** Read this first.
>
> Settled with the user **2026-09-17** (general/education-first + cloud-layer reframe).
> Grounded in `docs/ux-rework-stage1.md` (the critique+architecture behind these calls).

---

## 1. Product thesis

**Onyx is a calm, local-first *reviewing* app for durable learning — general and
education-first, over a plain folder of files.** Its audience is learners and teachers
across every subject and level (K→grad, self-directed adults); SWE-interview prep is one
*configuration*, never a privileged default. Motivation comes from **honest information
about your own progress toward your own goal** — never points, badges, streaks-as-score,
or guilt. It runs fully offline with no account and no AI; a cloud layer (AI generation,
sync, shared decks) *layers on* without ever being required. `[principle 10; §6, §7]`

The one-line test for every feature: *does it make honest, spaced review of a learner's
own material calmer and more effective?* If a feature pulls the center of gravity toward
authoring, engagement-farming, or a walled cloud, it is off-thesis.

---

## 2. Audience

Five modeled personas + one latent — full JTBD and user stories in
**`docs/personas-and-stories.md`**. The load-bearing shape:

- **Assigned learner (K-12)** — given a class code, shared device, short horizon, little
  pre-existing intrinsic motivation; needs *relatedness* (teacher presence), not solo grit.
- **Deadline-driven student (college/grad/pro-exam)** — owns messy source material, has a
  real dated target, wants cards fast and honest "will I be ready?".
- **Self-directed adult** — open-ended coverage goal, no deadline; wants steady durable
  progress and shared-deck import to start with zero authoring.
- **SWE / power user** — markdown-fluent, BYO key, git; the *currently-built* persona. The
  risk is baking their assumptions in as universal (folder-first, BYO-key-only,
  "authoring lives in the folder") — do not.
- **Teacher-as-pusher** — authors/curates a deck, pushes to a class, controls access,
  pushes corrections; the distribution persona.
- **Institution/admin** *(latent)* — seam reserved, not designed.

**No privileged subject.** Dimensions, tracks, rubrics, and terminology route through the
active goal's template; the built-in software-interviews config is a de-privileged
example, not a baked-in identity. `[principle 10]`

---

## 3. The local-first solo core (the contract)

This is the shippable foundation. Everything else layers on top of an intact core.

- **Account-free.** No login, ever, to study your own material. We render account UI
  *only* when a backend capability is actually reachable — an empty "Sign in" row is the
  dark pattern we reject. `[Stage-1 §4 P0-3]`
- **Fully offline.** The daily loop, FSRS scheduling, readiness, browse, and settings work
  with the network off. "Offline" is a `muted` state, never an error, in a local-first app.
- **Works with NO AI.** AI is additive. With no key and no managed tier, review is 100%
  functional; AI-dependent surfaces degrade to an honest state that says the core still
  works, never a nag.
- **Single-goal degradation is byte-identical.** The common case (one active goal) looks and
  behaves exactly like a single-purpose study app — no hub chrome, no "mix" affordances.
  This is a **CI invariant**, tested (airplane-mode full-loop + single-goal parity), not a
  wish. `[locked; ux-vision §2]`
- **The folder is the source of truth; the DB is a derived cache.** This is what makes
  "account never required" achievable and sign-out cheap — nothing durable lives only in
  the cloud.

> **Degradation rule.** Turning off AI, sync, and accounts must leave the app *behaving
> identically* to a build that never had them. If a feature can't degrade this way, it is
> designed wrong.

---

## 4. Folder substrate + decks (critical framing)

**The substrate is ALWAYS just a folder of files.** Cards are parsed out of plain markdown
(an Obsidian folder works as-is; Obsidian is never required). A **"deck" is a user-facing
grouping over those files** — something a user can *import* (many), *create*, or *author* —
not a separate store. User-facing noun is **"folder" / "study folder,"** never "vault"
(the code layer keeps `VaultSource`).

**Onyx is a REVIEWING app, not an authoring app.** Content on-ramps — AI-generate, import,
point-at-a-folder — are **lightweight, co-equal on-ramps to content**, never the center of
gravity. A **minimal create-a-deck / edit-a-card** capability exists; a **full manual
authoring studio does not** (that is out of scope by design). This *is* principle #1 —
"zero *manual* deck-building friction" — fulfilled, not violated. `[principle 1; Stage-1
decision 1]`

---

## 5. The three co-equal content on-ramps

None is "the hero." Onboarding is an **intent-gate** — "What do you want to do?" with three
tonal choices, ordered by audience size but *co-equal*, never a folder-first gate:

1. **Make cards from my material** — paste text / a topic / a PDF / a photo → AI-generate.
   *(Ship Paste + Topic first; PDF/photo deferred.)*
2. **I have a class code** — pull a restricted, teacher-pushed deck.
3. **Point me at my folder** — the only path that names "folder" (the power path); Onyx can
   also *create* a folder + seed a subject-neutral sample deck for a user with no notes.

The folder is a **silent consequence** of paths 1–2, not a gate in front of them. Entry to
acquisition also lives at the `+` in Browse (your library) and in empty states — never a
5th tab. `[Stage-1 §5; decision 1]`

**The Draft/Review gate (shared primitive across all three).** AI-generated, imported, and
upstream-updated cards enter as **`draft`** — *excluded from FSRS and from every readiness
denominator* until promoted. Promotion is **self-test-then-promote**: each draft runs once
through the existing recall→reveal gate (the first pass IS a retrieval rep), per-card
keep/edit/discard, **no bulk "Accept all."** This one mechanism makes every on-ramp obey
honest-readiness + "spacing is FSRS's job" *by construction* — it neutralizes the
generation-effect risk, hallucination risk, the scheduling-stripped-import law, and silent
readiness inflation at once. Owned in **`docs/content-creation.md`**. `[Stage-1 §4 P0-2;
decision 4]`

---

## 6. AI stance — hybrid, but honestly seamed

AI is **hybrid but seamed**, and the user-facing name is always **"AI," never "Claude"**
(leaking a vendor re-privileges it the way "vault" leaked Obsidian).

- **BYO-Anthropic-key is FIRST (v1).** A user brings their own key; the just-in-time 3-way
  choice fires at *first AI use*, never at onboarding.
- **Managed "Onyx AI" is a seam, an honest "coming soon" until a server exists** — shown as
  a disabled/"coming soon" row, never a v1 dependency. If the hosted server won't exist for
  v1, the AI-gen path still ships on BYO-key; the managed tier is the *seam*, not the
  linchpin. `[decision 2; Stage-1 §10.8]`
- **Key-less core always works.** With `AiProvider = off`, everything but the AI on-ramps
  runs; those show an honest `AiUnavailableState` (offline / no-tier / quota-exhausted)
  that states the core is unaffected.
- Usage/quota, when the managed tier lands, renders as a **`CoverageBar`, never a ring or a
  countdown** — a depleting quota must never become a loss-aversion timer. `[principle 4;
  design-system §4.3/§5]`

Three states, one affordance: `AiProvider { off, managed, byoKey }`, routed through a single
shared chooser. Managed-tier privacy/cost/minors' data are gated preconditions owned in
**`docs/registry-and-sync.md`** (plain-language disclosure at opt-in; no direct child
accounts on managed in v1). `[Stage-1 §4 P1-8]`

---

## 7. Optional accounts + sync (never required, capability-gated)

**`sync ≠ server ≠ accounts`** — three separable layers, none required for solo local use.

- **Accounts are opt-in and never a launch gate.** They are driven by managed-AI +
  restricted-deck pull, *not* by sync. One account concept carries three capability flags
  (sync / managed-AI / sharing). The ACCOUNT settings group renders **only when a backend
  capability is reachable.** `[Stage-1 §4 P0-3]`
- **Sync is optional, off by default, decoupled from the folder source** ("a synced folder
  is just a folder"). Most of sync's value ships as a **merge-correct snapshot over
  folder-sync with zero server** — per-`(cardId, sectionSlug)` last-review-wins + an
  idempotent review event-log, *replacing today's last-write-wins blob* (a present bug that
  corrupts progress across two devices). Account-sync, if built, carries **progress + goals
  only, never content** — folder-sync is the content-sync story; we do not re-implement
  Obsidian Sync or git. `[Stage-1 §4 P0-6, §9, §10.10]`

Local→account migration is designed now (FK-ordering, reversible) and the build deferred.
Details in **`docs/registry-and-sync.md`**.

---

## 8. Distribution — a permissioned deck push/pull registry (restricted-first)

Distribution is a **permissioned push/pull registry**: anyone can push or pull. Teachers
push, students pull; a **group/class is the permission unit** (not per-deck-per-user ACLs),
with exactly two roles — **maintainer** (push/approve) and **subscriber** (pull/suggest).

- **Three visibility tiers:** `local` (default, offline) → `restricted` (group-gated) →
  `public`. **Restricted-first;** public is **deferred-hard behind moderation** (report /
  takedown / review queue) — teacher→known-students needs no open moderation, so it ships
  first. `[Stage-1 §9 defer-hard; §10.11]`
- **Scheduling never travels with a deck** (the Anki law): a pulled "90%-mastered" deck
  shows *your* readiness = fresh. Upstream updates flow through the **same Draft gate** —
  never auto-applied into FSRS ("nothing mutates silently"). `[Stage-1 §5]`
- **No engagement metrics** in the registry — no download counts, ratings, "trending," or
  "N studying." Card-count is allowed (a size fact, not an engagement metric).

Deck identity is namespaced (`deckId`; join key `(deckId, cardId, sectionSlug)`) so pulled
cards can't collide with local FSRS state. Owned in **`docs/registry-and-sync.md`**.

---

## 9. Motivation stance

A single model configured by *context*, not forked per audience. **Honest information is
the default.**

- **KEEP:** honest readiness that can *fall* + weakest-link cap + "can't judge yet";
  "focus here next" weakest-area guidance; small-quantity-first Home (today's wins is the
  hero, readiness a chip); coach that is task-level, feed-forward, quiet-when-on-track,
  ≤1–2/day; per-card confidence display; **"Done" = the absence of the Filled button, not a
  reward animation.**
- **DELETE the consecutive-day streak + `StreakInfo.best`** (a can-only-rise vanity metric
  that ships a live loss-aversion violation today). **Replace with a no-loss "N of last 7
  days"** non-consecutive consistency indicator — the habit support the streak reached for,
  minus the condemned loss-aversion. This matters *more* for the new K-12 audience
  (guilt/equity). `[decision 3; Stage-1 §1.7, §7]`
- **The belonging-yes / comparison-no rule.** Split the old blanket "reject social" line:
  **aggregate / anonymous belonging cues are allowed via the class config** (relatedness is
  a core SDT need the solo app lacked — g≈1.78, the largest motivational lever in the
  evidence base); **ANY per-student comparison or ranking is forbidden.** Relatedness is
  not gamification. `[Stage-1 §7]`
- **STILL REJECT (stronger for kids):** points/XP currency, badges, levels, leaderboards /
  any cross-student ranking, consecutive-day streaks, streak-freeze/loss-aversion,
  confetti/trophies, countdown urgency, guilt notifications, any metric that only rises.
- **Notifications:** not a blanket cut — **one opt-in, off-by-default, due/plan-tied,
  non-guilt reminder** (backlog is the dominant SRS failure; a due-reminder is retention
  infrastructure, not a streak crutch). Never streak/guilt/nag; ~1–2/day cap.
- **Gated behind a research pass (do NOT build blind):** any *reward-adjacent* K-12
  scaffold beyond the honest ring. Honest-info-only is calibrated to adults; the corpus has
  zero child-development sources. Keep honest-info-only as the default; permit a bounded,
  teacher-gated, SDT-safe competence/effort layer *only* after a dedicated pass, never with
  leaderboards/loss-aversion/currency, and gated behind the accounts/class layer so it can't
  leak into the solo core. `[Stage-1 §7]`

---

## 10. LOCKED non-negotiables

These are settled. New work must honor them; regressing any is a failure condition.

- **The 10 UX principles** — time-to-first-review; bounded/finishable sessions with an
  honest "done"; recall principle-first; **spacing is FSRS's job** (never expose cramming;
  the only overload lever is cutting NEW intake); **honest readiness** (band that can fall,
  weakest-link cap, "can't judge yet," never a fabricated 0%); **under-notify** (coach quiet
  when on-track, ≤1–2/day); **autonomy** (Apply / Not-now / Undo, nothing mutates silently);
  calm visual restraint; **per-goal truth** (no cross-goal aggregate number); **no privileged
  subject.**
- **Dataviz rules** — bars > rings (exactly one ring app-wide = today's completion %);
  uncertainty-first; **never color-only** (color + shape + number + Semantics); WCAG floors;
  no vanity metrics.
- **Learning-science rules** — recall→reveal→self-grade gate; Learn blocks / Review
  interleaves; FSRS owns spacing; generation-effect ("automation reduces friction, not
  cognition").
- **4-tab IA** (Home / Browse / Insights / Settings) — **no 5th tab** under any pressure
  (Library/Create/Classes/Account/Aim all live inside existing tabs) — plus the nullable
  **`focusedGoalProvider` spine** + **single-goal byte-identical degradation.**
- **SheetHeader-everywhere** — every drill-down/editor/explainer is a slide-up sheet; the
  **one carve-out** is the full-screen draft-review *session* (a bounded, finishable session,
  like `/learn` and `/report`).
- **The design-system tokens** — dark-locked (off-white on dark-gray, never `#FFF` on
  `#000`), one accent hue, Material-3 emphasis (exactly one Filled per surface).

---

## What changed & why (2026-09-17)

Two reframes, both settled with the user, both authoritative over the older docs:

1. **General/education-first (de-SWE).** Onyx is a study app for *all* learners and
   teachers, not an SWE-interview tool that happens to generalize. SWE is one config; there
   is no shipped default subject. The earlier "AI-generation is the default/hero" framing is
   **superseded** — the three content on-ramps are **co-equal**, and Onyx is a **reviewing**
   app (import/create/generate are lightweight on-ramps, not the product's center).
2. **The cloud layer *layers on* an intact local-first core.** The docs used to equate
   `sync == server == accounts == deferred`. That is broken apart: the solo core is
   account-free / offline / no-AI / byte-identical; AI is **hybrid but seamed** (BYO-key
   first, managed "coming soon"); accounts + sync + the registry are **optional and
   capability-gated**, reserved-in-writing now and built when audience + legal/moderation
   work justify a server. The old "accounts are rejected" and "no server, ever" statements
   are retired.

Everything else in the corpus stays valid; where an older doc still reads SWE-first or
"accounts rejected," it is being updated to match this file.

---

**Reading order:** see **`docs/INDEX.md`** — product-direction (this file) → ux-vision →
design-system / settings-ux → personas-and-stories → content-creation / registry-and-sync →
feature docs. Historical/superseded: `architecture.md` (v1 offline core; server layer
reserved), `vault-structure.md` (power-path only).
