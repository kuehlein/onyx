---
id: async-and-event-loop
type: flashcard
tags:
  - concurrency
  - backend
tiers:
  concurrency: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Async, Event Loop, and Non-Blocking I/O

The async model achieves concurrency *without a thread per task*: one thread runs an **event loop** that registers interest in many I/O sources, asks the OS "which of these are ready?" via a kernel event API (epoll on Linux, kqueue on BSD/macOS, IOCP on Windows — the first two report *readiness*, IOCP reports *completion*), and dispatches a callback only when the I/O can make progress. Because a socket that is waiting costs a file descriptor and a callback — not a parked OS thread with its ~1 MB+ stack (Java defaults ~1 MB; the Linux pthread default is up to 8 MB, mostly reserved) — a single process can juggle tens of thousands of connections cheaply. The whole model rests on one contract: **every operation must yield control quickly**; the loop makes progress only while no callback is hogging it.

> [!tip] Recognition
> Reach for this when the workload is **I/O-bound with high connection count** and each request spends most of its time *waiting* (network calls, DB queries, disk, upstream APIs): chat/websocket servers, API gateways, proxies, fan-out to many microservices. Signals in prose: "10k+ concurrent connections," "mostly waiting on other services," "thread-per-request is exhausting memory/context-switch budget" (the C10k problem). If the work is **CPU-bound** (image resize, crypto, parsing), this is the *wrong* tool — it will stall the loop.
>
> **vs. threads-vs-processes:** async is about *how one thread waits on many I/O sources at once* (concurrency without parallelism); threads/processes are about *getting more execution contexts* (real parallelism, isolation). Distinguishing signal: if the pain is "too many parked threads waiting on I/O," reach for async; if the pain is "I need CPU work to actually run at the same time" or "I need fault/memory isolation," reach for threads/processes.

## When to Use

**Problem signals that suggest an async / event-loop design:**
- Many simultaneous connections that are each mostly idle-waiting on I/O (websockets, long-poll, streaming, proxying)
- The bottleneck is "we run out of memory/threads at N connections," not "the CPU is pegged" — classic C10k scaling wall
- Latency is dominated by *waiting* on downstream services, not computing a result

**Prefer async over a thread-per-request pool when:**
- Over blocking threads: connections scale into the tens of thousands — you avoid ~1 MB of stack per thread and the context-switch cost of thousands of runnable threads
- Over spawning a process/thread per task: tasks are fine-grained and short, so setup/teardown cost would dominate

**Do not use when:**
- The work is **CPU-bound** → a busy callback monopolizes the single loop thread and every other connection stalls; use a worker pool / multiple processes / real parallelism instead
- You depend on a **blocking** library (a synchronous DB driver, `fs.readFileSync`, a blocking C extension) → it freezes the loop; you need an async-native client or must offload it to a thread pool
- The concurrency is modest and the code is simpler as straight-line blocking calls → don't pay the async complexity tax for no scaling benefit

## Key Properties

- **Concurrency is not parallelism.** One event loop interleaves *many* tasks on *one* core (concurrency: progress on multiple things by rapidly switching at yield points). It does **not** run them simultaneously. Parallelism needs multiple cores/threads/processes. Async gives you cheap concurrency, never a speedup on CPU work.
- **Cooperative, not preemptive.** Control transfers only at explicit suspension points (`await`, returning to the loop). Nothing preempts a running callback — so one long callback blocks *everything* until it yields.
- **Readiness-based, not thread-based, waiting.** The loop blocks in one syscall (`epoll_wait`/`kqueue`) on *all* fds at once, then wakes and runs the handlers for whichever became ready — O(ready events), not O(watched fds).
- **`async`/`await` is sugar over the loop.** An `await` suspends the current task, registers a continuation, and returns control to the loop; the continuation resumes when the awaited thing completes. Callbacks → promises/futures → async/await are three ergonomics for the same machine.

## Trade-offs

