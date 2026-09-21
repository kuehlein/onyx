# Onyx — Settings & Configuration UX

*Companion to `docs/ux-vision.md` (refines §3.7; touches §3.8, §1) and consistent with `docs/design-system.md` (§4.9). Serves the canonical `docs/product-direction.md` (§6 AI, §7 accounts/sync) and defers the optional-cloud-layer mechanics to `docs/registry-and-sync.md` (accounts/sync/registry/managed-AI) and `docs/content-creation.md` (the AI tier chooser). This spec is decisive: where the four design drafts disagreed, the choice is made here and the losing option is named so it doesn't get "helpfully" re-added.*

> **Build-state note (2026-09-20):** most of this spec is now **built** — the shared folder-source sheet + persisted `VaultRef` (ADR-0002), the Source / Card-parsing / AI-tier / SHARING rows, `showApiKeySheet`, `DestructiveRow`, and the neutral-vault scaffolder. **Genuinely remaining:** the group-header renames + demoting Pace/Algorithms/Gym to per-goal drill-downs (task #85), and iOS/Android on-device folder-picking (#82). See [roadmap.md](roadmap.md).

---

## 1. Placement — Settings stays the 4th bottom-tab

**Decision: Settings remains a co-equal 4th tab (Home · Browse · Insights · Settings) in the IndexedStack frame. Reject gear-icon, drawer, and profile-screen relocations.**

The generic settings-UX research ("never burn a bottom-tab on Settings") is correct *for its assumed app shape* — a mostly-casual app whose settings are a handful of appearance/notification toggles. It does not apply to Onyx, for four codebase-grounded reasons:

1. **Settings is the local-first app's config + data-stewardship home, not a toggle drawer.** Source (the content contract), the AI provider/key (the AI contract), backup/restore (the data-safety contract), and goal management (the config that defines every deck) are all app-wide, rarely-changed, and genuinely destination-worthy. Android's own rule (15+ settings → subscreens) and Toptal's "4–5 categories" put Onyx squarely at destination scale.
2. **Every alternative breaks a harder locked constraint.**
   - *App-bar gear:* Settings is **altitude-agnostic** (§2) — it renders identically whether `focusedGoal` is null or a goal id. A gear on one screen's AppBar re-couples it to an altitude and re-introduces the "which screen owns global config" ambiguity the `focusedGoalProvider` single-spine was built to kill.
   - *Drawer:* NN/G's own finding is that hidden menus cut engagement ("out of sight is out of mind"). A drawer is strictly worse than a visible co-equal tab, and there's no drawer anywhere else in the app to hang it on.
   - *Profile screen:* requires a standing identity anchor. In the solo core there is **no account by principle**, and even when the optional cloud layer supplies one, account/sign-in is a **capability-gated ACCOUNT group inside Settings** (§2), never a top-level profile destination — and rendered *only when a backend capability is reachable* (a persistent "Sign in" surface for a server that doesn't exist is the dark pattern the docs forbid; `registry-and-sync.md` §1.1).
3. **The tab test passes.** §2 already frames the four tabs as "co-equal, cross-cutting, revisited across sessions." A local-first user revisits Settings *more* than a cloud user: checking indexing status after editing notes, managing goals, verifying backups.
4. **No claimant for the freed slot.** §2 explicitly rejects a Goals/Aim 5th tab — the only candidate. Freeing the slot buys nothing; demoting Settings is architectural churn against a locked decision for zero benefit.

The research heuristic guards against *clutter and displacement*. Onyx displaces nothing and avoids clutter by keeping the study-behavior levers state-only and pushing prose one layer down (§2). **The tab stays; the discipline lives inside it.**

---

## 2. Final Settings IA — 6 groups + collapsed Developer

**Group set (this is the binding §3.7 refinement):**

```
┌─ Settings ─────────────────────────────── (tab, AppBar title only, no gear)
│
│ SOURCE                                          ← was "VAULT"
│   📁 Folder             Onyx · ~/Documents/Onyx        ›
│   🗂  Cards             428 cards                        ↻
│   🧩 Card parsing        Headings (H2) · .md             ›   ← NEW (read-only explainer)
│
│ STUDY LOAD
│   ⏱  Daily study time    2h 30m target                  [− +]
│   📚 New cards per day    8 · moderate                   [− +]
│   ❤  Weekly load check-in                                [ ● ]
│   ⓘ  How much should I study?                            ›
│
│ STUDY GOALS
│   🎯 Goals               3 active                         ›
│
│ DATA & BACKUP                                   ← was "DATA & PROGRESS"
│   ⤴  Back up now         Last backup 2h ago              ›
│   ⟲  Restore from backup                                 ›   (DestructiveRow)
│
│ AI                                               ← was "CLAUDE (AI)"
│   🤖 AI provider          Off                             ›   ← 3-state tier chooser
│
│ SYNC                                             (optional; off by default)
│   ☁  Sync                Off                              ›
│
│ SHARING                                          (only if sharing is reachable)
│   ↗  Shared decks         Manage my shared decks          ›
│
│ ACCOUNT                                          (only if a backend is reachable)
│   👤 Account             Not signed in                    ›
│
│ ABOUT
│   ℹ  About Onyx          Version 1.4.0                   ›
│
│ ▸ Developer   (dev builds only, collapsed — the SOLE collapsed group)
└──────────────────────────────────────────────────────────
```

**Group order** (by importance/frequency, per Android): SOURCE → STUDY LOAD → STUDY GOALS → DATA & BACKUP → AI → SYNC → SHARING → ACCOUNT → ABOUT → ▸ Developer. Source first (the app is nothing without content); Developer last and collapsed. **SYNC / SHARING / ACCOUNT are the optional cloud-layer groups** — capability-gated, rendered **only when a backend capability is reachable** (absent, *not* a disabled row); `sync ≠ server ≠ accounts` (owned in `registry-and-sync.md` §§0–2, §4). In the account-free / offline solo core (the common case) only AI is present of the cloud groups, so **3–5 above the fold** (§8) is unchanged: SOURCE(3) + top of STUDY LOAD fills the first screen; everything heavier is a drill-down.

**Decisions made against the drafts:**
- **No "Advanced" group.** PART 1 proposed an always-present Advanced group nesting Developer; PART 3 correctly rebutted it as dead UI (a header over one stub) that violates §8 calm-restraint. One stub does not earn a group. Onyx satisfies the research's "advanced-one-layer-down" principle **via a sheet, not a group** — record this in §3.7 so a future reader doesn't re-add it.
- **STUDY LOAD stays in Settings** (reject PART 1's "delete it, inline the levers" overrule). PART 1 misread the governing rule: the doc author wrote *"tune today → where you study; configured once → here"* and then deliberately kept these two levers here as the config-once-ish ones. Worse, PART 1 wanted to cram Daily-time / New-per-day into Home's `[Adjust mix]` — but §4.6 line 193 makes `AdjustMixSheet` **"the sole budget editor,"** and it edits per-goal *share-of-time* MixSliders, not absolute minutes or new/day. Merging them collides with §4.6 and violates §7's "no duplicate editors."
- **Two group renames** (VAULT→SOURCE, DATA & PROGRESS→DATA & BACKUP), written into §3.7 as one decision (the drafts each renamed differently — SOURCE from PART 4 wins as the tightest topic-noun; "Progress" collides with Insights, which owns progress *display*).
- **CLAUDE (AI) → AI, as a 3-state tier chooser.** The group is renamed **AI** (never "Claude" — a vendor name re-privileges AI the way "vault" leaked Obsidian) and collapses from an "API key + Test connection" pair to **one AI-provider row** driving the `AiProvider { off, managed, byoKey }` chooser (`Off` · `Onyx AI (coming soon)` · `My key`), JIT at first AI use. `Onyx AI` is disabled "coming soon" until the managed server is reachable. `[content-creation.md §2.2; registry-and-sync.md §5]`
- **Three optional cloud-layer groups added — SYNC, SHARING, ACCOUNT — all capability-gated.** They render **only when a backend capability is reachable** (absent, *not* a disabled row — a disabled row for a nonexistent capability is the very dark pattern §1 rejects). `sync ≠ server ≠ accounts`: SYNC is optional/off-by-default and decoupled from SOURCE; SHARING is the config-once home for a producer's shared decks (per-deck publish lives on the deck); ACCOUNT is one account with three capability flags. In the solo core all three are simply absent, so the account-free/offline experience is unchanged. `[registry-and-sync.md §§1–2, §4; content-creation.md §5]`

**Governing rule, sharpened (keep in §3.7):** *"Anything you tune to change today lives where you study; anything configured once lives here. Config that changes what becomes a card lives here (rare, app-wide, dangerous-if-wrong); config that changes what you study today lives where you study."*

### Per-row copy and behavior

Every row that opens something opens a `showOnyxSheet`/`showApiKeySheet` **SheetHeader** sheet — never a route. Nested detail = in-place `AnimatedSize`, never sheet-in-a-sheet (§4.9). Honest/muted state uses `_ink55` (5.7:1), never `0.38` alpha. 48×48 targets; text-scaling uncapped (rows reflow).

**SOURCE**

| Row | State | Copy |
|---|---|---|
| Folder | configured | `{vaultName} · {shortPath}` (home-relative, middle-ellipsis — not raw `rootLabel`) |
| Folder | unconfigured (dev-bypass only) | `No folder connected` |
| Cards | data | `{n} cards` + `· {k} need id` / `· {k} malformed` (error tint on the problem fragment only) |
| Cards | loading / error | `Indexing…` / `Couldn't read the folder` (raw `$e` behind a "Details" tap) |
| Card parsing | default | `Headings (H2) · .md` (derived from live `SubjectConfig`, never a hardcoded string) |

- **Folder** → opens the shared `showFolderSourceSheet` (§3).
- **Cards** trailing `↻` invalidates `vaultIndexProvider`.
- **Card parsing** → opens the read-only `HowCardsAreReadSheet` explainer (§4). This is a real, tappable, complete row (opens honest info) — *not* a disabled control.

**STUDY LOAD** — rows show *state*, not paragraphs (Android: "show status, don't describe"; ~150-char cap). The ramp/taper/retention prose relocates to the ⓘ sheet.

| Row | Copy | Control |
|---|---|---|
| Daily study time | `{prettyMinutes} target` | Stepper min 30 / max 240 / step 15 (default 150) |
| New cards per day | `{limit} · {loadLabel}` | Stepper min 2 / max 50 / step 1 (default 8) |
| Weekly load check-in | `Once a week, the coach asks how the load feels.` | SwitchListTile (default off) |
| How much should I study? | `What the levers mean, and a start-slow plan.` | ⓘ → `showStudyLoadHelp` |

Pref key `new_section_limit` stays internal; the **visible** word is "cards," not "sections" (see §6 copy sweep).

**STUDY GOALS**

- **Goals** — `{n} active` → `showGoalsManager` (SheetHeader). Per-goal template levers (Algorithms min/max, Gym mode + rest timer, retention target) live **inside** the goal editor, rendered only when the goal's template declares the track. Interim honest state: under the default goal, labeled **"Algorithms track"** — not fake per-goal independence. Goal target editing routes to §5's `GoalEditorSheet`, never the legacy `showTargetSheet`/`target_sheet.dart`. Interviews live inside that editor.

**DATA & BACKUP**

- **Back up now** — `Last backup {relativeTime}` (or `Not backed up yet`); disabled with `Connect a folder first` when `source == null`. Success: transient snackbar `Backed up.` (drop "vault snapshot" jargon).
- **Restore from backup** — a real `DestructiveRow` (§4.9: error color + outlined shape + text label + confirm dialog — all four; today it's only an error-tinted icon on a plain `ListTile`, which is color-only and non-compliant). Subtitle `Replaces current progress with your last backup.` Confirm body: `This replaces your current progress with your last backup. Reviews recorded since then will be lost.` Results: `No backup found.` / `Restored {n} cards from your backup.`

**AI** — one row, a **3-state tier chooser** (not a bare "API key" row). The user-facing name is always **"AI," never "Claude"** (a vendor name re-privileges AI the way "vault" leaked Obsidian; `registry-and-sync.md` §5, `product-direction.md` §6). Mechanism nouns (Anthropic / Keychain / `ANTHROPIC_API_KEY`) demote off the primary line.

The single **AI provider** row's subtitle is the live `AiProvider { off, managed, byoKey }` state:

| `AiProvider` | Primary subtitle |
|---|---|
| `off` | `Off` |
| `byoKey` (saved) | `My key · saved on this device` (secondary/sheet: "Kept in the Keychain, this device only") |
| `byoKey` (from env, desktop dev) | `My key · using ANTHROPIC_API_KEY` (env-only, non-editable) |
| `managed` | `Onyx AI` (only reachable once the managed server exists) |
| Checking / error | `Checking…` / `Couldn't read stored key` |

- **AI provider** → the shared **`showApiKeySheet`** (the tier chooser; extracted from Settings, shared with onboarding's first-AI-flow per §3.8; today it's a local `_editApiKey` dialog and must be extracted). It presents the same **just-in-time 3-way choice** that fires at *first AI use* (`content-creation.md` §2.2) — three options, one Filled:
  - **`Off`** — no AI; the key-less core is byte-identical.
  - **`Onyx AI (coming soon)`** — the managed/hosted tier, rendered as an **honest disabled "coming soon"** row **until the proxy server is reachable** (the same capability-reachable guard as ACCOUNT §below and SYNC — never show "Onyx AI" as *available* until the backend is actually reachable; `registry-and-sync.md` §5.1/§1.1).
  - **`My key`** — BYO-Anthropic-key (v1); store `ThisDeviceOnly`. Trailing delete (`_ink55`) only when a user-saved (non-env) key exists. Includes the honest connection check (`Send a tiny request to check the key.` → sends `Reply with exactly: pong`; `Connected.` / `Couldn't connect.`, keeping the auth-vs-network *reason* behind a tap).
- **Usage-as-`CoverageBar` (when managed lands).** Once the `managed` tier is reachable, per-account quota surfaces here as a **`CoverageBar`** (`design-system §4.3/§5`) — **never a ring, never a countdown, never a loss-aversion timer**; quiet below exhaustion (a `▲ near limit` micro-label near the top), with the upgrade/BYO-key prompt **only at true exhaustion** (`registry-and-sync.md` §5.2). Not built now — the row is the `AiProvider` state until then.

**SYNC** (optional cloud group — rendered only when reachable) — sync is **optional, off by default, and decoupled from SOURCE** ("a synced folder is just a folder"; §3, `registry-and-sync.md` §2). `sync ≠ server ≠ accounts`: folder-sync ships with *zero server* over a folder the user already syncs, and account-sync (if ever built) carries **progress + goals only, never content**.

| `SyncState` | Primary subtitle |
|---|---|
| `Off` | `Off` (default) |
| `On` | `On · last synced {relativeTime}` |
| Conflict merged | `On · resolved a sync conflict` (details behind a tap) |
| Offline | `Offline` — a **`muted` `StatusPill`**, *not* an error tone (offline and "a conflict was merged" are not failures in a local-first app) |
| Error | `Sync error` (only a true irreconcilable case) |

- **Sync** → `showSyncSheet`. Status via `StatusPill`; "Offline" is `muted`, never `bad`. The default is **silent correct merge** (per-`(deckId,cardId,sectionSlug)` last-review-wins + append-union review events + goals-in-payload, `registry-and-sync.md` §2.2) — no modal, no interrupt, no data-loss without a tombstone.

**SHARING** (optional cloud group — rendered only when `sharing` is reachable) — the **config-once home** for a producer's shared decks. Per-deck publish lives on the deck (the `PublishSheet` reached from a deck's detail, owned by `registry-and-sync.md` §4 / `content-creation.md` §5); this group is where you *manage* what you've already published, not where you publish.

- **Shared decks** — `Manage my shared decks` → a SheetHeader sheet listing your maintained decks with **who has access** per deck (the group/class binding is the permission unit — never per-student ACLs; `registry-and-sync.md` §4.1). No vanity metrics (no downloads/ratings/"N studying"); **card-count only** as a size fact (§4.6 of that doc).

**ACCOUNT** (optional cloud group — rendered only when a backend capability is reachable) — one account concept with three capability flags (`sync` / `managedAi` / `sharing`); the group shows exactly the capabilities this account actually has. **With no reachable backend the ACCOUNT group is absent, NOT a disabled row** — a disabled "Sign in" row for a server that doesn't exist is the original dark pattern (`registry-and-sync.md` §1.1; `product-direction.md` §7). Never a 5th tab, never a profile screen (no identity anchor exists in the solo core).

| Account state | Primary subtitle |
|---|---|
| Not signed in (but a backend is reachable) | `Not signed in` |
| Signed in | `{email} · signed in` |

- **Account** → the sign-in / account sheet (SheetHeader). Sign-out drops the *account binding*, not your data — progress remains in the folder snapshot and local DB (the DB is a derived cache; the folder is the source of truth), so sign-out is cheap and reversible (`registry-and-sync.md` §1.3).

**ABOUT** (new group)

- **About Onyx** — `Version {x.y.z}` → SheetHeader "About" sheet containing: version+build; a plain **Privacy** paragraph (*"Onyx is local-first. Your notes and progress stay in your folder on this device. AI features send only the text of a card to Anthropic when you use them; nothing else leaves your device."*); **Open-source licenses** (in-place `AnimatedSize`, not a sub-sheet); and a text action **Restore default settings** (resets the tunable levers only — daily time, new/day, parsing preset — with a confirm that makes clear it does *not* touch progress). Research-backed (restore-defaults + privacy-in-plain-terms).

**▸ Developer** (`isDevDataMode` only, collapsed `ExpansionTile`) — Reset local progress, Simulate study progress, Time travel; wiring unchanged. Reset-local-progress must also become a real `DestructiveRow`. Sweep "New sections per day pace" → "New cards per day pace."

### What lives inline-elsewhere instead (not in Settings)

- **Per-goal share-of-time / proportions / pause** → `AdjustMixSheet` (§4.6, the sole budget editor), reached from the hub `[Adjust mix]` and single-goal Home.
- **Pace planner** → Insights (`/insights?focus=pace`) — it's a forecast dashboard, not a setting.
- **Algorithms min/max + Gym mode toggle** → per-goal template drill-down inside `GoalEditorSheet`.
- **Gym rest-timer duration** → the review screen's in-context options (Apple's task-context rule — it's felt during a set), not an app-wide Settings row.

---

## 3. Directory-agnostic content source

**One shared sheet body powers two flows: `/welcome` (renders it as the pre-shell page — the sole hard gate, sole full page) and the Settings Source row (renders it as a real `showOnyxSheet`).** No third surface, no wizard. This persisted-path wiring is now **built** (`VaultRefController.choose` → `VaultRefStore`, resolving env → persisted `VaultRef` → null; ADR-0002) — it was the missing piece the `settings_screen.dart` doc-comment promised and `vault.dart` originally left env-only.

**Naming:** the user-facing noun is **"study folder" / "folder,"** never "vault" ("vault" is Obsidian's word; the mandate is Obsidian-compatible, never required). The code layer keeps `VaultSource`/`vaultSourceProvider`/`ONYX_VAULT_PATH` (renaming the model is large and load-bearing — snapshot keys, providers, docs). A one-line comment at each source class should note the deliberate copy/code divergence so no one re-introduces "vault" into the UI.

### The shared picker — `showFolderSourceSheet`

```
╭───────────────── (drag handle) ─────────────────╮
│ 📁  Study folder                            ✕    │  SheetHeader
├──────────────────────────────────────────────────┤
│  Onyx studies the markdown files in a folder on   │  _ink55, ≤150 chars
│  this device. Pick one you already have, or let   │
│  Onyx make one for you. Nothing leaves the folder.│
│                                                    │
│  [ Choose a folder ]                              │  ← ONE Filled (the primary case)
│                                                    │
│  [ Create a study folder ]                        │  ← Tonal (zero-folder escape hatch)
│                                                    │
│  What can I point it at?                        ›  │  text → in-place AnimatedSize
╰──────────────────────────────────────────────────╯
```

M3 emphasis ladder (§8 exactly-one-Filled): **Choose = Filled** (dominant real case — even a fresh Obsidian user has a folder), **Create = Tonal**, **explainer = text**. Two verbs cover every case (Choose/Open an existing folder, Create a fresh one); never enumerate cloud providers (a synced folder is just a folder); **sync is decoupled** — no sync UI here.

"What can I point it at?" expands in place (never a sheet-in-a-sheet):
```
│  • Any folder of markdown (.md) notes.
│  • An Obsidian vault works as-is — Onyx reads it and ignores its config files.
│  • No notes yet? “Create a study folder” and Onyx starts you with a small sample deck.
```
This is the *only* place Obsidian is named, and only as reassurance. It replaces the old "What's a vault?" gate sheet (§3.8) — folded here so the concept is explained where the choice is made.

**Drop PART 2's read-only `_meta/` / `onyx-state.json` / exclusion "Reading" sub-rows** from this sheet — those are exactly the dev-noun leaks §6 kills, and they belong (if anywhere) in deferred parser/metadata config, not on a first-run folder-picker surface.

### Interactions

- **Choose a folder** — iOS: security-scoped picker → persist a bookmark → `IosVaultSource`. Desktop: native directory picker → persist path → `DesktopVaultSource`. On pick: set `vaultSourceProvider`, invalidate `vaultIndexProvider`, pop returning the source. **No content-validation gate** — an empty folder lands on the calm no-cards empty state (§3.8), never a "no cards found" block.
- **Create a study folder** — scaffold into the platform's blessed container (iOS: app's iCloud-visible Documents subfolder, so the OS registers it and sidesteps Obsidian's "app doesn't recognize the folder" trap; desktop: `~/Documents/Onyx/`). No path prompt — creating means *we* choose the location. Seed a **small sample deck** (2–3 `.md` cards, heading-based, no frontmatter beyond the parser's needs) so first-run isn't the empty state.
- **Cancel** — dismissible ("Not now") **only in Settings** (source already set → returns null, no change). On `/welcome` the ✕ and barrier-dismiss are suppressed: the hard gate can only be left by choosing or creating.

### Flow 1 — `/welcome` (only hard gate, only full page)

Renders the same three-action body as a Scaffold (no SheetHeader/drag-handle/✕):
```
              ⬦  Onyx
   Study your own markdown notes, on this device.
   [ Choose a folder ]            ← Filled
   [ Create a study folder ]      ← Tonal
   Nothing leaves this folder.    ← local-first contract, _ink55
   What can I point it at?      ›  ← same AnimatedSize expander
```
Router (§9 Phase 1): `launch → needsVault? (vaultSourceProvider == null) → /welcome`. After choose/create: index ("Indexing…") → auto-create default `AllMembership` goal → land on single-goal Home.

**§3.8 copy edit required:** §3.8 currently says one Filled "Choose your vault folder." This spec keeps **one Filled** ("Choose a folder") and adds **Create a study folder** as **Tonal** — still one-Filled-per-surface — and drops "vault." Amend §3.8's welcome bullet accordingly.

### Flow 2 — Settings Source row (§2 SOURCE)

Add `trailing: chevron` + `onTap: showFolderSourceSheet` to the existing display-only Folder row. Re-picking a *different* folder swaps the source and re-indexes; local progress is keyed to the old folder, so gate the swap with a **plain confirm** (not a `DestructiveRow` — nothing is deleted):
> **Switch study folder?** — Your reviews and schedule stay with the current folder. Pointing at a different folder starts fresh there — your progress here isn't deleted.  `[ Cancel ] [ Switch ]`

**Build-blocker (verify before this copy ships):** switching folders changes where the snapshot lives (`snapshot.dart:29` hardcodes `_meta/onyx-state.json`). Confirm the swap doesn't strand or overwrite a snapshot — the reassurance "your progress here isn't deleted" **must be true**, or tighten the copy / gate the swap.

---

## 4. Configurable parsing / file types — future shape + ship-now stub

### Future shape (reserving scope, not designing the editor)

When built, **Card parsing** becomes a SheetHeader sheet editing a **parse profile** persisted into `SubjectConfig` / `onyx-subject.yaml` (`FlowSpec`/`SubjectConfig` is the natural home; `subject_config_yaml.dart` the serializer). At altitude: section markers (`Headings H2/H3` / `--- rule` / custom start-end markers → drives `card_parser.dart:25` `_h2` + `_splitBody`); accepted file types (a short read-only "Reads: …" list — **never** a per-file parser chooser; foreign formats go to a separate future Import flow); the card-ness gate + frontmatter field-map (the O2A capture-group→field power tier, gated hardest); the never-quizzed blocklist (`card_parser.dart:35-56`) as an editable set; wikilinks on/off; profile scope (per-subject default + app-wide fallback for config-less folders). De-scared exactly as the flashcard-app research prescribes: a preset picker with one default selected, Anki invariants adopted for free (empty-front = no card; Anki-compatible cloze `{{c1::…}}`), regex behind one "Custom rule (advanced)" `AnimatedSize` disclosure.

### Ship-now stub — read-only explainer (not a control)

**Decision: ship PART 3's read-only `HowCardsAreReadSheet`. Reject PART 4's live radio-list.** A radio group with one live radio and four disabled ones is a *control surface* that looks changeable-but-broken and spawns per-row "Soon" badge spam — the exact anti-pattern the research and PART 3 warn against. An enabled row opening honest read-only info reads as calm and complete.

The **Card parsing** row (SOURCE, §2) opens:
```
┌─────────────────────────────────────────────┐
│ ══   How cards are read                   ✕  │  SheetHeader
│─────────────────────────────────────────────│
│  Onyx turns your notes into cards using       │
│  these rules. They're the same for every      │  body, _ink primary
│  folder for now — per-folder rules are         │
│  coming.                                       │
│                                               │
│  NOW                                           │  _SectionHeader
│  ▦  Sections split on   Headings (H2)          │  read-only fact
│  ▦  Reads files          .md                   │  read-only fact
│  ▦  A note is a card when it has a  type:       │  read-only fact
│                                                │
│  LATER                                    Later │  _SectionHeader + ONE tag
│  ○  --- rule                            (dim)   │  inert, _ink55
│  ○  Headings (H3)                       (dim)   │  inert
│  ○  Custom start/end markers            (dim)   │  inert
│  ○  More file types (.txt, .org)        (dim)   │  inert
│  ○  Custom rule (advanced)              (dim) › │  inert (dim › signals future editor)
│                                                │
│  Sensible defaults mean most folders never     │  footnote, _ink55
│  need to change these.                         │
└─────────────────────────────────────────────┘
```

- **NOW rows** reflect live parser truth (derived, never hardcoded) — facts, not settings.
- **LATER rows** are inert (`_ink55`, no `onTap`, no ripple), with a **single section-level `Later` tag** (not per-row badges — calm restraint; token-based, no new "coming-soon" hue). `Semantics` announces each as e.g. *"--- rule, not yet available."* Avoid the literal "Coming soon" (marketing-toned; "Later" matches the anti-hype voice).

**Why it's not a dead-end:** every piece is load-bearing skeleton — the row stays (only its subtitle gains derivation and its sheet gains controls); NOW rows become the *selected* states of the future preset picker; LATER rows become enabled toggles in place with the final labels already written; the Custom-rule dim `›` becomes a live `AnimatedSize` disclosure; persistence lands in the already-identified `SubjectConfig`/`onyx-subject.yaml`, committing to zero throwaway storage. Mirror `study_load_help.dart`'s explainer-sheet scaffold to avoid divergence.

---

## 5. Implementation note — build now vs. deferred

**Build now (Phase 1 / Phase 3, mapped to code):**

1. `lib/core/vault/ios_vault_source.dart` — security-scoped-bookmark source. **Deferred (#82):** desktop `DesktopVaultSource` is built; iOS/Android on-device picking still needs this.
2. `lib/shared/providers/vault.dart` — **BUILT:** `VaultRefController` resolves env → persisted `VaultRef` → null (env still wins for dev); path (desktop) persisted in `preferences` via `VaultRefStore`; the `.choose()` setter (with snapshot swap, ADR-0002) is used by both the picker and Create. (iOS bookmark persistence rides with #82.)
3. `lib/features/onboarding/folder_source_sheet.dart` — shared body + `showFolderSourceSheet(context, ref)` over `showOnyxSheet` (mirrors how `showApiKeySheet` is shared).
4. `lib/features/onboarding/welcome_screen.dart` — renders the shared body as the pre-shell page; router redirect on `vaultSourceProvider == null`.
5. `lib/features/settings/settings_screen.dart` — SOURCE row gains chevron + `onTap` (`:47-51`, ~2 lines); rename group labels VAULT→SOURCE, DATA&PROGRESS→DATA&BACKUP, **CLAUDE (AI)→AI**; add ABOUT group; add the **Card parsing** row + `how_cards_are_read.dart` explainer (mirror `study_load_help.dart`); wrap Developer in a collapsed `ExpansionTile`. **Render the capability-gated cloud groups (SYNC / SHARING / ACCOUNT) behind the reachable-backend guard — absent, not disabled, in the solo core** (schema + guard owned by `registry-and-sync.md` §§1–2, §4).
6. **Make Restore a real `DestructiveRow`** (`:206-217`) and Reset-local-progress likewise (`:280-288`) — §4.9 compliance (currently error-tinted icons only).
7. **Extract `showApiKeySheet` as the 3-state AI-tier chooser** from the local `_editApiKey` dialog (§3.8 / Phase-0), shared with onboarding — drives `AiProvider { off, managed, byoKey }` (`Off` · `Onyx AI (coming soon)` · `My key`), with the `managed` option disabled until the proxy is reachable.
8. Copy sweep (§6): "sections"→"cards" in visible strings; drop "vault snapshot"; strip raw `$e`; demote Keychain/ANTHROPIC_API_KEY off primary subtitles; **"Claude"→"AI" in visible strings** (route the ~9 hardcoded "Add your Anthropic API key" strings through the one tier chooser; `registry-and-sync.md` §5.1).
9. Create-folder scaffolder + bundled sample-deck asset (2–3 `.md`).

**Deferred (stub-only now):** the configurable parser itself — no changes to `card_parser.dart`, `desktop_vault_source.dart` exclusions (`:50,91-93`), or config discovery (`subject.dart:17`). The hardcodings (`onyx-subject.yaml`, `_meta/`, `.`-prefix) stay as **defaults**; a config-less folder already falls back to the built-in subject (`subject.dart:27-28`), so Choose/Create of a bare folder Just Works today. The `HowCardsAreReadSheet` LATER rows reserve the seam.

**Build-blockers to verify before the copy is truthful:** (a) snapshot semantics on folder-switch (§3 — the "not deleted" reassurance must be true); (b) Restore→real `DestructiveRow`; (c) `showApiKeySheet` extraction; (d) persisted `VaultRef` wiring.

---

## 6. Missing-settings recommendations

- **ABOUT group — ADD** (version, privacy-in-plain-terms, licenses, restore-defaults). Currently entirely absent; research flags privacy + restore-defaults as expected.
- **Card parsing row — ADD** as the read-only stub (§4).
- **Notifications / reminders — NOT a blanket cut: one opt-in, off-by-default, due/plan reminder.** The settled stance is a single opt-in **STUDY LOAD · Daily reminder** (time picker), **off by default**, tied to due/plan and never to a streak (backlog is the dominant SRS failure, so a due-reminder is retention infrastructure, not a streak crutch; `product-direction.md` §9). Never streak/guilt/nag; ~1–2/day cap. No reminder *engine* exists yet, so the row lands when the engine ships — until then the recommendation is reserved, not a dead toggle.
- **Theme — stay CUT** (dark-locked). Do not re-add.
- **ACCOUNT group — render only when a backend capability is reachable** (not "stay CUT"). Accounts are optional-but-real (§2 ACCOUNT); the earlier "empty-account = dark pattern" objection was **conditional on there being nothing to sign into** — it is honored by the capability-reachable guard (group **absent, not disabled**, until a backend is reachable), *not* by a blanket cut. `[registry-and-sync.md §1.1; product-direction.md §7]`

---

## Doc edits required (so nothing gets "helpfully" re-added)

- **§3.7** — rename VAULT→SOURCE, DATA & PROGRESS→DATA & BACKUP, and **CLAUDE (AI)→AI** (now a 3-state `AiProvider` tier chooser, not an "API key" row); add ABOUT group; add the **Card parsing** row (explainer, *not* a control); **add the three capability-gated cloud groups SYNC / SHARING / ACCOUNT, rendered only when a backend capability is reachable (absent, not disabled) — so the binding group set is the base groups plus these optional ones**; note that Onyx satisfies "advanced one-layer-down" via a sheet, **not** an Advanced group (reject PART 1's group); confirm STUDY LOAD stays here (levers are config-once, and merging into `AdjustMixSheet` collides with §4.6/§7).
- **§3.8** — welcome gets Filled **"Choose a folder"** + Tonal **"Create a study folder"** + local-first line + "What can I point it at?" on-request expander (replaces "What's a vault?").
- **§1** — mission line "a calm, local-first study client over a plain Obsidian vault" → "…over a plain markdown folder" (Obsidian-compatible, not required). *(Applied.)*

**Authoritative anchors:** `docs/product-direction.md` §6 (AI stance — "AI" never "Claude"), §7 (optional accounts + sync, capability-gated); `docs/registry-and-sync.md` §1 (accounts — one object, three flags, reachable-guard), §2 (sync — optional/off/decoupled, `StatusPill`), §4 (the SHARING registry), §5 (managed AI — proxy seam, tier chooser, CoverageBar usage); `docs/content-creation.md` §2.2 (the AI tier chooser + JIT-at-first-use), §5 (SHARING boundary); `docs/ux-vision.md` §2 (4-tab IndexedStack frame), §3.7 (the binding group set — base groups + the capability-gated cloud groups), §3.8 (onboarding + shared key sheet), §4.6 (`AdjustMixSheet` = sole budget editor — the collision that keeps STUDY LOAD in Settings), §7 (no duplicate editors), §8 (SheetHeader-everywhere / one-Filled / 3–5 above fold / calm restraint); `docs/design-system.md` §4.9 (`DestructiveRow` / `showApiKeySheet` / `showOnyxSheet`), §4.3/§5 (`CoverageBar` / `StatusPill`), §339/§4.6 (`GoalEditorSheet`). Code: `lib/features/settings/settings_screen.dart:46-346`, `lib/shared/providers/settings.dart:24-268`, `lib/shared/providers/vault.dart:18-25`, `lib/core/vault/desktop_vault_source.dart`, `lib/core/vault/card_parser.dart`, `lib/core/backup/snapshot.dart:29`, `lib/shared/providers/subject.dart:17,27-28`.
