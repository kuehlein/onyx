# ADR 0021 — Registry sync & teacher-push: account-based upstream, lens-as-filter, overwrite-on-pull, iTIP aims

- **Status:** Accepted *(the contract is decided; the push/pull **machinery is post-MVP and gated** on the
  #83 server — see Consequences. This ADR resolves the shape of the parked decision so dependent work stops
  being blocked on an undecided contract.)*
- **Date:** 2026-09-28
- **Deciders:** Kyle Uehlein (+ AI-assisted scaffolding; 3 adversarial research passes)
- **Related:** **Resolves the "Sync & source-of-truth" open decision** in `docs/user_stories/index.md`.
  Built on **ADR-0019** (config/state split, `_onyx/` layout) + **ADR-0020** (deckId-free datum key,
  retain-but-detach, id identity). Extends **ADR-0003** (draft-gate + content-only inflow), **ADR-0002**
  (on-device source). Depends on **ADR-0001** (convergent merge). Tasks: **#152** (shareable/teacher aims),
  **#83** (registry server), **#63/#84** (authoring-kit/parse-profile distribution). Code:
  `lib/core/registry/` (`import_deck.dart`, `deck_update.dart`, `registry_client.dart`),
  `lib/shared/providers/registry*.dart`, `lib/core/deck/deck_store.dart`, `lib/features/home/target_sheet.dart`
  (aim id minting), `lib/core/vault/desktop_vault_source.dart` (enumeration).

## Context

