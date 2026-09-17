# ADR 0001 — Progress sync via a convergent snapshot merge

- **Status:** Accepted
- **Date:** 2026-09-17
- **Deciders:** Kyle Uehlein (+ AI-assisted scaffolding)
- **Related:** `docs/registry-and-sync.md` §2 (sync), `docs/product-direction.md` §7,
  `docs/ux-rework-stage1.md` P0-6; code: `lib/core/backup/snapshot.dart`,
  `lib/shared/providers/backup.dart`. Phase 0 of `docs/roadmap.md`.

## Context

Onyx is local-first: the durable store is the user's folder, and the SQLite DB is a
derived cache. To let progress survive a lost DB and follow the user across devices,
`SnapshotService` writes study progress to `_meta/onyx-state.json` in the folder
(debounced after each review) and reads it back. The folder is expected to be synced
by the user's own tooling (iCloud Drive, Obsidian Sync, git, Dropbox).

The pre-existing implementation was **last-write-wins on the whole blob**, and this
silently corrupts progress across two devices:

- `export()` serialized *all* rows and overwrote the file.
- `restore()` did `DELETE *` then bulk-insert (replace-with-remote).
- `startupRestore` only ran **when the local DB was empty**.

So a second device never merged an incoming snapshot, and its next `export()`
overwrote the file — **the last device to export wins the entire blob; the other
device's progress since the last common state is lost.** This violates the honest-
readiness principle (a number silently reverts) and is a live data-loss bug, not a
future concern.

The relevant schema (`lib/core/database/tables.dart`): `SrsStates` and
`RecognitionStates` are **keyed state** (PK `(cardId, sectionSlug)`), each carrying a
recency timestamp (`lastReview`, `lastExplainedAt`); `Reviews` and `AppliedAttempts`
are **append-only event logs** (autoincrement `id` + a natural event key).

## Decision

Replace blob-LWW with a **convergent merge** — a CRDT-style operation that is
**commutative, idempotent, and convergent**, so any two devices exchanging snapshots
in any order, any number of times, reach the same result with no data loss.

The core is a **pure function** `mergeSnapshots(a, b)` over two decoded snapshot
payloads (`lib/core/backup/snapshot.dart`):

- **Keyed state** (`srsStates`, `recognitionStates`) → **last-review-wins** per
  section key `(cardId, sectionSlug)`: keep the side with the later recency stamp
  (`lastReview` / `lastExplainedAt`), tie-broken by the higher `reviewCount`. A
  section studied on two devices keeps the newer schedule; neither reverts.
- **Event logs** (`reviews`, `appliedAttempts`) → **union** by a natural event key
  (`(cardId, sectionSlug, reviewedAt)`; `(cardId, sectionSlug, occurredAt, source)`).
  No history is dropped; re-merging is a no-op. Output lists are sorted by key for a
  deterministic, churn-free file.

It is wired non-destructively at both boundaries:

- **`export()` = read-merge-write:** merge the on-disk snapshot with the local DB
  payload before writing, so a snapshot that arrived from another device but has not
  yet been imported is preserved rather than clobbered.
- **`restore()` = merge-into-DB:** merge the snapshot with the local payload, then
  rewrite the tables from the **union**. The `DELETE *`+insert is retained but is now
  safe, because it replaces the DB with a superset of local (never "remote wins").
- **`startupRestore` runs the merge whenever a snapshot exists**, not only on an
  empty DB.

`goals` (`_meta/study-goals.json`, owned by `GoalStore`) already live in the folder
and sync at the file level; they are out of scope for this snapshot and tracked
separately.

## Alternatives considered

- **Per-device snapshot files (`onyx-state.<deviceId>.json`) + glob-merge on import.**
  The fully conflict-free design: no two devices write the same file, so folder-sync
  never produces conflict copies. Closest alternative and the likely evolution — but
  it needs a stable device id and a multi-file read path. Deferred; the merge core
  here is exactly what a glob-merge would fold over, so no rework is wasted.
- **Single-file, blob LWW (status quo).** Rejected — the data-loss bug above.
- **Full operation-log CRDT / vector clocks.** Over-engineered for two-to-few
  personal devices; last-review-wins on state + union on events is sufficient and far
  simpler to verify.

## Consequences

- **Positive:** no silent cross-device progress loss; deterministic, order-independent
  convergence; the merge is a pure function, so correctness is proven by fast unit
  tests with no DB; deterministic file output reduces sync churn. Reuses the existing
  (de)serialization — a small, contained diff.
- **Trade-offs:** `startupRestore` now does a merge+rewrite on every launch when a
  snapshot exists (bounded, acceptable). Last-review-wins can discard the *older*
  side's schedule for a section studied on both devices before either synced — this
  is the correct, honest resolution (newest study wins), not data loss (both devices'
  *review events* are still unioned into history).
- **Known limitations / follow-ups:** two devices exporting to the *same* file truly
  concurrently still race at the filesystem layer; folder-sync tools resolve that by
  creating conflict copies (`onyx-state (conflicted copy).json`). Importing all
  matching snapshot files (or the per-device-file design above) closes this gap — a
  Phase-0/cloud-track follow-up. Also out of scope: goals in the payload; account-
  mediated sync (see `docs/registry-and-sync.md`).

## Validation

- **Pure merge properties** (`test/unit/snapshot_merge_test.dart`, no sqlite): union
  (no event loss), idempotence `merge(x,x)≈x` and `merge(merge(a,b),b)≈merge(a,b)`,
  commutativity (same result set either order), last-review-wins, reviewCount
  tie-break, event dedup, and empty/missing-key handling.
- **Two-device convergence** (`test/unit/snapshot_test.dart`, in-memory DB): device A
  studies X and exports; device B studies Y, restores (merge), and ends with **both**
  X and Y; a subsequent A-restore also converges to X+Y — the exact scenario the old
  blob-LWW corrupted.
