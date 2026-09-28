# ADR 0019 — Vault layout: config/state separation, the `_onyx/` namespace, per-deck directories

- **Status:** Accepted
- **Date:** 2026-09-28
- **Deciders:** Kyle Uehlein (+ AI-assisted scaffolding; 3 adversarial research passes, 45 agents)
- **Related:** Resolves part of the **"Sync & source-of-truth" open decision** in
  `docs/user_stories/index.md`. Foundation for **ADR-0020** (card & scheduling model — forthcoming)
  and **ADR-0021** (registry sync + teacher-push — forthcoming). Amends the flat-`_meta/` convention
  (`docs/archive/vault-structure.md`, superseded 2026-09-20 flat layout). Touches ADR-0001 (snapshot
  merge), ADR-0002 (on-device source), ADR-0003 (`deckId` seam), ADR-0006 (deck-as-lens),
  ADR-0013 (query/lens engine). Tasks: **#30/#88** (generalization), **#152/#153/#155/#156**.
  Code: `lib/core/vault/vault_source.dart`, `desktop_vault_source.dart`, `lib/core/deck/deck_store.dart`,
  `lib/core/backup/snapshot.dart`, `lib/shared/providers/vault.dart`.

## Context

Onyx keeps everything in the vault (invariant #1: **vault = source of truth; the DB is a derived
cache**). Today that store is a **flat `_meta/`** directory mixing four *different kinds* of data with
one flat naming space: authored config (`glossary.md`, `coach.md`), app-managed deck state
(`study-goals.json` — a single blob array of every deck+aim), the FSRS snapshot (`onyx-state.json`),
and dead legacy migration inputs (`onyx-goals.json`, `onyx-target.json`). A diagnosis session found
this conflation is already causing real problems (a paused single deck silently orphaned 155 cards),
and the multi-subject + teacher-registry direction (#30/#152) will multiply the config surface —
a student may accumulate dozens of decks over years of classes.

Three properties force a layout decision now, before that surface grows:

1. **Config and state have opposite natures.** *Config* (a deck's lens, priority, aims-as-authored) is
   low-frequency, app-managed, and — for teacher-push — **shippable**. *State* (FSRS schedules, review
   history, a student's accept/decline of a pushed aim) is high-frequency, personal, machine-owned, and
   **must never travel**. Mixing them in one file makes the whole-file the merge grain and couples the
   ship boundary to the personal boundary.
2. **Multi-device is a design target** (incl. iOS). `study-goals.json` is saved whole-file
   last-write-wins (`deck_store.dart` re-encodes the entire array); two devices editing different decks
   silently lose one side's edit — the exact class of bug ADR-0001 fixed for *progress* but explicitly
   left open for goals. Per-file, per-deck config shrinks the conflict surface.
3. **iOS sync excludes dot-folders.** iOS Files + iCloud Drive do not display or reliably sync
   leading-dot folders (verified; even Obsidian's own `.obsidian/` fails to sync to iPhone via iCloud).
   A hidden config dir would silently fail to reach a second device — unacceptable when the vault is the
   source of truth and config must ride the user's own folder-sync until Onyx owns sync.

Underneath the layout sits a **guiding principle** the whole redesign depends on, which this ADR states
and the siblings mechanize.

## Decision

### 1. The guiding principle — *the datum owns its state; decks and lenses are access paths*

- The **atomic unit** is the **quizzable datum** (today: `cardId::sectionSlug`). A datum owns **exactly
  one global scheduling state**; advancing it anywhere advances it everywhere (Anki-style, knowledge-keyed —
  validated against Anki/RemNote/SuperMemo/Logseq).
- A **deck** is a saved **query lens** — **exactly one** `CardQuery` over card-intrinsic attributes — plus
  aims + priority + state. A **lens SELECTS/SURFACES** units; it **never owns** a datum's state or its flow.
  Decks overlap. A deck spanning several **flows** (SWE = learn + algo + system-design + behavioral) is
  **emergent**: the one lens matches cards of several *kinds*, and each card routes to its flow by its own
  kind (ADR-0020), never by a per-flow lens. To scope a deck to one flow, add a kind leaf (`… && kind:algo`).
  **One lens, not a bundle of per-flow lenses** — a per-flow lens would make the *lens* decide the flow,
  forking a datum's single global state (the illegal state ADR-0020 forbids).
- A datum's **flow** (hence which sections are quizzable) is a property of the **datum's kind**, resolved
  by a **subject-level rule**, never by the deck lens.

This is the invariant `_onyx/`'s shape and the sibling ADRs enforce: **config never carries state; the
lens is not a scheduler; the datum is not owned by a deck.**

### 2. Config vs state vs content — three physical classes, drawn on one line

| Class | What | Format | Owner | Travels (push)? | Merge |
|---|---|---|---|---|---|
| **Content** | cards, per-flow AI skills | markdown (+ YAML frontmatter) | human-authored | **yes** (id-keyed) | ADR-0021 |
| **Config** | deck lens/priority/state, subject template, aims-as-authored | **JSON**, app-managed | app (hand-edit = power-user escape hatch) | subject/aims: yes | per-id (ADR-0021) |
| **State** | FSRS schedules, review log, aim overlay (accept/decline/importance/outcomes) | **JSON**, machine-only | the learner | **never** | ADR-0001 |

Config + state are **JSON** (robust, trivially app-serialized, no YAML implicit-typing footguns);
content stays markdown (Obsidian-native, human-authored). Genuinely device-local data (the vault
bookmark, the retention knob, coach chat) stays **DB-only**, out of the vault (moving it in would break
the bootstrap: Preferences holds *which folder is the vault*).

### 3. The `_onyx/` vault layout

Rename the config root **`_meta/` → `_onyx/`**: **visible** (leading underscore, not a dot → syncs on
iOS, shows in Obsidian's explorer, sorts to the top, signals "app-owned"), and **excluded from Onyx's
card index** (as `_meta/` is today). All Onyx data lives under it, namespaced:

```
vault/
  <anything>.md              # CONTENT: cards live anywhere in the tree (unchanged)
  korean/ …                  # content subtrees (unchanged)
  _onyx/                     # ALL Onyx data — visible, iOS-sync-safe, not card-indexed
    app.json                 # app-level config (NOT device-local prefs — those stay in the DB)
    glossary.md
    subjects/<subjectId>/     # shared, referenceable subject templates (CONFIG)  ← the SWE template lifts here (#153)
      subject.json           #   flows + their selectors + vocab + readiness dims + tiers
      coach.md               #   per-subject coach skill (CONTENT)
      skills/<flow>.md       #   per-flow AI skill files (CONTENT)
    decks/<deckId>/           # per-deck cluster (one dir per deck)
      deck.json              #   CONFIG: the lens (CardQuery), priority, state, template ref
      aims.json              #   CONFIG: aims as authored (self or, later, pulled definitions)
      overlay.json           #   STATE: puller-owned aim overlay      (populated by ADR-0021)
      provenance.json        #   CONFIG: teacher-push subscription record (populated by ADR-0021)
    state/
      <deviceId>.json        #   STATE: per-device FSRS/scheduling snapshot → glob-merged (ADR-0001 follow-up)
```

- **Per-deck directory** keyed by the stable `deckId` (collision-safe already, ADR-0013). It clusters a
  deck's artifacts for atomic add/copy/archive and eliminates flat-naming collisions at scale — the
  convergent pattern (`.vscode/`, `.idea/`, `.obsidian/plugins/<id>/`). **Cards are NOT moved into it**
  — only the deck's own config/state — so lens overlap is preserved.
- **Per-device state files** (`state/<deviceId>.json`, glob-merged) replace the single
  `onyx-state.json`, closing the same-file multi-device write race (ADR-0001's own deferred follow-up).
  This ADR introduces a stable **device id** (Preferences-backed) that other merge work also needs.
- `deck.json`/`aims.json`/`overlay.json` split lets a per-id merge replace the whole-file LWW, and keeps
  the **teacher-owned** (aims definition) physically apart from the **learner-owned** (overlay) — the
  anti-clobber architecture ADR-0021 relies on.
- **VaultSource gains a subpath contract.** `readMeta`/`writeMeta` treat the name as a POSIX relative
  path under `_onyx/`; `readMeta` already passes separators through, `writeMeta` needs recursive
  parent-mkdir (the idiom `writeFile` already uses). The name-based `_meta` index-exclusion becomes an
  `_onyx` exclusion; the one spot that deliberately walks *into* the config dir (`listConfigPaths`) is
  rewritten to be `_onyx`-aware rather than relying on the underscore/dot skip.

### 4. Migration

The existing on-disk data is **junk** (dev fixtures) — there is **no preservation constraint**, which
frees the cleanest keys/layout. On first run against a legacy vault: read the old flat `_meta/`, fold
into the new `_onyx/` shape, write through, stop consulting the old files (the pattern
`decks.dart` already uses for the pre-#30d fold), then the legacy readers are deleted in a later unit
once the fold is proven. Retire the dead `onyx-goals*.json`/`onyx-target.json` inputs and the
`budgetWeight` field in the same pass.

## Alternatives considered

- **Hidden `.onyx/`.** Rejected: dot-folders don't sync/show on iOS (the primary target) — config would
  silently fail to reach a second device. Revisit only once Onyx owns its own sync layer; a visible
  `_onyx/` is the safe default now. (`onyx_configuration/` — clearer to novices, but long and an unusual
  dir style; the escape-hatch audience is power users who recognize `_onyx/`.)
- **Keep the flat `_meta/`; fix only the data.** Rejected: it doesn't address the scaling collision
  surface, keeps `study-goals.json` as one whole-file-LWW blob, and leaves config/state entangled so the
  teacher-push ship boundary can't be drawn cleanly.
- **Per-deck config *inside* a `<deckSlug>/` card folder** (cards move into the deck). Rejected: breaks
  deck overlap (a card in two decks has no single home) and re-collapses deck==folder — exactly the
  duality ADR-0013 removed. Config-dirs hold *config only*; cards stay put.
- **Nested `_onyx/subjects|decks` requiring a full VaultSource tree API on every backend now.** The
  desktop source (the only one built) needs a ~1-line `writeMeta` change; iOS/Android SAF sources are
  unbuilt (ADR-0002) so subpaths cost nothing extra there today — but the VaultSource *contract* is
  documented as "name = POSIX relative path" so those fill-ins implement it deliberately.
- **YAML for config** (human-friendliness). Rejected once hand-editing was de-prioritized to a power-user
  escape hatch: app-managed JSON is more robust (no Norway-problem/implicit-typing crashes), trivially
  serialized, and matches the machine-owned nature. Content stays markdown/YAML-frontmatter.

## Consequences

- **Positive:** config and state separate cleanly, so the teacher-push ship boundary (content + config)
  and the personal boundary (state) fall out of the file layout; per-deck dirs scale to dozens of decks
  without collisions; per-device state files + a device id close the multi-device write race; per-file
  config enables a real per-id merge (replacing whole-file LWW); a visible `_onyx/` syncs to iOS; the
  guiding principle is written down as the invariant the sibling ADRs enforce.
- **Negative / trade-offs:** a `_meta/`→`_onyx/` rename touches ~30 string literals + the index-exclusion
  + `listConfigPaths` + docs/glossary anchors (contained, but real); introduces a VaultSource subpath
  contract that every future backend must honor; more (smaller) files means more objects a folder-syncer
  could spawn conflict copies of — mitigated by conflict-copy detection (ADR-0021) and per-file merge.
- **Known limitations & follow-ups (deliberately NOT here):**
  - The **card & scheduling model** — knowledge-keyed one-state-per-datum, thin cards + a `kind:` marker
    + card-kind quizzability, the uniform state record + pluggable per-kind scheduler (#155), and
    retain-but-detach lifecycle — is **ADR-0020**. It supersedes ADR-0003's reserved `(deckId, cardId,
    sectionSlug)` direction in favor of a **deckId-free** datum key (the datum is deck-independent).
  - The **registry sync + teacher-push** model — account-based read/write access to an upstream vault,
    the **lens-as-transfer-filter** (structure-preserving export/pull), id-keyed reconciliation,
    **overwrite-on-pull** for pulled content (student local edits to pulled cards are overwritten; a
    same-path *different-id* collision is refused/quarantined), preserved overlay, conflict-copy
    detection, and **iTIP multi-source aims** (author-owned definition + puller-owned overlay, one-way
    publish, one author per aim) — is **ADR-0021**, gated on the remaining half of the parked
    source-of-truth decision.
  - Section-granular lens predicates (`section:usage`) require a **stable section key** (never
    slugify(heading)) and a `(cardId,sectionSlug)` readiness denominator — Browse-only until then
    (ADR-0020).

## Validation

- `test/unit/deck_store_test.dart` (+ a new per-deck-dir store test): the flat→`_onyx/` fold is
  write-through and idempotent; a legacy `_meta/` vault loads byte-identically into the new shape; a
  single-deck vault degrades identically (invariant #8).
- A `DesktopVaultSource` test: `readMeta`/`writeMeta` round-trip a nested `decks/<id>/deck.json` path
  (recursive mkdir); `_onyx/` is excluded from the card index; `listConfigPaths` still resolves subject
  templates under the renamed dir.
- The full suite stays green through the rename (the ~30 `_meta` literals swept in one unit); the
  merge/device-id + per-id-config-merge work is validated in ADR-0020/0021 with the pure-merge test style
  ADR-0001 established.
