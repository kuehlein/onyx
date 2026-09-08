---
id: oltp-vs-olap
type: flashcard
tags:
  - databases
  - oltp
  - olap
tiers:
  databases: 1
created: 2026-09-08
confidence: high
priority: normal
---

# OLTP vs OLAP

Two fundamentally different access patterns drive two different storage designs. **[OLTP](_meta/glossary.md#oltp)** (Online Transaction Processing) serves the application: many small, latency-sensitive reads and writes that each touch a few rows by key — so it uses **row-oriented** storage where one row's columns sit contiguously on disk. **[OLAP](_meta/glossary.md#olap)** (Online Analytical Processing) serves analysts: a few long-running queries that scan millions of rows but only a handful of columns to compute aggregates — so it uses **column-oriented** storage where each column is stored contiguously, enabling the engine to read only the columns a query needs and to compress them aggressively. This is the core insight of DDIA Ch. 3: the disk layout should mirror the query's access pattern.

> [!tip] Recognition
> Ask "does the query touch **few rows × all columns** (point/range lookup by key → OLTP, row store) or **all rows × few columns** (aggregate scan → OLAP, column store)?" If the answer is "load a customer profile and update it," that's OLTP. If it's "sum revenue by product category over Q3," that's OLAP fed by a nightly ETL into a warehouse.

## When to Use

**Signals that the workload is OLTP (row store: Postgres, MySQL/InnoDB):**
- Access is by primary key or a selective index — you fetch or mutate a small number of rows per request
- Writes are frequent, small, and must be durable and low-latency (order placement, profile edit)
- The application is the client; queries are known and templated by the code path
- You need row-level transactions with [ACID](_meta/glossary.md#acid) isolation ([[acid-properties]], [[transaction-lifecycle]])

**Signals that the workload is OLAP (column store / warehouse: BigQuery, Redshift, Snowflake, ClickHouse):**
- Queries scan a huge fraction of the rows but project only a few columns and aggregate (`SUM`, `COUNT`, `GROUP BY`, window functions)
- The client is a human analyst or a dashboard; queries are exploratory and ad hoc
- Data is loaded in bulk (batch ETL/ELT or streaming ingest), rarely updated in place afterward
- Latency budget is seconds-to-minutes per query, not milliseconds

**Do not conflate them:**
- Do not run heavy analytics on your OLTP primary → a single full-table aggregate scan competes for buffer cache and I/O with latency-critical transactions. Extract to a warehouse (or at least a read replica) instead.
- Do not point-update single rows in a column store → column stores make single-row updates expensive (see Common Pitfalls); they are built for bulk load + scan.
- **HTAP** systems (TiDB, SingleStore, Postgres + columnar extensions) blur the line by keeping both a row store and a column store, but for interviews the default answer is: separate the two, connected by a data pipeline.

## Key Properties

**Row-oriented (OLTP):**
- All values of one row are stored adjacently → reading/writing a whole row is one contiguous access; ideal for "fetch this record."
- A full-column aggregate must read every row (all columns) off disk even to touch one column → wasteful for analytics.

**Column-oriented (OLAP):**
- Each column stored as its own file/segment; row `i`'s value is the `i`-th entry in every column file. Row reassembly relies on **all columns sharing the same row order** (positional alignment).
- A query reads only the column files it references → dramatically less I/O for wide tables where a query touches 3 of 100 columns.
- **Compression is far more effective** because a single column has low-entropy, same-type data. DDIA's canonical example is **bitmap encoding**: for a column with `n` distinct values, store `n` bitmaps (one bit per row); then **run-length encode** the bitmaps. Low-cardinality columns compress to a tiny fraction of their raw size.
- **Vectorized processing:** compressed columns fit in L1/L2 cache and are scanned in tight SIMD loops; predicates like `WHERE product_id IN (…)` become fast bitwise-AND over bitmaps.
- **Sort order is a design choice, not a given.** The warehouse chooses a sort key (e.g. `date`); the whole table is stored sorted by it, which both speeds range filters and improves run-length compression on the sort column. C-Store/Vertica even keep the *same* data in multiple sort orders ("projections") for different query classes.

**Data-warehouse schema (dimensional modeling):**
- **Star schema:** one central **fact table** (one row per event — a sale, a click; mostly foreign keys + numeric measures) surrounded by **dimension tables** (who/what/where/when/how — `dim_product`, `dim_date`, `dim_customer`). Fact tables are enormous and narrow-per-row but very wide in column count; dimensions are small.
- **Snowflake schema:** dimensions are further normalized into sub-dimensions (e.g. `dim_product → dim_brand`, `dim_category`). More normalized, less redundancy, but more joins → star is usually preferred for query simplicity and performance.

## Trade-offs

| Aspect | Row store (OLTP) | Column store (OLAP) |
|---|---|---|
| Single-row read/write | Fast (one contiguous access) | Slow (touch every column file) |
| Full-column scan / aggregate | Slow (reads unused columns) | Fast (reads only needed columns) |
| Compression ratio | Modest (mixed types per row) | High (uniform type per column) |
| Write model | In-place, transactional | Bulk load / append; updates expensive |
| Typical latency | ms | seconds–minutes |

- **Star vs snowflake:** snowflake normalizes dimensions (saves space, avoids update anomalies) at the cost of extra joins; star denormalizes for fewer joins and simpler queries — the usual warehouse default.
- **Freshness vs isolation:** offloading analytics to a warehouse means the analytical data is stale by one ETL cycle. HTAP trades engineering/operational complexity for real-time analytics on fresh data.
- **Compression vs CPU:** aggressive column encoding cuts I/O but costs CPU to decode — a good trade when scans are I/O-bound, which analytics usually are (and vectorized decode + RLE often lets the engine evaluate predicates without full decompression).

## Common Pitfalls

- **Single-row updates on a column store are expensive.** An in-place update would have to rewrite/seek into every column file, and it breaks compression (especially the sort order + RLE). The standard fix (DDIA): buffer writes in an **in-memory row-oriented write store**, and periodically merge it into the sorted column files on disk — the same LSM-tree idea as [LSM](_meta/glossary.md#lsm)-tree storage engines. Queries read both stores and merge. So column stores are not "no updates," but updates are batched, not point-mutations.
- **Running OLAP on the OLTP box.** A big analytical scan evicts the hot working set from the buffer pool and saturates I/O, spiking transaction latency. Separate the concerns.
- **Confusing column-oriented storage with NoSQL "column-family" stores.** Cassandra/HBase "wide-column" stores are *not* column-oriented in the DDIA/analytics sense — within a column family they still store rows together and do not do per-column compression across all rows. Different concept, similar name.
- **Assuming column order matters for reassembly** — it's *row order* (positional alignment across all column files) that must be consistent, not the order you list columns.
- **Over-normalizing the warehouse (snowflake everywhere).** Extra joins on billion-row facts hurt; dimension tables are small, so a little redundancy (star) is usually the right call.
- **Treating materialized aggregates as free.** A [materialized view](_meta/glossary.md#materialized-view) / **data cube** (OLAP cube) precomputes `GROUP BY` rollups for speed, but must be recomputed on new data and can't answer queries outside its precomputed dimensions — it's a cache, not a source of truth.

## Implementation Notes

**Star-schema fact + dimension (warehouse DDL sketch):**
```sql
-- fact table: one row per sale, mostly FKs + measures
CREATE TABLE fact_sales (
    date_key     INT   NOT NULL REFERENCES dim_date(date_key),
    product_key  INT   NOT NULL REFERENCES dim_product(product_key),
    store_key    INT   NOT NULL REFERENCES dim_store(store_key),
    quantity     INT   NOT NULL,
    net_price    NUMERIC(12,2) NOT NULL
);
-- typical analytical query: all rows, few columns, aggregate
SELECT d.year, p.category, SUM(f.net_price) AS revenue
FROM fact_sales f
JOIN dim_date d    ON d.date_key    = f.date_key
JOIN dim_product p ON p.product_key = f.product_key
GROUP BY d.year, p.category;
```

**Bitmap + run-length encoding (the DDIA compression example):**
```
product_id column (row order):  29 29 29 30 31 31 29 ...

bitmap for value 29:  1 1 1 0 0 0 1 ...   -> RLE: (3×1, 3×0, 1×1, ...)
bitmap for value 30:  0 0 0 1 0 0 0 ...
bitmap for value 31:  0 0 0 0 1 1 0 ...

WHERE product_id IN (30, 31)  ->  bitwise OR of the two bitmaps, then scan set bits.
```

**Redshift / column-store physical tuning (verify per engine):**
- Choose a **sort key** aligned to common range filters (often a timestamp) → enables zone-map/min-max block skipping and better RLE.
- Choose a **distribution key** on the join column of the largest fact so joins stay node-local.
- On-disk formats **Parquet/ORC** apply the same ideas (dictionary + RLE + bitpacking, per-column) and are what lakes/lakehouses store.

**Pipeline:** OLTP source → [CDC](_meta/glossary.md#change-data-capture)/batch ETL → warehouse (columnar). Never let a BI dashboard query the transactional primary directly.

## Variants

- **HTAP (Hybrid Transactional/Analytical Processing):** one system serving both, usually by maintaining a row store and a synchronized column store (TiDB/TiFlash, SingleStore, SQL Server columnstore indexes, Postgres columnar extensions).
- **Column-store projections (C-Store/Vertica):** the same table materialized in several sort orders, each optimized for a query class.
- **Data cube / materialized rollups:** precomputed multi-dimensional aggregates for interactive dashboards.
- **Lakehouse:** columnar files (Parquet/ORC) in object storage + a table format (Iceberg/Delta) giving warehouse-like semantics over a data lake.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 3 — "Transaction Processing or Analytics?" and "Column-Oriented Storage" (the primary source)
- Stonebraker et al., *C-Store: A Column-oriented DBMS* (VLDB 2005) — https://web.stanford.edu/class/cs345d-01/rl/cstore.pdf
- Amazon Redshift — columnar storage & compression: https://docs.aws.amazon.com/redshift/latest/dg/c_columnar_storage_disk_mem_mgmnt.html
- Apache Parquet file format (columnar, per-column encoding): https://parquet.apache.org/docs/file-format/

## Related

- [[sql-vs-nosql]]
- [[database-indexing]]
- [[acid-properties]]
- [[transaction-lifecycle]]
- [[caching]]
