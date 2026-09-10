---
id: producer-consumer-and-blocking-queues
type: flashcard
tags:
  - concurrency
  - blocking-queue
  - backpressure
tiers:
  concurrency: 2
created: 2026-09-10
confidence: high
priority: normal
---

# Producer-Consumer & Blocking Queues

The producer-consumer pattern decouples threads that *generate* work (producers) from threads that *process* it (consumers) via a shared thread-safe queue, so each side runs at its own rate and can be scaled independently. A **[blocking queue](_meta/glossary.md#blocking-queue)** is the synchronization primitive that makes this work safely: consumers block when it is empty (waiting for an item) and producers block when it is full (waiting for space) — and a *bounded* blocking queue is exactly where [backpressure](_meta/glossary.md#backpressure) comes from, since a full queue forces fast producers down to the consumers' throughput.

> [!tip] Recognition
> Reach for this when you hear: "decouple ingestion from processing," "smooth out bursty traffic," "batch/pipeline stages," a fast producer and a slower consumer, "worker pool draining a queue," or one thread handing off work to others. Keywords: work queue, task queue, `BlockingQueue` / `put`/`take`, bounded buffer, consumer lag, "run at independent rates." A thread pool draining submitted tasks is this pattern in disguise.

## When to Use

**Problem signals that suggest producer-consumer + a blocking queue:**
- Work is produced and consumed at *different, variable rates* and you want to smooth bursts (rate-mismatch buffering).
- You want to *decouple* the thing accepting requests from the thing doing the slow work (e.g., accept-and-enqueue, process async).
- A pipeline of stages where each stage hands off to the next via a queue.
- You need to fan work out to multiple worker threads (competing consumers) from a single source.
- You want built-in [backpressure](_meta/glossary.md#backpressure): slow the intake automatically when downstream can't keep up.

**Prefer an in-process blocking queue over alternatives when:**
- Over hand-rolled locks + shared list: the blocking queue *is* the correct, tested encapsulation of the mutex + condition-variable dance — don't reimplement it.
- Over a busy-wait / polling loop: blocking `take()` parks the thread with no CPU spin; polling wastes cycles and adds latency.
- Over a full message broker: work stays in one process, doesn't need durability/network, and you want microsecond hand-off, not a network hop.

**Do not use when:**
- Work must survive process crashes, cross machine boundaries, or be consumed by other services -> use a durable [[message-queues]] broker instead.
- Producer and consumer run at the *same* rate with a simple 1:1 handoff and no buffering need -> a direct call or a `SynchronousQueue`-style rendezvous may be simpler.
- The queue would be unbounded and producers can outrun consumers indefinitely -> you need bounding + a shedding/blocking policy, not a bigger buffer.

## Key Properties

- **Decoupling in time and rate.** Producers and consumers never call each other directly; the queue absorbs rate differences up to its capacity. Independent scaling: add consumers to raise throughput, add producers to raise intake.
- **Blocking semantics come from [condition variables](_meta/glossary.md#condition-variable).** `take()` waits on a "not-empty" condition; `put()` waits on a "not-full" condition. Signaling wakes a waiter when state changes. Semaphore-based equivalent: one counting semaphore for *empty* slots (producers acquire), one for *filled* slots (consumers acquire) — see [[locks-mutex-semaphore]].
- **[Bounded queue](_meta/glossary.md#bounded-queue) = backpressure + memory safety.** A full queue makes producers block (or the offer fail), transmitting the "slow down" signal upstream. This is the mechanism, not a side effect. See [[backpressure-and-bulkhead]].
- **Unbounded queue = latent failure.** A producer faster than consumers grows the buffer without limit -> unbounded latency (items sit longer and longer) and eventual [OOM](_meta/glossary.md#oom). "Unbounded" hides the overload instead of surfacing it.
- **Ordering.** A [FIFO](_meta/glossary.md#fifo) queue preserves order with a *single* consumer. With *multiple* competing consumers, items are still dequeued in FIFO order but processed concurrently, so completion order is not guaranteed — do not rely on global ordering across a consumer pool.
- **A thread pool IS a producer-consumer system.** Task submitters are producers; worker threads are consumers pulling from an internal blocking work queue. Its bounding/rejection policy is exactly the backpressure decision. See [[thread-pools-and-executors]].

## Common Pitfalls

- **Unbounded queue -> OOM / unbounded latency.** The classic production incident: a fast producer floods an unbounded buffer. Always bound the queue and pick an explicit full-policy (block, drop-newest, drop-oldest, or reject/shed).
- **Not re-checking the condition in a `while` loop (lost/[spurious wakeups](_meta/glossary.md#spurious-wakeup)).** A thread woken from `wait()` must **re-test the predicate** (`while (queue.isEmpty()) cond.await();`), never `if`. Spurious wakeups happen, and another thread may have consumed the item between the signal and your reacquiring the lock. An `if` here is a real bug.
- **Forgetting to signal.** After a `put()`, signal "not-empty"; after a `take()`, signal "not-full." Miss a signal and a waiter sleeps forever (a lost-wakeup deadlock). Use `signalAll`/broadcast when multiple distinct predicates share one lock, or maintain separate condition variables.
- **Wrong lock ordering / holding the lock across slow work.** Acquiring locks in inconsistent order across threads causes deadlock (see [[deadlock]]); doing the actual item *processing* while holding the queue lock serializes everything. Take the item, release the lock, then process.
- **Racing on the count / non-atomic check-then-act.** "Check not-full, then insert" must be atomic under the lock — a check outside the lock is a [[race-conditions-and-atomicity]] bug.
- **Not draining on shutdown.** Killing consumers mid-flight loses queued work. Signal shutdown, let consumers drain (or explicitly discard) remaining items, then stop.

## Trade-offs

**Bounded vs unbounded queue:**

| Axis | Bounded | Unbounded |
|---|---|---|
| Memory | Capped, safe | Grows until [OOM](_meta/glossary.md#oom) |
| Overload behavior | Producers block / shed -> [backpressure](_meta/glossary.md#backpressure) | Latency climbs silently, then crash |
| Latency under load | Bounded (queue depth capped) | Unbounded |
| Failure mode | Visible early (blocking / rejects) | Catastrophic and late |
| When | **Production default** | Only if producer is provably rate-limited |

**In-process blocking queue vs message broker ([[message-queues]]):** *the confusable pair* — same producer-consumer shape, different scope.

| Axis | In-process blocking queue | Message broker |
|---|---|---|
| Scope | One process, shared memory | Cross-process / cross-service, network |
| Durability | Volatile — lost on crash | Persistent, survives restarts |
| Latency | Nanos–micros (memory) | Millis (network + fsync) |
| Delivery | In-memory handoff | at-least-once / exactly-once, acks, retries |
| Use for | Threads in one JVM/process | Decoupling separate services |

Distinguishing axis: **same pattern, different boundary** — memory vs network + durability.

## Implementation Notes

Bounded blocking queue with a mutex and two condition variables (blocklisted from quiz; reference sketch):

```text
class BoundedBlockingQueue(capacity):
    buffer   = ring buffer of size capacity
    lock     = mutex
    notFull  = condition(lock)   # producers wait here
    notEmpty = condition(lock)   # consumers wait here

    put(item):                    # producer
        lock.acquire()
        try:
            while buffer.isFull():        # WHILE, not IF
                notFull.wait()            # releases lock, parks; re-acquires on wake
            buffer.enqueue(item)
            notEmpty.signal()             # wake one waiting consumer
        finally:
            lock.release()

    take():                       # consumer
        lock.acquire()
        try:
            while buffer.isEmpty():       # WHILE, not IF
                notEmpty.wait()
            item = buffer.dequeue()
            notFull.signal()              # wake one waiting producer
            return item
        finally:
            lock.release()
```

Semaphore form: `empty = Semaphore(capacity)`, `filled = Semaphore(0)`, plus a mutex around the buffer. Producer: `empty.acquire(); lock; enqueue; unlock; filled.release()`. Consumer: `filled.acquire(); lock; dequeue; unlock; empty.release()`.

**Graceful shutdown ([poison pill](_meta/glossary.md#poison-pill)):** enqueue N sentinel items — one per consumer. Each consumer, on dequeuing the sentinel, re-checks nothing else and exits, so remaining real items ahead of it drain first. With a shared count instead, set an atomic `shutdown` flag, then `signalAll` so parked consumers wake, see the flag + empty queue, and exit. Never just interrupt/kill — that abandons in-flight and queued work.

## Resources

- Java Concurrency in Practice, Goetz et al. — ch. 5 (bounded blocking queues, producer-consumer) and ch. 8 (thread pools as producer-consumer).
- `java.util.concurrent.BlockingQueue` / `ArrayBlockingQueue` / `LinkedBlockingQueue` Javadoc.
- The Little Book of Semaphores, Downey — producer-consumer and bounded-buffer chapters.

## Related

- [[thread-pools-and-executors]]
- [[backpressure-and-bulkhead]]
- [[message-queues]]
- [[locks-mutex-semaphore]]
- [[race-conditions-and-atomicity]]
- [[deadlock]]
