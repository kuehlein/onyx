# Onyx — Registry, Accounts & Sync (the optional cloud layer)

> **Stage 2 of the UI/UX rework** — the cross-cutting doc for the **optional cloud
> layer**: accounts, sync, deck identity, the permissioned deck registry, and the
> managed-AI infrastructure. Companion to `docs/product-direction.md` (§7 accounts,
> §8 distribution — this doc *owns* their mechanics), `docs/personas-and-stories.md`
> (P5 producer, P1 class-code, P6 latent institution), `docs/content-creation.md`
> (the Draft gate this doc's inflows share), and the locked `docs/ux-vision.md` /
> `docs/design-system.md` / `docs/settings-ux.md`.
>
> **The governing stance: seams now, build later, core never compromised.** Every
> capability here is **optional and capability-gated**. None is a launch dependency;
> none may weaken the local-first, account-free, offline, no-AI solo core, which is
> the shippable foundation this layer *layers on* (`product-direction §3`). Where a
> feature can't degrade to that intact core, it is designed wrong.
>
> Grounded in `docs/ux-rework-stage1.md` (P0-3/P0-5/P0-6, P1-8, §5, §9) and the
> settled **2026-09-17** decisions. Where Stage-1 and those decisions differ, the
> decisions win and are marked inline. Code seams verified against `snapshot.dart`,
> `claude_service.dart`, `tables.dart`, `study_goal.dart` (§8 of this doc).

---

## 0. The three-way separation this whole doc rests on

The old corpus equated **`sync == server == accounts == deferred`**, and rejected
accounts in four places (`ux-vision §1/§3.7`, `settings-ux §1.2`). The single most
important reframe in the cloud layer is that these are **three independent axes**:

- **Sync** is a *data-reconciliation* problem. Most of its value ships with **zero
  server** (over a folder the user already syncs — iCloud/Dropbox/git). `[P0-6]`
- **A server** is *hosted infrastructure* (the managed-AI proxy; the deck registry
  backend). It is the thing that does not exist yet and gates the honest "coming
  soon" tiers.
- **Accounts** are an *identity* concept. They are driven by managed-AI + restricted-
  deck pull, **not by sync**, and are rendered only when a server capability is
  actually reachable. `[P0-3]`

**Consequence, load-bearing:** you can have merge-correct sync with no account and no
server (v1). You can pull a class deck with a *credential* but no full account (a
class code). You only need a real account when you reach for managed AI or for
publishing/authorizing/account-sync. Never collapse the three back together.

> **The degradation contract (from `product-direction §3`, restated as this doc's
> acceptance test).** Turning off sync, accounts, and managed AI must leave the app
> behaving **byte-identically** to a build that never had them. This is a **CI
> invariant** (airplane-mode full-loop + single-goal parity), not a wish. Every
> section below is written to preserve it.

---

## 1. Accounts — one concept, three capability flags, backend-gated

**Verdict:** reframe accounts from *rejected* → **optional-but-real, never required,
seams-reserved-now, UI rendered only when a backend capability is reachable.**
`[P0-3 — v1 for the model + guard; the account *build* is seamed-deferred]`

### 1.1 The dark-pattern objection was conditional — honor its real form

`ux-vision §1` listed "accounts/login" under *Explicitly rejected*; `settings-ux §1.2`
called an account section "a dark pattern." **That objection was conditional on there
being nothing to sign into** — an empty "Sign in" row that does nothing is the dark
pattern. The cloud layer creates *real* things to sign into (managed AI, restricted
decks, account-sync), so the reframe is not a reversal of the *principle*, it is the
principle applied correctly:

> **The capability-reachable guard (the guard, codified).** Render account UI **only
> when a backend capability is actually reachable** — i.e. a server endpoint is
> configured *and* health-reachable, or a class code has bound this device to a
> group. With no reachable backend, the ACCOUNT settings group is **absent, not
> disabled** (a disabled row for a nonexistent capability re-creates the exact dark
> pattern). This is the same rule as the AI-tier "coming soon" row and the sync group.
> `[P0-3; personas S5; product-direction §7]`

### 1.2 One account object, three orthogonal capability flags

There is **one** account concept. It carries three independent capability flags,
each independently `off` until the backing server exists:

```
Account {
  id            // opaque server id (never the folder, never a device id)
  handle/email  // display + login; email optional for class-code-only identities
  capabilities: {
    sync:       off | enabled   // account-sync of PROGRESS + GOALS (never content)
    managedAi:  off | enabled   // the hosted "Onyx AI" tier + quota
    sharing:    off | enabled   // publish/maintain decks; author identity
  }
  memberships: [ GroupRef ]     // classes/groups; optional org (P6 seam, unbuilt)
}
```

Rationale: a teacher (P5) needs `sharing`; a deadline student (P2) may want
`managedAi` + `sync` but never `sharing`; a K-12 student (P1) has a *class-code
identity* with none of the three until a teacher/guardian provisions more. Modeling
one object with flags (not three account types) keeps Settings honest — the ACCOUNT
group shows exactly the capabilities this account actually has, and the group itself
appears only when ≥1 is reachable. `[personas P1/P2/P5; product-direction §6/§7]`

**IA (from Stage-1 §5, locked):** Account/sign-in lives in **Settings → ACCOUNT**
(backend-gated), never a 5th tab, never a profile screen (no identity anchor exists
for a profile screen in the solo core). Enrollment via a remembered class code binds
to the **account**, not the device, once an account exists.

### 1.3 Local→account migration — designed now, built later

The migration path is **designed now** (cheap to reserve, a nightmare to retrofit)
and its **build is deferred** with the account server. Two properties make it safe,
and both fall out of the local-first contract:

1. **The DB is a derived cache; the folder is the source of truth**
   (`product-direction §3`). Verified in code: `snapshot.dart` treats the folder
   `_meta/` snapshot as durable and the DB as restorable-from-it. This is what makes
   **sign-out cheap and reversible** — signing out drops the *account binding*, not
   the user's data; progress remains in the folder snapshot and the local DB.

2. **Migration is additive and FK-ordered, never destructive.** Local→account
   migration *uploads a copy* of the mergeable progress payload (§2) keyed by the
   account, and stamps local rows with the account id. It does **not** move content
   (content never travels to an account — §2, §3) and it does **not** delete the
   local store. FK/insert order for the payload: **groups → account membership →
   goals → per-`(deckId,cardId,sectionSlug)` SRS state → append-only review events**
   (parents before children; the review log last because it references the SRS key).

> **Reversibility is the acceptance test.** Sign-out → sign-in-as-local must leave a
> fully working app with all progress intact, *offline*, with the account server
> unreachable. If sign-out ever bricks the local core, the migration is wrong.
> `[Stage-1 §9 "migration designed now"; product-direction §7]`

**Mark:** account model + capability flags + the reachable-guard = **v1** (the guard
must ship so the *absence* of the group is correct from day one). The account
*server*, real sign-in, and the migration *execution* = **seamed-deferred** (arrive
with managed-AI + restricted-pull). Direct child accounts = **defer-hard** (§5.4).

---

## 2. Sync — merge-correct, folder-first, zero-server v1

**`sync ≠ server ≠ accounts`.** This is where the reframe pays off most, because sync
*already ships* — **badly** — and corrupts progress today.

### 2.1 The present bug (a live honest-readiness violation, not a future concern)

`snapshot.dart` writes **the entire progress state to one JSON blob** in the folder
(`_meta/onyx-state.json`, debounced post-review). Because users already fold that
folder through iCloud/Dropbox/git, **progress already syncs** — but reconciliation is
**last-write-wins on a monolithic blob**, and `restore()` only fires when the local
DB is empty. Verified in code:

- `export()` serializes whole tables (`srsStates`, `reviews`, `appliedAttempts`,
  `recognitionStates`) into one document and `writeMeta`s it.
- `restore()` guards on `isDbEmpty()` and then does **`DELETE *` on every table +
  bulk re-insert** — a whole-blob replace, no row-level merge.
- **Goals are not in the snapshot at all** (confirmed: no goal read/write in
  `snapshot.dart`; goals persist separately via `goal_store.dart` in `_meta/`).

**Result:** two devices editing the same folder → the later writer's blob overwrites
the earlier one wholesale, or (if both started non-empty) they diverge forever and
`restore()` never reconciles them. A card reviewed on the phone silently vanishes
when the laptop's blob wins. **This violates honest-readiness right now** (readiness
computed on clobbered history is a lie), and it is the true content of persona **S9**
("second device → my progress syncs, no card silently lost — *present bug*").
`[P0-6; personas S9]`

