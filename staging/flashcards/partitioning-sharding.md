---
id: partitioning-sharding
type: flashcard
tags: [distributed-systems, partitioning, sharding]
tiers: { distributed-systems: 1 }
created: 2026-09-08
confidence: high
priority: normal
---

# Partitioning (Sharding)

Partitioning (a.k.a. sharding) splits one logical dataset across many nodes so that each node holds only a subset, letting storage and throughput scale horizontally beyond a single machine. The core design problem is choosing a partitioning scheme that keeps load *even* — a badly chosen key concentrates reads/writes on one partition (a hot spot), and no amount of extra nodes helps. Partitioning is almost always combined with replication: each partition is replicated across nodes for fault tolerance, orthogonally to how data is split. Terminology is a minefield — the same idea is called *shard* (MongoDB, Elasticsearch, [RDBMS](_meta/glossary.md#rdbms)), *region* (HBase), *tablet* (Bigtable/Spanner), *vnode* (Cassandra, Riak), and *vBucket* (Couchbase). DDIA uses "partition."

> [!tip] Recognition
> Reach for partitioning when a single node can no longer hold the dataset or serve the write throughput — "our primary DB is at 4 TB and write IOPS is maxed," "one table has 50 B rows," "the leader replica can't keep up with writes." The interview tells: they ask how you'd distribute data across nodes, how you route a request to the right node, how you avoid a *celebrity/hot key*, and how you *rebalance* when adding capacity. If the question is only about read scaling or read latency, the answer is usually replication or indexing first — partitioning is the tool for when the *write* path or *dataset size* exceeds one node.

## When to Use

**Problem signals that suggest partitioning:**
- "The dataset no longer fits on one node" — storage exceeds a single machine's disk (multi-TB → PB).
- "Write throughput exceeds what one leader can handle" — replication scales reads, not writes; the write path bottlenecks on the single leader.
- "We need to keep growing linearly by adding nodes" — horizontal scale-out as the explicit requirement.
- "Tenant data must be isolated / co-located per region" — partition by tenant or geography for isolation, locality, or data-residency law.

**Prefer partitioning over alternatives when:**
- Over read replicas: replicas fan out *reads* but every write still hits the single leader; partition when *writes* or *size* are the wall.
- Over a bigger box (vertical scaling): when you've exhausted vertical scaling economically, or need fault isolation so one node's failure loses only 1/N of the data.
- Over indexing/caching: those cut read latency on a dataset that still fits one node; partitioning is for when the data or write load itself no longer fits.

**Do not use when:**
- The dataset fits comfortably on one node and writes are within a single leader's capacity → partitioning adds cross-partition query cost, rebalancing ops, and distributed-transaction pain for no benefit.
- Queries are inherently cross-partition (frequent joins/aggregations over the whole set) → sharding turns every query into a scatter/gather; consider an [OLAP](_meta/glossary.md#olap) store or a different data model first.
- You just need read scaling or lower read latency → add replicas / indexes / a cache first.

## Key Properties

**Two primary key-partitioning strategies (DDIA Ch. 6):**

| | Key-range partitioning | Hash-of-key partitioning |
|---|---|---|
| Assignment | Contiguous ranges of the sort key (e.g. `a–f`, `g–m`) | Ranges of a *hash* of the key |
| Range queries | Efficient — keys stored in sorted order, scan one/few partitions | Broken — adjacent keys scatter across partitions; must query all |
| Hot-spot risk | High if the key is monotonic (timestamps) — all recent writes hit one partition | Low — hashing spreads sequential keys evenly |
| Example systems | HBase, Bigtable, Spanner, MongoDB (range mode) | Cassandra, DynamoDB, MongoDB (hash mode), Riak |

- **Compound keys mitigate the range/hash tension.** Cassandra hashes only the *partition key* to place data, then stores rows *sorted* by the *clustering columns* within a partition — so you get even distribution across partitions *and* efficient range scans within one (e.g. partition by `user_id`, cluster by `timestamp`).
- **Hashing kills range queries but not exact lookups.** A good hash function (Cassandra uses Murmur3, not a cryptographic hash — speed matters, not security) distributes keys uniformly; you lose ordered scans in exchange.
- **Consistent hashing is a specific technique, not the whole story.** DDIA notes it maps both keys and nodes onto a ring so adding/removing a node only moves keys on the adjacent arc — but classic Dynamo-style consistent hashing gives poor balance, which is why real systems layer *virtual nodes* on top (see Implementation Notes).

**Local vs global secondary indexes:**

| | Local / document-partitioned | Global / term-partitioned |
|---|---|---|
| Index layout | Each partition indexes only its own rows | One index partitioned by the *indexed term*, independent of primary partitioning |
| Read (by secondary key) | **Scatter/gather** — query every partition, merge | Hits only the partition holding that term — efficient |
| Write | Local — one partition update | Touches multiple index partitions; usually **asynchronous** (read-after-write may lag) |
| Systems | MongoDB, Cassandra, Elasticsearch, Riak, VoltDB | DynamoDB global secondary indexes, Riak (search) |

## Common Pitfalls

- **Monotonic key + range partitioning = write hot spot.** Partitioning by timestamp (or auto-increment ID) with range partitioning sends *all* new writes to the last partition. Fix: prefix the key with something high-cardinality (e.g. `sensor_id` then timestamp) so writes spread, at the cost of needing N queries for a time range across all sensors.
- **Celebrity / hot key that hashing cannot fix.** Hashing spreads *distinct* keys, but a single hot key (a celebrity user's ID, one viral tweet) all hashes to one partition. DDIA notes systems do not solve this automatically — the app must split the hot key manually (append a random 2-digit suffix → 100 sub-keys → 100 partitions), which then requires reading all 100 and combining. Only apply this to the few keys that are actually hot; it adds read overhead.
- **`hash(key) mod N` for partition assignment.** Tempting but wrong: changing N (adding a node) remaps almost *every* key, forcing a massive rebalance. Use a fixed large partition count or consistent hashing instead so only a fraction of keys move.
- **Assuming a global secondary index is read-your-writes consistent.** Global (term-partitioned) index updates are typically asynchronous, so a read immediately after a write may not see the new row in the index.
- **Forgetting scatter/gather cost of local indexes.** Any query on a local secondary index that isn't the partition key must hit every partition; tail latency ([P99](_meta/glossary.md#p99)) is governed by the *slowest* partition, so it degrades as you add partitions.

## Trade-offs

- **Range vs hash:** range keeps efficient ordered scans but risks monotonic-key hot spots; hash spreads load but destroys range-query locality. Compound partition+clustering keys buy back within-partition ordering.
- **Local vs global secondary index:** local = cheap writes, expensive (scatter/gather) reads; global = cheap targeted reads, expensive multi-partition (and async) writes. Pick based on read vs write ratio and consistency needs.
- **Fixed vs dynamic rebalancing:** a large fixed partition count is operationally simple (only whole partitions move, never split) but you must guess the right count up front and each partition carries fixed overhead; dynamic splitting/merging adapts to data volume automatically but adds coordination complexity and can thrash under bursty load.
- **More virtual nodes = more even balance but worse availability/repair.** Cassandra's `num_tokens` trades distribution smoothness against the number of peer nodes each node shares data with (which affects availability and streaming/repair cost) — the default was lowered from 256 to 16 in Cassandra 4.0 precisely because 256 hurt availability and made repair painful.
- **Partitioning vs distributed transactions:** once a logical operation spans partitions, you lose cheap single-node atomicity and need two-phase commit or a saga; a well-chosen partition key that co-locates related data (e.g. all of one tenant's rows) avoids this. This is why entity-group / partition-key design dominates schema choices in sharded stores.

## Implementation Notes

**Virtual nodes (the fix for consistent hashing's imbalance):** instead of one token per physical node on the ring, assign many (Cassandra: `num_tokens`, default 16 in 4.0+). Each physical node owns many small ranges scattered around the ring. Benefits: (1) balance smooths out as tokens average; (2) adding a node steals a slice from *many* nodes at once (faster rebalance, no single donor); (3) heterogeneous hardware can be given proportionally more vnodes.

**Rebalancing strategies (DDIA):**

```
# BAD: hash mod N  — changing N remaps almost everything
partition = hash(key) % num_nodes          # avoid

# GOOD 1: fixed number of partitions (Riak, ES, Couchbase style)
#   Create way more partitions than nodes up front (e.g. 1000 partitions, 10 nodes).
#   A node owns ~100 partitions. Adding a node => it *steals* whole partitions
#   from existing nodes; the key->partition map never changes, only partition->node.
num_partitions = 1000                       # fixed at cluster creation
partition = hash(key) % num_partitions      # stable: num_partitions never changes
node = partition_to_node_map[partition]     # only THIS map changes on rebalance

# GOOD 2: dynamic partitioning (HBase, Bigtable, MongoDB, RethinkDB)
#   Partitions split when they exceed a size threshold, merge when they shrink.
#   Partition count tracks data volume; no need to guess up front.

# DynamoDB-style: fixed key-range partitions decoupled from node placement,
#   hot partitions split and half moves to a lightly loaded node (adaptive).
```

**Request routing (service discovery — "how does a client find the right partition?"):** three DDIA approaches —
1. Client contacts any node; if it doesn't own the key it forwards the request (Cassandra/Riak gossip — any node can act as coordinator).
2. A routing tier / partition-aware load balancer sits in front and forwards (MongoDB `mongos`).
3. Client is partition-aware and queries the right node directly.

Many systems keep the partition→node mapping in a separate coordination service (ZooKeeper/etcd) that routers subscribe to; the routing layer must stay in sync as rebalancing changes ownership. Redis Cluster instead hard-codes 16384 hash slots (`CRC16(key) mod 16384`) split across nodes, and clients cache the slot→node map, redirecting on a `MOVED` reply.

## Variants

- **Consistent hashing (Dynamo/Karger):** keys and nodes on a hash ring; each key owned by the next node clockwise. Minimizes key movement on membership change; needs vnodes for balance.
- **Fixed hash-slot (Redis Cluster):** 16384 slots via `CRC16 mod 16384`; simple mental model, explicit slot migration.
- **Range-partitioned with auto-split (HBase / Bigtable tablets, Spanner):** ordered key space split into ranges that split/merge by size; great for range scans.
- **Directory/lookup-based sharding:** an explicit lookup table maps key→shard (flexible, allows arbitrary placement, but the directory is a lookup on every request and a scaling concern itself).

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 6 "Partitioning" (O'Reilly, 2017) — the primary source for every claim here.
- Amazon Dynamo paper (SOSP 2007): https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf
- Cassandra virtual nodes / `num_tokens` docs: https://cassandra.apache.org/doc/latest/cassandra/architecture/dynamo.html
- Redis Cluster specification (hash slots): https://redis.io/docs/latest/operate/oss_and_stack/reference/cluster-spec/

## Related

- [[database-replication]]
- [[consistent-hashing]]
- [[database-indexing]]
- [[cap-theorem]]
- [[sql-vs-nosql]]
- [[hash-map]]
