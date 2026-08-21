---
id: 7f3a2e1b-84c6-4d9f-b0e2-3c5a9d6f1e8b
type: flashcard
tags:
  - system-design
  - database
  - acid
  - sql
tiers:
  system-design: 1
created: 2026-08-20
confidence: medium
---

# ACID Properties

ACID is the set of four guarantees — Atomicity, Consistency, Isolation, Durability — that relational databases provide to ensure correctness in the face of failures and concurrent access. Each property eliminates a specific class of data corruption; together they let you reason about transactions as if they run alone and completely.

## When to Use

**Problem signals that suggest ACID is relevant:**

- The problem involves financial transactions, payment processing, or any transfer of value between accounts (classic: "design a payment system," "design a banking ledger")
- The interviewer mentions that **data integrity is non-negotiable** or uses words like "correct," "consistent," or "no double-spend"
- The system must handle **concurrent writes to shared data** (inventory deduction, seat reservation, coupon redemption)
- The interviewer asks "what happens if the server crashes mid-operation?" — atomicity and durability directly answer this
- The design requires **multi-step operations that must succeed or fail together** (order creation that also decrements stock and charges a card)
- Any mention of **auditability, regulatory compliance, or financial reporting** — these all assume durable, consistent records

**Prefer ACID-compliant databases (PostgreSQL, MySQL InnoDB, CockroachDB) over BASE/NoSQL when:**

- Over eventual-consistency NoSQL: write correctness matters more than write throughput; you cannot tolerate stale reads on critical data (account balance, inventory count)
- Over Cassandra/DynamoDB: you have complex multi-entity transactions and can afford slightly higher write latency for correctness guarantees
- Over Redis (primary store): you need durability across process restarts and ACID semantics, not just speed

**Do not use when:**

- You need massive horizontal write scalability across many nodes → consider trading some consistency for availability (BASE model, Cassandra, DynamoDB)
- The data is append-only analytics or log data where partial writes are acceptable → use columnar stores (BigQuery, Redshift)
- Strict ACID would create lock contention that kills your throughput target → evaluate optimistic concurrency or CRDT-based designs
- You are storing user sessions, caches, or ephemeral data → durability overhead is wasted cost

## Key Properties

Each property eliminates a distinct failure mode:

**Atomicity — "all or nothing"**
A transaction either commits fully or rolls back completely. If a transfer deducts $100 from Alice but the process crashes before crediting Bob, the deduction is rolled back. Implemented via write-ahead log (WAL): changes are logged before they are applied, so the database can undo incomplete transactions on restart.

**Consistency — "rules are never violated"**
Every transaction moves the database from one valid state to another. "Valid" is defined by constraints, foreign keys, and application-level invariants. Note: this is the weakest of the four — the database enforces schema-level constraints, but application logic must enforce business invariants (e.g., balance ≥ 0 requires a CHECK constraint or application guard).

**Isolation — "concurrent transactions don't see each other's intermediate states"**
This is the most nuanced property. Isolation levels (weakest to strongest):
- **Read Uncommitted** — dirty reads possible (almost never used)
- **Read Committed** — no dirty reads; non-repeatable reads possible (PostgreSQL default)
- **Repeatable Read** — same row returns same value within a transaction; phantom reads possible (MySQL InnoDB default)
- **Serializable** — full isolation; transactions behave as if run sequentially; highest lock contention

Most systems run Read Committed and handle anomalies at the application layer. Serializable is used when correctness is more valuable than throughput (financial settlement, ledger systems).

**Durability — "committed data survives failures"**
Once the database acknowledges a commit, the data persists even if the server crashes immediately after. Achieved via WAL flushed to disk (fsync) before the commit acknowledgment is returned. Synchronous replication extends durability across machines.

## Trade-offs

| Dimension | ACID Strength | Cost |
|---|---|---|
| Atomicity | Eliminates partial writes | WAL write overhead on every transaction |
| Isolation (Serializable) | Zero anomalies | Lock contention; throughput ≈ single-threaded |
| Isolation (Read Committed) | Practical default | Allows non-repeatable reads and phantoms |
| Durability (fsync) | Survives crashes | ~1–10 ms added latency per commit (disk flush) |
| Durability (sync replication) | Survives node loss | Write latency = network RTT to replica (~1–5 ms LAN) |

