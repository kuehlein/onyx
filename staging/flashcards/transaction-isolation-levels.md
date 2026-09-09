---
id: transaction-isolation-levels
type: flashcard
tags:
  - databases
  - transactions
  - isolation
tiers:
  databases: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Transaction Isolation Levels

Isolation levels define which concurrency anomalies a database permits between transactions that run at the same time. They form a ladder from weak to strong: **read uncommitted → read committed → snapshot / repeatable read → serializable**. Each rung prevents one more class of race condition at the cost of more blocking, more aborts, or lower throughput. The core insight from *Designing Data-Intensive Applications* (DDIA) Ch.7: "[ACID](_meta/glossary.md#acid)" says nothing about *which* level you get — most databases default to read committed or snapshot isolation, not serializable, so weak-isolation races are your responsibility to reason about.

> [!tip] Recognition heuristic
> Any time two transactions touch overlapping data concurrently and correctness depends on *what one sees of the other*, name the anomaly first ([dirty read](_meta/glossary.md#dirty-read)? [lost update](_meta/glossary.md#lost-update)? [write skew](_meta/glossary.md#write-skew)?), then pick the weakest level that prevents it. If money, inventory, or an invariant across multiple rows is at stake, you likely need serializable or an explicit lock — not the default.

## When to Use

**Problem signals that point to an isolation discussion:**
- "Two users bought the last item at the same time" — lost update / write skew on shared state
- "The report showed a half-applied transfer" — dirty read or read skew (non-atomic read across rows)
- "Balance check passed but the account went negative under load" — write skew: both transactions read a stale snapshot, both pass a guard, both write
- "Counter increments are being lost" — lost update on read-modify-write
- "Same query returned different rows within one transaction" — non-repeatable read or [phantom](_meta/glossary.md#phantom-read)

**Choosing a level:**
- **Read committed** (default in Postgres, Oracle, SQL Server): fine for most [OLTP](_meta/glossary.md#oltp) where each statement is self-contained; use `SELECT ... FOR UPDATE` for the rare read-modify-write.
- **Snapshot / repeatable read**: when a transaction issues *multiple reads* that must see one consistent point-in-time view (analytics, backups, multi-row invariant checks that don't also write to the checked rows).
- **Serializable**: when correctness depends on an invariant spanning rows a transaction reads but does not modify (booking systems, double-spend guards) — i.e. write skew must be impossible.

**Do not reach for serializable when:**
- A targeted `SELECT ... FOR UPDATE` / atomic `UPDATE ... SET x = x + 1` solves the one race → cheaper than globally serializable.
- The workload is read-heavy analytics with no cross-row invariants → [snapshot isolation](_meta/glossary.md#snapshot-isolation) is enough and doesn't abort.

## Key Properties

**The ladder and what each rung prevents (SQL-standard anomaly model):**

| Level | Dirty write | Dirty read | Lost update | Non-repeatable read | Phantom | Write skew |
|---|---|---|---|---|---|---|
| Read uncommitted | prevented | **allowed** | allowed | allowed | allowed | allowed |
| Read committed | prevented | prevented | allowed | allowed | allowed | allowed |
| Snapshot / repeatable read | prevented | prevented | prevented¹ | prevented | prevented² | **allowed** |
| Serializable | prevented | prevented | prevented | prevented | prevented | prevented |

¹ Snapshot isolation detects lost updates via first-committer-wins abort or explicit `FOR UPDATE`; the SQL-standard "repeatable read" does not by itself.
² Snapshot isolation prevents phantoms (reads see one consistent snapshot); SQL-standard "repeatable read" does *not* (new rows aren't locked) — see the note below.

**Anomaly definitions (memorize these):**
- **Dirty write** — a transaction overwrites another's *uncommitted* write. Prevented at every level via row write-locks.
- **Dirty read** — a transaction reads another transaction's *uncommitted* data (which may roll back).
- **Non-repeatable read (read skew)** — re-reading the *same row* returns a different value because another transaction committed in between.
- **Phantom** — a query with a predicate (`WHERE status='pending'`) returns a *different set of rows* on re-execution because another transaction inserted/deleted matching rows.
- **Lost update** — two read-modify-write cycles interleave; one overwrites the other's result (e.g. two `counter = counter + 1` collapse to +1).
- **Write skew** — two transactions read overlapping data, each makes a decision from that snapshot, then each writes to *different* rows, jointly violating an invariant neither could see being broken (e.g. both on-call doctors go off shift because each saw the other still on).

**Snapshot isolation vs. SQL-standard repeatable read (the senior gotcha):**
- These are *not* the same guarantee, though vendors conflate them.
- **Snapshot isolation** ([MVCC](_meta/glossary.md#mvcc)-based) blocks phantoms and non-repeatable reads but **allows write skew**.
- The SQL-standard **repeatable read** locks read rows so it blocks write skew on those rows but **allows phantoms** (new rows aren't locked).
- Neither is fully serializable; write skew is the anomaly that distinguishes snapshot isolation from serializable.

**vs. [MVCC](_meta/glossary.md#mvcc):** MVCC is the *mechanism* (keep multiple row versions so readers don't block writers); an isolation level is the *policy* (which anomalies you tolerate). MVCC is how most engines implement read committed and snapshot isolation — but the same engine's serializable adds conflict detection (SSI) on top. Don't equate "uses MVCC" with any particular level.

## Common Pitfalls

- **Assuming "ACID" implies serializable.** It doesn't. The I in ACID is whatever level is configured; most engines default to read committed (Postgres/Oracle/SQL Server) or repeatable read (MySQL InnoDB).
- **Vendor label ≠ standard meaning.** Postgres `REPEATABLE READ` is actually *snapshot isolation* (allows write skew). Postgres/Oracle `READ UNCOMMITTED` silently behaves as `READ COMMITTED`. Read the vendor docs, not the SQL keyword.
- **Read-modify-write in application code.** `SELECT balance` → compute in app → `UPDATE balance` is a lost-update trap at read committed *and* snapshot isolation. Use an atomic `UPDATE ... SET balance = balance - ?`, `SELECT ... FOR UPDATE`, or a compare-and-set.
- **Believing snapshot isolation prevents write skew.** It does not. The classic bug: two transactions each check "at least one doctor still on call", each sees the other, each goes off call.
- **Forgetting serializable can abort.** SSI (Postgres serializable) and [OCC](_meta/glossary.md#optimistic-concurrency-control)-style implementations abort transactions on conflict at commit — the app *must* retry on serialization failure (SQLSTATE `40001`). Code that assumes commit always succeeds breaks under contention.
- **Long-running transactions at snapshot isolation.** They pin an old MVCC snapshot, bloating undo/version storage (Postgres dead-tuple bloat, MySQL undo-log growth) and blocking vacuum/purge.

## Trade-offs

**Weak vs. strong isolation:**
- Weaker (read committed) → higher concurrency, no aborts from isolation, but application must hand-guard every race. Stronger (serializable) → correctness by default, but pays in blocking (2PL) or abort-and-retry (SSI).

**The three ways to implement serializable, and their trade-offs (DDIA Ch.7):**
- **Actual serial execution** (single-threaded, e.g. Redis, VoltDB): no locking overhead, trivially correct — but throughput bounded by one CPU core and requires short, stored-procedure-style transactions.
- **Two-phase locking (2PL / strict S2PL)** (traditional SQL serializable, MySQL): acquire shared/exclusive locks on everything read or written, hold to commit; uses predicate/next-key locks to kill phantoms. Correct but slow — readers block writers and vice versa, deadlocks require detection and abort.
- **Serializable Snapshot Isolation (SSI)** (Postgres serializable): optimistic — run at snapshot isolation, track read-write antidependencies (SIREAD locks that don't block), abort at commit if a dangerous cycle is detected. Great throughput when contention is low; wasted work and retries when contention is high.

**Latency vs. abort rate:** 2PL trades latency (waiting on locks) for determinism; SSI trades occasional aborts (retry cost) for non-blocking reads. Choose based on whether your contention is low (favor SSI/OCC) or high (2PL may thrash less than constant retries).

## Implementation Notes

**Set the level (ANSI SQL, per-transaction):**
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;  -- or REPEATABLE READ / READ COMMITTED
-- ... statements ...
COMMIT;
```

**Guarding a read-modify-write without going serializable:**
```sql
-- Atomic, no lost update at any level:
UPDATE accounts SET balance = balance - 100 WHERE id = 1 AND balance >= 100;

-- Or pessimistic lock the row first:
BEGIN;
SELECT balance FROM accounts WHERE id = 1 FOR UPDATE;  -- blocks concurrent writers
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
COMMIT;
```

**Retry loop for serializable / SSI (mandatory):**
```python
while True:
    try:
        run_transaction()          # BEGIN ... COMMIT at SERIALIZABLE
        break
    except SerializationFailure:   # Postgres SQLSTATE 40001
        continue                   # snapshot too old / dangerous conflict — safe to retry
```

**Vendor cheat sheet (verified against current docs):**
- **PostgreSQL**: default `READ COMMITTED`. `REPEATABLE READ` = snapshot isolation (blocks phantoms, allows write skew). `SERIALIZABLE` = SSI (aborts on conflict). `READ UNCOMMITTED` treated as `READ COMMITTED`.
- **MySQL InnoDB**: default `REPEATABLE READ`, and it goes further than the standard — plain reads use an MVCC snapshot, while locking reads/writes use next-key locks (record + gap) that block phantom inserts. It is *not* fully serializable, though (write skew via non-locking reads still possible). `SERIALIZABLE` implicitly adds shared locks to plain `SELECT`s.

## Variants

- **Read skew (anti-)** — a special case of non-repeatable read across *multiple* rows (a backup or report seeing a transfer half-applied); snapshot isolation is the standard fix.
- **Cursor stability** — a lock-based intermediate (DB2) that holds a lock only on the row under the current cursor, preventing lost updates without full repeatable read.
- **Monotonic atomic view / causal consistency** — replication-side isolation notions relevant in distributed databases, orthogonal to the single-node ladder.
- **Predicate locks vs. next-key locks** — two mechanisms for killing phantoms under 2PL; next-key (index gap) locking is InnoDB's approximation of true predicate locks.

## Resources

- Martin Kleppmann, *Designing Data-Intensive Applications*, Ch.7 (Transactions) — the canonical treatment of weak isolation, write skew, and the three serializability techniques
- PostgreSQL docs — Transaction Isolation: https://www.postgresql.org/docs/current/transaction-iso.html
- PostgreSQL wiki — Serializable Snapshot Isolation (SSI): https://wiki.postgresql.org/wiki/SSI
- MySQL 8.4 Reference — InnoDB Transaction Isolation Levels: https://dev.mysql.com/doc/refman/8.4/en/innodb-transaction-isolation-levels.html

## Related

- [[acid-properties]]
- [[sql-vs-nosql]]
- [[database-indexing]]
- [[cap-theorem]]
