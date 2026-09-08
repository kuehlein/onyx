---
id: mvcc
type: flashcard
tags:
  - databases
  - transactions
  - mvcc
tiers:
  databases: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Multi-Version Concurrency Control (MVCC)

MVCC lets a database serve each transaction a consistent point-in-time snapshot without readers and writers blocking each other. Instead of overwriting a row in place, a write creates a *new version* of the row and leaves the old one intact; each version is tagged with the transaction that created it (and, once superseded, the transaction that deleted it). A reader then consults *visibility rules* against its snapshot to decide which single version of each row it is allowed to see. This is how virtually every modern OLTP engine (Postgres, InnoDB, Oracle, SQL Server RCSI) implements **snapshot isolation** — DDIA Ch.7's "readers never block writers, writers never block readers."

> [!tip] Recognition
> Reach for MVCC reasoning when you see: "reader sees stale/old data mid-transaction," "long-running analytics query on a live OLTP table," "readers-don't-block-writers," row-version tags (`xmin`/`xmax`, undo logs), table *bloat* / `VACUUM` / autovacuum tuning, or "could not serialize access" / write-skew anomalies. Any question about *how snapshot isolation actually works under the hood* is an MVCC question.

## When to Use

**Problem signals that point to MVCC / snapshot isolation:**
- "A long analytical read must not block concurrent writes (or vice versa)" — the defining win of MVCC over lock-based concurrency
- "Each transaction should see a stable, consistent view for its whole duration" — repeatable reads without holding read locks
- "We're seeing table bloat / autovacuum can't keep up / dead tuples" — an operational symptom that only makes sense once you understand version retention
- "Two transactions read-modify-write the same row and one silently lost its update" — lost update / write skew, whose fix depends on the MVCC isolation level
- "Why did my transaction abort with `could not serialize access due to concurrent update`?" — first-updater-wins under RR/serializable on an MVCC engine

**Prefer MVCC (snapshot isolation) over alternatives when:**
- Over two-phase locking ([[two-phase-locking]]): read-heavy or mixed workloads where read locks would serialize everything — MVCC removes reader/writer contention entirely
- Over READ UNCOMMITTED / dirty reads: you need each transaction to see only committed data as of a consistent instant, with no torn reads
- Over application-level snapshotting: the engine gives you a transactionally consistent snapshot for free, cheaper and more correct than copying data

**Do not rely on plain snapshot isolation when:**
- You need **serializability** — SI alone permits **write skew** and phantom anomalies (DDIA Ch.7). Use SERIALIZABLE (Postgres SSI) or explicit locking (`SELECT ... FOR UPDATE`).
- The workload is write-mostly with high row churn → version accumulation and GC/`VACUUM` become the bottleneck; consider an [[lsm-tree]] store or partition/TTL strategy.
- You assumed "REPEATABLE READ = serializable." It does not; the SQL-standard names are weaker than their intuitive meaning.

## Key Properties

- **Version chain per logical row.** A row is a chain of physical versions ordered newest→oldest. A write appends a version; it does not mutate the current one in place (Postgres) or logs the prior image to undo (InnoDB).
- **Visibility metadata.** Each version carries the creating transaction id and (once deleted/updated) the deleting transaction id. In Postgres these are the tuple's `xmin` / `xmax`.
- **Snapshot = the set of transactions considered committed at snapshot time.** A version is visible iff its creator is committed-and-in-snapshot **and** its deleter is *not* (i.e. `xmin` visible, `xmax` null or not-yet-visible).
- **Readers-don't-block-writers, writers-don't-block-readers.** A reader picks an old version; a concurrent writer creates a new one. The only blocking is writer-vs-writer on the *same* row.
- **Isolation levels differ only in when the snapshot is taken.** READ COMMITTED takes a fresh snapshot per statement; REPEATABLE READ / SNAPSHOT takes one snapshot at transaction (or first-statement) start and reuses it.
- **Write conflicts still need arbitration.** Two concurrent writers to one row are resolved by **first-updater/first-committer-wins**: the second either blocks then aborts (RR: `ERROR: could not serialize access due to concurrent update`) or overwrites (READ COMMITTED re-reads the new version).
- **Dead versions must be reclaimed.** Old versions no longer visible to any live snapshot are garbage; a GC process (Postgres `VACUUM`/autovacuum, InnoDB purge thread) frees them. Retention is bounded by the *oldest running transaction's* snapshot.

## Common Pitfalls

- **Assuming REPEATABLE READ prevents all anomalies.** It stops dirty reads, non-repeatable reads, and (via first-updater-wins) lost updates — but **not write skew or phantoms** under pure SI. Only SERIALIZABLE does. Classic interview trap.
- **Ignoring the long-running-transaction → bloat link.** In Postgres, one forgotten idle-in-transaction (or an open replication slot / `hot_standby_feedback`) pins the oldest snapshot, so `VACUUM` cannot remove *any* newer dead tuples system-wide. Tables bloat and scans slow even though rows were "deleted."
- **Confusing `UPDATE` with cheap in-place mutation.** In Postgres every `UPDATE` writes a whole new tuple and marks the old one dead — an update is delete+insert internally. High update rates on wide rows generate heavy bloat and index churn.
- **Forgetting index entries point at versions too.** A non-HOT Postgres update must add index entries for the new tuple; only a **HOT update** (new version fits on the same heap page *and* no indexed column changed) skips new index entries.
- **Treating `SELECT COUNT(*)` as free.** Because visibility is per-tuple, Postgres can't get an exact count from a secondary index alone; it must check visibility of matching rows (index-only scans help only when the visibility map marks pages all-visible).
- **Believing MVCC eliminates locks.** It removes *read* locks; row-level *write* locks and, in InnoDB at RR, **gap / next-key locks** still exist and still cause deadlocks.

