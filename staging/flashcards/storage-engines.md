---
id: storage-engines
type: flashcard
tags:
  - databases
  - storage-engines
  - lsm-tree
  - b-tree
tiers:
  databases: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Storage Engines: B-Tree vs LSM-Tree

The storage engine is the layer that decides how a database's index and rows are laid out on disk and mutated. Two families dominate [OLTP](_meta/glossary.md#oltp): **B-trees** update fixed-size pages *in place* (optimized for reads), and **[LSM](_meta/glossary.md#lsm)-trees** (Log-Structured Merge) buffer writes in memory and flush *append-only* sorted files, converting random writes into sequential I/O (optimized for writes). The whole subject is a set of amplification trade-offs — you cannot minimize read, write, and space amplification simultaneously, so an engine picks two and pays for the third.

> [!tip] Recognition
> "Which storage engine?" / "Postgres vs Cassandra vs RocksDB" / "why is our write throughput capped" / "our SSD is wearing out from writes" / "reads got slow after a bulk delete" / "why does compaction spike latency". Whenever the question pits **write throughput against read latency or space**, reach for the B-tree ↔ LSM-tree amplification framing.

## When to Use

**Problem signals that suggest a B-tree engine (Postgres, InnoDB):**
- Read-heavy OLTP with point lookups and range scans; predictable, low read latency matters
- Strong single-key read-after-write and transactional semantics on one node
- Query planner needs an ordered index for `ORDER BY` / range predicates without a sort step

**Problem signals that suggest an LSM engine (RocksDB, Cassandra, ScyllaDB, LevelDB):**
- Write-heavy ingestion: event streams, time-series, metrics, logs, write-ahead pipelines
- Sustained high write throughput is the SLO; occasional read amplification is acceptable
- Flash/SSD where sequential writes and lower write amplification extend device life

**Prefer LSM over B-tree when:**
- Write throughput is the bottleneck — LSM turns random writes into sequential SSTable flushes and typically sustains higher write throughput (DDIA Ch.3)
- You need better on-disk compression — SSTables are densely packed sorted runs with no per-page fragmentation, so they usually compress better than a B-tree with ~50–70% page fill

**Prefer B-tree over LSM when:**
- Reads dominate and tail latency must be predictable — a B-tree lookup is a bounded ~3–4 page reads, while an LSM read may probe the memtable plus multiple SSTable levels
- You want each key to live in exactly one place — simpler locking, strong single-node transaction support, no compaction-induced latency spikes

**Do not use LSM when:** you need predictable p99 read latency and cannot tolerate compaction stalls, or the workload is read-mostly with tight range-scan latency → B-tree.
**Do not use B-tree when:** write amplification / SSD write budget is the constraint on a write-saturated table → LSM.

## Key Properties

