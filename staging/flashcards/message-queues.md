---
id: message-queues
type: flashcard
tags:
  - system-design
  - messaging
  - kafka
tiers:
  system-design: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Message Queues & Event Streaming

A message queue decouples producers from consumers by putting a durable buffer between them: the producer writes and moves on, the consumer reads at its own pace. This buys you three things at once — **temporal decoupling** (consumer can be down when the producer writes), **load leveling** (a spike is absorbed by the buffer instead of crushing the consumer), and **fan-out** (one event, many independent consumers). The core design axis is *point-to-point* (each message goes to exactly one worker — a work queue) vs *pub-sub* (each message goes to every subscriber — an event bus). Kafka unifies both with a partitioned, replayable log: a [consumer group](_meta/glossary.md#consumer-group) load-balances a topic like a work queue, while multiple groups each get the full stream like pub-sub.

> [!tip] Recognition — reach for a queue/stream when you see
> - **"decouple", "absorb spikes", "the downstream service is slow/flaky"** — a buffer lets the producer commit without waiting on the consumer
> - **"async", "fire-and-forget", "don't block the request path"** — send email / resize image / update search index *after* returning 200
> - **"process events in order", "audit log", "replay", "rebuild the read model"** — a log-based broker (Kafka) whose retention lets you re-consume from any offset
> - **"multiple teams need the same events"** (payments → fraud + analytics + notifications) — fan-out via pub-sub / consumer groups
> - **"exactly one worker should handle each job"** — point-to-point work queue with competing consumers
> - Anti-signal: a **synchronous request/response where the caller needs the result now** → that's [gRPC](_meta/glossary.md#grpc)/HTTP, not a queue.

## When to Use

**Problem signals that suggest a message queue / stream:**
- A write triggers slow or optional side effects (send email, transcode video, index into search) — do it async so the user-facing request stays fast
- Producer and consumer scale independently or have mismatched throughput — the queue absorbs bursts and smooths a spiky producer into a steady consumer drain rate
- One event must fan out to N independent consumers that evolve separately — pub-sub avoids the producer knowing every downstream
- You need durability + replay of an event history — event sourcing, [change data capture](_meta/glossary.md#change-data-capture) (CDC), rebuilding a derived store → log-based broker (Kafka)
- Cross-service communication that must survive a consumer outage — the broker holds messages until the consumer recovers

**Prefer a queue over alternatives when:**
- Over a synchronous RPC call: when the caller does **not** need the result inline, or the callee is slow/unreliable — async decouples availability (caller succeeds even if callee is down)
- Over a database polling table ("outbox-as-queue by SELECT"): when you need push delivery, [back-pressure](_meta/glossary.md#backpressure), and horizontal consumer scaling without hammering the DB — though the **transactional outbox** pattern deliberately combines both
- Kafka (log) over RabbitMQ/SQS (traditional broker): when you need **replay, retention, high throughput, ordered partitions, or multiple independent consumer groups** over the same stream
- RabbitMQ/SQS (traditional broker) over Kafka: when you need **per-message ack/redelivery, complex routing, priority queues, or per-message [TTL](_meta/glossary.md#ttl)/delay** — the smart-broker model fits work-queue semantics better

**Do not use when:**
- The caller needs the response synchronously to proceed → use RPC/HTTP; a queue adds latency and complexity for nothing
- The workload is a simple in-process background task on one box → a thread pool / local task queue is simpler than a network broker
- You'd be adding an operational [SPOF](_meta/glossary.md#spof) you can't staff → a managed queue (SQS, Pub/Sub) or none at all beats a self-run cluster you can't operate

## Key Properties

**Delivery semantics** (the central interview axis — always know which one and why):

| Semantic | Guarantee | How you get it | Cost |
|---|---|---|---|
| At-most-once | 0 or 1 delivery; may lose | Commit offset / ack **before** processing (fire-and-forget) | Data loss on crash |
| At-least-once | 1+ delivery; may dup | Ack / commit offset **after** processing succeeds | Consumer must be **idempotent** |
| Exactly-once | Effectively 1 | Idempotent producer + transactions (Kafka), or dedup on a key | Bounded to Kafka-internal; throughput cost |

At-least-once is the **practical default** and the right answer most of the time: make the consumer [idempotent](_meta/glossary.md#idempotency) (dedup on a business key or message ID) and redelivery becomes harmless.

**Pub-sub vs point-to-point:**
- **Point-to-point:** one queue, competing consumers, each message delivered to exactly one worker → parallelism for a work queue
- **Pub-sub:** each subscriber (or Kafka consumer group) gets its own copy of every message → independent fan-out

**Kafka's model (partitioned log):**
- A **topic** is split into **partitions**; each partition is an ordered, append-only, immutable log addressed by a monotonic **offset**
- A **consumer group** assigns each partition to exactly one consumer in the group → parallelism is capped at the partition count (more consumers than partitions ⇒ idle consumers)
- Ordering is **per-partition only**, never across a topic — messages that must stay ordered must share a partition key
- Consumers track a committed **offset** per partition; the broker is "dumb" (stores + serves the log), the consumer is "smart" (owns its position, retries, DLQ)
- Retention is time/size-based, independent of consumption — any group can **replay** by resetting its offset

## Common Pitfalls

- **Assuming global ordering.** Kafka orders *within a partition*, not across the topic. If order matters (e.g. all events for one `user_id`), you must route them to the same partition via a partition key; otherwise concurrent partitions interleave arbitrarily.
- **Non-idempotent at-least-once consumers.** With at-least-once (the default), redelivery *will* happen on rebalance or crash-after-processing-before-commit. A consumer that charges a card or increments a counter without a dedup key will double-apply.
- **Committing the offset before processing.** This silently turns at-least-once into at-most-once — a crash after commit but before the work finishes loses the message with no error.
- **A poison message blocking the partition.** One un-deserializable/un-processable record throws forever; because Kafka delivers a partition in order, the consumer retries the same record and the whole partition stalls behind it. You need a retry-then-[DLQ](_meta/glossary.md#dead-letter-queue) escape hatch (see below).
- **More consumers than partitions.** Extra consumers in a group sit idle — they cannot share a partition. Scale throughput by *raising partition count* (and partitions can only be increased, never decreased, and increasing them breaks keyed ordering for in-flight keys).
- **Treating "[exactly-once](_meta/glossary.md#exactly-once-semantics)" as end-to-end.** Kafka EOS is scoped to *consume-transform-produce within Kafka*. An RPC to an external store or a DB write inside the consumer is **not** covered — you still need idempotent writes on that side.
- **Unbounded lag with no back-pressure.** If the consumer can't keep up, lag grows until retention drops un-read messages (data loss) or the buffer/disk fills. Monitor consumer lag as a first-class SLO signal.

## Trade-offs

- **Decoupling vs added latency + operational complexity.** A queue removes the synchronous dependency but adds a hop, an at-least-once dedup burden on the consumer, and a broker to operate/monitor. Don't insert one where a direct call suffices.
- **Throughput/replay (log) vs flexible routing (traditional broker).** Kafka's append-only log gives huge sequential-I/O throughput and replay, but pushes ack/retry/DLQ logic to the consumer and offers only partition-key routing. RabbitMQ/SQS give per-message acks, redelivery, dead-lettering, priorities, and rich routing — at lower throughput and no long-term replay.
- **Ordering vs parallelism.** Strict order forces messages onto one partition/one consumer (serial). Throughput wants many partitions/consumers (interleaved). You trade one for the other; the usual compromise is *ordering per key* with parallelism across keys.
- **Exactly-once vs throughput/scope.** Kafka transactions add coordinator round-trips and `read_committed` read latency, and only cover Kafka-internal flows. At-least-once + idempotent consumer is usually cheaper and covers external side effects too.
- **Retention window vs storage cost.** Long retention enables replay and new-consumer bootstrap but costs disk; short retention risks a lagging or newly-added consumer missing data.
- **Push vs pull.** Kafka consumers *pull* (natural back-pressure, consumer sets its own rate); traditional brokers often *push* (lower latency, but a slow consumer needs explicit prefetch/flow-control limits or it's overwhelmed).

## Implementation Notes

**At-least-once consumer (the default you'll describe most often):**
```
poll() a batch
for each record: process()          # side effect must be idempotent
commit offsets AFTER processing      # crash before commit ⇒ redeliver, not lose
```
Make `process()` idempotent: upsert on a natural key, or record a processed-message-ID set and skip duplicates. This makes redelivery a no-op.

**Kafka exactly-once (consume-transform-produce), verified against Kafka producer docs:**
- **Idempotent producer** — `enable.idempotence=true` (default in modern Kafka). Broker dedups retries via a **Producer ID (PID) + per-partition monotonic sequence number**. Requires `acks=all`, `retries>0`, and `max.in.flight.requests.per.connection <= 5` (ordering is still preserved within that window). A conflicting config throws `ConfigException`.
- **Transactions** — set a `transactional.id`; the producer atomically writes output records **and** commits the input consumer offsets in one transaction (`sendOffsetsToTransaction`). Restarting with the same `transactional.id` gets the same PID with a bumped **producer epoch**, which **fences** the zombie old instance (its writes are rejected).
- **Consumer** — `isolation.level=read_committed`: reads only up to the **Last Stable Offset (LSO)**, so records from open or aborted transactions are never delivered.
- Scope caveat: this is Kafka-in → Kafka-out. External writes need their own idempotency (dedup key / conditional write).

**Dead-letter queue (DLQ) + retry — a consumer-side pattern, not a Kafka broker primitive:**
```
try: process(record)
except Retryable:   route to retry-topic (delay/backoff), keep primary moving
except Fatal:       route to DLQ (with headers: error, stacktrace, original offset)
# in all cases commit the primary offset so the partition is NOT blocked
```
Tiered topics — `main` → `retry` (delayed re-consume with exponential backoff) → `dlq` (parked for manual/automated inspection). The DLQ prevents a poison message from stalling the partition; alert on DLQ depth. (Kafka Connect and Spring-Kafka give this out of the box; raw consumers implement it.)

**Backpressure in Kafka:** consumers pull, which is inherently back-pressuring. To slow down without losing position, `pause()` the partition and **do not commit** its offset; `resume()` when ready — on the next poll the same records are re-fetched. Tune `max.poll.records` / `max.poll.interval.ms` so a slow batch doesn't trip a rebalance (the consumer being kicked from the group for missing the poll deadline).

**Transactional outbox (avoid dual-write inconsistency):** don't write the DB *and* publish to the broker as two independent operations (either can fail, leaving them inconsistent). Instead, in the same DB transaction write the domain row **and** an `outbox` row; a separate relay (or CDC via Debezium) tails the outbox and publishes — giving at-least-once publish tied atomically to the DB commit.

## Variants

- **Log-based broker:** Apache Kafka, AWS Kinesis, Apache Pulsar — partitioned, replayable, retention-based; high throughput, per-partition order.
- **Traditional/JMS-AMQP broker:** RabbitMQ, ActiveMQ, AWS SQS — per-message ack/redelivery, routing, priorities, native DLQ; smart broker.
- **Cloud pub-sub:** Google Pub/Sub, AWS SNS+SQS fan-out, Azure Service Bus — managed, at-least-once, auto-scaling.
- **Stream processing on top:** Kafka Streams, Apache Flink — stateful consume-transform-produce with EOS and windowing over the log.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 11 "Stream Processing" (message brokers vs log-based, delivery guarantees)
- Apache Kafka — Producer Configs (`enable.idempotence`, `acks`, `max.in.flight`): https://kafka.apache.org/41/configuration/producer-configs/
- Confluent — "Exactly-Once Semantics Are Possible: Here's How Kafka Does It": https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/
- Alex Xu, *System Design Interview Vol. 2*, "Distributed Message Queue" chapter

## Related

- [[kafka]]
- [[pub-sub]]
- [[event-sourcing]]
- [[idempotency]]
- [[change-data-capture]]
- [[distributed-transactions]]
