---
id: change-data-capture
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

# Change Data Capture (CDC)

Change Data Capture turns a database's row-level mutations (inserts, updates, deletes) into an ordered stream of change events that downstream consumers can follow. The point is to keep *derived* data systems — a search index, a cache, a data warehouse, another service — continuously in sync with a system-of-record database without dual-writing to each one from application code. The database stays the source of truth; CDC is the reliable pipe that fans its changes out. Kleppmann (DDIA ch. 11) frames it as the general mechanism for keeping heterogeneous systems in sync via a single ordered log of writes.

> [!tip] Recognition
> Reach for CDC when you hear: "the search index / cache / warehouse is stale or drifts from the DB," "we're dual-writing to the DB and to Kafka/Elasticsearch and they get out of sync," "we need a real-time feed of everything that changes in this table," or "replicate this [OLTP](_meta/glossary.md#oltp) database into analytics without hammering it with queries." The tell is *an existing mutable database that other systems must mirror.*

## When to Use

- **Keep derived systems in sync with a system-of-record.** Search index, cache, read models, [materialized views](_meta/glossary.md#materialized-view), and data warehouse all subscribe to one change stream instead of each being written to directly.
- **Eliminate dual writes.** When app code writes the DB *and* publishes an event separately, the two can diverge on partial failure. CDC (often via the outbox pattern) removes the second write.
- **Low-impact replication into analytics/ETL.** Stream OLTP changes into a warehouse without repeated full-table queries against the primary.
- **Prefer over event-sourcing when** you already have a normal mutable database and just need other systems to react to its changes — you are not willing to rebuild the app around an event log.

## Log-based vs. Query-based

| | Log-based CDC | Query-based (polling) |
|---|---|---|
| Mechanism | Tails the DB replication log (Postgres [WAL](_meta/glossary.md#wal), MySQL binlog) | Polls table for rows where `updated_at > lastRun` |
| Deletes | Captured (delete appears in the log) | **Missed** (deleted rows no longer match the query) |
| Intermediate states | All changes captured in order | Only the *latest* value between polls; intermediate updates lost |
| Ordering | Total order from the log | Approximate; ties/clock skew on the timestamp column |
| Overhead | Low; reads the log the DB already writes | Repeated queries load the primary |
| Setup cost | Higher (connector, log access/permissions) | Trivial (a `SELECT` on a schedule) |

Debezium is the canonical log-based implementation; it reads WAL/binlog and emits ordered events including deletes.

## Key Properties

- **Derives events from a mutable DB.** The events are a *consequence* of DB writes, not the primary record.
- **Ordered, complete change log.** Log-based CDC yields every committed change in commit order, which is what lets a consumer rebuild a consistent replica.
- **Asynchronous and [eventually consistent](_meta/glossary.md#eventual-consistency).** Consumers lag the primary by the pipeline delay; downstream systems converge, they are not transactionally in lockstep with the DB.
- **Outbox pattern for reliable publishing.** Write business rows *and* an event row into an `outbox` table in the *same DB transaction*, then let CDC tail that table. This gives atomic "state change + event emitted" without a distributed/[two-phase commit](_meta/glossary.md#two-phase-commit).

## Trade-offs

- **Contrast vs. event-sourcing (highest-value):** CDC *derives* an event stream **from** a mutable database that remains the source of truth. Event-sourcing makes the *events themselves* the source of truth and derives current state by replaying them. CDC captures the *effect* of a write (the new row value); event-sourcing captures the *intent* (the domain command, e.g. `CartItemAdded`). Choose CDC to sync systems around an existing DB; choose event-sourcing to model the domain as an append-only history.
- **Contrast vs. a plain message queue:** A message queue is generic transport — the app must decide to publish, which reintroduces the dual-write problem. CDC's messages are *automatically* derived from committed DB changes, so nothing is missed even if app code forgets to publish. A queue is often the *transport* CDC publishes *into* (e.g. Debezium → Kafka), not an alternative to it.
- **Eventual consistency + lag:** downstream is always slightly behind; not suitable when a consumer needs [read-your-writes](_meta/glossary.md#read-your-writes) against the derived store.
- **Operational coupling to the DB internals:** log-based CDC depends on WAL/binlog format, retention, and privileged log access; schema changes and log rotation must be handled.

## Common Pitfalls

- **Assuming query-based polling is complete.** It silently drops deletes and any intermediate values that changed and reverted between polls. If deletes or full history matter, you need log-based CDC.
- **Dual-writing instead of using the outbox.** Writing the DB and separately publishing to Kafka is not atomic; a crash between them loses or duplicates events. Put the event in the same transaction (outbox), then let CDC read it.
- **Ignoring initial snapshot.** A new consumer needs a consistent snapshot of existing rows before applying the ongoing log, or it starts from an incomplete state.
- **Unbounded log retention needs / connector downtime.** If the CDC consumer falls behind and the DB recycles WAL/binlog segments, changes are permanently lost; retention and lag must be monitored.
- **Treating derived stores as a source of truth.** Consumers must be [idempotent](_meta/glossary.md#idempotency) and rebuildable from the log, since the DB — not the index/cache — is authoritative.

## Implementation Notes

- Debezium connectors tail Postgres logical replication (WAL) and MySQL binlog and publish to Kafka; each change event carries `before`/`after` row images and an op type (`c`/`u`/`d`/`r`).
- Outbox: an `outbox` table row written in the business transaction; Debezium's outbox event router unwraps it into a properly-keyed topic message. See the Debezium outbox example.
- For Postgres, ensure `wal_level = logical` and a replication slot with sufficient retention.

## Resources

- Martin Kleppmann, *Designing Data-Intensive Applications*, ch. 11 (Change Data Capture): https://dataintensive.net
- Debezium — Event Sourcing vs. Change Data Capture: https://debezium.io/blog/2020/02/10/event-sourcing-vs-cdc/
- Debezium documentation: https://debezium.io/documentation/reference/stable/index.html
- Debezium outbox event router: https://debezium.io/documentation/reference/stable/transformations/outbox-event-router.html

## Related

- [[event-sourcing]]
- [[message-queues]]
- [[database-replication]]
- [[caching]]
- [[write-ahead-log]]
