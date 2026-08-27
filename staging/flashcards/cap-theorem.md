---
id: 3f7a2c1e-8b4d-4e9a-b6f3-2d5c0a1e7f84
type: flashcard
tags:
  - system-design
  - cap-theorem
  - distributed-systems
tiers:
  system-design: 1
created: 2026-08-20
confidence: medium
---

# CAP Theorem

A distributed data store can guarantee at most two of three properties simultaneously: **Consistency** (every read receives the most recent write or an error), **Availability** (every request receives a non-error response, though it may be stale), and **Partition Tolerance** (the system continues operating despite network partitions). Because network partitions are unavoidable in practice, real-world systems choose between [CP](_meta/glossary.md#cp) and [AP](_meta/glossary.md#ap) behavior — not CA.

> [!important] The real choice is CP vs AP — never "CA"
> Partitions are unavoidable in any networked system, so **P is non-negotiable**. During a partition you either refuse requests you can't safely answer (CP) or serve possibly-stale data (AP). "CA without P" just means a single-node system.

## When to Use

**Problem signals that suggest [CAP](_meta/glossary.md#cap) Theorem is relevant:**
- "Design a distributed database / cache / key-value store"
- "What happens when two data centers lose connectivity?"
- "How do you handle network failures between nodes?"
- "Should the system return stale data or return an error when a node is unreachable?"
- The problem involves replication, multi-region deployments, or sharding
- The interviewer asks "what are your consistency guarantees?" or "how does this behave under failure?"
- Any system where data is stored on more than one machine

**Prefer explicit CAP discussion over alternatives when:**
- Over generic availability/reliability framing: CAP forces you to name the concrete trade-off at partition time, which is what interviewers want to hear
- Over [ACID](_meta/glossary.md#acid) framing: ACID applies within a single node or single transaction; CAP applies to the distributed coordination between nodes

**Do not use when:**
- Designing a single-node system → ACID and locking are the right frame
- Discussing latency vs. throughput → this is a different axis ([PACELC](_meta/glossary.md#pacelc) extends CAP with latency trade-offs)

## Key Properties

**Consistency (C)**
Every read sees the most recent committed write — equivalent to linearizability. A read after a write on any node returns the new value or an error. This requires coordination (consensus) across nodes before acknowledging writes.

**Availability (A)**
Every non-failing node returns a response for every request. No timeouts, no errors due to partition. The response may be stale. This requires nodes to serve requests independently without waiting for coordination.

**Partition Tolerance (P)**
The system continues to function when messages between nodes are lost or delayed arbitrarily. In any real distributed system deployed across a network, you cannot eliminate partitions — you can only choose how to react to them.

**The real choice: CP vs. AP**
Since P is non-negotiable, the practical question is: during a partition, does the system preserve consistency (refusing requests it cannot safely answer) or preserve availability (answering with potentially stale data)?

| System Type | Under Partition | Examples |
|-------------|-----------------|---------|
| CP | Returns error or timeout | HBase, Zookeeper, etcd, Spanner |
| AP | Returns stale data | Cassandra, DynamoDB (default), CouchDB, Riak |

## Trade-offs

**CP systems:**
- Guarantee the user never reads stale data — critical for financial transactions, leader election, distributed locks
- Sacrifice availability: a minority partition cannot serve reads/writes until quorum is restored
- Latency spikes during coordination (Paxos/Raft rounds add [RTT](_meta/glossary.md#rtt)s)
- Complexity: requires quorum reads/writes, leader election, fencing tokens

**AP systems:**
- Guarantee the system stays responsive even during network failures — critical for shopping carts, social feeds, [DNS](_meta/glossary.md#dns), [CDN](_meta/glossary.md#cdn)s
- Sacrifice consistency: nodes diverge during a partition; conflicts must be resolved on merge
- Conflict resolution strategies: last-write-wins ([LWW](_meta/glossary.md#lww)), vector clocks, [CRDT](_meta/glossary.md#crdt)s, application-level merge
- Typical staleness window: seconds to minutes depending on replication lag and gossip interval

**PACELC extension (what interviewers may probe further):**
Even when no partition exists, there is a latency (L) vs. consistency (C) trade-off. Spanner (CP) uses TrueTime to achieve external consistency at ~10 ms commit latency; DynamoDB (AP, tunable) achieves single-digit ms at the cost of eventual consistency.

**When strong consistency is "good enough" at scale:**
Many workloads tolerate slightly higher latency for consistency. Google Spanner and CockroachDB demonstrate that global CP systems are commercially viable — the CP vs. AP choice is not always as stark as the theorem implies in practice.

## Common Pitfalls

- **Treating CA as a valid option:** "CA without P" means a single-node system. In any distributed deployment, P is assumed — you are choosing CP or AP.
- **Conflating consistency with durability:** CAP consistency is about read-after-write across nodes, not about data surviving crashes. A system can be durable (fsync) but still eventually consistent.
- **Forgetting that AP systems have tunable consistency:** Cassandra's `QUORUM` read/write level can approximate strong consistency at the cost of availability, blurring the hard boundary.
- **Ignoring the partition recovery phase:** After a partition heals, AP systems must reconcile diverged state. Failing to design this reconciliation path (e.g., using CRDTs or application merge logic) leads to data corruption.
- **Conflating availability in CAP with SLA uptime:** CAP availability is a formal property (every request gets a response from a non-failing node). A 99.99% [SLA](_meta/glossary.md#sla) uptime is a separate operational concern.

## Implementation Notes

**CP architecture patterns:**
- **Raft/Paxos consensus group:** Leader accepts all writes; followers replicate before ACK. Reads from leader guarantee linearizability. Example: etcd, Zookeeper, CockroachDB (Raft).
- **Synchronous replication:** Primary waits for at least one replica to confirm write before responding to client. Read replicas are gated — requests to lagging replicas return errors or redirect to primary.
- **Read quorum:** For a cluster of N nodes, require R reads and W writes where R + W > N. Typical: N=3, W=2, R=2 (majority quorum).

**AP architecture patterns:**
- **Eventual consistency with gossip protocol:** Nodes propagate writes asynchronously via gossip (e.g., Cassandra). Reads may return stale data during propagation window (typically < 1 second in same region, seconds across regions).
- **Last-write-wins (LWW):** Conflict resolved by wall-clock or logical timestamp. Simple to implement; loses updates if writes race.
- **CRDTs (Conflict-free Replicated Data Types):** Data structures that merge deterministically without coordination — counters, sets, maps. Used in Riak, Redis cluster, collaborative editing.
- **Tunable consistency:** Expose per-request consistency level (e.g., Cassandra: `ONE`, `QUORUM`, `ALL`). Operators tune the CP/AP dial per use-case without re-architecting.

**Multi-region design decision:**
In active-active multi-region, cross-region writes over [WAN](_meta/glossary.md#wan) (~80–150 ms RTT) make synchronous consensus expensive. Most teams accept AP (async cross-region replication) for the global tier and enforce CP within a single region. Write conflicts across regions are rare by design (geo-routing keeps users on their home region's primary).

## Resources

- Brewer, E. (2000). "Towards robust distributed systems" (CAP conjecture origin — PODC keynote)
- Gilbert & Lynch (2002). "Brewer's Conjecture and the Feasibility of Consistent, Available, Partition-Tolerant Web Services" (formal proof)
- Kleppmann, M. *Designing Data-Intensive Applications*, Ch. 9 — Consistency and Consensus
- https://www.infoq.com/articles/cap-twelve-years-later-how-the-rules-have-changed/ (Brewer's 2012 retrospective on CA and PACELC)
- https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html (nuance on why CP/AP labels are imprecise)

## Related

- [[acid-properties]]
- [[replication-strategies]]
- [[consistent-hashing]]
- [[distributed-consensus]]
- [[eventual-consistency]]
