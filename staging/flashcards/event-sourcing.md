---
id: event-sourcing
type: flashcard
tags:
  - distributed-systems
  - backend
tiers:
  distributed-systems: 3
created: 2026-09-08
confidence: high
priority: normal
---

# Event Sourcing

Event sourcing stores every change to application state as an immutable, append-only sequence of domain events, rather than storing (and mutating) only the current state. The current state is a *derived* value: you reconstruct it by replaying and folding the event log from the beginning (with periodic snapshots to avoid replaying from zero). The log — not any table of "current" rows — is the single source of truth, which makes history first-class: you can audit exactly how state was reached, run temporal queries ("what did this look like on March 3rd?"), and build brand-new read models retroactively by replaying old events through new projection logic.

> [!tip] Recognition
> Reach for event sourcing when the requirements name the *history itself* as a product concern, not just an incidental log: "we must be able to answer why the balance is what it is / who changed what and when," "regulators require a tamper-evident audit trail," "we need to reconstruct account state at any past point in time," "product wants to add new dashboards/analytics over data we already have without re-instrumenting writes," or "we keep discovering we threw away information we now wish we'd kept." Domain-event language ("OrderPlaced", "FundsWithdrawn") in the ubiquitous vocabulary is a strong signal.

## When to Use

Use it when the sequence of *changes* has intrinsic business value beyond the latest state: financial ledgers, audit/compliance domains, collaborative editing, order/workflow lifecycles, and anywhere you expect to derive multiple, evolving read models from the same facts. The killer capability is retroactive derivation — replay the existing log through new logic to build a projection you didn't know you needed at write time.

Avoid it when current state is all anyone ever asks for and CRUD is sufficient — the added complexity (replay, snapshots, schema evolution, [eventual consistency](_meta/glossary.md#eventual-consistency)) is real overhead with no payoff. Also avoid it for domains where you must *hard-delete* data on demand (e.g. GDPR erasure), since the log is append-only and immutable by design; you must plan cryptographic erasure or log rewriting up front.

## Key Properties

- **Events are immutable facts, stored append-only** — never updated or deleted in place. New information becomes a *new* event (a correction/reversal), never an edit.
- **Current state is derived, not stored** — `state = fold(events)`. Snapshots are a pure optimization (a cached fold up to event N) and can always be discarded and rebuilt.
- **Events describe what happened in domain terms** (`FundsWithdrawn`), capturing intent — unlike a diff of columns, which only captures the mechanical result.
- **Complete history and time-travel are free** — audit trail and "state as of time T" fall out of the model rather than being bolted on.

## Trade-offs

| Concern | Event sourcing | Plain CRUD |
|---|---|---|
| Source of truth | The event log (state derived) | Current-state rows (mutated in place) |
| History | Complete, by construction | Lost unless separately logged |
| Read a single record's current value | Replay/snapshot fold (indirect) | Direct row read |
| Retroactively derive a new view | Replay log through new logic | Not possible; data was discarded |
| Deleting/forgetting data | Hard — append-only, needs special handling | Trivial `DELETE` |

Frequently paired with **CQRS**: the write side appends events to the log; the read side maintains one or more query-optimized **projections** (materialized read models) updated by consuming the event stream. This splits the write model from read models but makes projections **eventually consistent** with the log.

## Common Pitfalls

- **Old-event schema evolution.** Events are immutable and live forever, so replay code must understand *every* historical version. Use additive/backward-compatible changes and upcasters (transform old event shapes to new on read); never repurpose an event type's meaning.
- **Snapshot correctness.** A snapshot must be recomputable from the log; if projection/fold logic changes, stale snapshots become wrong. Treat snapshots as disposable caches, version them, and be able to rebuild from scratch.
- **Assuming read-after-write consistency.** Projections lag the log. UIs that read their own writes need to handle the window (read from the write model, or wait for the projection to catch up).
- **Leaking commands as events.** Store *events* (things that already happened, past tense) — not *commands* (requests that may still be rejected). Validation happens before an event is emitted; once emitted, it is a fact.
- **Overusing it.** Applying event sourcing to a simple CRUD domain buys history nobody needs at the cost of permanent complexity.

## Implementation Notes

Storage is typically an append-only event store (a dedicated store like KurrentDB — formerly EventStoreDB — or an events table / stream in a log system such as Kafka) partitioned by aggregate/stream id with a monotonically increasing sequence number per stream. Concurrency control is usually [optimistic](_meta/glossary.md#optimistic-concurrency-control): on append, assert the expected last sequence number for the stream and reject on mismatch. Projections are rebuildable by replaying from offset 0. See DDIA Ch. 11 for the event-log / derived-state framing.

**Contrast vs. CDC ([change data capture](_meta/glossary.md#change-data-capture)):** CDC also produces a stream of change events, but the direction of truth is reversed. In CDC the *mutable database is the source of truth* and events are *extracted from it* (e.g. tailing the DB's [write-ahead](_meta/glossary.md#wal)/replication log) to sync downstream systems — the events are a derivative byproduct. In event sourcing the *events are the source of truth* and any current-state table is the derivative. CDC bolts a stream onto an existing CRUD schema; event sourcing designs the domain around the stream.

**Contrast vs. Saga:** a saga is orthogonal — it coordinates a *distributed transaction* across services via a sequence of local transactions plus compensating actions on failure. It answers "how do I keep multiple services consistent without a [2PC](_meta/glossary.md#two-phase-commit) lock," not "how do I store state." You can implement a saga *using* events (choreography), but event sourcing is a persistence/state model, not a coordination protocol.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 11 (Event Sourcing & derived state) — https://dataintensive.net/
- Martin Fowler, "Event Sourcing" — https://martinfowler.com/eaaDev/EventSourcing.html
- Microsoft, "Event Sourcing pattern" — https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing
- Microsoft, "CQRS pattern" — https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs

## Related

- [[cqrs]]
- [[change-data-capture]]
- [[saga-pattern]]
- [[message-queues]]
- [[eventual-consistency]]
- [[write-ahead-log]]
