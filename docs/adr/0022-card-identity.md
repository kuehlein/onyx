# ADR 0022 — Card identity: filename-slug default, optional embedded id

- **Status:** Accepted
- **Date:** 2026-09-29
- **Deciders:** Kyle Uehlein (+ AI-assisted; a deep-research pass over Anki, Mochi/Logseq, org-roam,
  and the Obsidian SRS plugin ecosystem — 101 agents, 19 primary sources, 23/25 claims verified 3-0).
- **Related:** **Amends invariant #5** (`cardId` = stable slug; "normalize the residual UUIDs") and
  **ADR-0020 §1** (the datum key `(cardId, dataSlug)`) — the *derivation* of `cardId` changes; the key
  *shape* does not. Extends **ADR-0020 §5 / #158** (index-diff rekey) from section grain to **card**
  grain. The mandatory-share-id rule feeds **ADR-0021** (registry sync / teacher-push). Continues the
  Wave C glue-removal (`type:`/`quiz:` — ADR-0020 §2). Code: `lib/core/vault/card_parser.dart`,
  `lib/shared/models/card.dart` (`Card.id`, `MissingCardIdException`), and every `"$cardId::$sectionSlug"`
  key site (`srs_repository`, `recognition_repository`, `snapshot`).

## Context

Wave C removes author "glue" — Onyx-specific frontmatter a self-authored card shouldn't need. `type:`
is going (flow membership moves to a subject-level selector, #153). This ADR settles the other field:
**`id:`**. Today `id:` is **mandatory** and is the join key between a card's file and all its FSRS state
(`(cardId, sectionSlug)`). A diagnosis of the shipped CS deck found `id:` is largely *redundant* glue:

- **135 of 163 card ids literally equal the filename** (`trie.md → id: trie`, `bloom-filter.md → id:
  bloom-filter`). The field just duplicates the filename.
- **28 are UUIDs** — the "residual UUIDs" invariant #5 already wanted to normalize away.
- Wikilinks, `depends-on:`, and `## Related` all reference a card by its **filename** — but `cardId` is
  the `id:` value, so for the 28 UUID cards the two namespaces diverge, forcing a filename→id hop
  (`concept_comfort`'s `idByFile` map) and a documented "silent id-vs-filename join bug" class
  (auto-memory `card-id-convention`).

So `id:` can largely go — but *card identity is a real need* (it links a file to its schedule across
edits/renames, and, later, across vaults for teacher-push). The question is what replaces it.

**What established tools do** (the research, grounded in primary sources):

- **Portability/durability camp** — Anki (per-note **GUID**, hidden, content-embedded), Mochi /
  logseq-mochi-sync (injected `mochi-id`), org-roam v2 (compulsory embedded `:ID:`), Retrieva (hidden
  UUIDv7): all use a **system-generated, content-embedded opaque id** because filename/filepath/content-
  hash all break on edit, rename, or crossing into another vault. Anki dedups/updates shared decks by
  **GUID, not the local note-id** — the canonical proof that *sharing needs a content-embedded id*.
- **Zero-glue camp** — obsidian-spaced-repetition-recall (path-keyed store), oscargarnerfernandez's fork
  ("never writes frontmatter/tags/ids"), st3v3nmw (inline `<!--SR:…-->` comment, positional): key on the
  **filepath** and lean on the **editor's rename event** to migrate `old→new`. This works for in-app
  renames but **orphans state on out-of-band moves** (external editor, git pull, sync, or *an app that
  writes files at runtime* — Onyx's own case).
- **Rename detection at card grain is already shipping** (obsidian-spaced-repetition-recall): a fallback
  cascade — optional blockID → content-similarity hash → line number — re-attaches a card's history with
  no stable id, with a known **hard failure on simultaneous move + heavy edit**.
- **Content-hash is rejected** as identity-of-record everywhere (every edit orphans the schedule); it is
  only usable as a rename-detection *signal*.

## Decision

**`cardId` = the card's explicit `id:` if present, else the bare filename slug** —
`cardId = frontmatter['id'] ?? slugify(basename(filePath))`. `id:` becomes **optional**: a durable /
shareable *override*, not a requirement. The datum key `(cardId, sectionSlug)` (ADR-0020 §1) is unchanged
in shape.

1. **Bare filename slug, not full relative path.** The research's general recommendation is the full
   relative filepath (collision-safe). Onyx **diverges deliberately**: its wikilink / `depends-on` /
   `## Related` namespace is the **bare filename** (an Obsidian constraint, not our choice), and the
   existing `id:`s are bare. Keying `cardId` on the full path would *reintroduce* the id-vs-filename
   mismatch this change is meant to kill. So `cardId` aligns with the filename namespace. The cost —
   **cross-folder filename collision** (two `binary-search.md`) — is real but (a) absent in the shipped
   vault (verified: CS is flat, no collisions), (b) already an Obsidian-level concern (it disambiguates
   duplicate note names in `[[links]]`), and (c) **detected at index time and surfaced as a vault-health
   warning** (ADR-0020 §2) — **never silently merged.** The one real corruption risk is two distinct cards
   fusing their FSRS state under a shared `cardId`; the collision guard refuses that (warn, and/or
   path-qualify only the collided pair), so a collision is a rare, visible, fixable condition, not data loss.
2. **Rename/move resilience via cold-reindex index-diff, not editor events.** Onyx writes the vault at
   runtime and rides folder-sync, so it *cannot* depend on an editor rename event (the zero-glue plugins'
   mechanism, which fails exactly here). Instead, on reindex, diff the last-indexed card set vs current;
   a gone `cardId` + a new file whose content still matches carries the schedule over (the ADR-0020 §5 /
   **#158** machinery, extended from section to **card** grain). **retain-but-detach** (ADR-0020 §4)
   softens a miss: the old state is retained (inert), re-attaching if detection later resolves it — a
   missed rename is *re-learn, never data loss*. Best-effort, with the documented hard failure (rename +
   heavy edit at once).
3. **Content-hash is not identity** — only a rename-detection signal (as in #158). Never the key.
4. **Sharing/teacher-push requires a mandatory embedded opaque id** (ADR-0021). Crossing vaults changes
   paths and can collide slugs (Anki renumbers its local note-id on collision for exactly this reason;
   org-roam dropped path-based links because "paths are very sensitive to file system changes"). So when
   a deck is **published/pushed**, Onyx mints and embeds an opaque `id:` (UUID-style) per card — the same
   escape hatch Anki/Mochi/org-roam all prove you eventually need. Local-first, un-shared cards need no
   `id:` at all.

**The `id:` field is therefore never *removed* — it is made optional.** The 155 shipped cards keep their
`id:` (honored verbatim → byte-identical, and their frontmatter id even survives a file rename today).
New self-authored cards work with zero `id:` glue. Stripping the now-redundant `id:` lines from the CS
cards is a *separate, optional* `chore(cards):` — deferred until #158's card-rename detection lands, so
those cards don't trade frontmatter-id resilience for detection-based resilience prematurely.

## Alternatives considered

*Framing.* Because the vault is the source of truth and the DB is a derived cache, a card's identity must be
**recoverable from the vault alone** (a fresh install / lost DB must rebuild it). That leaves only three
intrinsic, zero-glue candidates — content, filename, filepath — and there is a genuine **impossibility**: no
purely-intrinsic identifier is simultaneously zero-glue, rename-stable, move-stable, collision-free, *and*
portable across vaults. So the design is not a magic stable id but a **layered** one: a zero-glue *derived*
key (filename) for the local case + **reconciliation** (rename detection) + **guarding** (collision warnings)
+ an *embedded* id only at the sharing boundary. The rejected options below each try to win all properties at
once and can't.

- **Full relative filepath as `cardId`** (the research's headline rec). Collision-free, but breaks
  wikilink-namespace alignment, is unstable under folder moves, and re-creates the id-vs-filename join-bug
  class. Rejected *for Onyx* specifically because the link namespace is bare-filename.
- **Minimal-unique-suffix of the path** (the "URL-shortener" idea: start at the filename, prepend the next
  path segment only on collision — exactly Obsidian's *shortest-unique-path* for link display). Rejected: it
  is *less* stable than a plain path, not more, because of **action at a distance** — adding an unrelated
  third file that collides (`data/trie.md`) forces a *previously-unique* file (`algo/trie.md`) to grow a
  path prefix, silently changing the id of a card that never moved or changed. A move or any collision
  churns unrelated ids; unusable as a durable key.
- **Deck-scoped filename/id** (qualify the id by its deck to dodge collisions). Rejected: it **forks a
  datum's single global state** across overlapping decks — the exact invariant ADR-0019/0020 exist to
  protect (advance-anywhere-advances-everywhere). A card in two decks must have *one* id, so the id cannot
  carry a deck.
- **Mandatory auto-generated opaque GUID everywhere** (the Anki/org-roam model). Durable + portable, but
  it *is* the glue we're removing — heavy for a local-first, Obsidian-native vault. Adopted only at the
  **sharing boundary**, where it's actually required.
- **Content hash.** Rejected (research-confirmed: every edit orphans the schedule). Signal only.
- **Editor-rename-event migration** (the zero-glue plugins). Insufficient: Onyx's runtime file writes and
  folder-sync emit no editor event. Cold-reindex index-diff covers that gap.
- **Keep `id:` mandatory.** Rejected: it's redundant glue for 135/163 cards and blocks the zero-glue,
  self-authored-card goal (#30).

## Consequences

- **Positive:** `id:` becomes optional → zero-glue local cards; `cardId` aligns with the wikilink /
  prereq namespace → kills the id-vs-filename join-bug class (retires the `idByFile` hop over time); a
  clean path to shareable decks via the opaque-id escape hatch (ADR-0021); the 155 shipped cards are
  **byte-identical** (their `id:` is honored).
- **Negative / trade-offs:** bare-filename **collision** risk (guarded by a vault-health warning; none in
  the shipped vault); rename resilience is **best-effort** (cold-reindex index-diff, #158) with a hard
  failure on simultaneous rename + heavy edit (retain-but-detach → re-learn, not loss); until #158 lands,
  a filename-keyed (id-less) card that is renamed orphans its schedule — so id-less authoring is safe to
  *enable* now but the CS cards keep their `id:` until detection ships.
- **Follow-ups:** card-rename detection (**#158**, now card + section grain); mandatory share-id
  (**ADR-0021**); the optional strip-redundant-`id:` chore (post-#158). Card-ness via selector (**#153**,
  engine piece) **landed 2026-09-29** — see below.
- **The zero-frontmatter vault (the realization this unblocks) — engine piece DONE (2026-09-29):** with `id:`
  optional (here) *and* card-ness + flow now driven by the subject's flow **selectors** (`card_parser.dart`:
  a file is a card iff some flow's selector matches its structural attributes; `type:` is taken from the
  claiming flow when absent; no-frontmatter is no longer an auto-skip), a plain Markdown vault with **no
  frontmatter at all** fully functions: the directory *is* the query lens (it decides both card-ness and
  flow), and the filename *is* the identity. `id:`/`type:` are now opt-in overrides, never requirements. The
  **collision guard** shipped (indexer detects two files resolving to one `cardId` — first-wins, skip +
  report, never merge). **Byte-identical for SWE** (its flows use the default `TypeIs` selector). *Remaining
  (product/config, deferred to a design call):* no shipping subject yet *authors* a folder/tag selector, so a
  template needs a way to **designate card-bearing folder(s)/tag(s)** (overlaps #162 + folder-path
  onboarding), and non-card notes (README/MOC) must be kept out of a card folder (skip files lacking the
  expected structure, or an ignore convention) — the two edges directory-based card-ness introduces.

## Open questions (from the research, unresolved by any single source)

- File-level rename-detection accuracy/perf at scale (the only observed impl uses a 6-char truncated hash
  with substring matching at *within-note* card grain; whole-file accuracy is unmeasured).
- The "promote implicit (filename) identity to an explicit opaque id" migration at publish time — no tool
  documents a retroactive promotion path (Anki/org-roam start with the id present).
- Teacher-push reconciliation when a student later renames/edits a pushed card locally (ADR-0021).
- Whether the human-facing card name and the durable id should stay folded (filename = both, our default)
  or decouple when shared (Anki/Mochi/org-roam all decouple a hidden id from the label).

## Validation

- Parser test: a card with `id:` → `cardId` = that id (unchanged); a card with **no** `id:` → `cardId` =
  the filename slug; the shipped-vault cards are byte-identical (their `id:` already equals their filename
  for 135, and is honored verbatim for all).
- (Deferred, #158) rename-detection test: a file renamed with stable content re-attaches its schedule on
  cold reindex; a rename + heavy edit orphans (retain-but-detach) rather than mis-attaching.
