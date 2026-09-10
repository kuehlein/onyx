---
id: quorum-consistency
type: flashcard
tags:
  - distributed-systems
  - replication
  - quorum
  - consistency
tiers:
  distributed-systems: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Quorum Consistency (Leaderless / Dynamo-style)

In a leaderless ([Dynamo-style](_meta/glossary.md#dynamo)) replicated store, every key is stored on `N` replicas and there is *no leader* — the client (or a coordinator on its behalf) writes to and reads from *many replicas in parallel*. A write is acknowledged once `W` replicas confirm it; a read gathers responses from `R` replicas and picks the newest by version. The single load-bearing rule is **`R + W > N`**: it forces the read set and the write set to overlap in *at least one* replica, so any read is guaranteed to touch a node that saw the latest successful write. Because there is no leader to serialize operations, availability is high (any replica can serve), but the consistency you get is only *eventual*, tunable via `R`/`W` — never linearizable. This is the Amazon Dynamo model and the basis of [Cassandra](_meta/glossary.md#cassandra) / Riak / Voldemort (DDIA Ch.5).

> [!tip] Recognition
> Reach for quorum reasoning when you see: **"N replicas, choose R and W,"** **"tunable consistency"** (`ONE`/`QUORUM`/`ALL`), **"no leader / any node accepts writes,"** **"read repair,"** **"hinted handoff,"** **"anti-entropy / Merkle tree repair,"** or **"stays writable during a partition."** Any AP-leaning, multi-datacenter, write-always-available store is a quorum system.
>
> **vs. single-leader replication:** a leader imposes a *total order* on writes (and can be linearizable); a leaderless quorum has no such order — concurrent writes to one key are reconciled after the fact, either by [LWW](_meta/glossary.md#lww) (highest timestamp wins, e.g. Cassandra) or by [version vectors](_meta/glossary.md#version-vector) that surface *siblings* for the client to merge (e.g. Riak). **vs. consensus (Raft/Paxos):** a *majority quorum in consensus* agrees on an ordered log and is linearizable/CP; a *Dynamo read/write quorum* only guarantees overlap, not order — it is not consensus.

## When to Use

**Problem signals that point to a leaderless quorum store:**
- "The system must **stay writable even during a network partition** or node failure" — no failover pause; any reachable replica takes the write
- "We can **tune consistency per operation**" — cheap `R=W=1` for logs/metrics, `R+W>N` (e.g. `QUORUM`) for read-your-writes on important keys
- "**Multi-datacenter, write-anywhere, low-latency** writes" — clients hit the nearest replicas; conflicts reconciled later
- "Occasional **stale reads are acceptable**" — the workload tolerates eventual consistency
- "We keyed everything and only ever do **single-key get/put**" — quorum stores have no cross-key transactions or joins

**Prefer a quorum store over alternatives when:**
- Over single-leader replication: when you cannot accept a leader as a write bottleneck / single point of failover, and you value write availability over a global order
- Over consensus (Raft/Paxos, [[consensus]]): when you want **AP** (availability under partition), not **CP** — you don't need linearizability or an agreed total order, just high uptime with eventual convergence
- Over a cache: when you need durable, replicated storage that survives node loss, not just best-effort speedup

**Do not use when:**
- You need **linearizability / read-after-write across clients**, uniqueness constraints, or "balance ≥ 0" invariants → use [[consensus]] or a single-leader store; quorums cannot enforce global invariants
- You need **multi-key atomic transactions**, secondary-index joins, or a total order of operations → wrong tool
- Contention is high and **conflicting concurrent writes are common** → you inherit sibling/conflict-resolution complexity (LWW silently drops data)

## Key Properties

- **`N`, `W`, `R` are the three dials.** `N` = replicas per key (the replication factor, not the cluster size). `W` = replicas that must ack a write. `R` = replicas that must respond to a read. The client picks `W`/`R` per request.
- **The overlap rule: `R + W > N` guarantees the read and write sets intersect** in at least one node, so a read sees at least one replica carrying the latest committed write. It is the entire correctness argument for strict quorums.
- **Common configuration:** `N` odd, `W = R = ⌈(N+1)/2⌉` (a majority) — e.g. `N=3, W=R=2`. This tolerates one node down for both reads and writes while keeping overlap.
- **Tuning shifts the cost.** `R+W>N` still lets you trade: `W=N, R=1` = fast reads, slow/fragile writes; `W=1, R=N` = fast writes, slow reads. `W=R=1` (so `R+W ≤ N`) gives max availability but **no overlap guarantee** — purely eventual.
- **Versioning is mandatory.** A read may return several values from different replicas; the store must decide which is "newest." Two families: **LWW** tags each write with a timestamp and keeps the highest (simple, lossy, clock-dependent — Cassandra, at the *cell* level); **version vectors** detect genuinely concurrent writes and surface them as **siblings** for the client to merge (Riak). Ordering here means causal/version ordering, not the reliability of wall-clock time.
- **Convergence is a separate mechanism.** Overlap only guarantees a *read* can find the latest value; getting *all* replicas up to date needs **read repair** (fix stale replicas seen during a read) and **anti-entropy** (background Merkle-tree comparison, e.g. Cassandra `nodetool repair`).
- **Availability math differs from consensus.** A strict-quorum write needs `W` of `N` replicas reachable; it does not need a *cluster majority*. Consensus needs a majority of the *whole* voting set to agree on an order — a stronger, CP requirement.

## Common Pitfalls

- **Believing `R + W > N` gives you linearizability.** It does **not**. It only guarantees *overlap*, which is weaker than a recency/order guarantee (DDIA Ch.5 & Ch.9). Concurrent writes, failed writes rolled forward, and sloppy quorums all break it — see Trade-offs.
- **Forgetting concurrent writes have no total order.** Two clients writing the same key "at the same time" both succeed. Under **[LWW](_meta/glossary.md#lww)** (Cassandra — resolved per *cell* by client timestamp) the lower-timestamp write is **silently discarded**, a classic data-loss trap worsened by clock skew. Under **version vectors** (Riak) both survive as *siblings* the app must merge — safer, but pushes reconciliation onto you. Note Cassandra does **not** produce siblings or use version vectors at all; that is the Riak/Voldemort model.
- **Assuming a sloppy quorum still guarantees overlap.** A **sloppy quorum** accepts `W` acks from *any* reachable nodes, including ones outside the key's `N` home replicas. Those extra nodes are *not* in the read set, so `R+W>N` no longer guarantees the reader sees the write until **hinted handoff** delivers it home. Sloppy quorums raise availability at the cost of the overlap guarantee.
- **Treating a failed write as rolled back.** If a write reaches only some of `W` replicas and the client reports failure, the partial write is **not undone**. A later read may or may not see it — quorum stores have no atomic rollback.
- **Confusing `N` with cluster size.** `N` is the per-key replication factor (often 3). A 100-node Cassandra cluster still has `N=3` per key.
- **Skipping anti-entropy repair.** Read repair only fixes keys that are actually read; rarely-read stale replicas silently diverge (and deleted-then-resurrected data — *zombies* — appear if repair doesn't run within the tombstone GC window). Schedule `nodetool repair`.

## Trade-offs

**Why quorums are NOT linearizable — the failure modes (DDIA Ch.5, "Limitations of Quorum Consistency"):**

| Scenario | Why `R+W>N` fails to give recency |
|---|---|
| **Concurrent writes** | No total order; overlap can't say which of two siblings is "latest." Merged by LWW/version vectors, not serialized. |
| **Sloppy quorum** | Write acked on non-home nodes; read quorum hits home nodes → sets may not overlap until hinted handoff completes. |
| **Read concurrent with a write** | A read racing an in-flight write may see it on some replicas, not others — result is nondeterministic (which value "wins" isn't defined). |
| **Partially failed write** | Write hit `< W` replicas, reported failure, but isn't rolled back; readers may or may not see it. |

- **Availability vs. consistency (AP vs. CP).** Quorum stores are the **AP** corner of [CAP](_meta/glossary.md#cap): with low `W`/`R` (or sloppy quorums) they stay available through partitions but only converge eventually. Push `R+W>N` and you get *stronger* read guarantees but *lower* availability (more replicas must be up). You cannot get linearizability out of this dial — that needs [[consensus]].
- **vs. single-leader replication:** a leader gives a total write order and can offer linearizable reads/uniqueness, but is a failover chokepoint and can lose the tail of its async log on failover. Leaderless trades that away for symmetric, always-writable replicas with no failover — and no global order.
- **Latency shaping via `R`/`W`.** Reads and writes wait for the *slowest* of the `R` (or `W`) fastest responders, so tail latency improves as you *lower* `R`/`W` — directly at the expense of the overlap guarantee.
- **Conflict-resolution burden moves to you.** No leader means the app (or the store's LWW/CRDT/version-vector logic) must reconcile siblings. Getting this wrong is the dominant source of data loss in Dynamo-style systems.

## Implementation Notes

- **Cassandra tunable consistency** maps directly onto `W`/`R`: consistency levels `ONE`, `QUORUM` (`floor(sum_of_RF / 2) + 1`, summed across all DCs), `LOCAL_QUORUM` (majority *within one datacenter*), `EACH_QUORUM`, `ALL`. `LOCAL_QUORUM` on both read and write is the common multi-DC choice — quorum within a DC, async cross-DC. Note Cassandra always *sends* writes to all replicas regardless of level; the level only sets how many acks the coordinator waits for.
- **Read-your-writes** within a session requires `R + W > N` (e.g. write `QUORUM`, read `QUORUM`); `ONE`/`ONE` does not.
- **Hinted handoff:** when a home replica is down, the coordinator stores a *hint* and replays the write once the node returns — bounded by a hint window (older hints dropped, so still run repair).
- **Anti-entropy:** replicas exchange **Merkle trees** to find and reconcile divergent ranges cheaply (`nodetool repair`); this is the safety net read repair can't provide for cold data.
- **Linearizable ops when you truly need them:** Cassandra offers **lightweight transactions** (LWT, `IF NOT EXISTS` / compare-and-set) that run **Paxos** for that single operation — an explicit, expensive escape hatch *out* of the quorum model into per-key consensus.

## Variants

- **Strict quorum** — reads/writes go to the designated `N` home replicas; `R+W>N` holds.
- **Sloppy quorum + hinted handoff** — `W` acks from any reachable nodes during a failure; hints later delivered home. Higher availability, weaker overlap.
- **`W=R=1` (max availability)** — no overlap guarantee; purely eventual (metrics, logs).
- **Conflict resolution:** **LWW** (timestamp wins, lossy) vs. **version vectors / siblings** (client merges) vs. **[CRDT](_meta/glossary.md#crdt)** (commutative merge, no coordination).

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch.5 (Leaderless Replication: Quorums, Sloppy Quorums, Read Repair, Limitations of Quorum Consistency) — the canonical grounding
- DeCandia et al., *Dynamo: Amazon's Highly Available Key-value Store* (SOSP 2007) — https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf
- Apache Cassandra — Configuring Data Consistency (consistency levels): https://cassandra.apache.org/doc/stable/cassandra/architecture/dynamo.html
- Apache Cassandra — Hints (hinted handoff): https://cassandra.apache.org/doc/stable/cassandra/managing/operating/hints.html

## Related

- [[database-replication]]
- [[consensus]]
- [[cap-theorem]]
- [[linearizability]]
- [[consistent-hashing]]
- [[eventual-consistency]]
