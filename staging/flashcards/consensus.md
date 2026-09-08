---
id: consensus
type: flashcard
tags:
  - distributed-systems
  - consensus
  - raft
tiers:
  distributed-systems: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Distributed Consensus

Consensus is the problem of getting a set of nodes to agree on a single value (or a single ordered sequence of values) despite crashes, delays, and network partitions. It is the primitive that turns a pile of unreliable machines into a system that behaves like one reliable machine: leader election, distributed locks, atomic commit, uniqueness constraints, and linearizable storage all reduce to consensus. Raft and (Multi-)Paxos are the two canonical algorithms; both work by requiring a **majority quorum** to agree, so the system tolerates a minority of failures while never producing two conflicting decisions.

> [!tip] Recognition
> Reach for consensus when the design says **"exactly one leader,"** **"agree on an order,"** **"linearizable,"** **"fencing token / lease,"** **"atomic commit across shards,"** or **"who owns this partition after failover?"** Anything requiring a single source of truth that survives node failure is a consensus problem in disguise.

## When to Use

**Problem signals that suggest consensus:**
- "We need automatic **leader failover** with no split-brain" — electing exactly one primary is the textbook consensus use case (etcd, ZooKeeper, Consul all exist for this)
- "Two nodes both think they're the primary and both accepted writes" — split-brain; you need a quorum-based election plus fencing tokens
- "Reads must reflect the most recent write" (**linearizability**) — a linearizable register/store is built on consensus
- "All replicas must apply operations in the **same order**" — total-order (atomic) broadcast, which is equivalent to consensus
- "Commit this transaction across shards atomically, and survive a coordinator crash" — fault-tolerant atomic commit needs consensus (not bare two-phase commit, which blocks on coordinator failure)
- "Store a small amount of **critical metadata** reliably" — config, service discovery, lock/lease state, shard assignments

