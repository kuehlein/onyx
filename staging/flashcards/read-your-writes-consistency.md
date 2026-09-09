---
id: read-your-writes-consistency
type: flashcard
tags:
  - distributed-systems
  - databases
tiers:
  distributed-systems: 3
created: 2026-09-08
confidence: high
priority: normal
---

# Read-Your-Writes & Replication Lag

In leader-based replication, writes go to the leader and are copied to followers **asynchronously**. Under load or network delay, followers fall behind — this gap is *[replication lag](_meta/glossary.md#replication-lag)*. A client that writes to the leader and then reads from a lagging follower sees stale data, or even its own write missing ("I posted a comment and it's gone"). The fix is not full [linearizability](_meta/glossary.md#linearizability) (expensive); instead you apply narrower, cheaper *consistency guarantees* that patch the specific anomalies users actually notice. This card is the practical replication-lag subset of the broader consistency-models space.

> [!tip] Recognition
> Async single-leader replication with read replicas, AND a user complaint like "I updated my profile but it still shows the old value," "my new post disappeared on refresh," "the comment count jumped backward," or "replies showed up before the question." Reaching for a stronger global model (linearizable) would be overkill — you want a targeted guarantee.

## When to Use

Reach for these guarantees — not linearizability — when you run asynchronous replication and want to eliminate a *specific* user-visible anomaly cheaply:

- **[Read-your-writes](_meta/glossary.md#read-your-writes) (read-after-write):** a user must always see their *own* updates immediately (says nothing about other users' writes). Use when a user edits then re-reads their own data.
- **[Monotonic reads](_meta/glossary.md#monotonic-reads):** a user must never see time "go backward" — reading newer data then older data on a refresh. Use when a user makes repeated reads and could hit different-lag replicas.
- **Consistent prefix reads:** writes that are causally related must be seen in that order (no answer appearing before its question). Use in partitioned/sharded systems where causally-linked writes land on different partitions.

**vs. consistency-models (sibling):** that card covers the *full* spectrum (linearizability, sequential, causal, eventual). This card is the narrow, practical toolkit for one root cause — async replication lag — under [eventual consistency](_meta/glossary.md#eventual-consistency). **vs. replication-models (sibling):** that card is about *how* data is copied (single-leader / multi-leader / leaderless, sync vs async); this card is about the *read anomalies* async copying causes and how to paper over them.

## Key Properties

Each guarantee is strictly weaker than linearizability and targets a distinct anomaly. The distinguishing cue is *whose* writes and *what* ordering:

- **Read-your-writes** — scope is *your own* writes only; guarantees you never fail to see an update you personally made. Says nothing about seeing others' writes or about ordering.
- **Monotonic reads** — a *per-user* guarantee that successive reads only move forward in time; you may still lag the leader, but you never regress. Weaker than strong consistency, stronger than eventual.
- **Consistent prefix reads** — a *causal-ordering* guarantee: if a sequence of writes happens in a certain order, anyone reading them sees them in that order (they may see a prefix, never a scramble).

These are independent: satisfying one does not imply another (e.g., you can read your own writes yet still see time go backward on data written by others).

## Trade-offs

| Guarantee | Anomaly it kills | Typical technique | Cost |
|---|---|---|---|
| Read-your-writes | Your own edit missing | Read own-editable data from leader; or sticky routing (route user to one replica); or client tracks write timestamp/version and reads a replica caught up past it | Load concentrates on leader; sticky routing hurts balancing/failover |
| Monotonic reads | Time jumping backward | Route each user to a fixed replica (hash of user id → replica); or track last-seen version and require replica ≥ it | Fixed routing complicates rebalancing; failover must reroute |
| Consistent prefix | Effect before cause | Ensure causally-related writes go to the same partition, or track causal dependencies explicitly | Partitioning by causal group is hard; explicit tracking adds bookkeeping |

Cross-cutting: all three are cheaper than linearizability (no cross-replica coordination on every read), but they are *partial* — they fix only the specific anomaly and can require client-side version tracking or routing state.

## Common Pitfalls

- **Assuming "eventual consistency is fine" ignores user-visible anomalies.** Eventual consistency permits all three anomalies; "eventually" can be seconds to minutes under lag, long enough for a user to hit refresh.
- **Sticky routing masks lag but breaks on failover.** If the pinned replica dies (or the user's device changes IP / clock), the guarantee silently lapses — the user may hit a fresh replica and regress.
- **Reading your own writes from a follower after a write to the leader is the classic bug** — the write may not have replicated yet. Route reads that could contain the user's own edits to the leader (or a caught-up replica), not just any follower.
- **Monotonic reads ≠ read-your-writes.** Monotonic reads only prevents *going backward* across a user's reads; it does not guarantee you see your latest write. Don't substitute one for the other.
- **Cross-device / logical timestamps.** "Same user" may span devices; naive routing keyed on connection won't keep the same replica. Version-based waiting is more robust than IP-based stickiness.
- **Clock-based version tracking needs care** across nodes — wall clocks skew; prefer logical versions / replication positions (e.g. LSN) over timestamps for "wait until replica ≥ X."

## Implementation Notes

Reference patterns (do not memorize verbatim):
- Track the user's last write position (log sequence number / version) client- or session-side; on read, pick a replica whose applied position ≥ that value, else fall back to the leader.
- [Sticky sessions](_meta/glossary.md#sticky-session) via [consistent hashing](_meta/glossary.md#consistent-hashing) of user id to a replica, with re-pinning on replica failure.
- Route write-then-read flows for a user's own mutable data to the leader for a short window after the write.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 5 "Replication" — "Problems with Replication Lag" section: https://dataintensive.net/
- Jepsen consistency models map (relative strength): https://jepsen.io/consistency
- AWS Aurora replica lag / read-after-write guidance: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Replication.html

## Related

- [[consistency-models]]
- [[replication-models]]
- [[database-replication]]
- [[cap-theorem]]
- [[eventual-consistency]]
