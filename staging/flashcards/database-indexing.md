---
id: 7f3a2c1e-84b6-4d9f-a3e0-c2f1b8d05e47
type: flashcard
tags:
  - system-design
  - database
  - database-indexing
tiers:
  system-design: 1
created: 2026-08-20
confidence: low
priority: normal
---

# Database Indexing

An index is a separate data structure (typically a B-tree or hash) that the database maintains alongside a table to allow it to locate rows matching a predicate without scanning every row. The cost is write overhead and storage; the benefit is query latency that drops from O(n) full-table scan to O(log n) or O(1) lookups.

## When to Use

**Problem signals that suggest database indexing:**
- "The read latency for user profile lookups is too high" — any read-heavy query on a large table with a WHERE, JOIN ON, or ORDER BY clause
- "We need to look up orders by user_id, status, or created_at" — filtering or sorting on columns that are not the primary key
- "The leaderboard query is slow" — range scans or sorted result sets on non-PK columns
- "Users search by email / username / phone number" — high-cardinality unique lookups
- "This table will grow to hundreds of millions of rows" — scale signals that make full scans prohibitively expensive
- "We need to enforce uniqueness on email across users" — unique indexes double as a constraint mechanism
- "JOIN between orders and products is slow" — foreign key columns involved in joins are classic index candidates

**Prefer indexing over alternatives when:**
- Over caching alone: indexes avoid cache-miss penalties and stay consistent with writes without requiring explicit invalidation
- Over sharding: add an index first — sharding is a last resort after indexes and query optimization are exhausted
- Over denormalization: indexes let you keep a normalized schema while still achieving fast reads; denormalize only when index + query rewrites are insufficient

