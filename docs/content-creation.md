# Onyx — Content Model & the Draft/Review Gate

> **Build-state note (2026-09-20):** this doc predates parts of the implementation. For the authoritative what's-built-vs-next, see [roadmap.md](roadmap.md). Corrections: the Draft/Review lifecycle (draft status, exclusion from FSRS + all readiness/coverage denominators, and the /draft-review self-test-then-promote gate) is BUILT and shipped.

> **Stage 2 of the UI/UX rework** — the cross-cutting doc that owns *how content
> gets into Onyx* and the one primitive that makes every inflow honest: the
> **Draft/Review gate**. Companion to `docs/product-direction.md` (which fixes the
> direction this serves), `docs/personas-and-stories.md` (the audiences), and the
> locked `docs/ux-vision.md` / `docs/design-system.md` / `docs/settings-ux.md`.
> Distribution mechanics (pull/push/registry/access) live in
> `docs/registry-and-sync.md`; this doc owns the *content* + *review-gate* half and
> points there for the wire.
>
> Grounded in `docs/ux-rework-stage1.md` §4 (P0-2 the gate, P0-5 deck identity,
> P1-7 IA home), §5 (IA reconciliation), §6 (flow inventory), and the settled
> **2026-09-17 decisions** (§0 below). Where Stage-1 and those decisions differ
> (AI-gen-as-default → co-equal; rubber-stamp import → self-test-then-promote),
> **the decisions win** and are marked inline.

---

## 0. The one framing this whole doc serves: Onyx REVIEWS, it does not author

Read this first; it re-weights everything below.

**The substrate is ALWAYS just a folder of files.** Cards are parsed out of plain
markdown (`card_parser.dart` over a `VaultSource`); an Obsidian folder works as-is,
Obsidian is never required. A **"deck" is a user-facing *grouping* over those
files** — something a user can *import* (many), *generate*, *create*, or *author* —
**not a separate store.** The user-facing noun is **"folder" / "study folder"**;
the code layer keeps `VaultSource`. `[product-direction §4]`

**Onyx is a REVIEWING app, not an authoring app.** The load-bearing loop is
*pull up today's due cards → recall → reveal → self-grade → honest "done"*
(`ux-vision.md` §4) — that is the product's center of gravity, and it is already
well-built. **Content acquisition — import, AI-generate, point-at-a-folder, light
manual create/edit — is an *on-ramp to that loop, never the destination.*** The
three on-ramps are **co-equal**; none is "the hero," and in particular
AI-generation is **not** elevated to the default (this corrects the Stage-1
architecture, where AI-gen was drawn as the default path). `[settled 2026-09-17 #1]`

Two consequences that govern every design choice in this doc:

1. **A full manual authoring studio does NOT exist and must not be built.** A
   *minimal* create-a-deck / edit-a-card capability exists — this **is** principle
   #1, "zero *manual* deck-building **friction**," *fulfilled*, not "zero
   deck-building **capability**." When a surface starts to grow toward a rich
   editor (WYSIWYG, templates gallery, card-type designer), that is the smell that
   we have drifted off-thesis; cut it. `[principle 1; Stage-1 P2-2/P2-3]`
2. **Every inflow is untrusted until *you* have retrieved from it once.** AI can
   hallucinate; an imported deck is someone else's claim; an upstream update mutates
   what you already knew. The single mechanism that makes all three safe *by
   construction* is the **Draft/Review gate** (§3–§4) — the spine of this document.

**The write-path already exists** (`VaultSource.writeFile`, proven by the story
bank at `story_repository.dart:31`). The `draft` status and the gate — which this
doc specifies — are now **BUILT and shipped**: the `status: draft` frontmatter, the
FSRS + readiness/coverage exclusion (ADR-0003), and the full-screen `/draft-review`
gate (`lib/features/drafts/`) all exist. `[Stage-1 P0-2; see roadmap.md]`

---

## 1. The content model — folders, decks, cards, and what "counts"

```
folder (VaultSource)  ── the ONE substrate; source of truth; DB is a derived cache
  └── files (.md)     ── parsed by card_parser.dart into Cards
        └── a "deck"  ── a user-facing GROUPING over files (a deckId namespace),
                          NOT a store: import-many / generate / create / author
              └── card ── has a lifecycle STATUS (§3): draft → active
                            (distinct from `confidence`, which is trust-at-creation)
```

