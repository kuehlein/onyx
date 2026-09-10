---
id: kafka-log-based-messaging
type: flashcard
tags:
  - system-design
  - message-queues
  - kafka
  - distributed-systems
tiers:
  system-design: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Log-Based Messaging (Kafka Model)

Log-based messaging replaces the ephemeral "deliver then delete" queue with a **partitioned, append-only, durable log**: producers append records to the tail, and consumers read forward at their own pace by tracking a numeric **offset**. The record is *not* removed when read — it stays until a retention policy expires it — so consumption is a cursor position, not a destructive dequeue. This single design choice is what buys Kafka its defining properties: **replayability** (rewind the offset and re-read history), cheap **fan-out** (many independent consumers read the same log without copies), and high sequential-write throughput (append to disk, page-cache-friendly). It is the messaging analogue of a database's write-ahead log, exposed as a first-class abstraction — DDIA Ch.11 calls this "logs for message storage."

> [!tip] Recognition
> Reach for the log/Kafka model when you see: **"replay events / re-process from the beginning,"** **"multiple independent consumers of the same stream"** (fan-out to analytics + search + billing), **"event sourcing / [change data capture](_meta/glossary.md#change-data-capture) (CDC),"** **"stream processing,"** **"ordered per key,"** or **high sustained throughput** with durable retention. Signals of a *traditional* queue instead: "distribute tasks to workers," "delete after ack," "per-message TTL / priority," "route by header/topic pattern."
>
> **vs. traditional queue (RabbitMQ/SQS):** a broker-managed queue treats a message as a unit of work that is *acked and removed* — great for load-balancing tasks across competing workers, weak at replay and multi-consumer fan-out. Kafka treats the stream as durable shared *storage* — great at replay/fan-out/ordering, but consumption parallelism is capped by partition count and per-message routing/priority is not native.

## When to Use

