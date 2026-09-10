---
id: logical-clocks
type: flashcard
tags:
  - distributed-systems
  - logical-clocks
  - causality
  - vector-clocks
tiers:
  distributed-systems: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Logical Clocks

Logical clocks order events in a distributed system by **causality** rather than by wall-clock time, because physical time cannot be trusted across nodes. Every machine's clock drifts, [NTP](_meta/glossary.md#ntp) corrections can jump time forward or *backward*, and even synchronized clocks disagree by enough (milliseconds) that "later timestamp" does not reliably mean "happened later." So instead of asking *when* did an event occur, logical clocks capture *what an event could have depended on*: the **happens-before** relation. Lamport timestamps give a cheap consistent *total* order (a single counter per node) but throw away enough information that they cannot tell "A caused B" from "A and B were concurrent." Vector clocks / version vectors keep one counter per node, which recovers the full **partial** order — so they *can* detect concurrency, at the cost of size proportional to the number of nodes. This is the machinery behind causal consistency, conflict detection in leaderless stores (Dynamo), and safe versioning of replicated objects. (DDIA Ch. 5 & 8-9.)

> [!tip] Recognition
> Reach for logical-clock reasoning when you see: "we can't rely on server timestamps / clock skew caused a bug," "[last-write-wins](_meta/glossary.md#lww) silently dropped a write," "detect whether two concurrent updates conflict or one supersedes the other," "preserve causal order (read-your-writes, causal consistency)," "sibling versions" in Dynamo/Riak (the managed AWS *DynamoDB* product does **not** expose them — it defaults to last-write-wins), or `(node, counter)` version metadata attached to objects. Any time correctness depends on *ordering events across machines* without a single coordinator, physical time is the wrong tool and a logical clock is the right one.
>
> **vs. Lamport (single counter):** total order, but cannot detect concurrency. **vs. vector/version vector (counter per node):** detects concurrency, but grows with node count.

## When to Use

**Problem signals that point to logical clocks:**
- "A write got lost because two nodes' clocks disagreed" / "we sorted by `updated_at` and picked the wrong version" — physical timestamps are unsafe for ordering; use a logical clock
- "How do we know if these two versions conflict or if one is strictly newer?" — the defining job of a **vector clock / version vector**: compare to see ancestor-vs-concurrent
- "Preserve causal order: if X read a post before commenting, everyone must see the post before the comment" — causal consistency is built on happens-before tracking
- "We need a single agreed-upon ordering of events for a log, and ties are acceptable to break arbitrarily" — a **Lamport timestamp** total order suffices