**Do not use when:**
- Table is small (< ~100K rows and fits in memory) → full scan is fast enough; indexes add write overhead for no gain
- Column has very low cardinality (e.g. a boolean `is_active`) → the optimizer may ignore the index anyway; use partial index or filter at application layer
- Write throughput is the bottleneck and read latency is acceptable → each index adds ~1 additional B-tree write per INSERT/UPDATE; on write-heavy tables (e.g. event ingestion) indexes hurt throughput
- The query pattern is unpredictable / ad-hoc analytics → use [OLAP](_meta/glossary.md#olap) columnar store (BigQuery, Redshift, ClickHouse) instead

## Key Properties

**B-tree index (default in Postgres, MySQL InnoDB):**
- Supports equality (`=`), range (`<`, `>`, `BETWEEN`), prefix (`LIKE 'foo%'`), and `ORDER BY` without a sort step
- Balanced tree; depth stays ~3–4 levels even at 100M rows → ~3–4 I/Os per lookup
- Leaf pages are linked for efficient range scans

**Hash index:**
- O(1) equality lookups; does NOT support range queries or sorting
- Postgres supports hash indexes on disk; MySQL InnoDB uses adaptive hash index internally but does not expose user-created hash indexes for InnoDB tables

**Covering index (index-only scan):**
- If all columns needed by a query are in the index, the engine never touches the heap; critical for latency at scale
- Example: `CREATE INDEX idx_orders_user_status ON orders (user_id, status) INCLUDE (total, created_at)`

**Composite index and column order:**
- Follows the leftmost prefix rule: an index on `(a, b, c)` serves queries filtering on `a`, `(a, b)`, or `(a, b, c)` but NOT on `b` or `c` alone
- Place the highest-cardinality equality column first; place range columns last

> [!important] Leftmost-prefix rule for composite indexes
> An index on `(a, b, c)` serves filters on `a`, `(a, b)`, or `(a, b, c)` — but **not `b` or `c` alone**. Put equality columns first (highest cardinality first), range/sort columns last.

**Partial index:**
- Index only rows matching a condition: `CREATE INDEX idx_active_users ON users (email) WHERE is_deleted = false`
- Smaller index, faster writes, query planner uses it only when the WHERE clause matches

## Time & Space Complexity

| Operation | Without index | With B-tree index |
|---|---|---|
| Point lookup (PK) | O(1) via clustered index | O(1) |
| Point lookup (secondary) | O(n) full scan | O(log n) |
| Range scan | O(n) | O(log n + k) where k = rows returned |
| INSERT / UPDATE / DELETE | O(log n) for PK tree | O(log n) × (1 + number of secondary indexes) |

**Storage overhead:** A secondary B-tree index on a single integer column typically adds ~10–30% of the table's storage size. Covering indexes with wide INCLUDE columns can approach the table size itself.

**Write amplification:** Each additional secondary index adds one B-tree insert per row write. A table with 5 secondary indexes incurs 6 total B-tree writes per row (1 for the clustered PK + 5 for secondary indexes) — 6× the baseline write I/O.

## Trade-offs

**Read latency vs. write throughput:**
- Every index speeds reads and slows writes. On event-ingestion tables (millions of writes/sec), indexes are the primary bottleneck — minimize them or use a write-optimized store ([LSM](_meta/glossary.md#lsm)-tree engines: RocksDB, Cassandra) and index separately.

**Index maintenance during bulk loads:**
- Drop non-essential indexes before a bulk INSERT, reload, then rebuild. Rebuilding one index at the end is faster than incrementally updating it per row during load.

**Covering index vs. index bloat:**
- Adding columns to INCLUDE widens the index and increases storage + write cost. Justify each included column with a measured query.

**Index cardinality and selectivity:**
- Low-selectivity indexes (< 5% of rows filtered) are often skipped by the query planner in favor of a full scan. Rule of thumb: if an index reduces the result set by less than ~10×, it may not be used.

**Clustered vs. non-clustered:**
- In InnoDB, the primary key IS the clustered index (row data lives in the B-tree leaf). Secondary indexes store the PK value and require a second lookup ("double lookup"). Use a short, monotonically increasing PK (e.g. `BIGINT AUTO_INCREMENT` or UUID v7) to avoid page splits on insert.
- Random UUIDs (v4) as PKs cause ~50% page fill factor and significant write amplification at scale — a well-known pathology at >10M rows.

**Partial index trade-off:**
- Faster and smaller, but the query planner only uses it when the WHERE clause exactly matches the partial condition. Easy to miss in ORM-generated queries.

**Hot spot risk:**
- Monotonically increasing PKs avoid page splits but concentrate writes on the rightmost leaf page (hot spot in distributed databases). In CockroachDB / Spanner, use hash-sharded indexes or random UUIDs (v4) to spread write load. Note: UUID v7 is time-ordered (k-sortable) and still concentrates recent inserts on the same key range in a distributed system — it solves InnoDB page splits for single-node databases but does not eliminate hot spots in range-partitioned distributed databases.

## Implementation Notes

**Index selection process (interview pattern):**
1. Identify the top N slowest / highest-frequency queries (via `EXPLAIN ANALYZE`, slow query log, or APM)
2. For each query, list every column in WHERE, JOIN ON, ORDER BY, GROUP BY
3. Build a composite index with equality columns first, range/sort columns last, and INCLUDE the remaining SELECT columns
4. Validate with `EXPLAIN (ANALYZE, BUFFERS)` — confirm "Index Only Scan" or "Index Scan" replaces "Seq Scan"
5. Measure write throughput impact in staging before deploying

**Multi-tenant SaaS pattern:**
- Always index the `tenant_id` (or `organization_id`) column first in every composite index. All queries are tenant-scoped; without this, every query does a cross-tenant full scan.
- Example composite: `(tenant_id, user_id, created_at DESC)`

**Read replica + index divergence:**
- Read replicas replicate all indexes. Consider creating read-optimized indexes (e.g. wide covering indexes) only on replicas to avoid write penalty on primary — some databases (Postgres with logical replication) support this.

**Postgres-specific patterns worth mentioning in interviews:**
- `CREATE INDEX CONCURRENTLY` — builds index without locking the table (takes longer; requires monitoring for failures)
- Expression indexes: `CREATE INDEX ON users (lower(email))` — supports case-insensitive lookups
- [GIN](_meta/glossary.md#gin) / [GiST](_meta/glossary.md#gist) indexes for full-text search, JSONB fields, and geometric data
- `pg_stat_user_indexes` — identify unused indexes consuming write budget

**Migration strategy at scale:**
- Build index concurrently on prod → validate query plans → only then drop the old wider index
- Never drop an index and rebuild in the same transaction; build new first

## Variants

- **Full-text index (inverted index):** Maps tokens to row IDs; used by Elasticsearch, Postgres `tsvector`. Not a B-tree — optimized for `CONTAINS` / ranked relevance queries.
- **Bitmap index:** Used in OLAP/data warehouses (Redshift, Oracle). Very efficient for low-cardinality columns in read-only or batch-write workloads; not suited for [OLTP](_meta/glossary.md#oltp).
- **Spatial index (R-tree / GiST):** Geospatial queries ("find all restaurants within 5 km"). PostGIS, MySQL SPATIAL INDEX.
- **LSM-tree (Log-Structured Merge):** Used by RocksDB, Cassandra, LevelDB. Converts random writes to sequential I/O at the cost of read amplification (must probe multiple [SSTable](_meta/glossary.md#sstable)s/levels per read) and space amplification (duplicate keys exist across levels until compaction merges them). Fundamentally different trade-off from B-tree.

## Resources

- Use The Index, Luke — https://use-the-index-luke.com (the canonical free reference)
- PostgreSQL docs — Index Types: https://www.postgresql.org/docs/current/indexes-types.html
- Alex Xu, *System Design Interview Vol. 1*, Chapter 6 (database scaling section)
- MySQL InnoDB clustered index: https://dev.mysql.com/doc/refman/8.0/en/innodb-index-types.html

## Related

- [[sharding]]
- [[database-replication]]
- [[caching]]
- [[cap-theorem]]
- [[sql-vs-nosql]]
