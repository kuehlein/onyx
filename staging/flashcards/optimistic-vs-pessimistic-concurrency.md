---
id: optimistic-vs-pessimistic-concurrency
type: flashcard
tags:
  - concurrency
  - databases
tiers:
  concurrency: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Optimistic vs Pessimistic Concurrency

Two opposite bets on how often concurrent transactions will fight over the same data. **Pessimistic** ([locking](_meta/glossary.md#pessimistic-locking)) assumes conflict is likely and locks the data *before* touching it, so others block until you're done. **Optimistic** ([OCC](_meta/glossary.md#optimistic-concurrency-control)) assumes conflict is rare and takes no locks: it reads a version, does its work, then at write time *validates* that nothing changed underneath (compare-and-set on a version/timestamp) and aborts+retries if it did. The right choice is dictated by contention: pessimistic pays a coordination cost on every access; optimistic pays a retry cost only on the rare collision — but that cost explodes when collisions are common.

> [!tip] Recognition
> Reach for this decision when two requests can **read-modify-write the same row** and you must avoid the [lost-update](_meta/glossary.md#lost-update) anomaly. Signals: "two users edit the same document/inventory count/balance," "increment a counter under load," "retries may replay a write." **High contention on a hot key → pessimistic (lock). Low contention / mostly-independent rows → optimistic (version + retry).**

> [!warning] Don't confuse with the siblings
> This card is the **conflict-handling strategy** (lock-first vs. validate-on-write). Distinguish it by the question each concept answers:
> - **vs. transaction isolation levels** — isolation levels name *which anomalies are forbidden* (the guarantee: read committed, repeatable read, serializable). OCC/pessimistic are *mechanisms* an engine uses to deliver those guarantees. "What's disallowed?" = isolation; "how do we detect the clash?" = this card.
> - **vs. [MVCC](_meta/glossary.md#mvcc)** — MVCC is the *storage/versioning technique* that lets readers see a snapshot without blocking writers. It is neither optimistic nor pessimistic; both strategies can run on top of it. "How are versions kept?" = MVCC; "when do we check for a conflict?" = this card.
> - **vs. race conditions & atomicity** — that card is the *problem* (unsynchronized interleavings, the need for an indivisible operation). Optimistic/pessimistic are two *solutions* to it at the data-store level.

## When to Use

**Signals that point to pessimistic (lock-first):**
- **High, sustained contention on the same rows** — many writers fighting over a hot key; retries would thrash
- The transaction is **long or expensive to redo**, so an abort-and-retry wastes significant work
- You need to *reserve* a row and act on it (e.g. `SELECT ... FOR UPDATE`, then decrement inventory) with a guarantee no one else can grab it meanwhile

**Signals that point to optimistic (validate-on-write):**
- **Conflicts are rare** — writers usually touch different rows, or reads vastly outnumber conflicting writes
- **Stateless / distributed clients** where holding a DB lock across a user "think time" (e.g. a web form open for minutes) is unacceptable — locks don't survive request boundaries well
- You want **maximum read/write concurrency** and can tolerate occasional retries

**Do not use when:**
- Pessimistic under **low contention** → you pay lock/coordination overhead and risk deadlocks for conflicts that almost never happen
- Optimistic under **high contention** → the abort/retry rate climbs, wasting CPU and starving writers (livelock); switch to a lock or a serialized single-writer path

## Key Properties

- **The core distinction is *when* you detect conflict.** Pessimistic prevents it up front by blocking (acquire lock → read → write → release). Optimistic detects it at the end by validating (read version → work → `UPDATE ... WHERE version = old` → if 0 rows changed, someone beat you → retry).
- **Optimistic requires a conflict-detection token**, typically a `version` integer or timestamp column bumped on every write. The write is a **compare-and-set**: it only commits if the token still matches what was read.
- **Optimistic implies retryable, hence [idempotent](_meta/glossary.md#idempotency), logic.** The whole read-compute-write must be safe to run again from the top, because it *will* re-run on conflict.
- **Pessimistic locks are held for the transaction's duration** and are released on commit/rollback — so a stuck or slow transaction blocks everyone waiting on those rows.
- **Neither is "the isolation level."** They are mechanisms an isolation level uses. [Snapshot isolation](_meta/glossary.md#snapshot-isolation) via MVCC gives non-blocking reads but still needs one of these (or SI's own first-committer-wins abort) to stop lost updates.

## Trade-offs

| Dimension | Pessimistic (lock-first) | Optimistic (validate-on-write) |
|---|---|---|
| Assumption | Conflicts likely | Conflicts rare |
| Conflict handling | **Block** until lock free | **Abort + retry** on version mismatch |
| Detects conflict | Before the work (up front) | After the work (at commit) |
| Cost paid | On **every** access (lock overhead) | Only on the **rare collision** (retry) |
| Failure mode | **Deadlocks**, blocked/stalled writers | **[Retry storms](_meta/glossary.md#retry-storm) / livelock** under contention |
| Read/write concurrency | Lower (readers may block writers) | Higher (no locks taken) |
| Best when | Hot rows, long/expensive txns | Low contention, short txns, stateless clients |

- **The crossover is contention.** Optimistic wins throughput while collisions stay rare; past a contention threshold its retry cost overtakes pessimistic's lock cost.
- **Latency shape differs:** pessimistic adds *waiting* latency to contended requests; optimistic keeps the fast path fast but adds *tail* latency (and wasted work) to the requests that lose and retry.

## Common Pitfalls

- **Optimistic without a retry loop is just a silent bug.** If you detect the version mismatch (0 rows updated) but don't re-read and retry, the user's change is dropped — the very lost update you were trying to prevent.
- **Read-modify-write outside a transaction/CAS.** `SELECT balance; balance = balance - 10; UPDATE balance = ...` without `FOR UPDATE` or a `WHERE version = x` guard is the textbook lost-update race. Prefer an atomic `UPDATE ... SET n = n - 10` where possible.
- **Holding pessimistic locks across a user round-trip.** Locking a row while a human stares at a form serializes users for minutes and courts deadlock — this is exactly where optimistic versioning belongs.
- **Unbounded / un-jittered optimistic retries** under contention produce a livelock: everyone reads the same version, everyone collides, everyone retries in lockstep. Cap attempts and add [backoff](_meta/glossary.md#exponential-backoff)/[jitter](_meta/glossary.md#jitter).
- **Assuming snapshot isolation alone stops lost updates.** SI stops dirty and non-repeatable reads, but a plain read-modify-write can still lose updates unless the engine does first-committer-wins detection, or you use `SELECT FOR UPDATE` / atomic CAS. SI never prevents [write skew](_meta/glossary.md#write-skew) — that needs serializable isolation.
- **`SELECT FOR UPDATE` inside snapshot isolation reads the *latest committed* row, not your snapshot.** Under MVCC, locking reads bypass the transaction's snapshot to lock the current version — a subtlety that surprises people who assume everything in the txn sees one frozen view.

## Implementation Notes

Pessimistic — acquire the row lock, then mutate:

```sql
BEGIN;
SELECT stock FROM items WHERE id = 42 FOR UPDATE;  -- blocks other writers
UPDATE items SET stock = stock - 1 WHERE id = 42;
COMMIT;
```

Optimistic — compare-and-set on a version column; retry when 0 rows change:

```sql
-- read
SELECT stock, version FROM items WHERE id = 42;      -- version = 7
-- write only if nobody else moved it
UPDATE items SET stock = stock - 1, version = version + 1
WHERE id = 42 AND version = 7;
-- rows_affected == 0  -> someone else committed; re-read and retry
```

`SELECT FOR UPDATE` (Postgres, MySQL InnoDB) is the standard pessimistic row lock; `FOR UPDATE SKIP LOCKED` turns a table into a work queue. The optimistic pattern is what most ORMs/JPA/Hibernate call "optimistic locking" via a `@Version` field — despite the name, it takes no locks.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 7 "Transactions" — lost update, locking reads, and compare-and-set: https://dataintensive.net/
- PostgreSQL — Explicit Locking (`SELECT FOR UPDATE`, row locks): https://www.postgresql.org/docs/current/explicit-locking.html
- PostgreSQL — Transaction Isolation (snapshot behavior, first-updater-wins): https://www.postgresql.org/docs/current/transaction-iso.html

## Related

- [[mvcc]]
- [[snapshot-isolation]]
- [[database-transactions]]
- [[idempotency]]
- [[two-phase-locking]]
- [[deadlock]]
