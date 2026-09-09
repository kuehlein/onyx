---
id: threads-vs-processes
type: flashcard
tags:
  - concurrency
  - threads
  - processes
  - parallelism
tiers:
  concurrency: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Threads vs Processes

A process is an OS-scheduled program with its own isolated virtual address space; a thread is an independently schedulable execution context that runs *inside* a process. The single distinction everything else follows from: **threads of one process share that process's memory (heap, globals, file descriptors); separate processes do not.** Sharing makes threads cheaper to create and to communicate between, but forces you to synchronize access and removes the fault isolation you get for free between processes.

> [!tip] Recognition
> Reach for **multiple processes** when the words are *isolation*, *fault tolerance*, *security boundary*, or *"one crash must not take down the rest"* — or when a CPU-bound workload runs in a runtime with a global interpreter lock. Reach for **multiple threads** when the words are *shared in-memory state*, *low-latency communication*, *many concurrent I/O waits*, or *"cheap to spawn thousands of."*

> [!warning] Not to be confused with (interference)
> This card is about the **unit of execution** (what runs your code). Don't confuse it with:
> - **Locks / mutex / semaphore** — those are the *synchronization primitives* you reach for **once you've already chosen threads** and now must guard shared memory. Distinguishing signal: "how do two units coordinate access?" → sibling card, not this one.
> - **Async / event loop** — a *single-threaded* concurrency model that interleaves I/O without extra OS units at all. Distinguishing signal: "I/O-bound, no multicore needed, avoid both context-switch and lock cost" → sibling card. Threads/processes are the answer when you need OS-scheduled units (parallelism or blocking work), async when you don't.

## When to Use

**Signals that suggest separate PROCESSES:**
- You need a **fault boundary**: a crash, memory corruption, or `abort()` in one unit must not kill the others (browser tab-per-process, Postgres backend-per-connection, nginx workers)
- You need a **security/privilege boundary**: untrusted code (a sandbox, a plugin) must not read another unit's memory
- CPU-bound parallelism in a runtime with a [GIL](_meta/glossary.md#gil) (CPython, standard Ruby) — only separate processes achieve true multicore parallelism there

**Signals that suggest THREADS:**
- Units must **share large mutable in-memory state** cheaply (an in-memory cache, a shared graph/index) without serializing it across a boundary
- You need **cheap, low-latency communication** between units — a shared variable beats a pipe or socket
- Many concurrent **I/O waits** (handling thousands of sockets); threads block on I/O while others proceed, at far lower per-unit cost than processes
- You spawn/tear down units frequently — thread creation is much cheaper than `fork`/`exec`

**Do not use when:**
- You reach for threads but the work is CPU-bound under a GIL → you get concurrency but not parallelism; use processes instead
- You reach for processes but the units must constantly share a large mutable structure → IPC serialization cost dominates; use threads (or shared memory) instead
- Either one where an async event loop (single-threaded, non-blocking I/O) already handles the I/O concurrency with less overhead

## Key Properties

| Property | Process | Thread |
|---|---|---|
| Address space | Own, isolated (private virtual memory) | Shared with all threads in the process |
| Memory sharing | None by default — needs explicit shared memory | Automatic (heap, globals, static data) |
| Communication | IPC: pipes, sockets, message queues, shared memory | Shared variables (guarded by locks) |
| Creation cost | Heavy (new address space, page tables, `fork`/`exec`) | Light (shares the process's resources) |
| Context switch | More expensive (full address-space/TLB switch) | Cheaper (same address space; TLB stays warm) |
| Fault isolation | Strong — one crash doesn't touch others | None — a segfault/unhandled crash takes the whole process down |
| Per-thread private state | (whole process) | Its own stack, registers, program counter, thread-local storage |

- Threads share the heap and globals but each has its **own stack and registers** — that private stack is why local variables are not shared.
- Both are scheduled by the OS (kernel threads); user-space "green threads"/coroutines are multiplexed onto OS threads by a runtime and don't get their own kernel scheduling.

## Trade-offs

- **Isolation vs. communication cost.** Processes give you a hard fault/security boundary but every cross-unit message must cross an IPC boundary (serialize/copy through the kernel, or set up shared memory). Threads communicate through a shared pointer for free — but that same shared memory is the source of data races.
- **Safety vs. speed of sharing.** Shared-memory threads are the fast path for shared state, but correctness now depends on you (locks, atomics, immutability). Process isolation makes whole classes of concurrency bugs *impossible* at the cost of copying data.
- **Blast radius.** One misbehaving thread can corrupt shared state or crash every thread in the process; one misbehaving process is contained. This is why high-reliability servers prefer a process-per-request/worker model despite the higher cost.
- **vs. async/event loop:** for pure I/O concurrency, a single-threaded async model avoids both context-switch cost *and* shared-state locking — prefer it when the work is I/O-bound and you don't need multicore CPU parallelism.

## Common Pitfalls

- **"Threads = parallelism" under a GIL.** In CPython/standard Ruby the GIL lets only one thread execute bytecode at a time, so CPU-bound threads run *concurrently but not in parallel* — no multicore speedup. Threads still help for I/O-bound work (the lock is released during blocking I/O). Use processes for CPU-bound parallelism. (Python ships an optional free-threaded build that removes the GIL — experimental in 3.13, officially supported as of 3.14 (PEP 779) — but the default interpreter still ships with the GIL enabled.)
- **Unsynchronized shared state = data race.** Any two threads touching the same mutable memory without a lock/atomic is undefined behavior, not merely "sometimes wrong." Shared-by-default is the trap.
- **Assuming process isolation is free of shared pitfalls.** Processes still share the *file system, ports, and OS resources*; and `fork()` copies the address space copy-on-write but does **not** copy other threads, so forking a multithreaded process can leave locks held forever (fork-in-multithreaded-program hazard).
- **Confusing concurrency with parallelism.** Concurrency = multiple tasks *in progress* (interleaved); parallelism = multiple tasks *executing at the same instant* on multiple cores. Threads give concurrency always, parallelism only without a GIL; processes give both.
- **Ignoring context-switch cost at scale.** Thousands of blocked threads still cost memory (each reserves a stack — Linux defaults to ~8 MB of virtual address space per thread, ~1 MB on Windows) and scheduler overhead — a common reason to switch to an async event loop.

## Implementation Notes

Reference APIs, not to memorize verbatim:
- POSIX: `pthread_create` (threads) vs `fork` + `exec` (processes); `pipe`, `mmap(MAP_SHARED)`, `shm_open` for IPC.
- Python: `threading` (I/O-bound), `multiprocessing` (CPU-bound, sidesteps the GIL with separate interpreters), `asyncio` (I/O-bound, single thread).
- Real systems combining both: nginx (worker *processes*, each with an event loop), Postgres (process per connection), Chrome (process per site/tab for isolation).

## Resources

- Bryant & O'Hallaron, *Computer Systems: A Programmer's Perspective*, ch. 12 (Concurrent Programming) — https://csapp.cs.cmu.edu/
- The Linux Programming Interface (Kerrisk), ch. 29–33 (Threads) and ch. 24 (fork) — https://man7.org/tlpi/
- Python docs — `multiprocessing` (GIL rationale): https://docs.python.org/3/library/multiprocessing.html
- PEP 703 — Making the GIL optional (free-threaded CPython): https://peps.python.org/pep-0703/

## Related

- [[mutex-vs-semaphore]]
- [[deadlock]]
- [[race-conditions]]
- [[async-event-loop]]
- [[connection-pooling]]
