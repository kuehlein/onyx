---
id: database-normalization
type: flashcard
tags:
  - databases
  - normalization
  - schema-design
tiers:
  databases: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Database Normalization

Normalization organizes a relational schema so that each fact is stored exactly once, eliminating the redundancy that causes insert, update, and delete anomalies. The formal target (1NF → BCNF) is defined in terms of functional dependencies: progressively stronger rules force every non-key attribute to depend on "the key, the whole key, and nothing but the key." Denormalization is the deliberate reverse move — reintroducing controlled redundancy to buy read performance or data locality once you accept the cost of keeping copies in sync.

> [!tip] Recognition
> Reach for **normalization** when the same fact lives in many rows and updates must touch all copies (an update anomaly), or when you cannot record a fact without inventing unrelated data (insert anomaly). Reach for **denormalization** when a hot read path fans out across many joins and the write rate on the duplicated data is low relative to reads.

## When to Use

**Problem signals that suggest normalizing further:**
- The same string (a category name, a user's city, a product title) is copied across thousands of rows and "we forgot to update one place" is a recurring bug — classic **update anomaly**
- You can't insert a legitimate entity because unrelated columns are NOT NULL (can't add a course with no enrolled student yet) — **insertion anomaly**
- Deleting the last row of one kind silently destroys an unrelated fact (removing the only employee on a project erases the project) — **deletion anomaly**
- A column holds a comma-separated list or repeating groups (`tags = "a,b,c"`, or `phone1/phone2/phone3`) — violates **1NF**
- A composite-key table has attributes that depend on only part of the key — violates **2NF**