- **Folder** = the substrate. Exactly one contract: a place Onyx can read and
  write `.md`. Sync, provider, and location are decoupled ("a synced folder is
  just a folder"; owned in `settings-ux.md` §SOURCE + `registry-and-sync.md`).
- **Deck** = a grouping, addressed by a `deckId` namespace so a pulled card can
  never collide with a local one — the join key becomes
  **`(deckId, cardId, sectionSlug)`**, which is *also* the unit of
  pull/update/attribution/license/access. `[Stage-1 P0-5; registry-and-sync.md owns it]`
- **Card** = a parsed file. It gains **one new lifecycle field, `status`**
  (§3) — orthogonal to the existing `confidence` enum (`high/medium/low`, set at
  creation from verification outcome; `card-schema.md`). *`confidence` says "how
  much to trust this card's content"; `status` says "does this card count yet."*
  Do not conflate them; a `draft` card can be `high`-confidence and still not count.

**"Counts" has one precise meaning, enforced in two places:** a card **counts**
iff `status == active`. An `active` card is (1) scheduled by FSRS
(`buildLearnQueue` / `buildReviewQueue`) and (2) included in every readiness
denominator. A `draft` card is excluded from *both*. This is the whole ballgame
(§3). `[principle 5 honest-readiness; principle 4 spacing-is-FSRS's-job]`

---

## 2. The three co-equal content on-ramps

None is the hero. All three land content in a folder, as `.md`, and all three
funnel into the **same Draft/Review gate** (§3–§4). Entry points are shared:
the **`+` in Browse altitude-0** (the library — the single durable entry to
acquisition), the **Home 0-goals empty state**, and the **`/welcome`
intent-gate**. There is **no 5th tab**; acquisition is not a destination.
`[Stage-1 §5, P1-7; ux-vision §2 4-tab IA]`

The entry chooser is a `showOnyxSheet` with three tonal, co-equal choices
(ordered by audience size, *not* priority): **Import a shared deck** ·
**Generate from my material** · **From my folder** (+ light manual create/edit).

### 2.1 Import / pull a shared deck  `[v1]`

The lightest on-ramp and the one that requires *zero* authoring or AI — the
primary path for P3 (hobbyist) and P1 (class code). Discovery lives in **Browse
altitude-0**; preview + import is a `DeckDetailSheet` (SheetHeader); import writes
`.md` via `writeFile` under the chosen deck's namespace.

- **The mechanics of pull/registry/access/class-code live in
  `docs/registry-and-sync.md`** — this doc owns only what happens to the *content*
  once it lands: **it lands as `draft`** (§3) and is promoted by the gate (§4).
- **No engagement metrics** at the content layer either — no "N imported,"
  ratings, or "trending." Card-count is a permitted size fact.
  `[product-direction §8]`
- v1 scope note: BYO-key is **not** required to import — import is fully offline
  once a deck is reachable; a *restricted* class deck needs the credential path in
  `registry-and-sync.md`, but never an account for pull-only. `[Stage-1 §10.3]`

### 2.2 AI-generate from my material  `[v1 = BYO-key; managed = seamed-deferred]`

Turn raw material into a starter deck — the on-ramp most valuable to P2
(deadline-driven student with messy PDFs/notes). **This is an on-ramp, not a
studio:** you paste or point at material, Onyx proposes cards, and *you* earn them
through the gate — Onyx never dumps a wall of accepted facts.

- **Inputs, phased.** **Ship Paste + Topic first `[v1]`**; **PDF/photo ingest is
  deferred** (heavier metering + managed-tier territory; `[defer]`,
  `registry-and-sync.md` §managed). The input surface is a `showOnyxSheet`, not a
  full-screen editor.
- **AI is hybrid but seamed. BYO-Anthropic-key is real in v1; a managed "Onyx AI"
  tier is an honest "coming soon" / disabled row until a server exists** — never a
  v1 dependency. The user-facing name is **"AI," never "Claude."** The just-in-time
  3-way choice (`Onyx AI (coming soon)` · `Use my key` · `Not now`) fires at
  **first AI use**, never at onboarding, through the one shared
  `showApiKeySheet`/tier chooser (`AiProvider { off, managed, byoKey }`).
  `[product-direction §6; settled #2; settings-ux §AI]`
- **Conservative default card counts.** Generation defaults to a *small* count
  (target ~8–12 cards per run, never "generate 100"), with a modest user cap. A
  large default would (a) manufacture a promotion backlog that fights bounded
  sessions, and (b) tempt bulk-acceptance — the exact anti-pattern the gate exists
  to prevent. Fewer, better, self-tested beats a mountain of unvetted drafts.
  `[principle 2 bounded sessions; §5 generation-effect law]`
- **Everything generated enters as `draft`** (§3) and is promoted one card at a
  time via self-test (§4). Generation is the *first retrieval rep*, not a delivery
  of finished knowledge.
- **Source-linkback** is captured per draft (which paste/topic/section it came
  from) so a promoted card can point back at its origin — reserved as a field now
  (`card-schema.md` provenance seam), surfaced lightly. `[Stage-1 §6]`

### 2.3 Point-at / create a folder + LIGHT manual create/edit  `[v1]`

The only on-ramp that names "folder" out loud — the power path (P4), plus the
minimal manual capability (P4/P5, story S11).

- **Point at an existing folder.** Choose/open a folder; Onyx indexes it; existing
  cards are treated as **already-yours → `active`** (they are not someone else's
  claim and have your own history; the gate is for *inflows you have not yet
  retrieved from*, not for re-indexing your own vault). *(Blocked on the on-device
  `VaultSource`, Phase 0; `settings-ux.md` §SOURCE, Stage-1 P0-4.)*
- **Create a folder.** Onyx can scaffold a folder under the blessed container +
  seed a **subject-neutral** sample deck for a user with no notes — *never* a SWE
  sample (that would re-privilege SWE). `[Stage-1 §10.7; principle 10]`
- **Light manual create-a-deck / edit-a-card `[v1]`.** Create an empty deck; add a
  card by hand (term + a reveal body); edit an existing card's text. That is the
  *ceiling*. **Explicitly NOT built:** a WYSIWYG studio, a card-type/template
  designer, bulk editors, a rich media composer, layout tools. A hand-created card
  is authored *by you* and is `active` on save (you wrote it — there is nothing to
  self-test-promote *from*; **hand-authoring *is* the generative act**, so the §4.2
  honest-count corollary — "`active` means engaged at least once" — still holds); a
  *hand-edit of a draft* stays a draft (§4).
  `[principle 1; settled #1; Stage-1 P2-2/P2-3]`

> **Design test for every on-ramp surface** (from `personas-and-stories.md` §4):
> name the persona + JTBD it serves; confirm it is an *on-ramp*, kept lightweight
> and co-equal; confirm it is **`focusedGoal`-invariant** (it may *offer* "add to
> current goal," must never *require* a focus — protecting single-goal
> degradation); confirm it degrades honestly with no AI / no account / offline.

---

## 3. THE DRAFT/REVIEW GATE — the shared primitive

**This is the highest-leverage primitive in the whole rework.** One card-status
seam, shared by all three inflows, makes every on-ramp obey honest-readiness +
"spacing is FSRS's job" *by construction*. `[Stage-1 P0-2, unanimous across critiques]`

### 3.1 The status field

Add a lifecycle `status` to `Card` / the schema:

| `status` | Meaning | FSRS? | In readiness denominator? | Visible where |
|---|---|---|---|---|
| **`draft`** *(a.k.a. unreviewed)* | Entered via an inflow, not yet promoted by *you* | **NO** | **NO** | Browse, marked "not counted" |
| **`active`** | Promoted through the gate (or authored/indexed by you) | **YES** | **YES** | everywhere, normally |

- **Excluded from FSRS.** `buildLearnQueue` and `buildReviewQueue` filter
  `status == active`. A draft is **never** scheduled, never appears in a daily
  session, never accrues review state. `[principle 4]`
- **Excluded from every readiness denominator.** Readiness, coverage, weakest-link,
  and the completion ring all compute over `active` only. **A pile of drafts can
  never move — up or down — any honest number.** This is what neutralizes silent
  readiness inflation from a big import or a big generation run. `[principle 5]`
- **`draft` is orthogonal to `confidence`.** `confidence` (existing) grades content
  trust at creation; `status` grades lifecycle. Both can be shown on a draft.

### 3.2 The three inflows that produce drafts

The gate's power is that it is **one mechanism for three problems**:

1. **AI-generated** cards → `draft` (hallucination risk: you vet each before it
   counts).
2. **Imported / pulled** decks → `draft` (someone else's claim + the
   *scheduling-never-travels* law, §6: their mastery is not yours).
3. **Upstream deck-updates** (a teacher/maintainer pushes a correction) → changed
   cards **re-enter as `draft`**, quietly, never auto-applied into FSRS. This
   honors "nothing mutates silently" and is the same gate as (1)/(2), so S6 (P1/P5)
   costs no new machinery. `[Stage-1 P2-4; settled #4]`

*(Not an inflow: re-indexing your **own** existing folder, or a card **you** author
by hand — those are already yours and land `active`. §2.3.)*

### 3.3 Drafts are visibly "not counted" in Browse

Non-inclusion must be *legible*, not silent — honesty cuts both ways. In Browse a
draft renders a **`StatusPill(muted, "Draft · not counted")`** (color + shape +
label + Semantics, per the never-color-only rule), and a deck with drafts shows a
quiet count (`"7 to review before they count ›"`) that opens the draft-review
session (§4). No badge dot alone; no red "error" tone — a draft is a normal,
expected, honest state (`muted`), not a problem. `[design-system §4.1, §4.9;
principle honest-null]`

### 3.4 Upstream-update change policy (the hard corner)

When an upstream update lands (§3.2 case 3), *what* re-enters as a draft is
graded — genuinely hard, flagged for a heuristic-vs-flag-vs-choice decision, with
the settled default: **a text tweak keeps the schedule; a section whose *meaning*
changed becomes a new `sectionSlug` and re-enters learning; a removed-upstream card
becomes a tombstone (never a silent delete of history).** `[Stage-1 §10.9]` The
full propagation wire lives in `registry-and-sync.md`; this doc fixes only that
the *result* flows through the same `draft` gate.

---

## 4. SELF-TEST-THEN-PROMOTE — the promotion default

Promotion is **generative, not a rubber-stamp.** The default path is
**self-test-then-promote**: each draft runs once through the *existing recall→reveal
gate*, and **the first pass IS a retrieval rep.** `[settled #4; Stage-1 §10.6]`

### 4.1 The per-draft loop

```
For each draft in the stack (bounded, e.g. "3 / 12"):
  1. see the CUE (term / prompt) — the recall side, answer hidden
  2. ATTEMPT recall in your head (the generative rep; this is the point)
  3. REVEAL the card's body (the AI's / author's proposed answer)
  4. decide, per card:
        KEEP     → status: draft → active   (now counts; enters FSRS)
        EDIT     → fix the text; stays draft; re-test or keep
        DISCARD  → remove the draft          (nothing enters FSRS)
```

- **No bulk "Accept all."** There is no button that promotes many drafts without a
  per-card decision. This is a hard rule, not a default — bulk-accept is the
  passive-acceptance anti-pattern. **Do NOT copy `story_capture_screen.dart`'s
  one-tap "Save to bank"** (the passive-acceptance pattern already in the
  codebase). `[Stage-1 §5; §4.2 below]`
- **Reuses the real gate.** This is the *same* recall→reveal→decide interaction as
  the daily loop (`quiz_screen` hides until revealed) — no parallel review UI. The
  only difference is the terminal action (keep/edit/discard vs Again/Hard/Good/Easy).
- **Escape hatch:** plain keep/edit/discard *without* attempting recall stays
  available (autonomy — the user may already know a card is junk on sight). But the
  *default framing* leads with the cue, because that is where the learning is.
  `[principle 7 autonomy; §10.6 "plain edit/keep as the escape hatch"]`
- **Bounded + finishable.** The stack is a bounded session with a counter and an
  honest end (§5). A 200-card import does not become a 200-card wall in one sitting;
  the session is capped and resumable, and the conservative generation default (§2.2)
  keeps runs small in the first place. `[principle 2]`

### 4.2 The generation-effect law (why passive acceptance is not studying)

**"Automation reduces friction, not cognition."** The generation effect
(learning-science canon; `docs/learning-science.md`) says memory is built by
*producing* an answer, not by *reading* one. Therefore:

- **Passively accepting AI-generated cards is not studying.** A one-tap "Accept
  all" would let a user feel productive while doing zero retrieval — manufacturing
  an inflated `active` count with no learning behind it, and re-importing the exact
  loss-aversion/vanity dishonesty the motivation stance forbids. `[principle 5;
  product-direction §9]`
- The gate deliberately **spends the friction where it buys cognition** (one
  retrieval attempt per card) and **removes it where it does not** (you didn't have
  to hand-type the card). That is the whole design thesis of AI-in-Onyx: it makes
  *getting* material frictionless without making *learning* it passive.
- **Corollary — the count is honest.** Because a card only becomes `active` after a
  human retrieval pass, the `active` count *means something*: "cards I have engaged
  at least once," not "cards a model emitted." Every downstream honest number
  inherits that integrity.

---

## 5. IA placement (where all of this lives)

The 4-tab IA holds; no 5th tab. `[ux-vision §2; Stage-1 §5]`

- **Acquisition entry** = the **`+` in Browse altitude-0** (the library — the single
  durable entry point where a pulled/generated/created deck lands), also surfaced in
  the **Home 0-goals empty state** and the **`/welcome` intent-gate**. Never a tab,
  never a persistent Home button. `[Stage-1 §5 Browse-as-library]`
- **The input step** (paste/topic sheet · deck-detail preview · create-a-deck ·
  edit-a-card) = **`showOnyxSheet` / SheetHeader sheets** — pickers and light
  editors are sheets, per SheetHeader-everywhere.
- **The draft-review SESSION is the one full-screen carve-out from
  SheetHeader-everywhere.** It is a bounded, finishable, focused *session* — exactly
  like `/learn` and `/report` in the router today — not a config drill-down. Route:
  **`/draft-review`**, a full-screen route outside the shell, **reusing
  `SessionScaffold`** (the bounded **linear** progress bar — never a ring — with the
  `"3 / 12"` counter). A 12-card review stack in a bottom sheet fights bounded-session
  ergonomics; ratify the exception. `[Stage-1 §5, §10.5; design-system §4.5;
  router.dart /learn + /report precedent]`
- **Distribution surfaces** (publish this deck; manage shared decks/access) are a
  per-deck `PublishSheet` + a **Settings → SHARING** group — owned by
  `registry-and-sync.md`, listed here only so the boundary is clear. `[settings-ux
  §SHARING]`

| Surface | Home | Why |
|---|---|---|
| Acquisition entry (import / generate / create) | `+` in Browse alt-0 + empty-states + `/welcome` | on-ramp, not a destination |
| Paste/topic input · deck preview · create/edit card | `showOnyxSheet` (SheetHeader) | pickers + light editors are sheets |
| **Draft-review session** | **full-screen `/draft-review`** (carve-out) | bounded finishable session; matches `/learn`, `/report` |
| Draft "not counted" marker | `StatusPill(muted)` in Browse | non-inclusion must be visible, honest, calm |

---

## 6. The imported-deck invariant: scheduling never travels

**A pulled deck brings *content*, never *schedule*.** No matter what an upstream
deck claims — "90% mastered," rich review history, low due counts — on import
**MY readiness for it is fresh**, and every card enters `draft` (§3), so it
contributes nothing to any honest number until *I* have retrieved from it. `[the
Anki law; Stage-1 §5, S8; product-direction §8]`

- **Enforced by namespacing:** the join key is **`(deckId, cardId, sectionSlug)`**,
  so a pulled card's id can never inherit a local card's FSRS row (slug-id and UUID
  collisions across decks are otherwise a silent-corruption blocker). `[Stage-1
  P0-5; registry-and-sync.md owns the schema]`
- **Two invariants, one guarantee:** *(a)* scheduling-never-travels (this section)
  strips foreign schedule at the boundary; *(b)* the draft gate (§3) makes even the
  *content* not count until self-tested. Together they mean **no producer can inflate
  a consumer's readiness** — the core protection of P1–P4 from P5. `[personas §3.3]`
- **This is a must-enforce invariant with a CI test**, not a nicety: import a deck
  with fabricated schedule/history → assert local readiness == fresh and all cards
  `draft`.

---

## 7. Honest AI-unavailable / offline / quota states

Every AI entry point must degrade to an **honest state that says the core still
works** — never a nag, never a fabricated affordance for a capability that isn't
reachable. `[Stage-1 S10, P1-8; product-direction §6; principle honest-info]`

- **One state object, three cases** — `AiUnavailableState`, rendered as an
  `EmptyState` variant (muted icon, one line, one action; never a scold;
  `design-system §4.9`):
  - **`off` (no key, no managed tier)** → *"Add an AI key to generate cards — or
    import a ready-made deck. Everything else works without AI."* The generate
    on-ramp is disabled with a reason; **import + folder + manual on-ramps stay fully
    functional** (they never needed AI).
  - **`offline`** → a **`muted`** state ("offline"), *never* a `bad`/error tone —
    offline is not an error in a local-first app. Import-from-network and generate
    wait; the whole review loop keeps running. `[design-system §4.9; ux-vision]`
  - **`quota-exhausted`** (only when the managed tier lands) → an honest "you're at
    your allowance" with the upgrade prompt **only at true exhaustion**. Usage
    renders as a **`CoverageBar`, never a ring or a countdown** — a depleting quota
    must never become a loss-aversion timer. `[principle 4; design-system §4.3, §5]`
- **Never render "Onyx AI" as *available* until a backend capability is actually
  reachable** — the same rule as the account UI; an empty affordance for a
  nonexistent capability is the dark pattern we reject. Until the managed server
  ships, it is an honest disabled "coming soon" row. `[settled #2; personas §3.4]`
- **The key-less core is byte-identical.** Turning AI off leaves import + folder +
  manual create/edit + the entire review loop behaving exactly as a build that never
  had AI. `[product-direction §3 degradation rule]`

---

## 8. Build state — what is v1 vs deferred

`[v1]` = ships in the offline/BYO-key foundation · `[seamed-deferred]` = seam
reserved now, built when the server/audience/legal work lands · `[defer-hard]` =
explicit gate.

**v1 (the foundation):**
- The **`draft`/`active` status** on `Card`/schema + FSRS exclusion + readiness
  exclusion + the Browse "not counted" marker. **BUILT** — the exclusion lives in
  ADR-0003; drafts are excluded from FSRS + every readiness/coverage denominator.
  `[Stage-1 P0-2, Phase 0; see roadmap.md]`
- **Import / pull** a shared deck as an on-ramp (content half; wire in
  `registry-and-sync.md` — restricted-first). Imported cards are **draft-stamped on
  landing** (`import_deck.dart`) — **BUILT**.
- **AI-generate on BYO-key**, **Paste + Topic** inputs, conservative default counts.
  Generated cards are **draft-stamped** (`generated_cards.dart`) — **BUILT**.
- **Point-at / create a folder + light manual create-a-deck / edit-a-card.**
- **The `/draft-review` full-screen session** + **self-test-then-promote** (no bulk
  accept). **BUILT** (`lib/features/drafts/`); promotion **removes the status line**
  (`card_promotion.dart`). `[see roadmap.md]`
- The **scheduling-never-travels** invariant (§6) + its CI test.
- Honest **`AiUnavailableState`** (`off` / `offline`) + the airplane-mode full-loop
  CI invariant.

**Seamed-deferred:**
- **Managed "Onyx AI"** generation (server proxy + per-account quota →
  `quota-exhausted` state + `CoverageBar` usage). Seam ready from Phase 0; honest
  "coming soon" until then. `[settled #2; registry-and-sync.md §managed]`
- **PDF / photo ingest** (heavier metering; managed-tier territory). Paste + Topic
  ship first.
- **Upstream-update propagation** into the draft gate (the *content* rule is fixed
  here §3.2/§3.4; the push/pull wire is `registry-and-sync.md`).

**Defer-hard:**
- Public-registry pull as a content source (needs moderation/takedown; restricted →
  public order). `[product-direction §8]`
- Anything resembling a **manual authoring studio** — not deferred, *out of scope by
  design*. `[settled #1]`

---

*Grounded in `docs/product-direction.md` (§4 substrate, §5 on-ramps + gate, §6 AI,
§9 motivation), `docs/personas-and-stories.md` (§0 review-focus, S2/S6/S8/S11, §3
collisions), `docs/ux-rework-stage1.md` (§4 P0-2/P0-5/P1-7, §5 IA, §6 flows, §10.5/6/9,
Phase 0/2), and the locked `docs/design-system.md` (StatusPill/CoverageBar/EmptyState/
SessionScaffold/showOnyxSheet) + `docs/ux-vision.md` (§2 4-tab IA, §4 loop, the 10
principles) + `docs/settings-ux.md` (AI/SHARING/SOURCE). Where Stage-1 and the
2026-09-17 decisions differ (AI-gen-as-default → co-equal; rubber-stamp → self-test-
then-promote), the decisions win and are marked inline. Distribution mechanics
(registry/pull/push/access/class-code/deck-identity schema) are owned by
`docs/registry-and-sync.md`; this doc owns the content model + the Draft/Review gate.*