**Prefer each variant when:**
- **Lamport timestamp** over vector clock: you only need *a* consistent total order (e.g. a tie-break rule for [LWW](_meta/glossary.md#lww), an ordering for a replicated log) and do *not* need to know whether two events were concurrent. One integer per node — cheap.
- **Vector clock / version vector** over Lamport: you must *detect concurrency* — decide "is B a descendant of A, or are they siblings that need merging?" Required for conflict detection in leaderless replication.
- **Logical clocks** over physical (NTP) time: whenever correctness depends on ordering, not on the actual time-of-day. Wall-clock time is for TTLs, human-facing timestamps, and coarse metrics — never for deciding causal order.

**Do not use when:**
- You need a **total order that all nodes agree is *the* order** with no lost writes and no arbitrary tie-breaking → that's [consensus](_meta/glossary.md#consensus) / total-order broadcast ([[consensus]]), not a logical clock. Logical clocks order events but don't *decide* a single durable log by themselves.
- You genuinely need real elapsed time (rate limiting, session expiry, "show local time") → use physical time; logical clocks carry no wall-clock meaning.
- Node count is huge and unbounded → naive vector clocks grow linearly per node; you need pruning, version-vector-per-replica (not per-client), or dotted version vectors.

## Key Properties

- **Happens-before (→), the partial order (Lamport 1978).** `a → b` if: (1) a and b are on the same node and a came first; (2) a is a *send* and b is the matching *receive*; or (3) transitively `a → c → b`. If neither `a → b` nor `b → a`, the events are **concurrent** (`a ∥ b`). This is a *partial* order — concurrent events are genuinely unordered.
- **Clock condition:** a correct logical clock guarantees `a → b ⟹ C(a) < C(b)`. Lamport clocks give *only* this one direction.
- **Lamport timestamp = one integer per node.** Rules: increment your counter before each local event; on send, attach the counter; on receive, set `counter = max(local, received) + 1`. Result: `a → b ⟹ L(a) < L(b)`, but the **converse is false** — `L(a) < L(b)` does *not* imply `a → b` (they may be concurrent). Hence Lamport clocks **cannot detect concurrency.**
- **Total order from Lamport:** break ties on equal timestamps with a fixed rule (e.g. node id) → a consistent total order across all nodes. Useful, but this order *invents* an ordering between truly concurrent events.
- **Vector clock = one counter per node** (an array `V[i]`). Rules: increment your own entry on a local event; on send, attach the whole vector; on receive, take the element-wise `max` of local and received, then increment your own entry.
- **Vector clock comparison recovers the full order (both directions):**
  - `V(a) < V(b)` (every entry `≤`, at least one strictly `<`) ⟺ `a → b` — b is a **descendant**, a is safely obsolete
  - `V(a) = V(b)` ⟺ same event
  - **neither ≤ the other** ⟺ **concurrent** — sibling versions that must be reconciled/merged
- **Version vector vs. vector clock (interference cue).** Same mechanism, different job: a **vector clock** timestamps *events* in a computation; a **version vector** summarizes the *causal history of a replicated object/replica* (one entry per replica). Dynamo/Riak attach a version vector to each object version to detect conflicting writes. Treat them as interchangeable concepts for interviews; the distinction is which thing you're tracking.

## Common Pitfalls

- **Trusting wall-clock time to order events.** Clock skew, [NTP](_meta/glossary.md#ntp) step corrections (time can move *backward*), leap seconds, and VM pauses all break "bigger timestamp = later." Sorting versions by physical timestamp for LWW **silently drops writes** whenever clocks disagree — a classic Cassandra footgun.
- **Assuming `L(a) < L(b)` means a caused b.** The #1 Lamport misconception. The implication only runs `a → b ⟹ L(a) < L(b)`; the reverse tells you nothing. To *detect* causality/concurrency you must use a vector clock.
- **Thinking Lamport's total order is "the real order."** It's a *consistent* order, not a *causal truth*; it linearizes concurrent events by fiat. Fine for a tie-break rule, wrong if you conclude one concurrent event "really happened first."
- **Ignoring vector-clock growth.** One entry per participant means the vector grows with the number of writers; using a per-*client* vector (not per-replica) makes it grow unboundedly. Real systems bound it (server-side version vectors, dotted version vectors, pruning old entries).
- **Confusing logical clocks with consensus.** A vector clock detects that two writes conflict; it does **not** resolve them or produce a single agreed log. Resolution needs application merge logic (or a CRDT), and a single durable total order needs [consensus](_meta/glossary.md#consensus).
- **Forgetting the increment-on-receive step.** Omitting `+1` after the `max` (or forgetting to bump your own entry) breaks the clock condition and can make causally-ordered events look concurrent or vice versa.

## Trade-offs

| | Physical (NTP) time | Lamport timestamp | Vector / version vector |
|---|---|---|---|
| Per-event size | fixed (a timestamp) | 1 integer | O(N) — one counter per node |
| Order captured | wall-clock (unreliable) | total (partial + tie-break) | **partial (full causal)** |
| Detect concurrency? | no | **no** | **yes** |
| `C(a)<C(b) ⟹ a→b`? | no | **no** | yes (with full compare) |
| `a→b ⟹ C(a)<C(b)`? | not reliably | yes | yes |
| Main use | TTLs, human display | tie-break / log order for LWW | conflict detection, causal consistency |
| Cost | free but unsafe for ordering | cheap | metadata grows with node count |

- **Information vs. size.** Lamport compresses causality into one number and *loses* the ability to tell concurrent from causal; vector clocks keep enough to recover it but pay O(N) metadata. This is the central trade-off.
- **Logical vs. hybrid.** Pure logical clocks carry no real-time meaning (bad for "show me events from the last hour"). **Hybrid Logical Clocks (HLC)** bolt a bounded physical component onto a logical clock so timestamps stay close to wall-clock while still respecting happens-before — used by CockroachDB/YugabyteDB.
- **Detection vs. resolution.** Logical clocks (vector) *detect* conflicts cheaply and correctly; they say nothing about how to *resolve* them. LWW resolves by discarding (lossy); application merge or [CRDTs](_meta/glossary.md#crdt) resolve without loss; a single global order needs consensus.

## Variants

- **Lamport timestamp** — scalar counter; total order, no concurrency detection.
- **Vector clock** — per-node counter array; detects concurrency; timestamps events.
- **Version vector** — same structure applied to replicated objects (per-replica entry); the Dynamo/Riak conflict-detection tool.
- **Dotted version vector (DVV)** — refines version vectors to avoid false conflicts and unbounded growth under many clients (Riak).
- **Matrix clock** — each node tracks a full N×N matrix (what each node knows about every other), used for garbage-collecting causal metadata.
- **Hybrid Logical Clock (HLC)** — logical clock with a bounded physical-time component; near-real-time timestamps that still honor causality (CockroachDB, YugabyteDB).

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 5 (Detecting Concurrent Writes / version vectors) and Ch. 8-9 (unreliable clocks, ordering, causality) — primary grounding
- Lamport, *Time, Clocks, and the Ordering of Events in a Distributed System* (1978) — https://lamport.azurewebsites.net/pubs/time-clocks.pdf
- DeCandia et al., *Dynamo: Amazon's Highly Available Key-value Store* (2007) — https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf
- Preguiça et al., *Dotted Version Vectors: Logical Clocks for Optimistic Replication* — https://arxiv.org/abs/1011.5808

## Related

- [[consistency-models]]
- [[read-your-writes-consistency]]
- [[replication-models]]
- [[consensus]]
- [[cap-theorem]]
- [[crdt]]
