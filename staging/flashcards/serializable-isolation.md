---
id: serializable-isolation
type: flashcard
tags:
  - databases
  - transactions
  - isolation
  - concurrency-control
tiers:
  databases: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Serializable Isolation

[SERIALIZABLE](_meta/glossary.md#serializability) is the strongest isolation level: it guarantees that even though transactions run concurrently, the end result is *as if* they had run one at a time in some serial order. This is the level that eliminates the anomalies weaker levels leave open — most importantly [write skew](_meta/glossary.md#write-skew) and [phantoms](_meta/glossary.md#phantom-read), which [snapshot isolation](_meta/glossary.md#snapshot-isolation) / REPEATABLE READ still permit. There are three ways to actually achieve it (DDIA Ch. 7): **literal serial execution** (one thread, no concurrency), **[two-phase locking (2PL)](_meta/glossary.md#two-phase-locking)** (pessimistic — block until safe), and **[Serializable Snapshot Isolation (SSI)](_meta/glossary.md#serializable-snapshot-isolation)** (optimistic — let transactions run on a snapshot, detect conflicts, abort losers). They differ enormously in performance but all deliver the same correctness contract.

> [!tip] Recognition
> Reach for serializable reasoning when you see: an invariant spanning **multiple rows the transaction only read** ("at least one doctor on call," "no double-booking," "balance ≥ 0 across accounts"), a read-decide-write that a *concurrent* transaction can invalidate, the phrase **"write skew,"** **"phantom,"** "I used REPEATABLE READ but the constraint was still violated," or `ERROR: could not serialize access due to read/write dependencies`. The tell for a *true* serializability need (not just SI): the anomaly comes from acting on a **query result that a concurrent write changes**, where the two transactions touch *different* rows so no single-row write conflict catches them.
>
> **vs. snapshot-isolation / repeatable-read:** SI gives each txn a consistent snapshot and prevents dirty/non-repeatable reads and (via first-writer-wins) lost updates — but it does **not** prevent write skew or phantoms, because two txns reading the same set and writing *different* rows never collide. SERIALIZABLE closes exactly that gap. **vs. mvcc:** [MVCC](_meta/glossary.md#mvcc) is the versioning *mechanism*; SSI is MVCC-plus-conflict-detection that upgrades SI's guarantee to serializable.

## When to Use

**Problem signals that demand SERIALIZABLE (not just SI/RR):**
- **Write skew:** two transactions read an overlapping set, each decides based on what it read, then each writes to a *different* row — jointly violating an invariant. Classic: two on-call doctors both check "is anyone else on call?", both see yes, both go off-call → zero coverage.
- **A constraint across rows the transaction did not modify** — e.g. "sum of withdrawals must not overdraw," "no two bookings overlap," "username unique" enforced by a `SELECT ... WHERE`.
- **Phantoms:** a transaction's decision depends on the *absence* of rows matching a predicate, and a concurrent insert adds one (materializing a conflict SI can't see).
- "We set REPEATABLE READ / relied on the snapshot and the invariant was **still** violated under concurrency."

**Prefer SERIALIZABLE over alternatives when:**
- Over snapshot isolation / RR: the invariant is a **cross-row / predicate** constraint (write skew or phantom territory) — SI structurally cannot prevent these.
- Over hand-rolled `SELECT ... FOR UPDATE` locking: when you'd otherwise have to remember to lock *every* read path correctly; SERIALIZABLE makes correctness the engine's job, and materializing-conflict locks are error-prone to place by hand.

**Do not use when:**
- The workload is high-throughput and contention-heavy and eventual/weaker consistency is acceptable → the cost (aborts+retries for SSI, lock waits+deadlocks for 2PL, or a single-thread ceiling for serial execution) may be prohibitive.
- A targeted `SELECT ... FOR UPDATE` (materializing the conflict on the specific rows) already closes the one anomaly you have — you don't need to promote the whole workload.

## Key Properties

- **The guarantee is behavioral, not a specific schedule.** SERIALIZABLE means the outcome is *equivalent to* some serial order — the engine may interleave freely as long as the result matches one serial execution. It does **not** promise a particular order, nor (by itself) real-time ordering; SERIALIZABLE + linearizable = *strict serializability*.
- **It is the only standard level that prevents write skew and phantoms.** READ COMMITTED, REPEATABLE READ, and SNAPSHOT all permit at least one of them.
- **Three implementation families, same contract:**
  - *Actual serial execution* — run one transaction at a time on a single thread (Redis, VoltDB/H-Store, Datomic). Concurrency anomalies are impossible by construction.
  - *Two-phase locking (2PL)* — pessimistic: acquire locks, block conflicting txns until commit.
  - *Serializable Snapshot Isolation (SSI)* — optimistic: run on an MVCC snapshot, detect serialization conflicts, abort a loser.
- **2PL's two phases:** a *growing* phase (only acquire locks) followed by a *shrinking* phase (only release, at commit/abort). Shared (read) locks and exclusive (write) locks; readers block writers and writers block readers — the opposite of MVCC.
- **Predicate / index-range locks are what make 2PL prevent phantoms.** Locking existing rows isn't enough when the anomaly is about rows that *don't exist yet*; you must lock the *predicate* (all rows matching a `WHERE`, including future inserts). In practice engines approximate predicate locks with **index-range locks** (e.g. InnoDB **[next-key locks](_meta/glossary.md#next-key-lock)** = row lock + gap lock).
- **SSI detects "dangerous structures," not cycles.** It tracks read/write dependencies via non-blocking **SIREAD** predicate locks and aborts a transaction when it sees two adjacent **rw-antidependencies** (the pattern that can produce a non-serializable schedule). SIREAD locks record reads for conflict detection — they never block.

## Common Pitfalls

- **Thinking REPEATABLE READ / snapshot isolation is serializable.** The SQL-standard names are weaker than they sound: RR/SI still allow **write skew** and, in pure SI, **phantoms**. This is the single most common interview trap. (SQL's *definition* of RR is phantom-permitting; some engines lock beyond it.)
- **Assuming SERIALIZABLE means "runs serially / slowly by definition."** No — it's a correctness guarantee about *outcomes*. SSI in particular keeps SI's read concurrency (readers don't block writers) and only pays for aborts.
- **Not writing a retry loop for SSI (and deadlock-driven 2PL) aborts.** Serializable transactions *will* abort with a serialization failure (`40001`) or deadlock; the application **must** catch and retry from the beginning. Forgetting this turns a correct engine into random user-facing errors.
- **Believing a single-row write conflict catches write skew.** It can't: the two transactions write **different** rows, so first-writer-wins never fires. Only predicate/read-dependency tracking (2PL predicate locks or SSI's SIREAD) sees it.
- **Vendor name confusion:** Oracle "SERIALIZABLE" and SQL Server SNAPSHOT are actually **snapshot isolation** (they permit write skew) — *not* truly serializable. PostgreSQL SERIALIZABLE (SSI, since 9.1) and MySQL/InnoDB SERIALIZABLE (2PL-style, via shared locks on reads) are genuinely serializable.
- **Leaving side effects un-retried.** If a serializable txn emails/charges before commit, a retry double-fires. Make external effects idempotent or defer them until after commit.

## Trade-offs

| | Actual serial execution | Two-phase locking (2PL) | Serializable Snapshot Isolation (SSI) |
|---|---|---|---|
| Strategy | No concurrency (single thread) | Pessimistic (block) | Optimistic (detect + abort) |
| Reads block writes? | N/A | **Yes** (shared/exclusive locks) | **No** (reads run on snapshot) |
| Main cost | Throughput ceiling of one core; every txn must be short | Lock contention + **deadlocks** (abort + retry) | **Aborts under contention** (false positives possible) + retry |
| Best when | Txns tiny, fit in memory, no user stalls (stored procs) | Moderate contention, can't tolerate abort churn | Read-heavy / low-to-moderate write contention |
| Phantom prevention | Inherent | Predicate / index-range (next-key) locks | SIREAD predicate locks + rw-antidependency detection |
| Used by | Redis, VoltDB, Datomic | InnoDB SERIALIZABLE, DB2 | PostgreSQL SERIALIZABLE (9.1+), CockroachDB (variant) |

- **Pessimistic vs. optimistic contention behavior:** 2PL degrades by *waiting* (latency spikes, deadlocks) as contention rises; SSI degrades by *aborting* (retry churn). Under low contention SSI is near-free (SI performance); under high write contention its abort rate can dominate.
- **Serial execution is astonishingly viable when it fits:** if all data is in RAM and transactions are short stored procedures with no client round-trips mid-transaction, single-threaded execution avoids *all* locking/versioning overhead — but it can't use multiple cores per partition and one slow transaction stalls everything.
- **Cross-region cost:** 2PL holds locks across the whole transaction (longer under WAN latency → more contention); SSI holds no read locks but sees more aborts as transactions live longer. Both make serializability expensive at distance.

## Implementation Notes

**Write skew — the anomaly to reconstruct in an interview:**
```
-- Invariant: at least one doctor must remain on call.
-- Txn A and Txn B run concurrently under SNAPSHOT ISOLATION.

-- both read the SAME set (each sees 2 on call), then write DIFFERENT rows:
Txn A:  SELECT count(*) FROM doctors WHERE on_call = true AND shift = 'x'; -- 2
Txn B:  SELECT count(*) FROM doctors WHERE on_call = true AND shift = 'x'; -- 2
Txn A:  UPDATE doctors SET on_call = false WHERE id = 'alice';  -- different row
Txn B:  UPDATE doctors SET on_call = false WHERE id = 'bob';    -- different row
-- both commit under SI -> ZERO doctors on call. Invariant violated.
-- SERIALIZABLE aborts one; a manual fix is SELECT ... FOR UPDATE on the read set.
```

**PostgreSQL (SSI):** set `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE`. On conflict you get `ERROR: could not serialize access due to read/write dependencies among transactions` (SQLSTATE `40001`). The app must retry. SSI adds bookkeeping (SIREAD locks) but no read blocking; it can produce *false-positive* aborts (it is conservative). See MVCC card for the version machinery underneath.

**InnoDB (lock-based):** `SET TRANSACTION ISOLATION LEVEL SERIALIZABLE` makes plain `SELECT`s inside a transaction take **shared next-key locks** (InnoDB implicitly converts them to `SELECT ... FOR SHARE`, the modern spelling of `LOCK IN SHARE MODE`), so reads block conflicting writes; phantoms are prevented by **gap / next-key locks** on scanned index ranges. (Exception: with `autocommit` enabled, a standalone `SELECT` is a read-only transaction and runs as a nonlocking consistent read.) Cost surfaces as lock waits and deadlocks (`ERROR 1213`), again requiring retry.

**Universal rule:** wrap serializable transactions in a bounded retry loop with backoff, and keep external side effects out of the transaction body (or idempotent) so retries are safe.

## Variants

- **Strict 2PL (S2PL) / Strong Strict 2PL (SS2PL):** hold write locks (S2PL) or all locks (SS2PL, the usual database implementation) until commit/abort — this also gives recoverability, not just serializability.
- **Snapshot Isolation (SI):** one level *below* serializable; the baseline MVCC guarantee that still permits write skew — the thing SERIALIZABLE fixes.
- **Serializable Snapshot Isolation (SSI):** SI plus rw-antidependency detection (PostgreSQL SERIALIZABLE); optimistic path to true serializability.
- **Strict serializability:** SERIALIZABLE **+** linearizability (real-time order also respected) — what Spanner/CockroachDB target for distributed correctness.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 7 (Weak Isolation → Write Skew and Phantoms → Serializability: serial execution, 2PL, SSI) — the canonical grounding
- PostgreSQL docs — 13.2.3 Serializable Isolation Level (SSI): https://www.postgresql.org/docs/current/transaction-iso.html#XACT-SERIALIZABLE
- Ports & Grittner, *Serializable Snapshot Isolation in PostgreSQL* (VLDB 2012): https://arxiv.org/pdf/1208.4179
- MySQL InnoDB SERIALIZABLE & locking reads: https://dev.mysql.com/doc/refman/8.0/en/innodb-transaction-isolation-levels.html

## Related

- [[snapshot-isolation]]
- [[mvcc]]
- [[two-phase-locking]]
- [[transaction-isolation-levels]]
- [[acid-properties]]
- [[linearizability]]
