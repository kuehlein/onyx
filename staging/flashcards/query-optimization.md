---
id: query-optimization
type: flashcard
tags: [databases, query-optimization]
tiers: { databases: 1 }
created: 2026-09-08
confidence: high
priority: normal
---

# Query Optimization

The query optimizer turns a declarative SQL statement into an executable physical plan (which access method, join algorithm, and join order to use). Modern relational databases are **cost-based**: the planner enumerates candidate plans, estimates each plan's cost from table statistics, and picks the cheapest. "Cost" is a dimensionless number combining estimated I/O and CPU — not milliseconds. Because the choice hinges on *estimated* row counts, the optimizer is only as good as its statistics: a bad cardinality estimate is the root cause of most catastrophic plans, including a perfectly good index being ignored.

> [!tip] Recognition
> Reach for optimizer reasoning when a query is slow *despite* a suitable index existing, when latency swings wildly with data volume or parameter values, or when an interviewer asks "why is this doing a Seq Scan?" / "why did the plan flip?". The mental checklist is: **is the predicate sargable → are the statistics fresh → is the estimated row count close to actual → is the chosen join algorithm right for the row counts.**

## When to Use

**Problem signals that suggest a query-optimizer problem (not a missing index):**
- "The index exists but `EXPLAIN` shows a Seq Scan" — the planner estimated the index scan as more expensive
- "The query was fast yesterday and slow today with no code change" — stale statistics or plan flip after data growth
- "It's fast for one customer and slow for another" — parameter-dependent selectivity (skewed data + a cached/generic plan)
- "Adding an `AND` clause made it 100× slower" — a correlated predicate broke the independence assumption, blowing up the estimate
- "`EXPLAIN ANALYZE` shows `rows=5` estimated but `actual rows=2,000,000`" — cardinality mis-estimate; downstream nested-loop join collapses
- "Joining 8+ tables and planning itself is slow" — join-order search explosion (GEQO territory in Postgres)

**Prefer fixing the plan over adding an index when:**
- Over adding an index: the right index already exists but is unused → fix sargability, run `ANALYZE`, or adjust `random_page_cost`; don't pile on redundant indexes
- Over rewriting into raw SQL hints: fix the *estimate* (extended statistics, `ANALYZE`, rewrite predicate) so every plan benefits, rather than pinning one plan that goes stale