The long-term direction is a teacher/registry that pushes study material to students (#30/#152), and the
parked decision — *"when a deck is pulled from upstream, who owns truth (publisher vs puller)? read-only or
free local edits? how to handle modified upstream content?"* — blocks it. This ADR settles that contract.
Facts a reviewer needs (verified):

- **A client-side registry already exists and is ~80% aligned.** A deck travels as a structure-preserving
  file tree (`DeckFile{path, content}`), content-only by construction ("scheduling never travels",
  invariant #3), pulled cards land `status: draft`, and a content-diff reconciler with tombstones exists
  (`deck_update.dart`). Two gaps: the importer **collapses the tree under a new `<deckSlug>/` folder** and
  stamps a `deck:` frontmatter key (not "merge at the same relative paths"); and reconcile keys on **path**
  (a moved card = delete+add = orphaned curve) and has **no persisted previous-manifest** (the deletion
  logic is un-wired dead code).
- **Aims have no transport and a broken foundation.** Aims live in app-managed `_meta/study-goals.json`
  as one whole-file-**LWW blob** (`deck_store.dart` re-encodes the array); aim ids are **device-local
  wall-clock counters** (`aim-${microsecondsSinceEpoch}`, target_sheet.dart); there is no
  provenance/SEQUENCE/overlay concept anywhere. So the solo multi-device case already **silently loses aim
  edits** — before any teacher-push exists.
- **Folder-sync conflict copies already corrupt the vault.** Nothing detects `*.sync-conflict-*.md` /
  `"card 2.md"` / `(conflicted copy)`; because Onyx sits on top of the user's iCloud/Dropbox/Obsidian
  Sync, such files get parsed as **brand-new cards with fresh ids + empty history**. ADR-0001 names this
  for the state file in the *solo* case — it bites before teacher-push.

## Decision

### 1. Ownership model — accounts + ACL on an upstream vault (resolves the parked decision)

- An **upstream vault** has per-account **read/write access** (server-side ACL, #83). **Write** → may
  push; **read** → may pull. Multi-author (teacher + TA) = multiple write-accounts on **one** upstream;
  the student pulls one coherent vault. A student in several classes pulls **several** upstreams
  (client-side aggregation).
- **Publisher owns pushed content + aim definitions** (authoritative). **Puller owns all state + their
  local edits + their aim overlay.**
- **No client-side content lock; local edits are PROTECTED.** A read-only puller may freely edit pulled
  cards locally (elaborate, add sections) — it's *their* vault. When a pull brings an upstream change to a
  card the student has **also edited locally** — detected as a true 3-way conflict via the last-synced
  content hash (base) vs local (ours) vs incoming (theirs) — Onyx **never silently clobbers**: it surfaces a
  **git-style conflict resolution** with three choices — **take upstream** (clobber local), **merge both**,
  or **cancel** (keep local, skip this update). Non-conflicting pulls (the student didn't touch the card)
  apply cleanly. State + student-authored cards are never touched regardless (§3).

### 2. Export — the lens IS the transfer filter (selection only)

- Publish resolves the deck's `CardQuery` to a **concrete path manifest** on the exporting device (the
  `--files-from` shape) and copies exactly those files **preserving relative directory structure** (drop
  the `<deckSlug>/` collapse and the import-time `deck:` stamp — the datum key is deckId-free, ADR-0020).
- Broadening/narrowing the lens re-resolves the manifest → more/fewer files travel. The manifest is
  **hashed for incremental delta** (only changed/added blobs move — the git sparse-checkout + partial-clone
  shape). Symlink/cycle-safe (the enumeration already walks `followLinks: false`).
- The lens is a **selection** predicate. It is **not** the deletion or overwrite authority (§3).

### 3. Reconciliation — id-keyed, overwrite pulled content, never touch state or student files

The pull-merge the lens does *not* perform:

- **Match on frontmatter `cardId`, not path.** Same id + new path = **move** → update in place, **keep the
  curve**. Same id + same path, student **hasn't** edited it = **clean update** (apply upstream). Same id,
  student **has** edited it (local hash ≠ last-synced) = **conflict** → the §1 three-way resolution
  (take-upstream / merge / cancel), **never a silent overwrite**. Same path + **different** id = **collision**
  (a student's own card at a pulled path) → **refuse/quarantine** (git's "would be overwritten, aborting").
- **Deletion authority is scoped to the last-synced manifest** (persist it per subscription): a datum is
  removed only if it **was in the previous manifest AND is absent now AND is unmodified pulled content** —
  **never** on lens-absence, **never** a student-authored/-modified file. A removed datum's schedule goes
  **retain-but-detach** (ADR-0020: dormant, inert, resurrectable), not deleted.
- **State never travels and is never overwritten:** FSRS schedules, the review log, and the aim **overlay**
  (§4) are the learner's; a pull writes only content + config, never state.
- **Conflict-copy detection at enumeration** (`*.sync-conflict-*`, `" N.md"`, `(conflicted copy)`,
  case-only path collisions): don't mint new ids into them, report a count in a sync summary. **Land this
  now** — it's orthogonal to teacher-push and already bites the solo multi-device case.

### 4. Aims — iTIP: author-owned definition + puller-owned overlay, one-way publish

Model teacher-pushed aims on iCalendar iTIP (the calendar-invite model):

- An aim splits into a **DEFINITION** (author-owned, read-only, travels as config: stable **UID** +
  monotonic **SEQUENCE** + **exactly one author/provenance** + title + assessment type + date/rounds) and
  a per-consumer **OVERLAY** (learner-owned **state**: `status` {needsAction, accepted, declined,
  tentative} + importance + outcomes/notes + the common-ancestor base). The overlay is layered at read
  time and **never round-trips upstream**.
- **One-way PUBLISH only** (no REQUEST/COUNTER back-channel) — works offline, needs no server round-trip
  beyond the pull. **Co-authored aims are forbidden** (one author per UID; a teacher's midterm and a TA's
  quiz are two aims). Self-authored aims are the degenerate single-source case (no overlay, no merge).
- **Significant-change gate:** a change to the **date/rounds/target** bumps SEQUENCE and flips the overlay
  to **needsAction**, which **gates the engine** — the pushed date must **not** feed
  `daysUntilInterview` → the desired-retention ramp (ADR-0008) or cross-deck allocation (ADR-0018) until
  the student re-accepts. A cosmetic change (title/notes) does **not** re-gate (auto-carry the prior
  status). This is the standards-aligned form of "a teacher date-change gates FSRS-adjacent scheduling."
- **Prerequisites (some do-now, independent of push):** aim + round ids become **stable,
  provenance-namespaced UIDs** (not device-local wall-clock); `study-goals.json`/`aims.json` gets a
  **per-id keyed merge** replacing the whole-file LWW (fixes the live solo-multi-device aim-loss). These
  land with ADR-0019's per-deck split + device id.

## Alternatives considered

- **Read-only lock on pulled content.** Rejected: it's the learner's vault; forbidding a student from
  elaborating a card is user-hostile.
- **Silent overwrite-on-pull** (clobber local edits). Rejected: it silently destroys a student's
  elaborations. The last-synced manifest already stores per-file hashes, so a true 3-way base/ours/theirs is
  cheap to detect; **protecting edits with a git-style choice (take-upstream / merge / cancel) is the decided
  model.** The full merge UI may land after a simpler interim (Consequences), but the default must **never**
  silently clobber.
- **Lens as the deletion authority ("not in the incoming subset → delete").** Rejected — catastrophic: it
  wipes the student's own out-of-lens and student-authored cards. Deletion is scoped to the last-synced
  manifest + unmodified-pulled-content only.
- **Aims travel as whole records (definition + the student's status together).** Rejected — clobbers the
  student's accept/decline/importance/outcomes on every re-push (the Nextcloud/Canvas re-import regression).
  Definition and overlay must be separate ownership layers.
- **Multiple organizers per aim (true co-authoring).** Rejected — iCalendar forbids it precisely because
  there's no clean multi-owner conflict model; multi-author = many single-author aims, aggregated.
- **Keep path-keyed reconcile + the `<deckSlug>/` collapse.** Rejected: path-keying orphans the curve on
  any move/rename and blocks true same-relative-path merge; the deckId-free datum (ADR-0020) makes the
  `deck:` stamp unnecessary.

## Consequences

- **Positive:** a clear, standards-grounded ownership contract (publisher owns content + aim definitions;
  puller owns state + overlay + local edits) unblocks the whole registry track; the lens doubles as the
  sync filter (no separate include/exclude language); id-keyed reconcile follows renames without orphaning
  curves; overwrite-on-pull is simple and provably safe for state; conflict-copy detection closes a live
  corruption path now; iTIP aims give teacher-push + multi-source aggregation without clobbering the learner.
- **Negative / trade-offs:** protecting local edits needs the persisted per-file-hash manifest + a conflict
  resolution UI (a real, if bounded, build); requires the aim-storage/identity rebuild (per-id merge + stable
  UIDs) and the persisted per-subscription manifest before any push; the incremental transport + the
  account/ACL server are net-new (#83) and remain **gated**.
- **Known limitations & follow-ups:** the **server + accounts/ACL + incremental wire** (#83) is unbuilt and
  is the gate for the *push/pull* machinery; the **interim** before the full three-choice merge UI ships is
  to **keep the student's copy and flag it** on a detected conflict (never auto-clobber) — the safe default
  that honors "protect" without the merge engine; **managed-AI/billing** and the **public deck tier**
  (moderation/COPPA) stay Phase-5 defer-hard. **Do-now, ungated slices** (they fix live solo-multi-device
  bugs and need no server): conflict-copy detection; the aim per-id merge + stable UIDs; the id-keyed
  reconcile rewrite + persisted manifest (wire it even before a server, against the existing `FakeRegistryClient`).

## Validation

- Reconcile tests (against `FakeRegistryClient`): same-id moved card keeps its curve; same-path/different-id
  collision is refused/quarantined; a clean update (student didn't touch the card) applies; a **conflict**
  (student edited it) never silently clobbers — it raises the three-way choice, and the interim keeps the
  local copy + flags it; the datum's state + a student-authored sibling stay untouched; a datum dropped from
  the manifest goes dormant (ADR-0020), not deleted; deletion never fires on mere lens-absence.
- Conflict-copy test: `*.sync-conflict-*` / `" 2.md"` files are detected, not ingested as new cards, and
  counted in the summary.
- Aim iTIP tests: a definition re-push with a higher SEQUENCE on the **date** flips the overlay to
  needsAction and does not feed the retention ramp until re-accept; a cosmetic re-push preserves accepted
  status + all overlay fields (the anti-clobber guarantee); a per-id aim merge converges across two devices
  (no whole-file LWW loss). Self-authored aims round-trip with no overlay.
