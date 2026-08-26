# Onyx — Architecture

## Overview

Onyx is a local-first iOS flashcard app backed by an Obsidian vault. Cards are
Obsidian markdown files. A local SQLite database stores derived metadata (SRS
state, review history, activity logs). The app never duplicates card content
into the database — SQLite is purely for app-specific data that has no place
in the vault.

## System Diagram

```
Desktop (Neovim + Obsidian)
        │
        │  writes .md files to vault folder
        ▼
  Obsidian Vault ──── Obsidian Sync ────► Vault on iOS (Files app)
  (Flashcards/ subfolder)                         │
                                                  │  one-time folder picker
                                                  │  security-scoped bookmark
                                                  ▼
                                    ┌─────────────────────────────┐
                                    │       Onyx (Flutter)        │
                                    │                             │
                                    │  VaultService               │
                                    │    parse .md files          │
                                    │    extract frontmatter      │
                                    │    index wikilinks          │
                                    │         │                   │
                                    │  FSRSEngine                 │
                                    │    compute due dates        │
                                    │    update stability         │
                                    │         │                   │
                                    │  SQLite (drift)             │
                                    │    srs_state                │
                                    │    reviews                  │
                                    │    activity_log             │
                                    │    card_links (cache)       │
                                    │         │                   │
                                    │  ClaudeService ──────────► Claude API
                                    └─────────────────────────────┘
```

## iOS Vault Access

iOS sandboxing prevents Flutter from reading another app's files directly. The
solution is `UIDocumentPickerViewController` (wrapped by the `file_picker`
package), which grants persistent folder access via a security-scoped bookmark.

Flow:
1. First launch: user taps "Select Vault Folder", picks `Flashcards/` subfolder
2. Flutter stores the security-scoped bookmark in SQLite preferences
3. On subsequent launches, Flutter reopens the bookmark with no re-prompt
4. No special entitlements required; works with any folder the iOS Files app
   can see (iCloud Drive, Obsidian Documents, Working Copy repos, etc.)

## Sync Strategy

Sync is user-managed and app-agnostic. Onyx reads whatever files are at the
bookmarked path — it does not care how they arrived.

| Option | Cost | Notes |
|---|---|---|
| Obsidian Sync (existing) | Paid | Zero changes required; just point picker at vault folder |
| iCloud vault | Free | Best for macOS desktop; vault in iCloud Drive |
| GitHub private repo + Working Copy | $20 one-time | Good for git workflow on iOS |
| Syncthing | Free | Peer-to-peer; no cloud dependency |

The vault subfolder (`Flashcards/`) lives within the broader Obsidian vault.
Obsidian Sync syncs the whole vault including this subfolder. Onyx only indexes
files within the selected folder.

## Vault Subfolder

Onyx operates on a single folder within the vault, defaulting to `Flashcards/`.
Cards in this folder can wikilink to notes anywhere in the broader vault; those
links appear as "unresolved" in Onyx but work fine in Obsidian. This keeps
Onyx's index focused and avoids scanning unrelated notes.

### `_meta/` subfolder

`Flashcards/_meta/` holds vault metadata — tag index, curriculum, card writing
conventions, and the standalone card creation skill. Onyx's indexer naturally
skips this folder because those files lack `type: flashcard` frontmatter.
Template files live in `examples/vault/_meta/` in the project repo.

## Data Architecture

**Vault — source of truth**
- Card content, structure, tags, wikilinks
- Human-readable markdown; editable in any text editor
- Obsidian-compatible

**SQLite — derived and app-specific only**
- SRS state per `(card_id, section_slug)` pair
- Review history
- Activity logs (for future AI analysis)
- Cached graph edges (rebuilt from vault on demand)
- Vault path bookmark + user preferences
- API key reference (actual key in iOS Keychain via `flutter_secure_storage`)

If SQLite is deleted, all card content survives in the vault, and the derived
caches (`card_cache`, `card_links`) rebuild on the next index. SRS *progress*
would be lost — except that Onyx periodically snapshots it into the vault (see
below), so a reinstall or corrupted DB restores your scheduling state too.

### SRS State Backup & Restore

The precious, non-rebuildable data is `srs_state` (current scheduling) and the
`reviews` history. To survive a lost SQLite file without a server, Onyx writes a
compact snapshot into the vault at `Flashcards/_meta/onyx-state.json`, carried
off-device for free by whatever already syncs the vault (Obsidian Sync, git,
iCloud).

