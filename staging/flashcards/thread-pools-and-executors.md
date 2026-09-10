---
id: thread-pools-and-executors
type: flashcard
tags:
  - concurrency
  - thread-pool
  - performance
tiers:
  concurrency: 2
created: 2026-09-10
confidence: high
priority: normal
---

# Thread Pools and Executors

A [thread pool](_meta/glossary.md#thread-pool) reuses a fixed set of worker threads that pull tasks from a shared queue, and an **[executor](_meta/glossary.md#executor)** is the abstraction that decouples task *submission* from task *execution* — you submit work items, workers execute them. This works because thread creation is expensive (stack allocation, kernel scheduling state) and unbounded threads exhaust memory and thrash the scheduler; a pool amortizes creation cost across many tasks AND caps concurrency, turning the pool into an admission-control point.

> [!tip] Recognition
> Reach for a thread pool when you see: "handle many incoming requests/tasks efficiently"; spawning a thread per request/item; a service that OOMs or slows to a crawl under load spikes; "limit how much work runs at once" / bound concurrency; CPU-bound batch work that should use all cores but no more; a fork-join / recursive divide-and-conquer computation. Keywords: executor, worker pool, task queue, saturation/[rejection policy](_meta/glossary.md#rejection-policy), [work-stealing](_meta/glossary.md#work-stealing), C10k.

## When to Use

**Problem signals that suggest a thread pool / executor:**
- You process many short-to-medium tasks and thread-creation overhead per task is measurable
- You need to *cap* concurrency to protect a downstream (DB connections, an API rate limit) or to bound memory
- Load is bursty and you want a queue to absorb spikes while a fixed number of workers drain it
- A recursive/divide-and-conquer computation splits into many uneven subtasks (fork-join / work-stealing)
- You want a single place to apply [backpressure](_meta/glossary.md#backpressure) and a saturation policy under overload

**Prefer a bounded thread pool over alternatives when:**
- Over **thread-per-request**: you must bound load. Thread-per-request has no ceiling — enough concurrent requests exhausts memory/scheduler (the C10k problem). A bounded pool caps live threads and gives you backpressure when saturated.
- Over an **[event loop](async-and-event-loop.md)**: your tasks contain *blocking* calls (blocking IO, native libs, CPU-heavy work) that would stall a single-threaded event loop. Multiple pool threads let one block while others run.
- Over creating threads ad hoc: task rate is high and you want reuse plus a shared admission-control point.

**Do not use when:**
- Workload is almost entirely non-blocking IO with huge fan-out (tens of thousands of connections) -> an [event loop](async-and-event-loop.md) / async runtime handles this on few threads with far less memory.
- Tasks are long-lived and few, or one-shot at startup -> a dedicated thread (or just running inline) is simpler.
- Subtasks in a fixed pool block waiting on *other* tasks submitted to the same pool -> risks pool-induced deadlock; use a separate pool, a caller-runs policy, or restructure (see Pitfalls).

## Key Properties

1. **Submission is decoupled from execution.** `submit(task)` enqueues and returns immediately (often a future); a worker later dequeues and runs it. This is the producer-consumer pattern with the queue as the buffer.
2. **The pool is an admission-control / concurrency cap.** At most `poolSize` tasks run simultaneously — a natural rate limiter for a protected resource.
3. **The task queue is the crux — its bound decides overload behavior.**
   - **Unbounded queue:** submission never blocks or fails, so overload is *hidden*. Latency grows without limit and the queue eventually causes [OOM](_meta/glossary.md#oom). No [backpressure](_meta/glossary.md#backpressure).
   - **[Bounded queue](_meta/glossary.md#bounded-queue):** when full, the pool must invoke a **rejection / saturation policy** — this is where backpressure surfaces to the caller. Link [[backpressure-and-bulkhead]].
4. **Sizing follows the wait/compute ratio, not a magic number** (Brian Goetz / [Little's law](_meta/glossary.md#littles-law)):
   `threads ≈ cores × (1 + wait/compute)` (× target CPU utilization).
   - **CPU-bound** (wait≈0): threads ≈ number of cores. More just adds context-switch overhead with no throughput gain.
   - **IO-bound** (wait≫compute): use many more threads, because each spends most of its time blocked and not on a CPU. A task that waits 90ms per 10ms of compute wants ~10× cores.
   - (In Python, a plain thread pool cannot run CPU-bound work in parallel because of the [GIL](_meta/glossary.md#gil) — use processes for CPU-bound there.)
5. **Work-stealing (fork-join pools):** each worker owns a double-ended queue; idle workers *steal* from the tail of busy workers' deques. This balances load automatically for recursive tasks that split into many uneven pieces, and reduces contention (each worker mostly touches its own deque).

## Common Pitfalls

- **Unbounded queue masking overload.** The default in some libraries. It converts a load problem into a silent latency-and-memory problem, then an OOM crash. Bound the queue and choose an explicit rejection policy.
- **Blocking inside a CPU-sized pool.** A pool sized to `cores` for CPU work, then given a blocking IO call, wedges: threads sit idle-blocked, CPUs go unused, throughput collapses. Separate IO tasks into an IO-sized pool (or make them non-blocking).
- **Pool-induced deadlock.** Task A runs on a fixed pool and blocks waiting on the result of task B — but B is queued to the *same* pool and every worker is already occupied by tasks like A waiting on their Bs. B can never be scheduled -> deadlock. See [[deadlock]]. Fix: give dependent tasks a distinct pool, avoid submitting-and-blocking on the same pool, or use a caller-runs policy so the submitter makes progress.
- **Not sizing for IO wait.** Sizing an IO-bound pool to `cores` leaves throughput bottlenecked by too few threads while CPUs sit idle waiting on network/disk.
- **Sharing one pool across unrelated dependencies.** One slow dependency occupies all workers and starves everything else. Partition with bulkheads (per-dependency pools) — see [[backpressure-and-bulkhead]].
- **Never shutting the pool down.** Non-daemon worker threads keep the process alive / leak; always have a shutdown path.

## Trade-offs

**Concurrency strategy:**

| Strategy | Concurrency ceiling | Memory per unit | Blocking-call tolerance | Best for |
|---|---|---|---|---|
| Thread-per-request | Unbounded (danger) | ~1 thread + stack each | Fine (each isolated) | Simple, low/moderate load |
| Bounded thread pool | Capped at pool size | Amortized; queue buffers | Fine (other threads run) | Bounded load, mixed/blocking work, backpressure |
| Event loop / async | Very high on few threads | ~1 task struct each | Poor — one blocking call stalls all | Massive non-blocking IO fan-out |

Disambiguation axis: **who bounds load and how blocking is tolerated.** Thread-per-request = simplest but unbounded (C10k). Bounded pool = caps concurrency + gives backpressure. Event loop [[async-and-event-loop]] = huge IO concurrency on few threads, but a single blocking call stalls everything.

**Task queue bound:**

| | Unbounded queue | Bounded queue |
|---|---|---|
| Submission under load | Always accepts | Blocks / rejects when full |
| Backpressure | None (hidden overload) | Yes (surfaces to caller) |
| Latency under overload | Grows without limit | Bounded (fast failure) |
| Failure mode | OOM crash | Rejected tasks (handleable) |

## Implementation Notes

*(Reference only — not quizzed.)*

Submit -> queue -> worker loop:

```text
submit(task):
    if not queue.offer(task):        # bounded queue full
        rejectionPolicy.handle(task) # backpressure surfaces here
# each worker thread:
loop:
    task = queue.take()   # blocks until work available
    task.run()
```

Common **rejection / saturation policies** when a bounded queue is full:
- **Abort/throw** — fail fast; caller sees rejection and can shed/retry.
- **Caller-runs** — the submitting thread executes the task itself; naturally throttles the producer (it stops submitting while busy) — a form of backpressure and it also avoids submit-and-block pool deadlock.
- **Drop-oldest / discard** — evict the oldest queued task (or silently drop the new one); acceptable only when stale work is worthless (e.g., latest-value-wins telemetry).

## Resources

- Goetz et al., *Java Concurrency in Practice*, Ch. 8 (Applying Thread Pools) — pool sizing and saturation policies.
- Java `ThreadPoolExecutor` / `ForkJoinPool` API docs — corePoolSize, queue types, RejectedExecutionHandler, work-stealing.
- "The C10k problem" (Dan Kegel) — why thread-per-connection does not scale.

## Related

- [[threads-vs-processes]]
- [[backpressure-and-bulkhead]]
- [[async-and-event-loop]]
- [[deadlock]]
- [[producer-consumer-and-blocking-queues]]