**ACID vs. BASE (Basically Available, Soft state, Eventual consistency):**
ACID sacrifices availability under partition (CAP theorem: choose CP) to maintain consistency. BASE systems sacrifice consistency for availability (AP). For a payment system, CP is correct. For a social media like count, AP is fine.

**Performance gotcha:** `fsync=off` in PostgreSQL gives ~10× faster writes but sacrifices durability — data loss on OS crash. Never use in production for primary data stores.

**Lock contention at scale:** Serializable isolation with high write concurrency produces lock waits and deadlocks. At 10k+ TPS, most systems drop to Read Committed and use explicit application-level locking (SELECT FOR UPDATE, optimistic locking via version columns) for the specific rows that need it.

## Common Pitfalls

- **Confusing Consistency with Isolation.** Consistency is about invariants; isolation is about visibility between concurrent transactions. Interviewers sometimes blur these — be precise.
- **Assuming ACID = safe from all bugs.** ACID guarantees transaction semantics; it does not protect against application logic errors (transferring to the wrong account is durable and isolated).
- **Treating isolation as binary.** There are four levels with different anomaly profiles. Defaulting to "just use Serializable" ignores the throughput cost; defaulting to Read Uncommitted is dangerous. The right answer is almost always Read Committed + selective `SELECT FOR UPDATE`.
- **Forgetting that distributed ACID is expensive.** Single-node ACID is cheap. Distributed ACID (two-phase commit across shards) adds coordinator latency (50–200 ms in cross-region setups) and introduces coordinator SPOF. CockroachDB/Spanner achieve distributed serializable isolation via consensus (Raft/Paxos) but at higher latency than local transactions.

## Implementation Notes

**Single-node RDBMS (PostgreSQL, MySQL InnoDB):**
ACID is handled by the storage engine. Key architectural decisions:
- Set `synchronous_commit = on` (default) for full durability — commit waits for WAL flush
- Use connection pooling (PgBouncer) to avoid connection overhead; PostgreSQL is process-per-connection
- Typical write latency: 1–5 ms (SSD, synchronous commit), throughput ceiling ~5–20k TPS per node

**Distributed ACID (CockroachDB, Google Spanner, YugabyteDB):**
- Uses consensus protocol (Raft) per data range; commits require quorum acknowledgment
- Achieves serializable isolation across nodes; latency is bounded by network RTT
- Spanner uses TrueTime (atomic clocks + GPS) to assign globally consistent timestamps; CockroachDB uses hybrid logical clocks (HLC)
- Useful when you need horizontal write scalability *without* sacrificing ACID; cost is p99 latency of 5–20 ms cross-zone

**2-Phase Commit (2PC) — distributed transactions across heterogeneous systems:**
Coordinator asks all participants to prepare (lock resources), then commits if all say yes. Blocking if coordinator fails between prepare and commit. Used in legacy systems; prefer distributed ACID databases for new designs.

**Saga pattern — ACID alternative for microservices:**
When each microservice owns its own DB and you cannot use distributed transactions, model multi-step workflows as a sequence of local transactions with compensating transactions on failure (e.g., Stripe creates a charge → inventory decrements → on failure, refund the charge). Achieves eventual consistency, not atomicity. Use when service boundaries make distributed ACID impractical.

## Resources

- [PostgreSQL documentation — Transaction Isolation](https://www.postgresql.org/docs/current/transaction-iso.html)
- Kleppmann, Martin. *Designing Data-Intensive Applications*, Ch. 7 — Transactions (the definitive treatment of isolation levels and anomalies)
- [CockroachDB — Serializable, Lockless, Distributed: Isolation in CockroachDB](https://www.cockroachlabs.com/blog/serializable-lockless-distributed-isolation-cockroachdb/)
- [Google Spanner — TrueTime and external consistency](https://research.google/pubs/pub39966/)

## Related

- [[cap-theorem]]
- [[database-replication]]
- [[sharding]]
- [[two-phase-commit]]
- [[saga-pattern]]