- **What:** `srs_state` for every `(card_id, section_slug)` — stability,
  difficulty, due, review count, last review — keyed by `card_id` so it survives
  file renames. ~120 KB for a few hundred cards. A compacted review summary is
  optional.
- **When:** debounced — written on session end / app backgrounding, never per
  review. The vault sees one changed file per session (no churn, and no volatile
  state mixed into authored card files).
- **Restore:** on launch with an empty `srs_state`, seed the DB from the snapshot
  if present. On conflict, most recent `last_review` wins.

This is a durability layer built after the core study loop works. It needs no
change to the card format — the snapshot is a separate `_meta/` file, decoupled
from the cards.

## SQLite Schema

```sql
-- SRS state is per (card, section) pair, not per card
CREATE TABLE srs_state (
  card_id       TEXT NOT NULL,
  section_slug  TEXT NOT NULL,   -- H2 heading lowercased, spaces → hyphens
  stability     REAL NOT NULL DEFAULT 0,
  difficulty    REAL NOT NULL DEFAULT 5,
  due_at        INTEGER NOT NULL,  -- unix timestamp (seconds)
  last_review   INTEGER,           -- unix timestamp
  review_count  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (card_id, section_slug)
);

-- Full review log; never deleted, used for activity analysis
CREATE TABLE reviews (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id       TEXT NOT NULL,
  section_slug  TEXT NOT NULL,
  reviewed_at   INTEGER NOT NULL,
  grade         INTEGER NOT NULL,  -- 1=Again, 2=Hard, 3=Good, 4=Easy
  stability     REAL NOT NULL,     -- FSRS stability after this review
  difficulty    REAL NOT NULL,     -- FSRS difficulty after this review
  elapsed_days  REAL NOT NULL      -- days since last review
);

-- Graph edge cache; rebuilt whenever vault is re-indexed
CREATE TABLE card_links (
  from_card  TEXT NOT NULL,
  to_card    TEXT NOT NULL,
  PRIMARY KEY (from_card, to_card)
);

-- Activity log for future AI analysis
CREATE TABLE activity_log (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  occurred_at  INTEGER NOT NULL,
  event_type   TEXT NOT NULL,   -- 'session_start', 'review', 'browse', 'ai_query'
  card_id      TEXT,
  section_slug TEXT,
  metadata     TEXT             -- JSON blob for event-specific data
);

-- Card metadata cache — rebuilt on vault re-index, never source of truth
-- Enables fast readiness calculation without re-parsing all markdown
CREATE TABLE card_cache (
  card_id      TEXT PRIMARY KEY,
  title        TEXT NOT NULL,
  card_type    TEXT NOT NULL,   -- 'flashcard' | 'interview-question'
  tags         TEXT NOT NULL,   -- JSON array: ["ds-a","bst","tree"]
  tiers        TEXT NOT NULL,   -- JSON object: {"ds-a":2,"system-design":1}
  category     TEXT,            -- for interview-question: 'coding'|'system-design'|'conceptual'|'language'
  difficulty   TEXT,            -- for interview-question: 'easy'|'medium'|'hard'
  frequency    TEXT,            -- for interview-question: 'high'|'medium'|'low'
  practice_url TEXT,            -- for interview-question: URL opened after Good/Easy grade
  file_path    TEXT NOT NULL,
  indexed_at   INTEGER NOT NULL
);

-- App preferences (vault bookmark, settings)
CREATE TABLE preferences (
  key    TEXT PRIMARY KEY,
  value  TEXT NOT NULL
);
```

## Card Types

Onyx indexes two card types from the vault:

| `type` value | Purpose | Quiz behavior |
|---|---|---|
| `flashcard` | Concept card or lang/framework syntax card | Per-section; front = "Title — Section" |
| `interview-question` | Actual interview question | Single item; front = problem statement; primary section = `## Approach` |

The `_meta/` subfolder is always skipped by the indexer (no `type` field).

### Interview question quiz flow

1. Front: problem statement (pre-H2 card body) shown as context
2. User attempts mentally; taps to reveal
3. Back: `## Approach` section rendered
4. User grades 1–4
5. If grade ≥ 3 (Good/Easy) AND `practice_url` is set: skippable prompt —
   "Ready to practice? [Open ↗] [Skip]" — opens URL via `url_launcher`
6. If grade < 3: prompt suppressed (review the approach more first)

This practice redirect directly addresses the transfer gap identified in
learning science research: flashcards build pattern recall; actual problem
solving builds the transfer skill needed for novel interview problems.

---

## Card Identity