## Trade-offs

**Version storage location — heap vs. undo (the central design fork):**

| | Postgres (heap versioning) | InnoDB / Oracle (undo versioning) |
|---|---|---|
| New version lives | In the table heap alongside old versions | In place; old image logged to undo/rollback segment |
| Reading latest row | Cheap (latest is in the heap) | Cheap |
| Reading old snapshot | Cheap (older heap tuple) | Costlier: reconstruct by walking undo backward |
| Cleanup mechanism | `VACUUM` / autovacuum reclaims dead tuples | Background **purge** thread trims undo |
| Failure mode | Table/index **bloat**, autovacuum tuning, XID wraparound risk | Undo/history-list growth from a long RR reader stalls the purge thread |
| Rollback cost | Cheap (just don't commit; tuple already dead) | Must apply undo to revert |

- **Read concurrency vs. space/GC cost.** MVCC buys lock-free reads at the price of storing and later collecting multiple versions. Write-heavy churn amplifies this.
- **Postgres vs. InnoDB defaults.** Postgres defaults to **READ COMMITTED**; InnoDB defaults to **REPEATABLE READ**. Same underlying MVCC, different default snapshot lifetime and different phantom handling.
- **Phantom prevention style.** Postgres RR prevents non-repeatable reads via the snapshot and detects concurrent-update conflicts by aborting; InnoDB RR additionally uses **gap/next-key locks** to physically block inserts into scanned ranges (blocks writers, reduces concurrency) — but plain reads still see the snapshot.

## Implementation Notes

**Postgres — tuple headers and the visibility check:**
```
-- Each heap tuple header carries:
--   xmin : XID that inserted this version
--   xmax : XID that deleted/updated it (0 if live)
-- A tuple is visible to my snapshot iff:
--   xmin is committed AND < my snapshot's horizon AND not in my in-progress set
--   AND (xmax = 0  OR xmax aborted  OR xmax not yet visible to me)
```
- Commit state of an XID lives in the **commit log (`clog`/`pg_xact`)**; **hint bits** cache "known committed/aborted" on the tuple so later reads skip the clog lookup.
- **`VACUUM`** marks dead tuples reusable and updates the **visibility map** (enabling index-only scans and freeze); it does *not* shrink the file. `VACUUM FULL` rewrites the table to reclaim disk but takes an ACCESS EXCLUSIVE lock.
- **XID freezing / wraparound:** XIDs are 32-bit and wrap; autovacuum must "freeze" old rows (`FrozenTransactionId`) before `autovacuum_freeze_max_age`, or the DB force-shuts to prevent data loss. This is a uniquely Postgres MVCC hazard.

**InnoDB — undo-based versioning:**
- Each row has hidden `DB_TRX_ID` (last writer) and `DB_ROLL_PTR` (pointer into the undo log). A snapshot read follows `DB_ROLL_PTR` back through undo to reconstruct the version visible to its **read view**.
- Old undo is reclaimed by the **purge thread** once no read view needs it; a long RR transaction stalls purge and inflates the undo/history list.

**Serializable on top of SI — Postgres SSI (v9.1+):**
- SERIALIZABLE uses **Serializable Snapshot Isolation**: normal snapshot reads plus lightweight `SIREAD` predicate "locks" that track read/write dependencies. It does not block; instead it detects a *dangerous structure* (two adjacent rw-antidependencies among transactions) and aborts one with a serialization failure. Application must retry.
- Cost is near SI on read-heavy workloads and far cheaper than two-phase locking — but requires retry loops in the app.

## Variants

- **Snapshot Isolation (SI):** the baseline MVCC isolation guarantee; permits write skew. (Oracle "SERIALIZABLE" and SQL Server SNAPSHOT are actually SI.)
- **Serializable Snapshot Isolation (SSI):** SI + rw-conflict detection → true serializability (PostgreSQL SERIALIZABLE).
- **Read Committed Snapshot Isolation (RCSI):** SQL Server option that makes READ COMMITTED use row versions (in `tempdb`) instead of shared read locks.
- **Heap versioning vs. undo/rollback-segment versioning:** the two families above (Postgres vs. InnoDB/Oracle).

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch.7 (Weak Isolation: Snapshot Isolation, Write Skew, Serializability) — the canonical grounding
- PostgreSQL docs — 13.2 Transaction Isolation: https://www.postgresql.org/docs/current/transaction-iso.html
- PostgreSQL docs — 25.1 Routine Vacuuming (dead tuples, freeze, wraparound): https://www.postgresql.org/docs/current/routine-vacuuming.html
- MySQL InnoDB Multi-Versioning: https://dev.mysql.com/doc/refman/8.0/en/innodb-multi-versioning.html

## Related

- [[snapshot-isolation]]
- [[acid-properties]]
- [[transaction-lifecycle]]
- [[two-phase-locking]]
- [[database-indexing]]
- [[lsm-tree]]
