---
id: 7f3a2c1e-8b4d-4e9f-a6c0-d5e1f2a3b4c5
type: flashcard
tags:
  - system-design
  - database
  - sql
  - nosql
tiers:
  system-design: 1
created: 2026-08-20
confidence: low
---

# SQL vs NoSQL Databases

Relational databases (SQL) enforce a rigid, typed schema and guarantee ACID transactions via a structured query language; NoSQL databases trade some of those guarantees for flexible schemas, horizontal scalability, and specialized data models (document, key-value, wide-column, graph). The right choice depends on data shape, consistency requirements, and scale — not on which sounds more modern.

## When to Use

**Problem signals that suggest SQL (relational):**
- The prompt involves **financial transactions, billing, or inventory** — anything where partial writes are unacceptable and atomicity across multiple rows/tables is required
- The data has **complex relationships** that are naturally expressed as joins (users → orders → line items → products)
- The problem specifies **strong consistency** or **ACID guarantees** explicitly ("ensure no double-charge", "no negative balances")
- The domain has a **well-known, stable schema** unlikely to change frequently (HR systems, ERP, booking engines)
- The interviewer mentions **reporting, analytics, or aggregations** over relational data (SQL's GROUP BY, window functions, JOINs are purpose-built for this)
- Read/write patterns are **mixed and unpredictable** — SQL's general-purpose query optimizer handles ad-hoc queries well

**Problem signals that suggest NoSQL:**
- The prompt specifies **massive scale** (hundreds of millions of users, petabyte-scale data, millions of writes/sec) where horizontal sharding of a relational DB becomes operationally complex
- Data is **sparse or heterogeneous** — user profiles with hundreds of optional fields, product catalogs with wildly different attributes per category
- The access pattern is **known and narrow**: always look up by a single key (session store, user preferences) → key-value store; always fetch a document by ID (product catalog, CMS) → document store
- The problem mentions **time-series data** (metrics, IoT, logs) → wide-column (Cassandra) or purpose-built TSDBs
- **Eventual consistency is acceptable** and the system tolerates stale reads (social media feeds, shopping cart recommendations, leaderboards)
- The data has a **graph structure** (social networks: "friends of friends", fraud rings) → graph DB (Neo4j)

**Prefer SQL over NoSQL when:**
- Over document stores: data has many-to-many relationships — denormalizing into documents creates costly update anomalies
- Over key-value stores: you need range queries, secondary indexes, or aggregations across many records
- Over wide-column: transaction semantics are required across multiple rows

**Prefer NoSQL over SQL when:**
- Over SQL for write-heavy workloads at scale: Cassandra's log-structured merge tree achieves ~1–5 ms p99 writes under typical single-DC conditions; PostgreSQL sharding is operationally expensive
- Over SQL for document-shaped data: MongoDB avoids costly schema migrations when product attributes change weekly
- Over SQL for caching / session storage: Redis delivers sub-millisecond reads from RAM vs. ~5–10 ms for indexed SQL queries

**Do not use NoSQL when:**
- Multi-entity transactions are required (transfer money between accounts) → SQL with ACID; NoSQL two-phase commit is fragile and rare
- The schema is complex and relational — you will recreate joins in application code, which is slower and harder to maintain
- The team is small and schema discipline matters — schema-less is a footgun without strong engineering culture

## Key Properties

| Property | SQL (e.g. PostgreSQL, MySQL) | Document (MongoDB) | Wide-Column (Cassandra) | Key-Value (Redis) |
|---|---|---|---|---|
| Schema | Rigid, typed | Flexible per document | Column families, flexible | None |
| Query model | Full SQL (JOINs, aggregations) | Document queries + aggregation pipeline | CQL (partition + clustering key only) | GET/SET/range |
| Consistency | Strong (ACID) | Tunable (majority r/w = CP; default eventual = AP) | Tunable (LOCAL_QUORUM for strong) | Strong (single node); eventual (cluster) |
| Horizontal scale | Hard (read replicas easy; write sharding complex) | Native sharding | Native; designed for it | Native clustering |
| Typical read latency | 5–50 ms (indexed, across network) | 5–20 ms | 1–5 ms | < 1 ms (in-memory) |
| Typical write throughput | ~50K–200K writes/sec per node (tuned) | ~20K–80K writes/sec | ~100K+ writes/sec per node | ~100K–1M ops/sec |

## Trade-offs

**Consistency vs. Availability (CAP Theorem):**
CAP applies to distributed systems — you cannot simultaneously guarantee Consistency, Availability, and Partition Tolerance. Single-node SQL sidesteps CAP entirely by not distributing writes. Distributed SQL systems (Spanner, CockroachDB) choose CP: under a network partition they reject writes rather than risk divergence. AP stores (Cassandra, DynamoDB by default) stay available and reconcile conflicts later. Not all NoSQL is AP: HBase and Zookeeper are CP; MongoDB with majority write/read concern is CP. In interviews, state the CAP classification of the specific database you choose and justify whether the system can tolerate stale reads.

**Schema flexibility vs. data integrity:**
NoSQL's flexible schema enables fast iteration but removes the database as a correctness boundary. Application code must validate data shapes; without this discipline, databases accumulate inconsistent documents that are expensive to migrate later.

**Horizontal scalability:**
NoSQL was built for horizontal scale — adding nodes linearly increases write throughput. Sharding a relational database (Vitess, Citus, manual range sharding) is operationally complex and limits the query surface (cross-shard JOINs become application-side).

**Operational complexity:**
Managed SQL (RDS PostgreSQL, Cloud SQL) is simpler to operate than a self-managed Cassandra or MongoDB cluster. At < 10 TB and < 100K writes/sec, the operational overhead of NoSQL rarely pays off. Default to SQL unless the scale signals are explicit.

**Query flexibility:**
SQL's optimizer handles arbitrary ad-hoc queries. NoSQL query models are narrow — Cassandra can only filter on partition + clustering keys efficiently; querying by non-key fields requires full-table scans or maintaining separate lookup tables (materialized views). Design NoSQL schemas query-first, not entity-first.

**ACID transactions across entities:**
SQL transactions spanning multiple tables are single-node operations with rollback guarantees. Multi-document transactions in MongoDB (4.0+) exist but add latency and reduce throughput. Cassandra's "lightweight transactions" use Paxos and are ~5–10x slower than normal writes. If the interview problem requires "all-or-nothing" across multiple entities, SQL wins clearly.

## Architecture Patterns

**Polyglot persistence (common in system design interviews):**
Production systems routinely use both. A canonical pattern:
- PostgreSQL as the system of record for user accounts, orders, payments (ACID required)
- Redis for session storage, rate limiting counters, and leaderboards (sub-ms latency, TTL support)
- Cassandra or DynamoDB for time-series events, activity feeds, or write-heavy analytics (horizontal scale)
- Elasticsearch for full-text search (inverted index, not a primary store)

When designing a system like Twitter or Uber, name the specific NoSQL store and justify the choice — "DynamoDB for the trip table because reads are always by trip_id and we need single-digit millisecond latency at global scale."

**Read replicas (SQL scaling pattern):**
One primary handles writes; N read replicas serve read traffic. Replication lag is typically milliseconds to seconds under normal load, but can reach minutes under heavy write bursts or on a lagging replica — design reads that require recency to go to the primary. This is the first scaling lever for read-heavy SQL workloads before considering NoSQL.

**Denormalization in NoSQL:**
NoSQL schemas are optimized for access patterns, not normal forms. In a document store, embedding a user's recent orders inside the user document avoids a join — but updates to order data now require updating every embedded copy. Acceptable if order data is immutable after creation; problematic if it changes.

## Common Pitfalls

- **Defaulting to NoSQL for "scale"** without verifying the scale actually exceeds what a well-indexed PostgreSQL instance handles. A single Postgres node on modern hardware with connection pooling handles ~100K–500K simple reads/sec and ~50K+ writes/sec — sufficient for most products at $1B ARR.
- **Treating NoSQL as schema-free in practice** — Cassandra schemas are rigid at the partition + clustering key level; changing them requires data migration just like SQL.
- **Forgetting replication lag** in eventual-consistent NoSQL — a user who writes a record and immediately reads it may get a stale result if the read hits a different replica. Design UX and application logic to tolerate this.
- **Using a relational model inside MongoDB** — if every query requires `$lookup` (MongoDB's join), you've chosen the wrong tool and paid the flexibility tax with no benefit.
- **Not specifying consistency level in Cassandra** — default is `ONE` (eventual). For reads-after-writes correctness, use `LOCAL_QUORUM` at the cost of ~2x latency.
- **Treating all NoSQL as AP** — MongoDB (majority r/w concern) and HBase are CP; always state the CAP classification of the specific system you choose.

## Resources

- Designing Data-Intensive Applications (Kleppmann) — Chapters 2, 5, 6 (data models, replication, partitioning)
- Alex Xu, System Design Interview Vol. 1 — Chapter 1 (scale from zero to millions of users)
- https://www.postgresql.org/docs/current/
- https://cassandra.apache.org/doc/latest/
- https://www.mongodb.com/docs/manual/core/data-modeling-introduction/

## Related

- [[cap-theorem]]
- [[acid-transactions]]
- [[database-indexing]]
- [[consistent-hashing]]
- [[sharding]]
- [[replication]]
- [[caching]]
