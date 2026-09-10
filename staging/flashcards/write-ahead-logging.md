---
id: write-ahead-logging
type: flashcard
tags:
  - databases
  - durability
  - recovery
  - wal
tiers:
  databases: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Write-Ahead Logging (WAL)

Write-ahead logging is the discipline that makes durable, atomic storage possible on top of unreliable disks and volatile buffers: **before any change to a data page is allowed to reach disk, the log record describing that change must already be durable.** A transaction's commit is defined not by its data pages hitting disk but by its log records — an append-only, sequential stream — being flushed (`fsync`) to stable storage. Because the log is a physically sequential write, WAL converts scattered random page writes into cheap append I/O *and* gives crash recovery an authoritative replay/rollback record. Every mainstream engine (Postgres WAL, InnoDB redo log, SQLite WAL mode, Oracle redo, MySQL binlog is a *separate* logical log) is built on this rule; it is the concrete mechanism behind ACID's **D**urability and **A**tomicity.

> [!tip] Recognition
> Reach for WAL reasoning when you see: "how does a commit survive a crash mid-write," "torn page / partial write on power loss," "`fsync` on every commit is the bottleneck," "group commit / commit latency," "replication or [CDC](_meta/glossary.md#cdc) reading the transaction log," "checkpoint / recovery time," "redo vs undo," or ARIES / LSN / `pageLSN`. Any question about *how durability and atomicity are actually implemented under the hood* is a WAL question.
>
> **vs. mvcc:** MVCC implements Isolation (versions + visibility); WAL implements Durability + Atomicity (log-before-apply + replay/rollback). They are orthogonal and coexist in one engine. **vs. lsm-tree commit log:** an [LSM tree](_meta/glossary.md#lsm-tree)'s commit log is *also* a WAL (durability for the in-memory memtable), but the LSM's SSTables are the primary store, not pages patched in place — see Trade-offs.

## When to Use

**Problem signals that point to WAL / recovery reasoning:**
- "The server lost power right after `COMMIT` returned — is the write still there?" — the defining WAL guarantee: committed = log durable, recoverable on restart
- "A page write was torn in half by a crash (partial 4 KB write)" — WAL replay (and Postgres `full_page_writes`) reconstructs the page
- "Commit throughput is capped by `fsync`/disk latency" — batching commits (group commit) amortizes the flush
- "We need to stream every change to a replica / a search index / Kafka" — read the WAL: logical/physical replication and [CDC](_meta/glossary.md#cdc) tail the same log
- "Recovery after a crash takes too long" — checkpoint frequency vs. redo-replay distance is the tuning knob
- "Explain how a database gives you atomicity without holding the whole transaction in memory" — undo information in the log rolls back uncommitted work

**Prefer WAL over alternatives when:**
- Over **force-at-commit** (writing every dirty data page before commit): WAL's *no-force* policy means commit only flushes the small sequential log, not scattered random pages — dramatically less commit-path I/O
- Over **shadow paging / copy-on-write file** (write new pages, atomically swap a root pointer): WAL supports fine-grained concurrent transactions and in-place updates; shadow paging fragments data and struggles with concurrency (though it needs no log)
- Over **no logging + periodic snapshot**: WAL bounds data loss to un-flushed *in-flight* work, not everything since the last snapshot

**Do not lean on WAL when:**
- The store is already log-structured and immutable (pure append-only event log) — the log *is* the data; a separate WAL is redundant
- You configured `fsync=off` / `synchronous_commit=off` for speed — you have then explicitly traded away the durability WAL exists to provide (fine for regenerable data, fatal for a ledger)

## Key Properties

- **The write-ahead rule (two clauses).** (1) The log record for a change must be on stable storage *before* the modified data page is written to disk. (2) *All* of a transaction's log records must be flushed *before* the commit is acknowledged. Clause 1 buys atomicity (undo); clause 2 buys durability (redo).
- **Commit = log flush, not data flush.** A `COMMIT` writes a commit log record and `fsync`s the log up to that point. The dirty data pages may still be only in the buffer pool; recovery will redo them from the log. This is the **no-force** policy.
- **Redo vs. undo information.** A log record typically carries the *new* value (redo, to reapply a committed change lost from the buffer) and the *old* value (undo, to roll back an uncommitted change that leaked to disk). Which you need is dictated by buffer policy (see Trade-offs).
- **LSN monotonicity.** Every log record has a unique, monotonically increasing **Log Sequence Number (LSN)**. Each data page stores the **`pageLSN`** of the last log record applied to it — recovery compares `pageLSN` on disk to the log record's LSN to decide whether a redo is already durable (idempotent replay).
- **Sequential > random.** The log is one append-only stream, so committing is a sequential disk write; the expensive random writes of data pages are deferred and batched. This is a large part of *why* WAL is fast, not just safe.
- **Idempotent recovery.** Redo and undo must be replayable multiple times (a crash *during* recovery re-runs recovery). `pageLSN` guards redo; **Compensation Log Records (CLRs)** make undo idempotent by logging the undo itself so it is never repeated.
- **Checkpoints bound recovery work.** A checkpoint records a consistent starting point (active transactions + dirty pages) so recovery need not scan the log from the beginning of time — only from around the last checkpoint.

## Common Pitfalls

- **Confusing "written" with "flushed."** `write()` to the OS page cache is not durable; only `fsync`/`fdatasync` (or `O_DSYNC`) forces it to stable media. A WAL that isn't `fsync`ed at commit provides *no* durability guarantee — a classic real-world data-loss bug (and the reason `fsync=off` is dangerous).
- **Assuming the data pages are safe at commit.** They usually are *not* on disk at commit under no-force; they live in the buffer pool and are recovered via redo. Candidates often invert this.
- **Forgetting torn/partial writes.** A crash can leave a page half-written (sectors are atomic, whole pages are not). WAL replay assumes it can reapply changes; Postgres writes a full page image to WAL on the first modification after a checkpoint (`full_page_writes`) precisely to survive this.
- **Believing WAL alone gives isolation.** WAL is durability + atomicity only. Concurrency/isolation is [MVCC](_meta/glossary.md#mvcc) or locking — a separate mechanism.
- **Ignoring the redo-vs-undo/buffer-policy coupling.** Saying "just log the new value" is wrong under a *steal* policy: if an uncommitted change's page reached disk, you need the *old* value to undo it. Steal ⇒ undo required; no-force ⇒ redo required.
- **Unbounded log growth.** WAL segments can only be recycled/archived once a checkpoint has flushed the pages they cover *and* every consumer (replication slot, archiver, backup) has read them. A stuck replica or inactive slot pins the log and fills the disk.
- **Treating the replication log as the same object as the redo log.** In MySQL the crash-recovery **redo log** (InnoDB, physical) and the replication **binlog** (server-level, logical) are two different logs kept in sync by an internal 2PC. Conflating them is a common interview slip.

## Trade-offs

**Buffer-management policy — the axis that decides what the log must contain (Steal/No-Force is the standard, ARIES, choice):**

| Policy | Meaning | Recovery need | Cost / benefit |
|---|---|---|---|
| **Steal** | A dirty page of an *uncommitted* txn *may* be evicted to disk | Must log **undo** (old value) to roll it back | Frees buffer memory freely; needs undo |
| **No-steal** | Uncommitted dirty pages pinned until commit | No undo needed | Simpler recovery, but pins buffers / limits txn size |
| **Force** | All dirty pages of a txn flushed *at commit* | No redo needed | Durable trivially, but slow commit (random I/O) |
| **No-force** | Dirty pages flushed lazily (checkpoint/eviction) | Must log **redo** (new value) to reapply | Fast, sequential commit; needs redo |

- **Steal + No-force** is what every serious engine uses: best runtime performance (lazy, sequential I/O), at the cost of needing *both* undo and redo in the log and a real recovery algorithm (ARIES).
- **Commit latency vs. throughput — group commit.** `fsync` per transaction serializes commits behind disk latency. **Group commit** batches many transactions' log records into one `fsync`, trading a little latency for far higher throughput. Postgres `commit_delay`/`commit_siblings`, MySQL `binlog_group_commit_sync_delay` expose this.
- **Durability vs. speed.** `synchronous_commit=off` (Postgres) or `innodb_flush_log_at_trx_commit=2` (MySQL) return commit *before* the log is durable — bounded data loss window in exchange for throughput. A deliberate, situational trade.
- **Checkpoint frequency.** Frequent checkpoints ⇒ short recovery (little redo to replay) but steady background write I/O and more full-page images; rare checkpoints ⇒ cheap steady state but long, painful recovery.
- **vs. LSM commit log.** An [LSM tree](_meta/glossary.md#lsm-tree) also fronts its memtable with a WAL for durability, but its *primary* durability comes from flushing immutable SSTables; the WAL only protects the not-yet-flushed memtable and is discarded after a memtable flush. A B-tree engine, by contrast, updates pages *in place*, so its WAL must protect every page mutation and drives full ARIES-style recovery.

## Implementation Notes

**ARIES recovery — three passes over the log** (the canonical redo/undo/no-force algorithm; the mental model to reconstruct in an interview):

```text
Start from the last CHECKPOINT (not the start of the log).

1. ANALYSIS  (scan forward from last checkpoint -> end of log)
     rebuild the Transaction Table  (who was live/uncommitted at crash)
     rebuild the Dirty Page Table   (which pages may be stale on disk,
                                      each with its recLSN = first dirtying LSN)

2. REDO      (scan forward from the smallest recLSN in the Dirty Page Table)
     REPEAT HISTORY: replay EVERY logged change (even uncommitted ones)
     skip a record if page.pageLSN (on disk) >= record.LSN   <- already durable
     -> database now reflects exact state at crash time

3. UNDO      (scan backward, for LOSER transactions only = live-but-not-committed)
     apply inverse of each of their changes
     write a Compensation Log Record (CLR) per undo, so undo is idempotent
        (a crash during recovery resumes via the CLR's UndoNextLSN, never redoing an undo)
```

- **Key ARIES ideas:** *redo repeats history* (replay committed *and* uncommitted work first, then undo the losers) — this keeps the algorithm simple and correct with fuzzy checkpoints and steal/no-force. `pageLSN` makes redo idempotent; CLRs make undo idempotent.
- **Postgres specifics:** WAL lives in `pg_wal/` as 16 MB segments; `synchronous_commit`, `wal_level` (`minimal`/`replica`/`logical`), and `full_page_writes` are the load-bearing knobs. Logical decoding turns physical WAL into a logical change stream for [CDC](_meta/glossary.md#cdc)/logical replication.
- **InnoDB specifics:** a circular physical **redo log** (`ib_logfile`/redo files) plus per-row **undo logs** (in the undo tablespaces, also feeding MVCC read-views). Redo + undo are separate structures here.
- **WAL as the source of truth for replication/CDC:** streaming/physical replication ships WAL records to replicas that replay them; logical replication and CDC tools (Debezium, Postgres logical decoding) parse the same log into row-level change events — the log is the system's ordered history, so it doubles as the change feed.

## Variants

- **Physical logging** — logs byte/page-level before-and-after images (e.g. InnoDB redo). Simple, idempotent, but verbose and engine-version-specific.
- **Logical logging** — logs the operation (`UPDATE ... WHERE id=…`) or row-level change (MySQL binlog ROW format, Postgres logical decoding). Compact and portable across replicas/consumers; harder to make crash-idempotent, so usually used for replication rather than low-level recovery.
- **Physiological logging** — ARIES' hybrid: *physical across pages, logical within a page* (log "insert this record on page P," not exact bytes). Balances compactness and idempotency; the industry standard.
- **LSM commit log** — a WAL guarding only the in-memory memtable, discarded after the memtable is flushed to an SSTable (see Trade-offs / [[lsm-tree]]).

## Resources

- Mohan et al., *ARIES: A Transaction Recovery Method Supporting Fine-Granularity Locking and Partial Rollbacks Using Write-Ahead Logging* (1992) — https://cs.stanford.edu/people/chrismre/cs345/rl/aries.pdf
- Kleppmann, *Designing Data-Intensive Applications*, Ch. 3 (B-tree WAL / redo log) & Ch. 7 (atomicity, durability) — grounding
- PostgreSQL docs — Ch. 28 Reliability and the Write-Ahead Log: https://www.postgresql.org/docs/current/wal-intro.html
- MySQL InnoDB Redo Log: https://dev.mysql.com/doc/refman/8.0/en/innodb-redo-log.html
- CMU 15-445 — Logging Schemes & ARIES lecture notes: https://15445.courses.cs.cmu.edu/fall2018/notes/20-logging.pdf

## Related

- [[acid-properties]]
- [[mvcc]]
- [[lsm-tree]]
- [[b-tree]]
- [[database-replication]]
- [[change-data-capture]]
- [[checkpointing]]
