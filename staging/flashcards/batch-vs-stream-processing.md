---
id: batch-vs-stream-processing
type: flashcard
tags:
  - distributed-systems
tiers:
  distributed-systems: 3
created: 2026-09-08
confidence: high
priority: normal
---

# Batch vs Stream Processing

The dividing line is the shape of the input, not the tool. **Batch processing** consumes a *bounded* dataset (a finite file / table / snapshot with a known end) and optimizes for throughput and correctness: it can read the whole input, sort, join, and — because the input is immutable and complete — trivially rerun to produce the same result. **Stream processing** consumes an *unbounded* dataset (an endless sequence of events with no "end") and optimizes for low latency: results emerge incrementally as events arrive. Everything hard about streaming (windowing, watermarks, [exactly-once](_meta/glossary.md#exactly-once-semantics)) exists because you must produce answers *before* you have seen all the data, over inputs that arrive late and out of order.

> [!tip] Recognition
> Reach for a **batch** framing when the input is a *finite, complete dataset* you can reprocess ("recompute yesterday's report", "backfill the full table", "nightly ETL", "train on the last 90 days"). Reach for a **stream** framing when the input is an *never-ending flow of events* and latency matters ("update the dashboard within seconds", "alert on fraud as it happens", "per-user session aggregation on a live clickstream"). The tell for streaming difficulty: any requirement mentioning *event time*, *out-of-order*, *late-arriving*, or *windows*.

## When to Use

- **Batch** — the full input is available and bounded; you value high throughput and reproducibility over freshness; you can tolerate latency measured in minutes-to-hours. Classic: nightly aggregation, ML training data prep, backfills, offline analytics. Tools: MapReduce, Spark (batch), Hive.
- **Stream** — input is unbounded and results are needed continuously with low (sub-second to seconds) latency; the value of an answer decays fast (alerting, real-time dashboards, personalization, fraud). Tools: Flink, Kafka Streams, Spark Structured Streaming.
- **Reprocessing is the deciding constraint.** If you must be able to recompute historical results from scratch (bug fix in logic, new derived view), a bounded/replayable log or a batch pass is far easier than mutating live stream state.

## Key Properties

- **Bounded vs unbounded input** is the definitional split; latency/throughput are *consequences*, not the definition. (A finite file processed as a stream is still just batch with extra machinery.)
- **Windowing** turns an unbounded stream into finite chunks you can aggregate:
  - *Tumbling* — fixed-size, non-overlapping (every event in exactly one window).
  - *Sliding* — fixed-size, overlapping by a step (an event can land in several windows).
  - *Session* — dynamic, closed by a gap of inactivity (per-user activity bursts).
- **Event time vs processing time.** Correct streaming aggregates by *event time* (when it happened), not *processing time* (when it arrived), so results are deterministic regardless of delays.
- **Watermarks** are the system's assertion "I believe I have seen all events up to time T," letting it *close* event-time windows despite out-of-order arrival. Events later than the watermark are *late*; you either drop them, side-output them, or allow lateness to re-fire the window (a latency vs completeness knob).
- **Exactly-once (end-to-end)** = *effectively* once, achieved by (a) periodic **checkpointing** of operator state that can be atomically rolled back on failure, plus (b) **[idempotent](_meta/glossary.md#idempotency) or transactional sinks** so replayed output isn't double-written. Flink pairs checkpoints with a [two-phase-commit](_meta/glossary.md#two-phase-commit) sink (e.g. transactional Kafka producer) so outputs commit only when their checkpoint completes.

## Trade-offs

| Dimension | Batch | Stream |
|---|---|---|
| Input | **Bounded** (finite, known end) | **Unbounded** (endless events) |
| Latency | High (minutes–hours) | Low (ms–seconds) |
| Throughput | Very high (whole-dataset optimizations) | High but per-event overhead |
| Reprocessing | Trivial — just rerun on immutable input | Hard — needs replayable log + state mgmt |
| Ordering / lateness | Non-issue (all data present) | Core problem (watermarks, late events) |
| State | Ephemeral per job | Long-lived, checkpointed, must be fault-tolerant |
| Result semantics | Complete & correct once | Incremental, may revise as late data arrives |

- **Freshness vs simplicity:** streaming buys latency at the cost of windowing, watermark tuning, and stateful fault tolerance. Don't pay it if minutes-old data is fine.
- **Exactly-once vs latency:** transactional sinks only make output visible when a checkpoint commits, so a longer checkpoint interval adds output latency. Exactly-once is not free throughput-wise.

## Architectures: Lambda vs Kappa

- **Lambda** — run a batch layer (accurate, reprocessable) *and* a speed/stream layer (fresh but approximate) in parallel, then merge at query time. Robust but you maintain the *same logic twice* in two codebases.
- **Kappa** — a *single* stream layer over a durable, replayable log (e.g. Kafka); "reprocessing" = replaying the log through updated stream code. One codebase; relies on the log retaining enough history to replay.

## Common Pitfalls

- **Confusing the tool with the paradigm.** Spark can do both; Flink treats batch as bounded streaming. "We use Spark" says nothing about whether the workload is bounded.
- **Aggregating by processing time.** Using arrival time for windows makes results non-deterministic and wrong under delays/replays — use event time + watermarks.
- **Ignoring late events.** Every windowed stream job needs an explicit late-data policy (drop / side-output / allowed-lateness); silently dropping them corrupts totals.
- **Assuming exactly-once means "no duplicates on the wire."** It means *effectively-once state/output* via checkpoint rollback + idempotent/transactional sinks. A non-idempotent sink (e.g. blind `INSERT`) breaks the guarantee even with checkpointing on.
- **Watermark too tight vs too loose.** Too tight → correct data dropped as "late"; too loose → windows close slowly, latency balloons. It is a tuning trade-off, not a fixed value.

## vs. Confusable Siblings

- **vs. message queues:** a queue/broker is the *transport* — it moves and buffers events between producers and consumers. Batch/stream *processing* is the *computation* over that data. Kafka (log/broker) is not stream processing; Kafka *Streams* / Flink reading from Kafka is. Distinguishing signal: "deliver / decouple / buffer messages" = queue; "aggregate / window / join / transform a data flow" = processing.
- **vs. [change data capture](_meta/glossary.md#change-data-capture) (CDC):** CDC is one *source* that turns a database's write log into an event stream. It answers "*where do the events come from*" (the DB); batch vs stream answers "*how is the finite-vs-endless dataset computed*." CDC feeds a stream processor; it is not itself the processing paradigm.

## Implementation Notes

- Flink `KafkaSink` with `DeliveryGuarantee.EXACTLY_ONCE` activates a two-phase-commit sink backed by Kafka transactions; downstream `read_committed` consumers see records only after the checkpoint commits.
- Kafka Streams offers `processing.guarantee=exactly_once_v2` using idempotent producers + transactions across its state stores.
- Spark Structured Streaming models a stream as an unbounded table with micro-batch (or continuous) execution — the same DataFrame API as batch, which is a Kappa-friendly property.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 10 (Batch) & Ch. 11 (Streams) — the primary source.
- The Dataflow Model paper (Google) — event time, windowing, watermarks: https://research.google/pubs/pub43864/
- Apache Flink — end-to-end exactly-once overview: https://flink.apache.org/2018/02/28/an-overview-of-end-to-end-exactly-once-processing-in-apache-flink-with-apache-kafka-too/
- Apache Flink — event time & watermarks: https://nightlies.apache.org/flink/flink-docs-stable/docs/concepts/time/

## Related

- [[message-queues]]
- [[change-data-capture]]
- [[mapreduce]]
- [[kafka]]
- [[idempotency]]
