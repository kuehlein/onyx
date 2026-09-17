# Onyx — Settings & Configuration UX

*Companion to `docs/ux-vision.md` (refines §3.7; touches §3.8, §16) and consistent with `docs/design-system.md` (§4.9). This spec is decisive: where the four design drafts disagreed, the choice is made here and the losing option is named so it doesn't get "helpfully" re-added.*

---

## 1. Placement — Settings stays the 4th bottom-tab

**Decision: Settings remains a co-equal 4th tab (Home · Browse · Insights · Settings) in the IndexedStack frame. Reject gear-icon, drawer, and profile-screen relocations.**

The generic settings-UX research ("never burn a bottom-tab on Settings") is correct *for its assumed app shape* — a mostly-casual app whose settings are a handful of appearance/notification toggles. It does not apply to Onyx, for four codebase-grounded reasons:

1. **Settings is the local-first app's config + data-stewardship home, not a toggle drawer.** Source (the content contract), the Claude key (the AI contract), backup/restore (the data-safety contract), and goal management (the config that defines every deck) are all app-wide, rarely-changed, and genuinely destination-worthy. Android's own rule (15+ settings → subscreens) and Toptal's "4–5 categories" put Onyx squarely at destination scale.
2. **Every alternative breaks a harder locked constraint.**
   - *App-bar gear:* Settings is **altitude-agnostic** (§2) — it renders identically whether `focusedGoal` is null or a goal id. A gear on one screen's AppBar re-couples it to an altitude and re-introduces the "which screen owns global config" ambiguity the `focusedGoalProvider` single-spine was built to kill.
   - *Drawer:* NN/G's own finding is that hidden menus cut engagement ("out of sight is out of mind"). A drawer is strictly worse than a visible co-equal tab, and there's no drawer anywhere else in the app to hang it on.
   - *Profile screen:* requires an identity anchor. Onyx has **no account by principle** — "an empty account section is itself a dark pattern." A profile entry with no profile is the dark pattern the docs forbid.
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
│ CLAUDE (AI)
│   🔑 API key             Saved on this device            ›
│   📡 Test connection                                     ›
│
│ ABOUT
│   ℹ  About Onyx          Version 1.4.0                   ›
│
│ ▸ Developer   (dev builds only, collapsed — the SOLE collapsed group)
└──────────────────────────────────────────────────────────
```

**Group order** (by importance/frequency, per Android): SOURCE → STUDY LOAD → STUDY GOALS → DATA & BACKUP → CLAUDE (AI) → ABOUT → ▸ Developer. Source first (the app is nothing without content); Developer last and collapsed. **3–5 above the fold** (§8) is satisfied: SOURCE(3) + top of STUDY LOAD fills the first screen; everything heavier is a drill-down.

**Decisions made against the drafts:**
- **No "Advanced" group.** PART 1 proposed an always-present Advanced group nesting Developer; PART 3 correctly rebutted it as dead UI (a header over one stub) that violates §8 calm-restraint. One stub does not earn a group. Onyx satisfies the research's "advanced-one-layer-down" principle **via a sheet, not a group** — record this in §3.7 so a future reader doesn't re-add it.
- **STUDY LOAD stays in Settings** (reject PART 1's "delete it, inline the levers" overrule). PART 1 misread the governing rule: the doc author wrote *"tune today → where you study; configured once → here"* and then deliberately kept these two levers here as the config-once-ish ones. Worse, PART 1 wanted to cram Daily-time / New-per-day into Home's `[Adjust mix]` — but §4.6 line 193 makes `AdjustMixSheet` **"the sole budget editor,"** and it edits per-goal *share-of-time* MixSliders, not absolute minutes or new/day. Merging them collides with §4.6 and violates §7's "no duplicate editors."
- **Two group renames** (VAULT→SOURCE, DATA & PROGRESS→DATA & BACKUP), written into §3.7 as one decision (the drafts each renamed differently — SOURCE from PART 4 wins as the tightest topic-noun; "Progress" collides with Insights, which owns progress *display*).

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

**CLAUDE (AI)** — mechanism nouns demoted off the primary line.

| State | Primary subtitle |
|---|---|
| Saved | `Saved on this device` (secondary/sheet: "Kept in the Keychain, this device only") |
| From env (desktop dev) | `Using ANTHROPIC_API_KEY` (row non-editable — only shows when the var is set) |
| Not set (iOS) | `Not set — tap to add` |
| Not set (Linux) | `Set ANTHROPIC_API_KEY to use AI` |
| Checking / error | `Checking…` / `Couldn't read stored key` |

- **API key** → the shared **`showApiKeySheet`** (extracted from Settings, shared with onboarding's first-AI-flow per §3.8; today it's a local `_editApiKey` dialog and must be extracted). Store `ThisDeviceOnly`. Trailing delete (`_ink55`) only when a user-saved (non-env) key exists.
- **Test connection** — `Send a tiny request to check the key.` Enabled only when a key is set; sends `Reply with exactly: pong`. Results: `Connected.` / `Couldn't connect.` — keep the *reason* (auth vs network) reachable behind a tap; a bare "Couldn't connect" on a bad key is unhelpfully calm.

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

