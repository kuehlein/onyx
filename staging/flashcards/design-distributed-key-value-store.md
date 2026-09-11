---
id: design-distributed-key-value-store
type: system-design
tags:
  - system-design
  - distributed
  - key-value-store
  - consistent-hashing
  - quorum
  - replication
tiers:
  system-design: 3
created: 2026-09-11
confidence: high
priority: normal
---

# Design a Distributed Key-Value Store

A horizontally scalable, always-writable `get(key)`/`put(key, value)` store (Dynamo-style) spread across hundreds of commodity nodes with no single master. The crux is the CAP choice under partition: this design deliberately picks **availability over strong consistency**, which pushes every hard problem — partitioning, replication, conflict resolution, failure recovery — into the data plane rather than a coordination service.

> [!tip] Interview signals
> The interviewer is really probing two decisions: (1) **how you place and replicate data without a master** — do you reach for consistent hashing with virtual nodes and quorum reads/writes, and can you explain N/W/R? and (2) **what happens to consistency when a partition heals** — do you understand that "always writable" means concurrent conflicting writes are *inevitable*, and can you reason about vector clocks vs last-write-wins? Classic curveballs: "Two clients `put` the same key on either side of a network split — what does a later `get` return?", "A node is down for 10 minutes then rejoins — how does it catch up?", "W+R > N gives you what, exactly, and why isn't that linearizability?" Junior answers hand-wave "it replicates"; senior answers name the exact mechanism (hinted handoff, Merkle-tree anti-entropy) and own the trade-off out loud (staleness/conflicts are the *price* of availability).

## Problem & Requirements

**Scope-narrowing questions a strong candidate asks first**
- Value size and shape? (Assume opaque blobs, ~1 KB avg, up to a few hundred KB — no server-side query/secondary indexes, pure primary-key access.)
- Consistency needs? (Assume eventual consistency is acceptable; the app can tolerate/resolve occasional conflicts. This is the whole reason we can go masterless.)
- Read vs write mix? (Assume write-heavy — a shopping cart / session store — since availability-on-write is the headline requirement.)
- Single region or multi-region? (Design single-region first; note the multi-region extension.)
- Durability bar? (No data loss on single-node failure; survive a rack/AZ outage.)

**Functional**
- `get(key)` returns the value (or the set of conflicting values) for a key.
- `put(key, value, context)` writes a value; `context` carries causality (version) from a prior read.
- No transactions across keys, no range scans, no joins.

**Non-functional**
- Scale: ~100 TB of data, hundreds of nodes; grow by adding nodes with minimal data movement.
- Availability: 99.99%+ — writes must succeed even during node failures and network partitions.
- Latency: p99 read/write under ~10 ms in-datacenter.
- Consistency: tunable (per-request), eventual by default; **read-your-writes** achievable via quorum.
- Elasticity: adding/removing a node re-homes only ~K/N keys.

## Estimation

- Assume 500 M keys, ~1 KB each ⇒ **~500 GB logical**, but round the working target to ~100 TB to include large values, multiple keyspaces, and headroom.
- Traffic: 50 M DAU, 40 requests/user/day ⇒ 2 B req/day ⇒ **~23,000 req/s average**. Peak ≈ 5× ⇒ **~115,000 req/s**.
- Write-heavy mix, say **read:write ≈ 2:1** ⇒ ~77 K reads/s, ~38 K writes/s at peak.
- Replication factor **N = 3** ⇒ each write becomes 3 physical writes ⇒ **~115 K physical writes/s** at peak; reads at R=2 ⇒ ~154 K physical reads/s.
- Storage with N=3: 100 TB × 3 = **300 TB raw**. At ~2 TB usable/node ⇒ **~150 nodes** (before virtual-node overcommit and headroom → ~200).
- Bandwidth: the 115 K physical writes/s already include the 3× replication, so replication traffic ≈ 115 K × 1 KB ≈ **~115 MB/s** (equivalently 38 K logical writes/s × 1 KB × N=3); comfortably within a datacenter fabric.
- Per-node QPS: 154 K reads / 200 nodes ≈ **~770 reads/s/node** — modest, so the constraint is storage density and tail latency, not raw CPU.