**B-tree:**
- Breaks the file into fixed-size **pages** (traditionally 4 KB), read/written one page at a time; updates happen **in place**
- Balanced by design; a branching factor of several hundred keeps depth to ~3–4 levels even at 100M+ rows → ~3–4 page reads per lookup
- A page split (insert overflows a page) rewrites the two split pages **and** the parent — multiple in-place page writes per logical write
- Durability via a **[write-ahead log](_meta/glossary.md#wal)** (a.k.a. redo log): every modification is appended to the WAL *before* the page is overwritten, so a crash mid-split can be recovered

**LSM-tree:**
- Writes go to an in-memory sorted structure (**memtable**, e.g. a skip list / red-black tree) fronted by a WAL for durability
- When the memtable fills, it flushes to an immutable, sorted on-disk **[SSTable](_meta/glossary.md#sstable)**; SSTables are never modified, only merged
- A read checks the memtable, then SSTables newest→oldest; a key can exist in several SSTables and the newest wins
- **Bloom filters** per SSTable let a read skip files that certainly don't contain the key, cutting disk I/O for non-existent-key lookups (but they do **not** help range scans)
- **Deletes are tombstones** — a marker shadowing older versions; the key isn't physically removed until compaction

**Hash index (context — DDIA's simplest engine):**
- An in-memory hash map from key → byte offset in an append-only log file; O(1) point lookups
- Constraints: all keys must fit in RAM, and it supports **no** range queries. This is the intuition LSM generalizes by keeping the on-disk segments *sorted* (SSTables) so keys need not all fit in memory.

**Compaction** (the LSM background merge):
- Merges/sorts overlapping SSTables into new ones, discarding overwritten values and tombstoned keys, reclaiming space
- Two main strategies with opposite trade-offs:
  - **Leveled** (RocksDB default; Cassandra LCS): non-overlapping runs per level → low read & space amplification, **high write amplification** (commonly 10–30×)
  - **Size-tiered / Universal** (Cassandra STCS): merge similarly-sized runs in batches → low write amplification, **higher read & space amplification** (a merge can transiently ~double disk usage)

## The Three Amplifications

The core mental model. You are always trading these against each other.

| Amplification | Definition | B-tree | LSM |
|---|---|---|---|
| **Write** | Physical bytes written per logical byte | Page rewrites + WAL; a small update dirties a whole page | Memtable→SSTable + every compaction rewrites the key again (leveled: 10–30×) |
| **Read** | Physical reads per logical read | Low & bounded (~3–4 pages) | Higher: probe memtable + N SSTable levels (Bloom filters mitigate point reads, not ranges) |
| **Space** | Disk used per logical dataset size | ~50–70% page fill + fragmentation | Obsolete/duplicate versions + tombstones persist until compaction; tiered can transiently double |

Rule of thumb: **B-tree pays write amplification to keep read and space amplification low; LSM pays read and/or space amplification to keep write amplification low.** Compaction strategy then trades write vs read/space *within* the LSM family.

## Common Pitfalls

- **Claiming "LSM always has lower write amplification."** True vs a naive B-tree, but *leveled* compaction can hit 10–30× write amplification — worse than a B-tree on some workloads. Write amplification is compaction-strategy-dependent, not an inherent LSM win.
- **Forgetting Bloom filters don't help range scans.** A range/iterator query must open every SSTable overlapping the range regardless of Bloom filters; only *point* lookups for absent keys benefit.
- **Ignoring tombstone/range-delete cost.** Deletes create tombstones that live until compaction; a large delete then a range scan re-reads shadowed data and is slow. "Reads got slow after a mass delete" is the classic LSM tell.
- **Treating compaction as free.** Compaction competes for disk I/O and CPU; unthrottled or backed-up compaction causes write stalls and p99 spikes. This is why B-trees give more predictable read latency.
- **Confusing the SSTable/LSM WAL with the memtable.** The WAL provides durability for writes not yet flushed; the memtable is the (volatile) sorted buffer. Both a B-tree *and* an LSM use a WAL — for different reasons (crash-consistent page updates vs. durability of un-flushed writes).
- **Assuming SSTables are mutable.** They are immutable; "updating" a key writes a new version in a newer SSTable and relies on read-time newest-wins + compaction to reconcile.

## Trade-offs

- **Write throughput vs read latency:** LSM's sequential appends win on write throughput; B-tree's single-location pages win on bounded, predictable read latency. This is the headline trade.
- **Read latency vs space (within LSM):** leveled compaction gives lower, more predictable reads and bounded space at the cost of write amplification; size-tiered gives the best write amplification but worse read and space amplification.
- **SSD wear:** high write amplification burns flash program/erase cycles. On write-saturated SSD workloads, minimizing write amplification (LSM + tiered, or fewer B-tree indexes) directly extends device life.
- **Predictability vs peak throughput:** B-trees have no background merge, so latency is steadier; LSM trades that steadiness for higher peak write throughput but must schedule compaction to avoid stalls.
- **Compression & storage cost:** densely packed SSTables typically compress better than partially-filled B-tree pages, lowering storage cost — a real factor at petabyte scale.
- **One place vs many:** a B-tree keeps each key in exactly one page (simpler transactions/locking); an LSM spreads versions across SSTables (needs compaction + read-time reconciliation).

## Implementation Notes

**LSM write path (pseudocode):**
```
write(k, v):
  append (k, v) to WAL          # durability
  memtable.insert(k, v)         # in-memory sorted structure
  if memtable.size >= threshold:
    flush memtable -> new immutable SSTable (sorted) + Bloom filter
    truncate WAL segment
# background: compaction merges overlapping SSTables, drops shadowed + tombstoned keys

read(k):
  if k in memtable: return newest
  for level in levels newest..oldest:
    if bloom[level].mightContain(k):   # skip file on definite miss
      v = binary_search SSTable(level, k)
      if found: return v               # newest wins
  return NOT_FOUND

delete(k): write(k, TOMBSTONE)         # physical removal deferred to compaction
```

**Real engines / config to name in an interview:**
- **Postgres, MySQL InnoDB** — B-tree engines. InnoDB clusters the row in the PK B-tree leaf; `innodb_flush_log_at_trx_commit`, `full_page_writes` relate to the WAL/redo path.
- **RocksDB / LevelDB / Cassandra / ScyllaDB / HBase** — LSM engines. RocksDB defaults to **leveled** compaction; switch to **universal** for write-amp-sensitive, space-tolerant workloads. Cassandra: `LeveledCompactionStrategy` (read-heavy) vs `SizeTieredCompactionStrategy` (write-heavy) vs `TimeWindowCompactionStrategy` (time-series).
- **MySQL MyRocks** — RocksDB storage engine under MySQL, chosen specifically to cut write/space amplification vs InnoDB on write-heavy fleets.

**Interview framing:** name the workload (read/write ratio, delete pattern, latency SLO, SSD budget) → pick the engine family → then pick the compaction strategy. Anchor every claim to a specific amplification.

## Variants

- **Fractal tree / B-ε tree** (TokuDB): buffers writes in internal nodes to cut B-tree write amplification — a hybrid between B-tree reads and LSM-like write batching.
- **Copy-on-write B-tree** (LMDB): never overwrites pages in place; writes new pages and swaps the root — [MVCC](_meta/glossary.md#mvcc) and crash safety without a WAL.
- **Time-window compaction** (Cassandra TWCS): SSTables grouped by time window, ideal for [TTL](_meta/glossary.md#ttl)'d time-series data where whole windows expire together.
- **Key-value separation** (WiscKey / RocksDB BlobDB): store large values outside the LSM to shrink compaction write amplification.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 3 "Storage and Retrieval" — the canonical treatment (hash indexes → SSTables → LSM → B-trees → comparison)
- RocksDB Wiki — Compaction: https://github.com/facebook/rocksdb/wiki/Compaction
- RocksDB Wiki — Leveled Compaction: https://github.com/facebook/rocksdb/wiki/Leveled-Compaction
- Cassandra docs — Compaction strategies: https://cassandra.apache.org/doc/4.1/cassandra/operating/compaction/index.html

## Related

- [[database-indexing]]
- [[sql-vs-nosql]]
- [[acid-properties]]
- [[transaction-lifecycle]]
- [[caching]]