Cards are identified by a UUID in frontmatter (`id` field), not by filename.
This means:
- Filenames can be renamed in Obsidian without breaking SRS history
- SQLite always references `card_id` (the UUID)
- Cards without a valid `id` field are skipped during indexing
- The AI card creation skill always generates a UUID; manually created cards
  need one added (a count of ID-less cards is shown in Settings)

## FSRS Integration

FSRS v4 (Free Spaced Repetition Scheduler) tracks each `(card_id, section_slug)`
pair independently. Each quizzable section of each card has its own forgetting
curve.

Grades: 1 (Again), 2 (Hard), 3 (Good), 4 (Easy)

Evaluate the `fsrs` package on pub.dev first. If unmaintained or absent,
implement from the FSRS-4.5 spec directly — the core algorithm is ~200 lines
and the spec is well-documented at github.com/open-spaced-repetition/fsrs4anki.

### Interleaving requirement

Research confirms that mixing topics within a session produces more durable
retention than blocking (all tree cards, then all graph cards). FSRS determines
*which* items are due; a post-selection reorder step determines *order*.

After selecting N due items, the scheduler round-robins them across the primary
tag of each item's parent card. Cards with no tag fall into a "general" bucket.
No two consecutive items share the same primary tag when queue size allows it.

This is a deliberate design constraint — not a cosmetic preference and not a
settings toggle in MVP. See `docs/learning-science.md` for the evidence.

## Claude API Integration

The app calls the Claude API directly from Flutter. No intermediary server.

- API key: stored in iOS Keychain via `flutter_secure_storage`; user enters it
  in Settings on first launch
- Model: `claude-haiku-4-5-20251001` for in-app explain (fast, cheap per query)
- Context sent per query: system prompt + full card markdown + user question
- Conversation history: stored in SQLite `activity_log` for the session;
  not persisted between sessions in MVP

## State Management

Riverpod with code generation (`@riverpod` annotation + `riverpod_generator`).

- All providers live in `providers/` subdirectories within each feature
- Cross-feature state (vault index, database connection) lives in
  `lib/shared/providers/`
- Use `AsyncNotifierProvider` for anything that loads from disk or network
- Use `NotifierProvider` for synchronous state (quiz session, UI state)

## Navigation

`go_router` with a bottom navigation shell route. Four top-level destinations:

| Route | View | Description |
|---|---|---|
| `/` | Dashboard | Due count, streak, quick-start quiz |
| `/browse` | Browse | Card list with search and tag filters |
| `/quiz` | Quiz | Active quiz session |
| `/settings` | Settings | Vault path, API key, preferences |

Card detail: `/browse/:cardId` (pushed onto browse stack).

## Project Structure

```
onyx/
├── docs/
│   ├── architecture.md          ← this file
│   ├── card-schema.md
│   └── roadmap.md
├── lib/
│   ├── core/
│   │   ├── database/            # drift schema, tables, DAOs
│   │   ├── vault/               # file access, markdown parser, indexer
│   │   ├── srs/                 # FSRS engine, scheduler
│   │   └── ai/                  # Claude API client
│   ├── features/
│   │   ├── dashboard/
│   │   ├── browse/
│   │   ├── quiz/
│   │   ├── card_detail/
│   │   └── settings/
│   ├── shared/
│   │   ├── models/              # Card, CardSection, QuizItem, Tag
│   │   ├── widgets/             # markdown renderer, tag chip, etc.
│   │   └── providers/           # vault index, db, cross-feature state
│   └── main.dart
├── test/
│   ├── unit/                    # FSRS engine, parser, scheduler logic
│   └── widget/                  # Flutter widget tests
├── flake.nix
├── pubspec.yaml
├── analysis_options.yaml
├── lefthook.yml
└── .commitlintrc.yaml
```

## Key Decisions Log

| Decision | Choice | Rationale |
|---|---|---|
| SRS algorithm | FSRS v4 | More accurate than SM-2; now the Anki default |
| SRS granularity | per (card, section) | Quiz specific aspects, not entire cards |
| State management | Riverpod + codegen | Best-in-class for reactive data-heavy Flutter apps |
| Database ORM | drift | Type-safe, reactive streams, strong migration support |
| Card storage | Obsidian vault (.md) | Human-readable, editable outside the app, no lock-in |
| Graph view | Not implemented | Obsidian provides this; avoids major complexity |
| iOS file access | Document picker + bookmark | No entitlements; works with any sync provider |
| AI | Claude API direct | No server, user controls key and cost |
| Quiz style | Self-graded (1-4) | Simplest effective format; matches FSRS grades |
| Card ID | UUID in frontmatter | Stable across filename renames |
