---
id: backpressure-and-bulkhead
type: flashcard
tags:
  - backend
  - reliability
tiers:
  backend: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Backpressure and Bulkhead

Backpressure and bulkhead are two complementary overload-survival patterns that keep a healthy system from being dragged down by too much work or a sick dependency. **[Backpressure](_meta/glossary.md#backpressure)** propagates a "slow down" signal from an overwhelmed consumer back up to the producer — via bounded queues, blocking, or load shedding — so work is refused or throttled at the source instead of piling up in unbounded buffers that eventually cause latency blowup and [OOM](_meta/glossary.md#oom). **[Bulkhead](_meta/glossary.md#bulkhead)** partitions finite resources (thread pools, connection pools, semaphores) into isolated compartments per dependency or tenant, so that one slow or failing dependency can only exhaust *its own* compartment and cannot starve the rest of the system. Backpressure controls the *rate/volume* of work flowing in; bulkhead controls the *blast radius* of a single misbehaving component.

> [!tip] Recognition
> Reach for these when you see: an unbounded in-memory queue or buffer that grows without limit under load; a fast producer feeding a slower consumer (Kafka consumer lag, message queue depth climbing); "one slow downstream call made the whole service unresponsive"; thread pool / connection pool fully occupied by calls to a single stuck dependency; rising latency with no errors just before an OOM crash; a shared pool that couples unrelated dependencies together.

## When to Use

**Backpressure — when producers can outpace consumers and buffering is unbounded:**
- Streaming / event pipelines where the consumer is the bottleneck (Kafka, Flink, reactive streams) — signal lag upstream rather than buffer forever
- Any producer/consumer boundary with a queue — bound the queue and decide the overflow policy (block, drop, or reject with 429/503)
- HTTP servers under traffic spikes — shed load (fast-fail) rather than accept requests you cannot serve within SLO

**Bulkhead — when one dependency's failure must not sink the whole service:**
- A service calls several downstreams and one can be slow/flaky — give each its own pool so a stall in one cannot consume all threads
- Multi-tenant systems — isolate per-tenant resource pools so a noisy tenant cannot starve others
- Mixing critical and non-critical work (e.g., checkout vs. recommendations) on the same host — separate pools protect the critical path

**Use both together:** bulkhead bounds *where* damage spreads; backpressure bounds *how much* work accumulates. A per-dependency pool (bulkhead) with a bounded queue that rejects on full (backpressure) is the canonical combination.

## Key Properties

**Backpressure:**
- The mechanism is a *feedback signal*, not just a limit — the consumer's saturation is communicated back to the producer (blocking a write, a full bounded queue, [TCP](_meta/glossary.md#tcp) flow control, a reactive `request(n)` demand signal)
- Overflow policy is an explicit design choice: **block** the producer, **drop** (oldest/newest), or **reject/shed** (fail fast so callers retry elsewhere)
- Bounded buffers are mandatory — an unbounded queue silently *hides* backpressure until memory runs out

**Bulkhead:**
- Isolation is achieved by partitioning a finite resource: separate thread pools, separate connection pools, or per-dependency semaphores (counting permits)
- Semaphore bulkhead limits *concurrency* cheaply on the calling thread; thread-pool bulkhead adds a timeout/isolation boundary at the cost of context-switch overhead
- Sizing matters: each compartment gets a fixed slice, so total capacity is partitioned, not shared on demand

## Trade-offs

| Pattern | Controls | Cost / downside |
|---|---|---|
| **Backpressure** | Rate & volume of incoming work | Someone must be told "no" — added latency (blocking) or dropped/rejected work; producers need a retry/fallback path |
| **Bulkhead** | Blast radius of one component | Lower total utilization — partitioned pools can sit idle while another is saturated; more pools to size and tune |

- Backpressure shifts pain to the producer: blocking couples producer latency to consumer speed; dropping loses data; rejecting pushes retry logic onto clients. Pick per-workload.
- Bulkhead trades efficiency for isolation: dedicating capacity per dependency means you can't opportunistically lend idle threads from one pool to a starved one, so aggregate throughput is lower than a single shared pool.

## Common Pitfalls

- **Unbounded queue = no backpressure.** An in-memory list, an unbounded `Executor` work queue, or an infinite buffer defers collapse rather than preventing it — latency climbs invisibly until OOM. Always bound the buffer and define an overflow policy.
- **Backpressure that only blocks.** Pure blocking can propagate a stall all the way to the user and deadlock thread pools; combine with timeouts and a shed/reject path.
- **Bulkhead pools sized too large.** If every pool is generous, their sum can exhaust CPU/memory/file descriptors, defeating isolation — the point is a *hard* cap per compartment.
- **Shared pool hidden underneath.** Per-dependency thread pools that all draw from one shared connection pool, DB pool, or event loop re-couple the dependencies; isolate the *actual* contended resource.
- **Confusing the four patterns (contrast cue):**
  - **Backpressure** — *slows the producer* by signaling upstream (bounded queue / demand signal).
  - **Bulkhead** — *isolates resources* into pools so failure can't spread (blast-radius control).
  - **[Circuit-breaker](_meta/glossary.md#circuit-breaker)** — *stops calls* to a dependency already detected as failing, then probes to recover (a state machine reacting to a downstream that is *broken now*).
  - **[Rate-limiting](_meta/glossary.md#rate-limiting)** — *caps inbound request rate* against a fixed budget ([token](_meta/glossary.md#token-bucket)/[leaky bucket](_meta/glossary.md#leaky-bucket)), regardless of downstream health or queue depth.
  - Key distinction: backpressure is reactive to *your own* saturation and adjusts flow; rate-limiting enforces a *predefined quota*; bulkhead is *structural* (how resources are carved up); circuit-breaker is *reactive to downstream failure* (stop vs. slow).

## Implementation Notes

- Reactive Streams / Project Reactor / RxJava implement backpressure natively via the `request(n)` demand protocol; Akka Streams and Flink propagate it through the pipeline.
- Resilience4j and (legacy) Hystrix provide both `Bulkhead` (semaphore) and `ThreadPoolBulkhead`, and pair naturally with circuit-breaker and rate-limiter decorators on the same call.
- Bounded `ThreadPoolExecutor` + a `RejectedExecutionHandler` (e.g. `CallerRunsPolicy` for crude backpressure, or `AbortPolicy` for load shedding) is the JVM primitive.
- At the network layer, TCP flow control (receive window) is backpressure; [gRPC](_meta/glossary.md#grpc)/HTTP-2 flow control extends it to streams.

## Resources

- Resilience4j Bulkhead docs: https://resilience4j.readme.io/docs/bulkhead
- Reactive Streams specification (backpressure via demand): https://www.reactive-streams.org/
- Netflix Hystrix — How it Works (bulkhead/isolation): https://github.com/Netflix/Hystrix/wiki/How-it-Works
- Nginx blog — What is Backpressure: https://blog.nginx.org/blog/what-is-backpressure

## Related

- [[circuit-breaker]]
- [[rate-limiting]]
- [[load-shedding]]
- [[message-queue]]
- [[timeouts-and-retries]]