**Problem signals that point to log-based messaging (Kafka):**
- "We need to **replay** the last N days of events into a new/ fixed service" — offsets rewind; a delete-on-ack queue cannot
- "Several **independent** consumers each need the *full* stream" (analytics, search indexer, audit) — [consumer groups](_meta/glossary.md#consumer-group) fan out without copying data
- "**Event sourcing** / **CDC** / audit log is the source of truth" — the log *is* the durable ordered history
- "**Stream processing**: windowed aggregation, joins, materialized views" — Kafka Streams / Flink build on the log
- "Order matters **per entity/key**" — key-based partitioning gives per-key ordering at scale
- "Very high sustained throughput with durable retention" — sequential appends + zero-copy reads

**Prefer Kafka over a traditional queue when:**
- Over RabbitMQ/SQS: you need **replay**, **fan-out to many consumer groups**, or a durable ordered history — a queue deletes on ack and can't cheaply re-serve
- Over a database polling table: you need a purpose-built, horizontally partitioned, high-throughput event pipe with [backpressure](_meta/glossary.md#backpressure) via consumer lag

**Do not use when:**
- You need a **task/work queue** with competing workers, per-message ack/redelivery, priorities, dead-letter routing, or per-message TTL → use RabbitMQ / SQS (Kafka has none of these natively; parallelism is bounded by partitions)
- You need **per-message routing** by header/content or complex topologies (topic exchanges, fanout+bindings) → RabbitMQ's exchange model
- The volume is tiny and operational simplicity matters → a managed queue is far less to run than a Kafka/ZooKeeper-or-KRaft cluster
- You require **[exactly-once](_meta/glossary.md#exactly-once-semantics) side effects on an external system** — Kafka's EOS is exactly-once *within Kafka* (read-process-write); external systems still need idempotent writes

## Key Properties

- **Partition = the unit of parallelism, ordering, and storage.** A topic is split into partitions; each partition is an independent append-only log with monotonically increasing offsets.
- **Ordering is per-partition only.** Kafka guarantees total order *within* a partition, never across partitions. To keep related events ordered, give them the same key (same key → same partition via hash).
- **Consumers track offsets; the broker doesn't push/track per-message state.** A consumer commits "I've processed up to offset X." This is why replay is trivial (reset the offset) and why the broker stays stateless-per-consumer and cheap.
- **Consumer groups give competing-consumer semantics *at partition granularity*.** Within one group, each partition is owned by exactly one consumer, so **max useful consumers per group = partition count**; extra consumers sit idle. Different groups read the same partitions independently (fan-out).
- **Rebalancing** redistributes partitions when members join/leave or partitions change. Legacy "eager" rebalance is stop-the-world (revoke all, reassign); **cooperative/incremental rebalancing (KIP-429, Kafka 2.4+)** revokes only the moving partitions so unaffected consumers keep processing.
- **Retention is decoupled from consumption.** Records live for `retention.ms` / `retention.bytes` regardless of whether anyone read them; consumers can be offline and catch up later (bounded by retention).
- **Durability via replication.** Each partition has a leader and `replication.factor` followers; producers with `acks=all` wait for the [in-sync replica](_meta/glossary.md#in-sync-replica) (ISR) set, so an acknowledged write survives leader failure.

## Common Pitfalls

- **Expecting global ordering.** There is none across partitions. Interviewers probe this: "how do you keep a user's events ordered?" → partition by user id; accept that cross-user order is undefined.
- **More consumers than partitions to "scale."** Consumers beyond the partition count in a group are idle. You must choose partition count for peak parallelism up front; increasing partitions later breaks key→partition ordering for existing keys.
- **Treating it as a work queue.** No per-message ack/redelivery, no priorities, no per-message TTL, no native dead-letter queue. A single "poison" record at the head of a partition can block that partition unless you build skip/DLQ logic yourself.
- **Confusing retention with compaction.** Time/size **retention** deletes *old* records; **[log compaction](_meta/glossary.md#log-compaction)** keeps the *latest value per key* forever (a changelog/snapshot). Enabling the wrong one silently loses data you expected to keep (or keeps data you expected to expire).
- **Assuming default = exactly-once.** Default delivery is **[at-least-once](_meta/glossary.md#at-least-once-delivery)** (consumer can crash after processing but before committing the offset → reprocessing). Real exactly-once needs the idempotent producer + transactions, or idempotent consumer logic.
- **Committing offsets before processing (or auto-commit).** `enable.auto.commit=true` commits on a timer regardless of processing success → **[at-most-once](_meta/glossary.md#at-most-once-delivery)** (silent message loss on crash). For at-least-once, process first, then commit.
- **Long processing stalling the group.** Taking longer than `max.poll.interval.ms` between polls makes the broker consider the consumer dead and triggers a rebalance, causing duplicate processing.

## Delivery Semantics

The three guarantees and how Kafka reaches each:

| Guarantee | How | Failure behavior |
|---|---|---|
| **At-most-once** | Commit offset *before* processing (or auto-commit) | Crash after commit, before work → **lost** message |
| **At-least-once** (default, most common) | Process, *then* commit offset; producer retries | Crash after work, before commit → **duplicate** on retry |
| **Exactly-once (within Kafka)** | Idempotent producer **+** transactions **+** `read_committed` consumer | No loss, no duplicates — for read-process-write pipelines |

- **Idempotent producer** (`enable.idempotence=true`, **the default since Kafka 3.0**): the broker assigns a Producer ID (PID) and tracks a per-partition sequence number, so a **retried** send is de-duplicated at the broker. Enabling it forces `acks=all`, `retries=MAX`, and `max.in.flight.requests.per.connection ≤ 5`. This alone stops *producer-retry* duplicates — not consumer-side reprocessing.
- **Transactions** (`transactional.id` set, `initTransactions`/`beginTransaction`/`sendOffsetsToTransaction`/`commitTransaction`): make the produced records **and** the consumed offsets commit **atomically** across partitions. Consumers set `isolation.level=read_committed` to skip aborted/in-flight records. This is what makes the **read-process-write** loop exactly-once.
- **Scope caveat:** EOS is exactly-once *inside Kafka*. A side effect on an external system (send an email, charge a card) is not covered — make those idempotent.
- EOS was introduced in **Kafka 0.11**.

## Trade-offs

**Log (Kafka) vs. traditional queue (RabbitMQ / classic broker):**

| Dimension | Log (Kafka) | Traditional queue (RabbitMQ/SQS) |
|---|---|---|
| Model | Durable append-only log; read by offset | Deliver-then-delete unit of work |
| Replay | Yes — rewind offset, re-read history | No — message gone after ack |
| Fan-out | Cheap — N consumer groups read same log | Needs N copies / exchange bindings |
| Ordering | Total **per partition** | Per-queue, but lost with competing consumers |
| Consumer parallelism | Bounded by partition count | Arbitrary competing workers on one queue |
| Per-message ack/redelivery | No (offset-based, coarse) | Yes — individual ack/nack, redelivery |
| Priorities / per-msg TTL / DLQ | Not native | First-class |
| Routing | By key→partition only | Rich (topic/fanout/header exchanges) |
| Retention | Time/size; survives consumption | Until acked (drains to empty) |
| Backpressure | Consumer lag (offset behind tail); log absorbs bursts | Queue depth grows; can hit memory/flow-control limits |
| Throughput | Very high (sequential I/O, batching, zero-copy) | Lower; per-message bookkeeping overhead |

- **Backpressure model differs.** Kafka doesn't slow producers when consumers lag; the durable log absorbs the burst and **consumer lag** (offset distance from the tail) is the signal to scale consumers — as long as data is still within retention. A queue instead grows in memory/broker and applies flow control, risking producer stalls or drops.
- **Ordering vs. parallelism is a direct tension.** Strict per-key order forces same-key records onto one partition → that key's throughput is capped by one consumer. More partitions = more parallelism but weaker locality and pricier rebalances.
- **Operational cost.** Kafka is a stateful distributed cluster (replication, ISR, ZooKeeper or KRaft). A managed queue (SQS) or single-broker RabbitMQ is dramatically simpler when you don't need replay/fan-out/throughput.

## Implementation Notes

**Retention vs. log compaction** (`cleanup.policy`):
- `delete` (default): drop segments older than `retention.ms` or beyond `retention.bytes`. A rolling window of recent events.
- `compact`: retain the **latest record per key** indefinitely; older values for the same key are garbage-collected. A `null` value is a **[tombstone](_meta/glossary.md#tombstone)** that deletes a key. Ideal for changelogs / current-state snapshots (e.g. Kafka Streams state stores, CDC "latest row" topics).
- `compact,delete`: compact *and* age out — keep latest-per-key but still bound total age.

**At-least-once consumer skeleton** (process then commit):
```text
while true:
  records = consumer.poll(timeout)
  for r in records: process(r)          # side effects must be idempotent
  consumer.commitSync()                 # commit AFTER processing
# crash between process() and commit -> records reprocessed (at-least-once)
```

**Exactly-once read-process-write** (transactional):
```text
producer.initTransactions()             # transactional.id set
producer.beginTransaction()
  producer.send(outputRecords)
  producer.sendOffsetsToTransaction(consumedOffsets, groupMetadata)
producer.commitTransaction()            # output + input offsets commit atomically
# consumer of output topic uses isolation.level=read_committed
```

## Variants

- **Log compaction topics** — key-addressed changelog; latest value per key kept forever (state stores, CDC).
- **Kafka Streams / ksqlDB** — stream-processing layer built on the log (stateful ops, windowing, exactly-once via transactions).
- **KRaft mode** — Kafka's built-in Raft metadata quorum replacing ZooKeeper (default in modern Kafka).
- **Tiered storage** — offload old log segments to object storage (S3) so retention can be effectively unbounded without local disk cost.
- **Other log-based systems** — Apache Pulsar, AWS Kinesis, Redpanda (Kafka-API compatible) share the offset/partition model.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch.11 (Stream Processing — "Logs for message storage", partitioned logs, consumer offsets) — primary grounding
- Apache Kafka documentation — Design & Semantics (message delivery, replication): https://kafka.apache.org/documentation/#design
- Confluent — *Exactly-Once Semantics Are Possible: Here's How Kafka Does It*: https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/
- Confluent — *Cooperative Rebalancing in the Kafka Consumer, Streams & ksqlDB*: https://www.confluent.io/blog/cooperative-rebalancing-in-kafka-streams-consumer-ksqldb/

## Related

- [[message-queues]]
- [[event-sourcing]]
- [[change-data-capture]]
- [[stream-processing]]
- [[consensus]]
- [[idempotency]]