| Model | Concurrency mechanism | Cost per waiting task | Best fit | Fatal weakness |
|---|---|---|---|---|
| **Async event loop** (Node, Python asyncio, Netty) | 1 thread, readiness API + callbacks | ~1 fd + a closure | I/O-bound, high connection count | one blocking/CPU-heavy call stalls the whole loop |
| **Thread-per-request** (classic Java/servlet, blocking) | OS thread per task, preemptive | ~1 MB stack + scheduler slot | moderate concurrency, simple blocking code | memory + context-switch blowup at ~10k+ threads |
| **Goroutines** (Go, M:N scheduler) | many lightweight tasks over few OS threads | small growable stack (~KB) | high concurrency *and* CPU work | runtime complexity; still shares memory (needs sync) |

- **vs. goroutines (the key contrast):** goroutines *look* like blocking code but the Go runtime **multiplexes M goroutines onto N OS threads (M:N)** and does the async I/O for you underneath — so a blocking-looking call parks only that goroutine, not a whole thread, and CPU-bound goroutines can run in *parallel* on other threads. An event loop is **1:1 with a single thread**: it can't hide a blocking call and can't parallelize CPU work without extra processes.
- **Ergonomics tax:** callback-based async fragments control flow ("callback hell"); async/await restores readability but "colors" functions (async calls can only be awaited from async contexts).

## Common Pitfalls

- **Blocking the loop is the cardinal sin.** A synchronous CPU-heavy computation, a `Sync` I/O call, or a tight loop inside a callback freezes *every* connection until it returns — tail latency spikes for unrelated requests. Offload CPU work to a worker pool / separate process; use async-native I/O clients.
- **Assuming async = faster.** Async adds *concurrency*, not speed. For a single CPU-bound task it is the same or slower (scheduling overhead). It only wins when tasks spend time *waiting*.
- **A single sync call poisons the pipeline.** One accidental blocking library (a synchronous Redis/DB driver, `JSON.parse` on a huge payload, synchronous logging) silently serializes an otherwise-async server. Audit every dependency for blocking calls.
- **Unhandled rejections / swallowed errors.** An error in a callback or an un-awaited promise doesn't propagate up a call stack the way a synchronous exception does; it can vanish silently or crash the process. Always attach error handling and `await` (or explicitly handle) every promise.
- **Forgetting the loop is one thread.** Shared in-memory state is safe *between* await points but *not* across them: another task can run during an `await`, so invariants held before an await may be violated after it (async interleaving, a subtle cousin of a data race).

## Implementation Notes

Reference only — reconstruct the shape, don't memorize.

- **Readiness APIs:** Linux `epoll`, BSD/macOS `kqueue`, Windows IOCP (completion-based, not readiness-based). Libraries like `libuv` (Node) and `libev` abstract these behind one interface.
- **Offloading blocking work:** Node hands file I/O, DNS `getaddrinfo`, and CPU offload to a small **libuv thread pool (default size 4**, tunable via `UV_THREADPOOL_SIZE`, max 1024); genuinely CPU-bound JS goes to `worker_threads` or a child process. Python asyncio uses `loop.run_in_executor(...)` to push blocking calls to a thread/process pool.
- **Python asyncio** runs coroutines on a single-threaded loop; the [GIL](_meta/glossary.md#gil) means threads don't give CPU parallelism anyway, so CPU work belongs in a `ProcessPoolExecutor`.
- **Scaling across cores:** because one loop = one core, production deployments run **one process per core** (Node `cluster`, multiple Gunicorn/uvicorn workers) behind a load balancer to use the whole machine.

## Resources

- The C10k problem (Dan Kegel) — http://www.kegel.com/c10k.html
- libuv design overview — https://docs.libuv.org/en/v1.x/design.html
- Python asyncio — Developing with asyncio (blocking/CPU caveats) — https://docs.python.org/3/library/asyncio-dev.html
- Node.js — The Node.js Event Loop — https://nodejs.org/en/learn/asynchronous-work/event-loop-timers-and-nexttick

## Related

- [[backpressure]]
- [[connection-pooling]]
- [[thread-pool]]
- [[goroutines]]
- [[grpc]]