### 2.2 The fix — a merge-correct snapshot (per-key LWW + append-merge + goals)

Replace the blob-replace with a **row-level, timestamp-merged reconciliation**. The
snapshot stays a file in the folder (still zero-server), but its *restore/merge*
becomes correct. Three merge rules, one per data shape:

1. **SRS state — per-`(deckId, cardId, sectionSlug)` last-review-wins.** For each
   scheduling row, keep the version with the newer `lastReview` timestamp (already
   stored on `SrsStates`; add `deckId` to the key per §3). This is safe because FSRS
   state is a *pure function of the review history up to `lastReview`* — the newer
   review subsumes the older schedule. No `DELETE *`; merge in place.

2. **Review events — append-merge, idempotent.** The review log is append-only
   (verified: `Reviews` has an autoincrement `id` and is documented "never deleted").
   Merge by the natural key **`(deckId, cardId, sectionSlug, reviewedAt)`** — union
   the two logs, dedupe on that tuple. An idempotent event-log union can be applied
   any number of times from any device without loss or double-count. (Local
   autoincrement `id` is a local artifact and is **not** the merge key — it must not
   travel or it will collide across devices.) Do the same for `appliedAttempts` and
   `recognitionStates` (each has a stable natural key).

3. **Goals — fold into the synced payload, LWW on a per-goal `updatedAt`.** Goals
   currently don't sync at all (today's progress syncs but the goals that scope it
   don't — a per-goal-truth hole). Include them, reconciled per-goal by an
   `updatedAt` stamp; a goal deletion is a **tombstone**, never a hard drop (so a
   stale device can't resurrect a deleted goal). `[P0-6]`

> **Why merge, not CRDT.** Review history is a monotonic append log and FSRS state is
> derivable from it — LWW-on-newer-review + append-union is *provably* non-lossy for
> this data without CRDT machinery. Do **not** re-implement Obsidian Sync or git, and
> do **not** reach for a CRDT: the data shape doesn't need it. `[Stage-1 §10.10]`

**Conflict UX (calm, honest, rare):** folder-sync conflicts surface as a **`muted`
`StatusPill`**, never an error color — *offline and "a conflict was merged" are not
failures in a local-first app* (`design-system §4.9`). The default is **silent
correct merge** (the three rules above need no user choice). A true irreconcilable
case (e.g. a duplicate-UUID conflict *file* the sync engine dropped in the folder,
Stage-1 §6) shows one quiet Settings→SYNC line ("Resolved a sync conflict") with
details behind a tap. No modal, no interrupt, no data-loss without a tombstone.

### 2.3 Folder-sync is the content-sync story; account-sync (if ever) carries no content

Two sync surfaces, deliberately unequal in scope:

- **Folder-sync (v1, zero-server).** The merge-correct snapshot above rides on
  whatever the user already syncs the folder with. **Content** (the `.md` cards
  themselves) syncs *because the folder syncs* — Onyx does not move content; "a synced
  folder is just a folder" (`settings-ux §3`). This covers the solo/power personas
  (P2/P4) completely with no account and no server. `[personas S9; Stage-1 §10.10]`

- **Account-sync (seamed-deferred, if ever built).** If a server-backed sync ever
  ships, it carries **progress + goals ONLY, never content.** A user's cards live in
  their folder; the account holds the mergeable progress payload (§2.2) so a second
  device can reconcile without a shared folder. **The scheduling-never-travels-with-
  content invariant (§3.4) is unaffected** — account-sync moves *your own* progress
  between *your* devices; it never distributes cards. `[Stage-1 §10.10]`

**Settings IA (Stage-1 §5, locked):** **SYNC** group — `Off` / `On · last synced {t}`
/ `Sync error` → `showSyncSheet`; **decoupled from SOURCE** (a synced folder is just a
folder); **off by default**. Status via `StatusPill`; "Offline" is `muted`, not `bad`.

**Mark:** merge-correct folder-sync snapshot + goals-in-payload + conflict `StatusPill`
= **v1** (it *fixes a live bug* — highest-priority real fix, not a new feature).
Account-sync of progress/goals = **seamed-deferred**. Content-over-account-sync =
**defer-hard / never** (content is the folder's job, permanently).

---

## 3. Deck identity — the join key everything else hangs off

This is **the one schema decision to make before any shared data exists** (Stage-1
§10.4). It is small now and a migration nightmare later.

### 3.1 The collision (verified in code)

Everything joins on **`(cardId, sectionSlug)`** — confirmed as the literal primary key
of `SrsStates` (`primaryKey => {cardId, sectionSlug}`) and the key of `Reviews`,
`CoachMessages`, the snapshot, etc. `cardId` is a frontmatter id. **Two problems make
this unsafe the moment decks are pulled:**

1. **The folder mixes UUID and slug ids** (the Card-ID-Convention memory: "vault mixes
   UUID + slug ids → silent id-vs-filename join bugs"). A pulled card's `cardId` **can
   and will collide** with a local card's — and on a collision the pulled card
   *silently inherits the local card's FSRS schedule* (a fresh card shows as
   "mastered," or a mastered card resets). This is the **silent-corruption blocker.**

2. **`card-schema.md` mandates a UUID v4 `id` generated at card-creation time** (the doc
   doesn't literally say "per-device," but generation is device-local in practice, so the
   same authored card gets a different id on each device) — which makes *cross-device deck
   identity impossible* and contradicts the normalize-to-slugs memory.

### 3.2 Decision: `deckId`-namespaced join key `(deckId, cardId, sectionSlug)`

**Adopt a `deckId` namespace; the universal join key becomes
`(deckId, cardId, sectionSlug)`.** `[P0-5; Stage-1 §10.4 — recommended option wins]`

- **Robust to id collisions by construction.** A pulled deck's cards live in the
  pulled deck's namespace; they *cannot* collide with local FSRS state even if a raw
  `cardId` (slug or UUID) is identical. This is the property UUID-only-with-collision-
  rejection cannot guarantee cheaply (rejection is a lossy, user-hostile fallback).
- **`deckId` becomes the unit of everything downstream:** the unit of **pull**,
  **update propagation**, **attribution/license**, and **access/authorization**. One
  namespace key carries the whole registry story — a strong reason to prefer it over
  a bare collision-rejection scheme.
- **Local-authored content** gets a stable local `deckId` too (so "my folder" is just
  the deck with the local namespace), keeping one code path for local and pulled.

### 3.3 Reconcile the UUID-vs-slug card-schema conflict

Under a `deckId` namespace the *raw* `cardId` no longer needs to be globally unique —
only unique **within its `deckId`**. Resolution: **normalize `cardId` to a slug within
a deck** (aligns with the Card-ID-Convention memory and #51's normalize-to-slugs);
retire the per-device-UUID mandate in `card-schema.md`. A UUID may remain a legal
*within-deck* id for back-compat, but device-scoped UUID generation is dropped — the
`deckId` namespace + within-deck slug is the stable cross-device identity. Add
**duplicate-id detection in the indexer** (Stage-1 §6): two cards with the same
`(deckId, cardId)` in a folder (e.g. from a sync conflict file) must be *flagged, not
double-scheduled.* `[P0-5; Stage-1 §10.4]`

### 3.4 The scheduling-never-travels invariant (the Anki law)

**Scheduling state is keyed by `(deckId, cardId, sectionSlug)` and is LOCAL. It never
travels with a deck.** A pulled "90%-mastered" deck shows **your** readiness = *fresh*
(no SRS rows exist yet under that `deckId` for you). This is persona **S8** and it is
a **must-enforce invariant**, protected structurally: the registry payload for a deck
carries **content only** (cards, sections, metadata, license) and **carries no
`srs_state` / `reviews`** — there is no field for it to travel in. Newly pulled cards
enter as **`draft`** and are earned into FSRS through the Draft gate (§4.3), so even
"seen it before" content starts honest. `[personas S8; content-creation; product-
direction §8]`

**Mark:** `deckId` + `(deckId,cardId,sectionSlug)` join key + duplicate-id detection +
slug normalization = **v1 (Phase 0 seam)** — reserve it *before any data exists*, even
though pulling decks is deferred, because it touches every SRS query and retrofitting
it after there is real user data is the nightmare this section exists to prevent.

---

## 4. The permissioned deck registry (restricted-first)

Distribution is a **permissioned push/pull registry**: anyone can push or pull.
Teachers push, students pull. `[product-direction §8; personas P5; Stage-1 §5]`

### 4.1 Roles and the permission unit

- **Two roles only:** **maintainer** (push / approve updates) and **subscriber**
  (pull / optionally suggest). No finer role matrix in v1.
- **The group/class is the permission unit** — *not* per-deck-per-user ACLs. A
  maintainer authorizes a **group**; membership in the group is what grants pull.
  This keeps a teacher's mental model to "my class can see this," never a spreadsheet
  of per-student toggles. `[Stage-1 §5; personas P5]`
- **Never expose "git remotes" as user IA.** `RegistryRemoteRow` is rejected — model
  remotes internally. Teachers and kids must never see developer plumbing.
  `[personas P5; Stage-1 §5]`

### 4.2 Visibility tiers: local → restricted → public

| Tier | State | Ships |
|---|---|---|
| **`local`** | default; offline; never leaves the device/folder | **v1** (it *is* the solo core — no registry needed) |
| **`restricted`** | group/class-gated; pull requires membership/credential | **seamed-deferred** (needs the registry server + accounts) — but **first** of the networked tiers |
| **`public`** | anyone can discover + pull | **defer-hard**, behind moderation |

**Restricted-first** is the settled ordering: teacher→known-students needs *no open
moderation*, so it ships before public. **Public is deferred-hard** until
**report / takedown / a review queue** exist — shipping open discovery without
moderation is the trap. `[product-direction §8; Stage-1 §9/§10.11]`

### 4.3 Upstream updates flow through the Draft gate — nothing mutates silently

When a maintainer pushes an update, subscribers do **not** get it auto-applied into
FSRS. Changed/added cards arrive **quietly as `draft`** (excluded from FSRS and every
readiness denominator) and are re-earned through **one pass of the recall→reveal gate**
before they count — the *same* Draft gate as AI-gen and import (owned in
`content-creation.md`). This is persona **S6**, and it honors two locked rules at once:
**"nothing mutates silently" (autonomy)** and **honest-readiness** (an upstream edit
can't silently inflate or reset your progress). `[content-creation; product-direction
§5/§8; personas S6; Stage-1 §5]`

Surface: a quiet **Browse** affordance ("3 cards updated upstream") → the full-screen
`/draft-review` session. Never a push interrupt, never an auto-merge into your
schedule. Changed-card FSRS policy (the genuinely-hard sub-decision, Stage-1 §10.9):
a **text tweak keeps the schedule**; a section whose *meaning changed* becomes a new
`sectionSlug` (re-enters learning as a draft); a removed-upstream card is a
**tombstone, never a history delete.** Flag as needing a heuristic-vs-maintainer-flag
decision at build time. `[Stage-1 §10.9]`

### 4.4 Class-code auth — a credential for pull, not a full account

The one genuine tension: restricted decks are group-gated, but **first-run must never
gate on an account** (personas §3.2, S5). Resolution:

> **Code-as-credential + lightweight/anonymous device identity for PULL-ONLY.** A
> class code is a bearer credential that authorizes *pulling* a restricted deck and
> receiving its updates, bound to a lightweight device identity. A **real account is
> deferred to publish/maintain/account-sync** — the writing/identity-bearing
> operations. A K-12 student (P1) thus reaches their teacher's cards and today's
> review **with no account, no key, no folder typed** — exactly the co-equal
> "I-have-a-class-code" onboarding path. `[Stage-1 §10.3; personas P1/§3.2]`

### 4.5 Attribution / license seams — reserved now, minimal UI

Reserve, on the deck (namespaced by `deckId`), fields for **`author`** (attribution)
and **`license`** (redistribution terms) plus **`visibility`** and **`accessControl`**
(the group binding). These are the provenance seam the consumption-only `StudyGoal`
lacks (verified: `StudyGoal` carries membership + template + target + budget + state
and **no** `source`/`sharedDeckId`/`accessControl`/provenance). The seam is
**orthogonal** to both goal *membership* and the `focusedGoalProvider` focus spine —
never overload one to carry another. `[Stage-1 §5/P2-5; personas §3.3]` Attribution
renders as a quiet line on the deck detail sheet; license as a short honest statement
at pull time. Full license *enforcement* is deferred; the *seam* is reserved now.

### 4.6 NO vanity metrics in the registry

**No download counts, no ratings, no "trending," no "N studying."** These are the
engagement-farming the anti-gamification principles forbid (and they are worse in a
learning context — social-proof pressure over honest fit). Order discovery (when
public ever lands) by **relevance / recency / provenance**, never by popularity.
**Card-count is allowed** — it is a *size fact*, not an engagement metric.
`[product-direction §8/§9; design-system §5; Stage-1 §5]`

### 4.7 The registry is `focusedGoal`-invariant

The library/registry shows **all** decks regardless of focus; pull/publish/authorize
never read or set `focusedGoalProvider`. Pulling *may offer* "add to current goal" but
must never *require* a focus — protecting single-goal byte-identical degradation. The
provenance seam is orthogonal to the focus seam. `[Stage-1 §5; product-direction §10]`

**Mark:** role/group model + visibility enum + `deckId` provenance fields +
class-code-as-credential + the Draft-gated update path + the no-vanity-metrics rule =
**seamed-deferred** (reserve the *schema* and the *rules* now; build with the registry
server + accounts). **Restricted** tier = first networked build; **public** tier +
moderation/takedown = **defer-hard**; AnkiHub-style suggestion-queue/merge/co-author =
**defer-hard**.

---

## 5. Managed-AI infrastructure

AI is **hybrid but seamed**: BYO-Anthropic-key **first (v1)**; a managed/hosted
"Onyx AI" tier is an **honest "coming soon"** until a server exists. The user-facing
name is always **"AI," never "Claude."** `[product-direction §6; personas §3.4/S12]`

### 5.1 The proxy seam (trivial, verified)

The managed tier is a **proxy** the client points at instead of Anthropic directly.
Verified: `ClaudeService` is `{apiKey}` + a hardcoded `_endpoint` +
`x-api-key`/`anthropic-version` headers. The seam is one file:

```
ClaudeService({ required Uri baseUrl, required Map<String,String> authHeaders, ... })
// BYO-key:   baseUrl = api.anthropic.com,  authHeaders = { 'x-api-key': userKey }
// managed:   baseUrl = onyx proxy,         authHeaders = { 'authorization': accountToken }
// off:       not constructed — callers see AiUnavailableState
```

Route the ~9 hardcoded "Add your Anthropic API key" strings through **one** 3-state
affordance driven by:

```
AiProvider { off, managed, byoKey }
```

The just-in-time 3-way choice ("Onyx AI · coming soon" / "Use my Anthropic key" /
"Not now") fires at **first AI use**, never at onboarding. Until the proxy exists, the
`managed` row renders as an **honest disabled "coming soon"** — the *same* reachable-
capability guard as accounts (§1.1): never show "Onyx AI" as *available* until the
backend is actually reachable. The fully key-less core always works (S5/S10).
`[Stage-1 P1-1; product-direction §6; personas S12/§3.4]`

### 5.2 Per-account quota — a CoverageBar, never a countdown

When the managed tier lands, metering is **server-side, per-account.** Its only UI is
a **`CoverageBar`** (`design-system §4.3/§5`) — **never a ring, never a countdown, and
crucially never a loss-aversion timer.** A depleting quota that becomes a ticking
clock is exactly the manufactured-urgency the anti-gamification principles forbid.
`[product-direction §6; design-system §2.6/§4.13; Stage-1 P1-8]`

- **Exhaustion-only prompt.** The upgrade/BYO-key prompt appears **only at true
  exhaustion**, not as a running "you have N left" nag. Below exhaustion the
  CoverageBar is quiet, informational, `▲ near limit` micro-label near the top
  (never color-only, never an interstitial). `[Stage-1 P1-8]`
- **Cost traps to meter (build-time):** heavier metering for PDF/photo ingest;
  **cap chat-history tokens** on managed (the growing-transcript cost trap — the
  coach's running history would otherwise balloon per-request cost). `[Stage-1 P1-8]`
- Exhausted → the honest **`AiUnavailableState`** (offline / no-tier / quota-
  exhausted) that states the *core is unaffected*, never a scold. `[personas S10]`

### 5.3 Plain-language data disclosure at opt-in

Managed AI sends card text/images to a server, so the managed tier requires a
**plain-language disclosure at opt-in** (not buried in a policy): *what* leaves the
device (the text of a card, and images if PDF/photo ingest is used), *when* (only when
you use an AI feature), *that it is not used for training*, and *short retention*.
This mirrors the honest **Privacy** paragraph the About sheet already specifies
(`settings-ux §2` ABOUT). BYO-key keeps today's honest line (card text → Anthropic
with *your* key; nothing else leaves the device). `[Stage-1 P1-8; settings-ux §2]`

### 5.4 Minors / COPPA / FERPA stance

**No direct child accounts on the managed tier in v1.** `[Stage-1 P1-8/§9 defer-hard]`

- Managed AI for minors is **defer-hard**, gated on a COPPA/FERPA stance **and** the
  unresearched K-12-motivation pass (`product-direction §9`). A minor's access, if any,
  is **teacher/guardian-provisioned**, never a self-serve child sign-up.
- **FERPA/COPPA is a prerequisite to marketing the managed tier to teachers** (P5) —
  not a fast-follow. Until then, **P1's realistic v1 path is import (class-code pull) +
  teacher-provisioned content, not self-serve AI generation** (personas §3.4). Do not
  design P1's v1 around an AI tier that isn't reachable *or* legal for them.
- The K-12 reward-adjacent motivation layer stays **gated behind its research pass**
  and behind the (deferred) accounts/class layer so it *cannot leak into the solo
  core* (`product-direction §9`; motivation is owned there, flagged here only where it
  intersects accounts/minors).

**Mark:** `ClaudeService(baseUrl, authHeaders)` + `AiProvider{off,managed,byoKey}` +
the 3-state affordance + JIT choice + BYO-key path + the honest "coming soon" managed
row = **v1** (the seam + BYO-key ship; managed shown disabled until reachable). The
managed **server** (proxy + quota + billing + cost controls + data disclosure copy) =
**seamed-deferred**. Managed AI for **minors / direct child accounts** = **defer-hard**.

---

## 6. Traps & must-fix responses

The failure modes this layer must be built *against*. Each is a way the optional cloud
could silently compromise the local-first core; each has a codified response and a
build-timing mark.

| # | Trap | Must-fix response | Mark |
|---|---|---|---|
| **T1** | **Empty account UI** — a "Sign in" row for a server that doesn't exist (the original dark pattern). | ACCOUNT group **absent (not disabled)** until a backend capability is *reachable* (§1.1). Same guard for the managed-AI row and SYNC. | **v1** (guard) |
| **T2** | **LWW blob clobber** — the *present* bug: two devices, whole-blob replace, silent loss (`snapshot.dart`, §2.1). | Merge-correct snapshot: per-`(deckId,cardId,sectionSlug)` last-review-wins + append-union review events + goals-in-payload (§2.2). | **v1** (fixes a live bug) |
| **T3** | **Pulled deck inherits local schedule** — id collision → fresh card shows "mastered" / mastered card resets (§3.1). | `deckId`-namespaced join key `(deckId,cardId,sectionSlug)` + duplicate-id detection in the indexer (§3.2/§3.3). | **v1** (Phase-0 seam) |
| **T4** | **Scheduling travels with a deck** — a "90%" deck lies about *your* readiness (§3.4). | Registry payload carries content only; **no `srs_state`/`reviews` field to travel in**; pulled cards enter as `draft` (§3.4/§4.3). Invariant S8. | **v1** (invariant) / build w/ registry |
| **T5** | **Silent upstream mutation** — a teacher's push auto-applies into FSRS. | Upstream updates flow through the **Draft gate**, re-earned before counting; quiet Browse affordance, never an interrupt (§4.3). | seamed-deferred |
| **T6** | **First-run gated on an account** to pull a class deck (breaks S5 for P1). | **Code-as-credential + anonymous device identity for pull-only**; real account deferred to publish/sync (§4.4). | seamed-deferred |
| **T7** | **Content leaking into an account** — re-implementing folder/Obsidian sync, tying cards to identity. | Account-sync carries **progress + goals only, never content**; content is the folder's job, permanently (§2.3). | defer-hard / never |
| **T8** | **Quota-as-countdown** — a depleting managed-AI meter becomes a loss-aversion timer. | **CoverageBar, exhaustion-only prompt**, never a ring/countdown/interstitial (§5.2). | build w/ managed |
| **T9** | **Vanity metrics** in the registry — downloads/ratings/"N studying" (engagement-farming). | None. Order by relevance/recency/provenance; **card-count only** (a size fact) (§4.6). | seamed-deferred |
| **T10** | **Public decks without moderation** — open discovery = report/takedown burden the maintainer never signed up for. | **Restricted-first; public defer-hard behind report/takedown/review-queue** (§4.2). | defer-hard |
| **T11** | **Managed AI for minors** with no COPPA/FERPA stance / no child-dev research. | **No direct child accounts**; teacher/guardian-provisioned only; defer-hard; import is P1's v1 path (§5.4). | defer-hard |
| **T12** | **Managed tier as a v1 *dependency*** — if the server slips, AI-gen collapses to "get an Anthropic key" (the old wall). | Managed is the **seam, not the linchpin**: v1 ships BYO-key AI-gen + import; managed shown "coming soon" until reachable (§5.1). | **v1** (seam only) |
| **T13** | **Sign-out bricks the local core** — data lived only in the account. | DB is a derived cache; folder is source of truth; migration additive + FK-ordered + **reversible** (§1.3). | **v1** (design) |
| **T14** | **Non-idempotent event sync** — replaying the review log double-counts. | Append-union dedup on `(deckId,cardId,sectionSlug,reviewedAt)`; local autoincrement `id` never travels (§2.2). | **v1** (with T2) |

---

## 7. Build-timing summary

- **v1 (ships with the local-first core; no server required):** the reachable-
  capability **guard** for all cloud UI (accounts / managed-AI row / sync) so their
  *absence* is correct from day one (§1.1); the **merge-correct folder-sync snapshot**
  — per-key LWW + append-union events + goals-in-payload — which **fixes the live LWW
  bug** (§2.2, the single highest-priority real fix here); the **`deckId` +
  `(deckId,cardId,sectionSlug)` join key** + duplicate-id detection + slug
  normalization, reserved in Phase 0 before any data exists (§3); the
  **`ClaudeService(baseUrl,authHeaders)` + `AiProvider{off,managed,byoKey}`** seam +
  the 3-state affordance + JIT choice + **BYO-key** AI (§5.1); the account **model +
  capability flags** and the **reversible-migration design** (§1) — model designed,
  build deferred; the **scheduling-never-travels** invariant (§3.4).

- **Seamed-deferred (schema + rules reserved now; build when audience + legal +
  moderation justify a server):** the account **server** + real sign-in + account-sync
  of **progress/goals** (§1.3/§2.3); the **restricted** deck registry — roles / group
  permission / class-code / Draft-gated updates / `deckId` provenance + license/
  attribution fields (§4); the **managed-AI server** — proxy + per-account quota +
  cost controls + data-disclosure copy (§5).

- **Defer-hard (explicit gates):** the **public** deck tier (blocked on
  moderation/takedown/review-queue, §4.2); **managed AI for minors / direct child
  accounts** (blocked on COPPA/FERPA + the K-12 research pass, §5.4); **content over
  account-sync** — never (content is the folder's job, §2.3/T7); AnkiHub-style
  suggestion-queue/merge/co-author, and the P6 institution/admin surfaces (§4 / seam
  reserved only).

---

## 8. Code seams verified for this doc

- `lib/core/backup/snapshot.dart` — **confirms the LWW bug (T2/§2.1):** `export()`
  serializes whole tables to one blob; `restore()` is `DELETE *` + bulk insert guarded
  on `isDbEmpty()`; **no goals** are in the snapshot (they persist separately via
  `goal_store.dart`). This is the file §2.2 rewrites.
- `lib/core/database/tables.dart` — **confirms the join-key problem (T3/§3):**
  `SrsStates.primaryKey => {cardId, sectionSlug}` (no `deckId`); `Reviews` is an
  append-only log with an autoincrement `id` (the local artifact §2.2 says must *not*
  be the merge key). `CardCache` has **no `draft`/status field** (the Draft-gate seam
  is reserved in `content-creation.md` / `card-schema.md`).
- `lib/core/ai/claude_service.dart` — **confirms the trivial proxy seam (§5.1):**
  `ClaudeService({apiKey})` + hardcoded `_endpoint` + `x-api-key`/`anthropic-version`
  headers → parameterize to `{baseUrl, authHeaders}`.
- `lib/core/goal/study_goal.dart` — **confirms `StudyGoal` is consumption-only
  (§4.5):** membership + template + target + budget + state; **no**
  `source`/`sharedDeckId`/`accessControl`/provenance → the provenance seam is genuinely
  absent and must be reserved.

---

*Grounded in `docs/product-direction.md` (§3 the contract, §6 AI, §7 accounts/sync,
§8 distribution), `docs/personas-and-stories.md` (P1/P2/P4/P5/P6, S5–S10/S12,
collisions §3.2/§3.3/§3.4), `docs/content-creation.md` (the shared Draft gate), and
`docs/ux-rework-stage1.md` (P0-3/P0-5/P0-6, P1-1/P1-8, §5, §9, §10.3/§10.4/§10.9/
§10.10/§10.11). Where Stage-1 and the 2026-09-17 decisions differ (accounts-rejected →
optional-but-real; sync==server==accounts → three separated axes; AI-gen-default →
co-equal + seamed managed tier), the decisions win and are marked inline. Every
capability here is optional, capability-gated, and forbidden from compromising the
account-free / offline / no-AI / byte-identical solo core — the acceptance test for
this entire layer.*