**Prefer denormalizing when:**
- Over a normalized join: a read-heavy path repeatedly joins 4+ tables and profiling shows joins dominate latency; a precomputed/duplicated column collapses it to a single lookup
- Over caching: the derived value must be queryable/filterable/sortable in SQL (e.g. a `comment_count` you `ORDER BY`), not just fetched by key
- The document/aggregate model fits: all the data is read together as one object and rarely mutated (DDIA's *data locality* argument — one document read beats stitching many indexes)
- You're building an [OLAP](_meta/glossary.md#olap) star schema: analytical warehouses denormalize into wide fact + dimension tables on purpose; normalization is an [OLTP](_meta/glossary.md#oltp) concern

**Do not use (denormalization) when:**
- The duplicated data is write-heavy → every write must fan out to N copies and risks divergence; keep it normalized
- You haven't measured → premature denormalization trades correctness risk for unproven speed. Normalize first, index (see [[database-indexing]]), then denormalize only the proven-hot path

## Key Properties

Each normal form assumes the previous one holds. The progression is defined by **functional dependencies** (FDs): `X → Y` means X's value determines Y's.

| Form | Rule | Fixes |
|---|---|---|
| **1NF** | Atomic column values; no repeating groups or arrays; a defined key | Non-relational structure |
| **2NF** | 1NF + no **partial** dependency (no non-key attribute depends on only *part* of a composite key) | Redundancy from composite keys |
| **3NF** | 2NF + no **transitive** dependency (no non-key attribute depends on another non-key attribute) | Insert/update/delete anomalies |
| **BCNF** | For every FD `X → Y`, X is a **superkey** | The residual anomalies 3NF misses when candidate keys overlap |

- **The 3NF mnemonic:** every non-key attribute depends on "the key, the whole key, and nothing but the key" — *whole key* = 2NF, *nothing but the key* = 3NF.
- **BCNF is stricter than 3NF only in a narrow case.** They differ only when a relation has **overlapping composite candidate keys** and an FD's determinant is a candidate key but not the primary one. Most real 3NF schemas are already BCNF.
- **3NF is always achievable with a lossless, dependency-preserving decomposition. BCNF is not.** Forcing BCNF can require dropping a functional dependency that then can only be enforced by re-joining tables — the fundamental 3NF-vs-BCNF trade-off (see Date).
- **Denormalization ≠ un-normalizing.** You design a normalized model first, then selectively add redundancy with a rule for keeping it consistent (trigger, application code, or materialized view) — you do not skip the modeling step.

## Common Pitfalls

- **Confusing 2NF and 3NF.** Partial dependency (2NF) needs a **composite** key to even exist; if the table has a single-column key it is automatically in 2NF. Transitive dependency (3NF) is a non-key attribute determining another non-key attribute.
- **Calling BCNF "4NF-lite."** BCNF is about functional dependencies and superkeys; 4NF/5NF concern multivalued and join dependencies — a different axis. Don't conflate them.
- **Over-normalizing OLTP hot paths.** Splitting into textbook BCNF can force expensive multi-join reads for data always accessed together. Normalization is a default, not a dogma.
- **Denormalizing without an invalidation strategy.** A duplicated `author_name` or a cached `order_total` that no process keeps in sync silently rots. Every denormalized copy needs an owner: a DB trigger, a transactional application write, or a materialized view with a defined refresh.
- **Storing derived aggregates you could compute cheaply.** A `COUNT(*)` with a good index is often faster and safer than a hand-maintained counter that drifts. Denormalize the count only when it is measurably hot.
- **Assuming denormalization always speeds things up.** Wider rows mean fewer rows per page, more I/O per scan, and larger indexes — it can slow the very reads you meant to help. Measure.

## Trade-offs

**Normalized (write-optimized):**
- Pros: one copy of each fact → no update anomalies; smaller rows; writes touch one place; integrity enforceable with FKs/constraints
- Cons: reads require joins; a single logical object may be spread across many tables/indexes (poor data locality)

**Denormalized (read-optimized):**
- Pros: fewer joins, better locality, precomputed aggregates queryable in SQL; the model NoSQL document stores lean on since they lack cheap joins ([[sql-vs-nosql]])
- Cons: redundant copies must be kept in sync → write amplification + risk of divergence; more storage; anomalies return unless guarded

**The core dial:** normalization optimizes writes and integrity; denormalization optimizes reads and locality. In practice: **normalize to 3NF/BCNF by default, then denormalize the specific paths profiling proves hot** — and only after indexing has failed to close the gap.

**3NF vs BCNF specifically:** BCNF removes more redundancy but may sacrifice dependency preservation; 3NF keeps all FDs enforceable without extra joins at the cost of a little residual redundancy. For most systems 3NF is the pragmatic stopping point.

## Implementation Notes

**Spotting the violation, then fixing it — worked example (transitive dependency, 3NF):**

```
-- Violates 3NF: zip → city, state is a transitive dependency
-- (city/state depend on zip, a non-key attribute, not on order_id)
orders(order_id PK, customer_id, ship_zip, ship_city, ship_state, total)

-- 3NF: extract the transitively-dependent facts into their own relation
orders   (order_id PK, customer_id, ship_zip FK, total)
zip_codes(zip PK, city, state)
```

**Denormalizing a proven-hot read (with a keep-in-sync mechanism):**

```sql
-- Hot path: post list needs comment_count on every render.
-- Option A (Postgres): a materialized view, refreshed on a schedule.
CREATE MATERIALIZED VIEW post_comment_counts AS
  SELECT post_id, COUNT(*) AS comment_count
  FROM comments GROUP BY post_id;
REFRESH MATERIALIZED VIEW CONCURRENTLY post_comment_counts;  -- needs a unique index

-- Option B: a denormalized column kept current transactionally / by trigger.
ALTER TABLE posts ADD COLUMN comment_count INT NOT NULL DEFAULT 0;
-- every insert/delete of a comment updates posts.comment_count in the SAME txn
```

- Prefer a **materialized view** or **generated column** over hand-maintained duplication when the engine supports it — the DB owns the consistency, not scattered application code.
- Postgres `GENERATED ALWAYS AS (...) STORED` columns denormalize a computed value the engine keeps correct automatically (deterministic expressions only).
- When duplication must live in application code, do the write inside the **same transaction** as the source change so a crash can't leave copies diverged.

## Variants

- **4NF** — eliminates multivalued dependencies (independent multi-valued facts crammed into one table).
- **5NF (PJ/NF)** — eliminates join dependencies not implied by candidate keys; rarely needed in practice.
- **DKNF / 6NF** — theoretical/temporal extremes; effectively never targeted in application schemas.
- **Star & snowflake schemas** — the deliberately denormalized (star) / partially-normalized (snowflake) dimensional models used in [OLAP](_meta/glossary.md#olap) warehouses.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 2 — normalization, many-to-one relationships, and the data-locality argument for denormalization
- PostgreSQL docs — Materialized Views: https://www.postgresql.org/docs/current/rules-materializedviews.html
- PostgreSQL docs — Generated Columns: https://www.postgresql.org/docs/current/ddl-generated-columns.html
- Codd, "Further Normalization of the Data Base Relational Model" (the original normalization paper); overview: https://en.wikipedia.org/wiki/Database_normalization

## Related

- [[database-indexing]]
- [[sql-vs-nosql]]
- [[acid-properties]]
- [[caching]]
- [[transaction-lifecycle]]