**Do not reach for optimizer tuning when:**
- The table genuinely has no supporting index and the query is selective → add the [index](database-indexing) first
- The workload is bulk analytical scans over the whole table → a Seq Scan is *correct*; move to an [OLAP](_meta/glossary.md#olap) columnar store
- The query returns most of the table → a Seq Scan legitimately beats an index scan; stop trying to force the index

## Key Properties

**Cost-based planning:**
- Plan cost = estimated I/O + CPU, expressed in abstract units. Postgres calibrates against `seq_page_cost = 1.0`, `random_page_cost = 4.0` (random reads assumed 4× slower — an HDD-era default), plus `cpu_tuple_cost`, `cpu_index_tuple_cost`, `cpu_operator_cost`.
- The planner does not measure real time; it *estimates*. `EXPLAIN` shows estimates; `EXPLAIN ANALYZE` actually runs the query and shows estimate-vs-actual side by side.

**Statistics drive every decision:**
- Collected by `ANALYZE` (Postgres) / auto-analyze / `ANALYZE TABLE` (MySQL) into a system catalog (`pg_statistic`, exposed via `pg_stats`).
- Per column: **n_distinct** (distinct-value count), a **Most-Common-Values (MCV) list** with frequencies (used for equality selectivity on skewed columns), and an **equi-depth histogram** of the remaining values (used for range selectivity). Sample size / bucket count is governed by `default_statistics_target` (default 100).
- Join and multi-predicate estimates rely on **uniformity, inclusion, and independence** assumptions. Correlated columns violate independence — fix with Postgres extended statistics (`CREATE STATISTICS ... (dependencies, ndistinct)`).

**Join algorithms (the planner picks per join, based on estimated input sizes and sort order):**

| Algorithm | Best when | Cost (rough) | Needs |
|---|---|---|---|
| **Nested loop** | One side tiny, or inner side has an index on the join key | O(N × M), or O(N × log M) with an inner index | Nothing; works for any join condition incl. non-equi |
| **Hash join** | Both sides large, equi-join, no useful sort/index | O(N + M) build+probe; needs hash table ≤ `work_mem` | Equi-join only; spills to disk if it exceeds memory |
| **Merge join** | Both inputs already sorted on the join key (e.g. via index) | O(N + M) after sort; O(N log N + M log M) if it must sort | Sorted inputs; supports range/inequality joins |

**Vendor reality (verified):**
- **Postgres** implements all three (nested loop, hash, merge).
- **MySQL/InnoDB** historically had only nested-loop (block-nested-loop). **Hash join arrived in 8.0.18** (used for equi-joins with no usable index; extended to outer/semi/anti joins in 8.0.20). MySQL has **no merge join**.

## Common Pitfalls

- **Non-sargable predicates.** *Sargable* = "Search ARGument ABLE" — the optimizer can seek the B-tree using the predicate. Wrapping the indexed column in a function or arithmetic (`WHERE lower(email) = ?`, `WHERE created_at + interval '1 day' > now()`, `WHERE col * 2 = 10`), a leading-wildcard `LIKE '%x'`, or a type mismatch that forces an implicit cast all defeat the index → full scan. Fix: keep the bare column on one side, or build a matching **expression index**.
- **Stale statistics.** After a bulk load or large data shift, estimates are wrong and the planner ignores a good index or picks a bad join. Run `ANALYZE` (Postgres) / `ANALYZE TABLE` (MySQL). This is the #1 real-world cause of "the index is being ignored."
- **Cardinality mis-estimate → nested-loop blowup.** If the planner *underestimates* rows (thinks 5, gets 2M — common with correlated `AND` predicates), it picks a nested loop that then executes the inner side millions of times. Underestimation is far more dangerous than overestimation. Detect via estimate-vs-actual in `EXPLAIN ANALYZE`.
- **Low selectivity → index correctly skipped.** If a predicate matches a large fraction of the table (rule of thumb, more than ~5–10%), an index scan with its random I/O per row costs *more* than a sequential scan. The planner is right to skip the index — this is not a bug.
- **Default `random_page_cost` on SSD/NVMe.** The 4.0 default assumes spinning disks. On SSD, random I/O is nearly as cheap as sequential, so 4.0 makes index scans look artificially expensive and the planner over-prefers Seq Scans. Lower to ~1.1 on SSD-backed storage.
- **`work_mem` too small.** A hash join or sort that doesn't fit in `work_mem` spills to disk (batched hash join / external merge sort), turning an O(N+M) plan into something far slower. Watch for "Disk" in `EXPLAIN ANALYZE` sort/hash nodes.
- **Reading raw `cost` as time.** `cost=0.00..431.00` is abstract units, not ms. Compare *plans* by cost; compare *reality* only via `EXPLAIN ANALYZE` actual time and rows.

## Trade-offs

- **Planning time vs. plan quality.** Exhaustive join-order search is factorial in the number of tables. Postgres switches to the **Genetic Query Optimizer (GEQO)** once the FROM-list reaches `geqo_threshold` (default **12**): it treats join ordering like a travelling-salesman problem and returns a *good* plan fast rather than the *optimal* one. Lowering `join_collapse_limit`/`from_collapse_limit` (e.g. to 8) caps planning time but can yield worse plans.
- **Generic vs. custom plans (prepared statements).** A cached generic plan skips re-planning per execution (fast) but ignores the actual parameter value — disastrous on skewed columns where selectivity depends on the value. A custom plan re-optimizes per value (accurate, slower to plan). Postgres heuristically chooses after ~5 executions.
- **Hint/pin the plan vs. fix the estimate.** Forcing a plan (session GUCs like `enable_seqscan=off`, MySQL optimizer hints, `pg_hint_plan`) fixes today's query but rots as data changes and hides the real cause. Fixing the estimate (fresh stats, extended statistics, a sargable rewrite) helps every plan and survives data growth. Prefer fixing the estimate; hints are a last resort.
- **More statistics vs. ANALYZE cost.** Raising `default_statistics_target` (or per-column `ALTER TABLE ... SET STATISTICS`) yields finer histograms/MCVs and better estimates on irregular data — at the cost of larger catalogs and slower `ANALYZE`.

## Implementation Notes

**Diagnosing a slow query (interview walkthrough):**
1. `EXPLAIN (ANALYZE, BUFFERS)` the query. Read the tree **bottom-up** (leaves execute first).
2. Compare **estimated `rows=` vs. `actual rows=`** at each node. A big gap (≳10×) is the smoking gun — chase it down to the scan node that started it.
3. If estimates are off → `ANALYZE` the table; if a correlated multi-column predicate → add extended statistics.
4. Check the scan node: `Seq Scan` where you expected an index? Verify the predicate is **sargable** and the index actually covers it.
5. Check join nodes: a `Nested Loop` over a huge inner side is the classic blowup; a `Hash Join` node showing "Batches: > 1" or "Disk" means it spilled `work_mem`.
6. Only after estimates are trustworthy, consider cost-parameter tuning (`random_page_cost` on SSD) or adding an index.

```sql
-- The single most useful command in the interview:
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;

-- Sargable rewrite: expression index so lower() is seekable
CREATE INDEX idx_users_lower_email ON users (lower(email));
-- now: WHERE lower(email) = $1   -- uses the index

-- Fix a correlated-predicate underestimate (city implies state):
CREATE STATISTICS stx_geo (dependencies, ndistinct) ON city, state FROM addresses;
ANALYZE addresses;

-- SSD tuning so index scans aren't over-penalized:
ALTER SYSTEM SET random_page_cost = 1.1;   -- vs. default 4.0

-- Diagnose only (Postgres): temporarily prove the index is faster
SET enable_seqscan = off;   -- session-local; a probe, NOT a fix to ship
```

**Reading a plan (Postgres):** `Index Only Scan` (best — never touches the heap) > `Index Scan` > `Bitmap Heap Scan` (many scattered matches) > `Seq Scan`. For joins, node label tells you the algorithm directly (`Nested Loop`, `Hash Join`, `Merge Join`).

## Variants

- **Rule-based optimizer (RBO):** legacy approach (old Oracle) using fixed heuristics instead of statistics. Superseded by cost-based optimization everywhere modern.
- **Adaptive / runtime re-optimization:** the executor adjusts mid-flight when estimates prove wrong (Oracle Adaptive Plans, SQL Server Adaptive Joins, Postgres JIT is related but distinct). Mitigates cardinality mis-estimation.
- **Learned cardinality estimation:** ML models replacing histogram-based estimates; active research, not yet default in mainstream engines.
- **Columnar / vectorized execution:** [OLAP](_meta/glossary.md#olap) engines (ClickHouse, DuckDB, Redshift) optimize whole-table scans with vectorized operators — a different cost model where Seq Scans dominate by design.

## Resources

- Martin Kleppmann, *Designing Data-Intensive Applications* — Ch. 3 (Storage and Retrieval; access methods, OLTP vs. OLAP)
- PostgreSQL docs — Statistics Used by the Planner: https://www.postgresql.org/docs/current/planner-stats.html
- PostgreSQL docs — Query Planning config (`random_page_cost`, `geqo_threshold`, `join_collapse_limit`): https://www.postgresql.org/docs/current/runtime-config-query.html
- MySQL docs — Hash Join Optimization: https://dev.mysql.com/doc/refman/8.0/en/hash-joins.html

## Related

- [[database-indexing]]
- [[sql-vs-nosql]]
- [[acid-properties]]
- [[transaction-lifecycle]]
- [[caching]]