**One shared sheet body powers two flows: `/welcome` (renders it as the pre-shell page — the sole hard gate, sole full page) and the Settings Source row (renders it as a real `showOnyxSheet`).** No third surface, no wizard. This is the missing persisted-path wiring the `settings_screen.dart:30-32` doc-comment already promises but `vault.dart:18-25` never implemented (env-only today).

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

1. `lib/core/vault/ios_vault_source.dart` — security-scoped-bookmark source (Phase-1 blocker: no on-device source exists).
2. `lib/shared/providers/vault.dart:18-25` — replace env-only resolution with **env → persisted `VaultRef` → null** (env still wins for dev). Persist path (desktop) / bookmark (iOS) in `preferences`; add a setter used by both the picker and Create. *This is net-new wiring, larger than Phase-3's "changes: settings_screen" note — flag as its own build item.*
3. `lib/features/onboarding/folder_source_sheet.dart` — shared body + `showFolderSourceSheet(context, ref)` over `showOnyxSheet` (mirrors how `showApiKeySheet` is shared).
4. `lib/features/onboarding/welcome_screen.dart` — renders the shared body as the pre-shell page; router redirect on `vaultSourceProvider == null`.
5. `lib/features/settings/settings_screen.dart` — SOURCE row gains chevron + `onTap` (`:47-51`, ~2 lines); rename group labels VAULT→SOURCE, DATA&PROGRESS→DATA&BACKUP; add ABOUT group; add the **Card parsing** row + `how_cards_are_read.dart` explainer (mirror `study_load_help.dart`); wrap Developer in a collapsed `ExpansionTile`.
6. **Make Restore a real `DestructiveRow`** (`:206-217`) and Reset-local-progress likewise (`:280-288`) — §4.9 compliance (currently error-tinted icons only).
7. **Extract `showApiKeySheet`** from the local `_editApiKey` dialog (§3.8 / Phase-0), shared with onboarding.
8. Copy sweep (§6): "sections"→"cards" in visible strings; drop "vault snapshot"; strip raw `$e`; demote Keychain/ANTHROPIC_API_KEY off primary subtitles.
9. Create-folder scaffolder + bundled sample-deck asset (2–3 `.md`).

**Deferred (stub-only now):** the configurable parser itself — no changes to `card_parser.dart`, `desktop_vault_source.dart` exclusions (`:50,91-93`), or config discovery (`subject.dart:17`). The hardcodings (`onyx-subject.yaml`, `_meta/`, `.`-prefix) stay as **defaults**; a config-less folder already falls back to the built-in subject (`subject.dart:27-28`), so Choose/Create of a bare folder Just Works today. The `HowCardsAreReadSheet` LATER rows reserve the seam.

**Build-blockers to verify before the copy is truthful:** (a) snapshot semantics on folder-switch (§3 — the "not deleted" reassurance must be true); (b) Restore→real `DestructiveRow`; (c) `showApiKeySheet` extraction; (d) persisted `VaultRef` wiring.

---

## 6. Missing-settings recommendations

- **ABOUT group — ADD** (version, privacy-in-plain-terms, licenses, restore-defaults). Currently entirely absent; research flags privacy + restore-defaults as expected.
- **Card parsing row — ADD** as the read-only stub (§4).
- **Notifications / reminders — CUT for v1.** No reminder engine exists (a dead toggle violates no-stub-in-casual-path), and streak-style nudges flirt with the rejected gamification surface. When an engine ships, add a single opt-in **STUDY LOAD · Daily reminder** (time picker), framed as a plan reminder, never a streak defense.
- **Theme / Account — stay CUT** (dark-locked; local-first; empty-account = dark pattern). Do not re-add.

---

## Doc edits required (so nothing gets "helpfully" re-added)

- **§3.7** — rename VAULT→SOURCE and DATA & PROGRESS→DATA & BACKUP; add ABOUT group; add the **Card parsing** row (explainer, *not* a control); note that Onyx satisfies "advanced one-layer-down" via a sheet, **not** an Advanced group (reject PART 1's group); confirm STUDY LOAD stays here (levers are config-once, and merging into `AdjustMixSheet` collides with §4.6/§7).
- **§3.8** — welcome gets Filled **"Choose a folder"** + Tonal **"Create a study folder"** + local-first line + "What can I point it at?" on-request expander (replaces "What's a vault?").
- **§16** — mission line "a calm, local-first study client over a plain Obsidian vault" → "…over a plain markdown folder" (Obsidian-compatible, not required).

**Authoritative anchors:** `docs/ux-vision.md` §2 (4-tab IndexedStack frame), §3.7 (the binding 6-group set), §3.8 (onboarding + shared key sheet), §4.6 (`AdjustMixSheet` = sole budget editor — the collision that keeps STUDY LOAD in Settings), §7 (no duplicate editors), §8 (SheetHeader-everywhere / one-Filled / 3–5 above fold / calm restraint); `docs/design-system.md` §4.9 (`DestructiveRow` / `showApiKeySheet` / `showOnyxSheet`), §339/§4.6 (`GoalEditorSheet`). Code: `lib/features/settings/settings_screen.dart:46-346`, `lib/shared/providers/settings.dart:24-268`, `lib/shared/providers/vault.dart:18-25`, `lib/core/vault/desktop_vault_source.dart`, `lib/core/vault/card_parser.dart`, `lib/core/backup/snapshot.dart:29`, `lib/shared/providers/subject.dart:17,27-28`.