## API Design

- `PUT /v1/objects/{key}` — body: value; header `X-Version-Context: <opaque vector-clock token from last GET>`; optional `?w=` override. → `200 {version_context}` on quorum ack, `503` if quorum unreachable.
- `GET /v1/objects/{key}` — optional `?r=` override. → `200 {value, version_context}`; on conflict → `300 {values:[{value, version_context}...]}` (siblings — client must reconcile and `PUT` back).
- `DELETE /v1/objects/{key}` — implemented as a tombstone write (a delete is just a special versioned value; GC'd later).
- Internal RPCs (not client-facing): `Coordinator.Replicate(key, value, vclock)`, `Node.HintedWrite(...)`, `Node.MerkleRange(range)` / `Node.SyncKeys([...])` for anti-entropy, gossip `Membership.Ping/State`.

Note the API is deliberately thin — no server-side conflict resolution for opaque values; the client (or a registered merge function) owns semantic reconciliation.

## Data Model & Storage

- Single logical entity: `(key, value, version_context, timestamp)`. Keys are opaque strings; values opaque bytes. No schema, no secondary indexes → this is exactly why **NoSQL / a plain KV engine** fits: access is 100% by primary key, we need write throughput and horizontal partitioning, and we explicitly gave up relational queries and cross-key transactions (SQL would buy us nothing here and cost us the masterless scaling).
- **Partitioning/sharding key:** the object key itself, hashed onto the [[consistent-hashing]] ring. Virtual nodes give each physical node many ring tokens so load and re-homing are smooth and heterogeneity-aware.
- **Per-node storage engine:** an LSM-tree ([[storage-engines]]) — writes go to a [[write-ahead-logging|WAL]] then an in-memory memtable, flushed to immutable sorted files, compacted in the background. This matches the write-heavy profile (sequential appends) far better than a B-tree's in-place random writes. Reads use a [[bloom-filter]] per SSTable to skip files that can't contain the key.
- Each replica stores the value plus its `version_context` (vector clock) so conflicts are detectable at read time.

## High-Level Design

Fully symmetric ring — **any node can coordinate any request** (routed by a smart client or an [[api-gateway|coordinator node]] that looks up the key's position on the ring). Membership and health propagate via **gossip**; no central config master.

**Write path (`put`):**
1. Client (or coordinator) hashes the key to a ring position; the **preference list** = the next N distinct physical nodes walking clockwise (skipping vnodes of already-chosen physical nodes; spanning racks/AZs).
2. Coordinator advances the vector clock and sends the write to all N replicas in parallel.
3. Once **W** replicas ack, the coordinator returns success. If a replica is down, the write goes to a live fallback node tagged with a **hint** (hinted handoff) so it counts toward W and is later delivered home.

**Read path (`get`):**
1. Coordinator sends the read to the preference-list replicas; waits for **R** responses.
2. If versions agree, return the value. If replicas disagree (concurrent versions), return **all siblings** and trigger **read repair** (write the reconciled/latest version back to stale replicas).

Setting **W + R > N** guarantees the read set and write set overlap by at least one node, so a quorum read sees the latest quorum write — see [[quorum-consistency]]. This is *not* linearizability (no total order across all clients), but it gives strong-enough guarantees like read-your-writes when tuned.

## Deep Dives

### 1. Partitioning: consistent hashing + virtual nodes
Naive `hash(key) mod N` remaps almost every key when N changes. Instead map keys and nodes onto a ring ([[consistent-hashing]]); a key belongs to the first node clockwise. Adding a node steals only one arc (~K/N keys). Problem: with few physical nodes, arcs are lumpy and a failed node dumps its whole load onto one neighbor. **Fix: virtual nodes** — each physical node claims many tokens, so its keyspace is scattered across the ring. Benefits: (a) smooth load, (b) a failed node's load spreads across *many* neighbors, (c) beefier hardware simply gets more tokens. Recommended: hundreds of vnodes per physical node.

### 2. Replication, quorum, and tunable consistency (N/W/R)
Replicate each key to the N nodes on its preference list. Expose **N, W, R** as knobs:
- `W=N, R=1`: read-optimized, slow/less-available writes.
- `W=1, R=N`: write-optimized, always writable, slow reads.
- `W=R=2, N=3` (the common default): W+R=4>3 ⇒ quorum overlap, balanced, tolerates one node down. See [[quorum-consistency]], [[replication-models]], [[consistency-models]].
Because we allow sloppy quorum (hinted handoff lets a fallback node satisfy W), overlap isn't *strictly* guaranteed during failures — which is precisely why we still need conflict resolution.

### 3. Conflict resolution: vector clocks vs LWW
Two clients writing the same key during a partition both succeed → divergent versions. To decide "is B a descendant of A, or are they concurrent?" attach a **vector clock** — a `{node: counter}` map ([[logical-clocks]]). On read, if one clock dominates another, keep the newer; if **concurrent (neither dominates)**, return both as siblings for the client to merge (e.g. union two shopping carts). Trade-off: vector clocks capture true causality but can grow; cap their length (evict oldest `{node,counter}` with a timestamp), accepting rare false-concurrency. Simpler alternative: **last-write-wins (LWW)** by wall-clock timestamp — trivial and stateless but silently drops a concurrent write and is hostage to clock skew. Recommendation: vector clocks when the app can merge (carts, sessions); LWW only when losing a concurrent write is acceptable.

### 4. Failure handling: hinted handoff + anti-entropy (Merkle)
- **Transient failure → hinted handoff:** if replica X is down, write to fallback Y with a hint "for X." When X returns, Y streams the hinted writes back, then drops them. Keeps W satisfiable during blips without permanent overreplication.
- **Permanent divergence / missed hints → anti-entropy with [[merkle-tree|Merkle trees]]:** each node keeps a Merkle tree over each key range it owns. Two replicas compare *root hashes*; if equal, they're in sync (one comparison). If not, they walk down only the differing branches, transferring just the keys that actually diverged — bandwidth proportional to the *difference*, not the dataset. This background repair converges replicas that hinted handoff/read-repair missed.

## Trade-offs & Bottlenecks

| Decision | Chosen | Alternative | Why |
|---|---|---|---|
| CAP under partition | AP (available) | CP (consistent) | Requirement is always-writable; app tolerates eventual consistency ([[cap-theorem]]) |
| Consistency model | Tunable quorum, eventual | Strong/linearizable | Avoids master + consensus on the hot path; W+R>N gives strong-*enough* |
| Conflict resolution | Vector clocks (siblings) | LWW timestamps | Never silently lose a concurrent write; cost is client-side merge |
| Partitioning | Consistent hashing + vnodes | `hash mod N` | Minimal re-homing on resize; smooth load; graceful failure spread |
| Storage engine | LSM-tree | B-tree | Write-heavy profile favors sequential appends over in-place writes |
| Coordination | Gossip, masterless | ZooKeeper/central config | No single point of failure; scales membership without a bottleneck |

**Bottlenecks under scale**
- **Hot keys:** one popular key concentrates traffic on its N replicas regardless of vnodes (vnodes spread *keys*, not a *single* key's load). Mitigate with a client/coordinator cache in front, request coalescing, or splitting the value.
- **Sibling explosion:** pathological churn/partitions can produce many concurrent versions; cap vector-clock size and truncate, and prefer mergeable value types.
- **Compaction I/O & read amplification:** LSM background compaction competes with foreground traffic; tune compaction, use bloom filters, and provision I/O headroom.
- **Tail latency:** p99 is dominated by the slowest of W/R responses; mitigate with hedged/speculative requests and by reading from the R fastest replicas.

## Related
[[consistent-hashing]]
[[quorum-consistency]]
[[replication-models]]
[[consistency-models]]
[[logical-clocks]]
[[merkle-tree]]
[[cap-theorem]]
[[storage-engines]]
[[bloom-filter]]
[[write-ahead-logging]]