**Prefer consensus over alternatives when:**
- Over a single primary with async replication: when you cannot tolerate losing acknowledged writes or electing a stale replica on failover (async replication can lose the tail of the log)
- Over leaderless quorum reads/writes (Dynamo-style): when you need a *total order* and linearizability, not just per-key last-write-wins — sloppy quorums and read-repair give eventual consistency, not agreement on order
- Over [LWW](_meta/glossary.md#lww) / [CRDT](_meta/glossary.md#crdt) merge: when concurrent updates must be *serialized into one order*, not merged commutatively; [CRDT](_meta/glossary.md#crdt)s deliberately avoid coordination and cannot enforce global invariants like "balance ≥ 0"

**Do not use when:**
- The workload can tolerate eventual consistency → use a leaderless/AP store; consensus adds a round-trip to a majority on every write and hurts latency, especially cross-region
- You only need per-key conflict resolution with no global invariant → [CRDT](_meta/glossary.md#crdt)s or [LWW](_meta/glossary.md#lww) avoid coordination entirely
- You are tempted to build consensus yourself → don't. Use etcd/ZooKeeper/Consul or an embedded Raft library. Hand-rolled consensus is a classic source of subtle, rare, catastrophic data-loss bugs.

## Key Properties

Consensus algorithms provide these guarantees (DDIA Ch. 9):

- **Uniform agreement** — no two nodes decide differently
- **Integrity** — no node decides twice
- **Validity** — the decided value was actually proposed by some node
- **Termination** — every non-crashed node eventually decides (this is the *liveness* property, and the one FLP shows you cannot guarantee in a fully asynchronous model)

**Quorum math** — with `N` nodes, a majority quorum is `⌊N/2⌋ + 1`. Any two majorities *intersect in at least one node*, which is what prevents two conflicting decisions. Fault tolerance is therefore `N − quorum = ⌊(N−1)/2⌋`:

| Cluster size `N` | Majority quorum | Crash faults tolerated |
|---|---|---|
| 3 | 2 | 1 |
| 5 | 3 | 2 |
| 7 | 4 | 3 |

- **Odd sizes are strictly better.** A 4-node cluster still needs a quorum of 3 and tolerates only 1 fault — same tolerance as 3 nodes but more nodes to coordinate. Always run 3, 5, or 7.
- These numbers assume **crash-fault tolerance** (nodes fail by stopping). Tolerating *Byzantine* (arbitrary/malicious) faults requires `3f + 1` nodes for `f` faults (PBFT) and is only needed in trustless settings like blockchains — DDIA and Raft/Paxos assume non-Byzantine.

**Terms / ballots as a logical clock:** Raft **terms** (Paxos **ballot/proposal numbers**) are monotonically increasing integers that fence out stale leaders. A message tagged with an older term is rejected; seeing a higher term forces a node to step down. This is what makes an old, partitioned-away leader harmless when it reconnects.

**Total-order broadcast ≡ consensus:** delivering messages to all nodes reliably and in the same order is equivalent to running one consensus decision per log slot. A replicated log *is* total-order broadcast, and linearizable storage is built on top of it.

## Common Pitfalls

- **"A majority replicated it, so it's committed" — not always.** In Raft, a leader must **not** consider an entry from a *previous* term committed just because it sits on a majority; such an entry can still be overwritten by a future leader (the Raft paper's Figure 8). A leader only commits by counting replicas for an entry **from its own current term**; earlier entries then commit indirectly via the Log Matching Property. Getting this wrong causes committed-write loss.
- **Assuming consensus removes the CAP trade-off.** It doesn't. Consensus systems are **CP**: during a partition, the minority side cannot form a quorum and must **refuse writes** (and linearizable reads) to stay consistent. If your requirement is availability during partitions ([CAP](_meta/glossary.md#cap) / [PACELC](_meta/glossary.md#pacelc)), consensus is the wrong tool.
- **Split-brain from missing fencing.** Electing a new leader is not enough; the *old* leader may still be alive and processing requests. Downstream resources must reject stale leaders using a monotonically increasing **fencing token** (the term/ballot number). Leases alone, without fencing, are unsafe under clock skew and GC pauses.
- **Even-numbered clusters.** Running 2, 4, or 6 nodes buys no extra fault tolerance over 1, 3, or 5 and increases the odds of a quorum-less partition.
- **Consensus across regions on the write path.** Every write waits for a majority round-trip. If your quorum spans continents, write latency is bounded by the [RTT](_meta/glossary.md#rtt) to the nearest majority — often 100 ms+. Keep the quorum within a region or use follower/local reads.
- **Confusing 2PC with consensus.** Two-phase commit is *not* fault-tolerant consensus: a coordinator crash after prepare leaves participants blocked holding locks. Fault-tolerant atomic commit runs the commit decision *through* consensus.

## Trade-offs

**Paxos vs. Raft** — both are majority-quorum, crash-fault-tolerant, and equally safe/expressive:

| Aspect | (Multi-)Paxos | Raft |
|---|---|---|
| Design goal | Minimal, general | **Understandability** |
| Leader | Optional; Multi-Paxos adds a stable leader | Strong single leader, always |
| Log | Entries can be agreed out of order, then ordered | Strictly append-only, no holes |
| Reputation | Notoriously hard to implement correctly | Prescriptive; easier to implement right |
| Used by | Chubby, Spanner, Cassandra LWTs | etcd, Consul, CockroachDB, TiKV, Kafka KRaft |

- **Strong leader (Raft) vs. leaderless (Paxos/EPaxos):** a single leader simplifies reasoning and gives one round-trip commits in the steady state, but the leader is a throughput bottleneck and a failover pause (one election timeout, typically 150–300 ms) on crash. Leaderless variants (EPaxos) reduce tail latency and remove the hotspot at the cost of much more complex conflict handling.
- **Consistency vs. latency ([PACELC](_meta/glossary.md#pacelc)):** even with no partition, consensus pays a majority round-trip on every write. That is the price of linearizability. Reads can be made cheaper with leader leases or by serving stale follower reads (giving up linearizability).
- **Membership changes are dangerous:** naively swapping the node set can create two disjoint majorities. Raft solves this with **joint consensus** (an overlapping old+new configuration) or single-server changes; do not hand-roll reconfiguration.

## Implementation Notes

**Raft in one page** (the mental model to reconstruct in an interview):

*Three roles:* follower, candidate, leader. *Two RPCs:* `RequestVote` and `AppendEntries` ([RPC](_meta/glossary.md#rpc); `AppendEntries` with no entries doubles as the heartbeat).

```text
LEADER ELECTION
  follower hears no heartbeat within a randomized election timeout (150-300ms)
    -> becomes candidate, increments currentTerm, votes for self,
       sends RequestVote(term, lastLogIndex, lastLogTerm) to all
  a node grants its vote iff:
    - candidate.term >= its currentTerm, AND
    - it hasn't already voted this term, AND
    - candidate's log is at least as up-to-date as its own
      (compare lastLogTerm, then lastLogIndex)   <-- the safety restriction
  candidate with a MAJORITY of votes -> leader; sends heartbeats immediately
  randomized timeouts make simultaneous candidates (split votes) rare;
    a split vote just triggers another randomized round

LOG REPLICATION
  client command -> leader appends to its log (uncommitted)
  leader sends AppendEntries(term, prevLogIndex, prevLogTerm, entries[], leaderCommit)
  follower rejects if prevLogIndex/prevLogTerm don't match  (Log Matching)
    -> leader decrements nextIndex[follower] and retries until logs converge
  once an entry FROM THE CURRENT TERM is on a majority -> leader advances commitIndex
    -> apply to state machine, reply to client
  leaderCommit piggybacks the commit index so followers apply too

SAFETY INVARIANTS
  - Election Safety: at most one leader per term
  - Leader Append-Only: a leader never overwrites/deletes its own entries
  - Log Matching: same (index, term) => identical logs up to that index
  - Leader Completeness: a committed entry is present in all future leaders
      (guaranteed by the up-to-date vote check above)
  - State Machine Safety: no two nodes apply different commands at the same index
```

**Recommended config:** 3 or 5 voting members; election timeout 150–300 ms randomized; heartbeat interval well below the election timeout (e.g. 50 ms). Persist `currentTerm`, `votedFor`, and the log to stable storage (a [WAL](_meta/glossary.md#wal)) *before* responding, or a crash-restart can violate safety.

**Read strategies:**
- *Linearizable read:* confirm leadership via a quorum heartbeat (ReadIndex) or a leader lease before answering — a partitioned old leader must not serve stale reads.
- *Stale read:* answer from any follower; cheap and low-latency, but not linearizable.

## Variants

- **Multi-Paxos** — Basic Paxos decides one value; Multi-Paxos elects a stable leader to chain decisions into a log, amortizing the prepare phase (one round-trip per entry in steady state).
- **EPaxos (Egalitarian Paxos)** — leaderless; commits non-conflicting commands in one round-trip and orders only conflicting ones, improving tail latency and removing the leader hotspot.
- **ZAB** — ZooKeeper Atomic Broadcast; a Raft-like primary-backup atomic broadcast protocol predating Raft.
- **Viewstamped Replication** — an early (1988) replication protocol structurally very close to Raft.
- **PBFT / Tendermint / HotStuff** — Byzantine-fault-tolerant consensus (`3f+1` nodes) for adversarial/blockchain settings, outside DDIA's non-Byzantine scope.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 9 (Consistency and Consensus) — the primary grounding
- Ongaro & Ousterhout, *In Search of an Understandable Consensus Algorithm (Raft)* — https://raft.github.io/raft.pdf
- Raft visualization & resources — https://raft.github.io/
- Fischer, Lynch, Paterson, *Impossibility of Distributed Consensus with One Faulty Process* (FLP, 1985) — https://groups.csail.mit.edu/tds/papers/Lynch/jacm85.pdf
- Lamport, *Paxos Made Simple* — https://lamport.azurewebsites.net/pubs/paxos-simple.pdf

## Related

- [[cap-theorem]]
- [[database-replication]]
- [[linearizability]]
- [[distributed-transactions]]
- [[leader-election]]
- [[zookeeper]]
