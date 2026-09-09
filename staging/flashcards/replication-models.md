---
id: replication-models
type: flashcard
tags:
  - distributed-systems
  - replication
tiers:
  distributed-systems: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Replication Models

Replication keeps copies of the same data on multiple nodes for lower read latency (serve reads locally), higher availability (survive node loss), and read throughput scaling. The whole design space reduces to two questions: **where can writes originate** (single-leader, multi-leader, leaderless) and **how do writes propagate** (synchronous vs asynchronous). Every consistency anomaly you have to reason about — stale reads, reads going backward in time, effects seen before causes, lost updates — is a direct consequence of the answers to those two questions. Grounded in DDIA Ch. 5.

> [!tip] Recognition
> Reach for this vocabulary when a design question involves multiple copies of the same dataset and someone asks "what happens if a replica is behind / a node fails / two people write at once." Signals: "read replica," "failover," "async replication lag," "multi-region writes," "eventually consistent," "[quorum](_meta/glossary.md#quorum)," or a user complaint like "I posted a comment and it disappeared on refresh" (that's a replication-lag anomaly, not a bug).
>
> **vs. siblings:** replication is the *mechanism* of keeping copies (where writes originate + how they propagate). **Consensus** (Raft/Paxos) is one *sub-mechanism* used to agree on a single-leader's log; **consistency-models** is the *taxonomy of guarantees* (linearizability, causal, etc.) — the read anomalies below are replication lag's *symptoms*, and consistency-models names the *guarantees*. **Partitioning/sharding** splits *different* data across nodes; replication copies the *same* data — orthogonal and usually combined.

## When to Use

**Problem signals that suggest each model:**

- **Single-leader** — "read-heavy, one region primary, need read replicas," "we need strong-ish consistency and simple conflict handling," classic [RDBMS](_meta/glossary.md#rdbms) HA (Postgres streaming replication, MySQL, MongoDB replica set). All writes serialize through one node → no write conflicts.
- **Multi-leader** — "users write from multiple regions/datacenters with local latency," "offline-capable clients that sync later" (calendar apps, Google Docs-style collab), "merging two datacenters." Accepts writes in multiple locations → **must** resolve concurrent-write conflicts.
- **Leaderless (Dynamo-style)** — "must stay writable during node failures / network partitions," "tunable consistency per query," high write availability (Cassandra, ScyllaDB, Riak, DynamoDB internals). Client (or coordinator) writes to many replicas directly; no failover step.

**Prefer single-leader when:**
- Over multi-leader: you can tolerate all writes going to one region and you want to avoid conflict resolution entirely — this is the default; only leave it when a hard requirement forces you.
- Over leaderless: you need read-your-writes and monotonicity to be easy, and you don't need to keep writing through a leader failure without a (seconds-long) failover.

**Prefer multi-leader / leaderless when:**
- Multi-leader: write latency must be local in several regions, OR clients operate offline. Accept that you now own conflict resolution.
- Leaderless: write availability during partitions is paramount and you want per-operation tunable consistency (`w`/`r`), accepting only [eventual consistency](_meta/glossary.md#eventual-consistency) by default.

**Do not use / anti-patterns:**
- Do not choose multi-leader "for scale" if a single region can serve your writes — the conflict-resolution complexity is rarely worth it. It solves a *latency/availability* problem, not a *throughput* problem.
- Do not treat a single-leader **async** read replica as strongly consistent — it lags. Reading your own write from a replica right after writing to the leader is the #1 production surprise.
- Do not assume a leaderless quorum (`w + r > n`) gives you linearizability — it does not (see Pitfalls).

## Key Properties

**Synchronous vs asynchronous propagation** (orthogonal to the leader model):

| | Sync replication | Async replication |
|---|---|---|
| Write acked after | follower(s) confirm | leader's local write only |
| Durability on leader crash | no data loss (for sync followers) | last writes can be **lost** |
| Write latency | higher (waits on slowest sync follower) | low |
| Availability | a stalled sync follower blocks writes | writes proceed regardless |

Fully-sync replication is impractical: one slow node stalls all writes. Real systems use **semi-synchronous** — one follower is synchronous (durability), the rest async (throughput). If the sync follower fails, another async follower is promoted to sync.

**Model comparison:**

| | Single-leader | Multi-leader | Leaderless |
|---|---|---|---|
| Where writes go | one node | several leader nodes | any/many replicas |
| Write conflicts | impossible (serialized) | **possible** → must resolve | **possible** → must resolve |
| Failover needed | yes (a weak point) | no (other leaders live) | no (no leader at all) |
| Default consistency | strong on leader, lag on replicas | eventual | eventual (tunable) |
| Examples | Postgres, MySQL, MongoDB RS | CouchDB, BDR, multi-DC MySQL | Cassandra, DynamoDB, Riak |

**Quorum math (leaderless):** with `n` replicas, if every write reaches `w` replicas and every read queries `r` replicas, then **`w + r > n` guarantees the read set and write set overlap in at least one node** that has the latest value. Common: `n=3, w=2, r=2`. Tuning: `w=n, r=1` = fast reads / slow writes; `w=1, r=n` = fast writes / slow reads. Lowering `w`/`r` below the quorum trades consistency for lower latency and higher availability. Version numbers (or timestamps) let the reader pick the newest returned value; stale replicas are repaired via **[read repair](_meta/glossary.md#read-repair)** (fix on read) and **[anti-entropy](_meta/glossary.md#anti-entropy)** (background sync).

**[Replication lag](_meta/glossary.md#replication-lag) and its read anomalies** (arise under async replication / eventual consistency). Three distinct guarantees, each fixing a distinct anomaly:

| Anomaly (what the user sees) | Guarantee that prevents it | How it's fixed |
|---|---|---|
| You write, then read a stale replica and don't see your own write | **[Read-your-writes](_meta/glossary.md#read-your-writes)** (read-after-write) | Read recently-written items from the leader; or route the user to the same replica for a window after their write; or track a write timestamp/version and only read from a replica caught up to it |
| Time moves **backward**: you see a value, refresh, and see an *older* value (two replicas, different lag) | **[Monotonic reads](_meta/glossary.md#monotonic-reads)** | Pin each user to **one** replica (e.g. hash of user ID → replica), so they never jump to a less-caught-up one |
| You see an effect before its cause (answer before the question it replies to) | **Consistent-prefix reads** | Ensure causally-related writes go to the **same partition** and are applied in write order; or track causal dependencies explicitly ([HLC](_meta/glossary.md#hlc)/version vectors) |

These are progressively weaker than [linearizability](_meta/glossary.md#linearizability) but individually cheap, and interviewers expect you to name the specific guarantee that fixes a specific complaint.

## Common Pitfalls

- **"Quorum = strong consistency."** False. `w + r > n` guarantees overlap but **not** linearizability. DDIA lists the edge cases: (1) a **[sloppy quorum](_meta/glossary.md#sloppy-quorum)** with [hinted handoff](_meta/glossary.md#hinted-handoff) may write to different nodes than it reads, so overlap isn't guaranteed; (2) two concurrent writes can't be totally ordered — you need conflict resolution (e.g. [LWW](_meta/glossary.md#lww) drops data); (3) a concurrent read + write may return either value; (4) if a write succeeds on fewer than `w` nodes it's **not rolled back**, so a later read may or may not see it; (5) node failure + restore-from-old-replica can drop the count below `w` silently.
- **Sync/async confusion under "failover."** In single-leader async, promoting a new leader after a crash can **lose** the old leader's un-replicated writes. If those writes' IDs were already used elsewhere (e.g. handed to a cache/Redis or another store), you get dangerous inconsistency. This is the DDIA GitHub-autoincrement failover example.
- **[Split brain](_meta/glossary.md#split-brain) in multi-leader / bad failover:** two nodes both believe they're leader and both accept writes → conflicting divergent state. Single-leader systems guard with fencing tokens; consensus systems (Raft) guarantee at most one leader **per term**.
- **[LWW](_meta/glossary.md#lww) silently discards writes.** "Last write wins" by timestamp is the default in Cassandra, but concurrent writes with clock skew mean a "later" wall-clock timestamp may be causally earlier — you lose data with no error. Prefer [CRDT](_meta/glossary.md#crdt)s or version vectors when correctness matters.
- **Monotonic reads vs read-your-writes confused.** They fix *different* anomalies. Read-your-writes is about seeing *your own* write; monotonic reads is about not seeing time go *backward* across successive reads. Pinning to one replica gives monotonic reads but not necessarily read-your-writes (that replica could itself be behind the leader).
- **Ignoring `w`/`r` failure modes:** with `n=3, w=2`, you can tolerate one dead node for writes; with `r=2`, one dead node for reads. Assuming higher fault tolerance than the numbers allow is a classic slip.

## Trade-offs

- **Consistency ↔ availability/latency:** stronger propagation (sync, read-from-leader, higher `w`+`r`) buys consistency at the cost of write latency and reduced availability under failure. This is [CAP](_meta/glossary.md#cap) at the model level, refined by [PACELC](_meta/glossary.md#pacelc): *even with no partition*, you still trade **L**atency vs **C**onsistency (async replica reads are fast but stale).
- **Single-leader:** simplest correctness (no conflicts) but the leader is a write bottleneck and a failover weak point (seconds of unavailability + possible lost async writes).
- **Multi-leader:** local write latency and DC-failure tolerance, but you *own* conflict resolution — the hardest part. Only justified by multi-region writes or offline clients.
- **Leaderless:** best write availability and tunable per-query consistency, but eventual consistency by default, no read-your-writes for free, and LWW data-loss risk.
- **More replicas** improves read throughput and durability but multiplies write cost and widens the staleness window (more nodes to keep in sync).

## Implementation Notes

**Single-leader propagation (Postgres-style):** leader appends to its [WAL](_meta/glossary.md#wal), streams log records to followers, which replay them. Followers track a log position; lag = leader position − follower position. Failover = detect leader death (timeout) → pick the most-up-to-date follower → reconfigure clients.

**Consensus-based single-leader (Raft — the interview-grade version of "[leader election](_meta/glossary.md#leader-election) + log replication"), verified against the Raft paper (Ongaro & Ousterhout, 2014):**

```
State per node: currentTerm, votedFor, log[], commitIndex
Roles: follower -> candidate -> leader

Leader election:
  - follower's election timer fires (no heartbeat) ->
    increment currentTerm, become candidate, vote for self,
    send RequestVote to all peers
  - a node grants its vote at most ONCE per term, and only to a
    candidate whose log is at least as up-to-date as its own
  - candidate with votes from a MAJORITY (n/2 + 1) becomes leader
  - >= 1 leader per term is IMPOSSIBLE (majority vote + one-vote rule)

Log replication:
  - client command -> leader appends entry {term, cmd} to its log
  - leader sends AppendEntries (also the heartbeat) to followers
  - an entry is COMMITTED once replicated on a MAJORITY;
    leader then advances commitIndex and applies to state machine
  - Log Matching: same (index, term) => identical logs up to that index
```

Majority overlap is the same idea as leaderless quorum: any two majorities of `n` intersect, so a newly elected leader is guaranteed to have every committed entry. Paxos solves the same problem with different mechanics; Raft is preferred for teaching/implementation because leadership is explicit.

**Leaderless read/write path (Dynamo-style):**

```
n = 3, w = 2, r = 2          # w + r > n  -> overlap guaranteed
write(k, v):
  attach version/timestamp; send to all n replicas (coordinator fans out)
  ACK the client once w replicas confirm
read(k):
  query all n; wait for r responses
  pick the value with the highest version (LWW) OR return siblings
    for the app/CRDT to merge on concurrent versions
  read-repair: push the newest value back to any stale replica seen
# background anti-entropy (Merkle-tree diff) repairs replicas never read
```

## Variants

- **Semi-synchronous replication** — one sync follower for durability, rest async for throughput; the practical default in MySQL/Postgres HA.
- **Chain replication** — replicas in a chain: writes enter the head, propagate to the tail, reads served from the tail; gives strong consistency with high throughput.
- **Conflict resolution strategies (multi-leader/leaderless):** [LWW](_meta/glossary.md#lww) (lossy, simple), version vectors (detect concurrency), [CRDT](_meta/glossary.md#crdt)s (auto-merge, no data loss), or application-supplied merge (like Git).
- **Sloppy quorum + hinted handoff** — during a partition, accept writes on *any* `w` reachable nodes (not the "home" nodes) to preserve availability; hand the data back later. Raises availability, weakens the quorum guarantee.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, **Ch. 5 (Replication)** — the canonical treatment of all three models, sync/async, lag anomalies, and quorums.
- Ongaro & Ousterhout, *In Search of an Understandable Consensus Algorithm (Raft)* — https://raft.github.io/raft.pdf
- DeCandia et al., *Dynamo: Amazon's Highly Available Key-value Store* (SOSP 2007) — https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf
- Raft visualization & resources — https://raft.github.io/

## Related

- [[cap-theorem]]
- [[consensus]]
- [[consistency-models]]
- [[partitioning-sharding]]
- [[conflict-free-replicated-data-types]]
