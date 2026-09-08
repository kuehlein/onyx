---
id: consistency-models
type: flashcard
tags:
  - distributed-systems
  - consistency
tiers:
  distributed-systems: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Consistency Models

A consistency model is the contract between a distributed data store and its clients about *which values a read is allowed to return* given the writes that have happened. The models form a spectrum from strong to weak — [linearizability](_meta/glossary.md#linearizability), then [causal](_meta/glossary.md#causal-consistency), then [eventual](_meta/glossary.md#eventual-consistency) — where each step down relaxes a guarantee to buy availability and lower latency. The core tension is [CAP](_meta/glossary.md#cap): the strongest model (linearizability) cannot be served while remaining available during a network partition, whereas causal and eventual consistency can.

> [!tip] Recognition
> Reach for **consistency models** whenever data is replicated and a design question asks "will a reader see a stale value?", "what happens to reads during a partition?", or "can two clients disagree about the order of updates?". Interview signals: geo-replicated databases, multi-leader/leaderless replication, "read-your-own-writes", distributed locks/leader election (needs linearizability), or shopping-cart/collaborative-editing merges (tolerates eventual + [CRDT](_meta/glossary.md#crdt)).

## When to Use

**Problem signals that point to a specific model:**
- "A user must never see their own write disappear on the next read" — session guarantee (read-your-writes); causal consistency subsumes it
- "Comments must never appear before the post they reply to" — causal consistency (preserves happens-before)
- "We elect one leader / grant one distributed lock / enforce a uniqueness constraint" — requires **linearizability**; anything weaker permits two leaders or duplicate values
- "Cross-region writes must stay available and fast during a WAN partition" — settle for causal or eventual; linearizability is off the table (CAP)
- "Shopping cart / like counter / collaborative doc that must always accept writes" — eventual consistency with a merge strategy (CRDT or [LWW](_meta/glossary.md#lww))

**Prefer a weaker model when:**
- Over linearizability: choose **causal** when you only need ordering of *related* operations, not a single global real-time order — it is the strongest model that stays available under a partition and does not pay the cross-node coordination latency of linearizability
- Over causal: choose **eventual** when even causal metadata (version vectors) is too expensive and the app can merge concurrent writes commutatively

**Do not use (linearizability) when:**
- The workload is geo-distributed and latency-sensitive → linearizable reads require a round trip to a quorum/leader; use causal + read-your-writes session guarantees instead
- Writes must never be refused → a [CP](_meta/glossary.md#cp) linearizable store rejects writes during a partition; pick an [AP](_meta/glossary.md#ap) eventual store if availability wins

## Key Properties

| Model | Guarantees | Forbids | Available under partition? |
|---|---|---|---|
| **Linearizable** (strong) | Single global total order that respects real-time; every read sees the most recent completed write (recency) | Stale reads, reorderings | **No** — the "C" in CAP |
| **Sequential** | Single global total order consistent with each process's program order | — | No (in practice, needs coordination) |
| **Causal** | All replicas agree on the order of causally-related (happens-before) ops; concurrent ops may be seen in different orders | Reads that violate causality (effect before cause) | **Yes** |
| **Eventual** | If writes stop, all replicas *converge* to the same value | — (almost nothing about intermediate reads) | **Yes** |

- **Linearizability is a recency guarantee (DDIA §9):** it makes a replicated system behave as if there is a *single copy* of the data and every operation is atomic and instantaneous at some point between its invocation and response. This is a stronger, orthogonal property from [serializability](_meta/glossary.md#serializability) (which is about transaction isolation, not single-object recency).
- **Session (client-centric) guarantees** sit under causal: read-your-writes, monotonic reads (never see time go backwards), monotonic writes, writes-follow-reads. Causal consistency implies all four.
- **Ordering hierarchy:** linearizable ⟹ sequential ⟹ causal ⟹ eventual. The strongest that survives a partition is **causal** (Attiya/Mahajan bound; DDIA §9).
- **Convergence needs conflict resolution.** Eventual/causal stores that accept concurrent writes must merge them: LWW (timestamp wins, silently drops the loser), version vectors + application merge, or a CRDT (mathematically guaranteed to converge without coordination).

## Common Pitfalls

- **Confusing "strong consistency" with a quorum.** A Dynamo-style [quorum](_meta/glossary.md#quorum) with `w + r > n` guarantees a read set *overlaps* a write set, so it returns some recent write — but this is **not linearizability**. DDIA §9 is explicit: [sloppy quorums](_meta/glossary.md#sloppy-quorum), concurrent writes, and [read-repair](_meta/glossary.md#read-repair) races mean `w + r > n` can still return stale values. Linearizability needs extra coordination (a consensus protocol or synchronous read-repair).
- **Confusing consistency (CAP) with consistency (ACID).** The "C" in CAP is *linearizability*; the "C" in [ACID](_meta/glossary.md#acid) is preserving invariants. Different concepts — do not conflate them in an interview.
- **Confusing linearizability with serializability.** Serializability is a *transaction isolation* property (transactions appear to run in some serial order). Linearizability is a *single-object recency* property. "Strict serializability" is the combination of both.
- **Assuming eventual = causal.** Plain eventual consistency can show effect-before-cause (see a reply before the post). You must add causal metadata to prevent that.
- **LWW silently loses data.** Two concurrent writes → the lower timestamp is discarded with no error. Fine for a cache/session; dangerous for a bank balance or an appended list.
- **Clock skew breaks LWW ordering.** LWW depends on comparable timestamps; wall-clock skew across nodes can order writes "wrong". [HLC](_meta/glossary.md#hlc) (hybrid logical clocks) mitigate this by combining physical time with a logical counter.

## Trade-offs

- **Consistency vs availability (CAP):** during a partition you either refuse to serve (linearizable/CP) or serve possibly-stale data (AP). There is no third option *while partitioned*.
- **Consistency vs latency ([PACELC](_meta/glossary.md#pacelc)):** CAP only speaks to the partitioned case. PACELC adds: *Else* (normal operation), you still trade Latency vs Consistency — a linearizable read must coordinate (leader/quorum round trip), so even with no partition it is slower than a local causal/eventual read.
- **Coordination cost:** linearizability requires cross-node agreement (consensus like Raft/Paxos, or a single leader). Causal consistency needs only per-key/per-client dependency metadata (version vectors), no global coordination. Eventual needs none.
- **Developer burden:** weaker models push conflict handling into the application (merge functions, CRDTs). Stronger models are easier to reason about but concentrate a coordination bottleneck and a latency floor.
- **Tunable middle ground:** leaderless stores (Cassandra, DynamoDB) expose `n/r/w` knobs — raise `r`+`w` for stronger reads, lower them for latency/availability.

## Implementation Notes

**How each model is realized:**

- **Linearizable:** single-leader with synchronous reads from the leader, or a consensus group (Raft/Paxos) where reads go through the log or a lease. Spanner reaches linearizability (external consistency) using TrueTime + Paxos, commit-waiting out clock uncertainty.
- **Causal:** attach a **version vector** (one counter per node) to each write; a replica delays applying a write until all its causal dependencies have arrived.

  ```text
  # Causal delivery of a write W with dependency vector dep[]
  on receive(W, dep):
      wait until for all nodes j:  localClock[j] >= dep[j]   # all causes applied
      apply(W)
      localClock[W.origin] += 1
  ```

  This is the mechanism behind COPS and behind read-your-writes session tickets.
- **Eventual:** async replication + a convergence rule. [Anti-entropy](_meta/glossary.md#anti-entropy) (Merkle-tree diff, à la Dynamo) plus read-repair reconciles replicas in the background; conflicts resolved by LWW, version vectors, or a CRDT.

**Quorum sanity check (leaderless):** with `n` replicas, choosing `w + r > n` forces every read quorum to intersect the last write quorum in ≥1 node — necessary but *not sufficient* for linearizability (see Pitfalls).

## Variants

- **Strict / strong consistency:** informal umbrella usually meaning linearizability.
- **Sequential consistency:** total order respecting per-process program order but *not* real-time — weaker than linearizable (the classic memory-model definition, Lamport 1979).
- **Bounded staleness:** reads are at most *t* seconds or *k* versions behind (Azure Cosmos DB offers this as an explicit level).
- **Read-your-writes / monotonic reads / consistent prefix:** session guarantees, all implied by causal consistency.
- **Strong eventual consistency (SEC):** eventual + a deterministic merge such that replicas that received the same set of updates are identical — the guarantee CRDTs provide.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 9 (Consistency and Consensus) — the primary grounding
- Herlihy & Wing, "Linearizability: A Correctness Condition for Concurrent Objects" (1990) — https://cs.brown.edu/~mph/HerlihyW90/p463-herlihy.pdf
- Lloyd et al., "Don't Settle for Eventual" (COPS, SOSP 2011) — causal+ consistency: https://www.cs.cmu.edu/~dga/papers/cops-sosp2011.pdf
- Kleppmann, "Please stop calling databases CP or AP" — https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html

## Related

- [[cap-theorem]]
- [[sql-vs-nosql]]
- [[mvcc]]
- [[transaction-isolation-levels]]
- [[acid-properties]]
- [[storage-engines]]
