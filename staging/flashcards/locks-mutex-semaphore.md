---
id: locks-mutex-semaphore
type: flashcard
tags:
  - concurrency
  - synchronization
  - locks
tiers:
  concurrency: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Locks: Mutex, Semaphore, RWLock

A lock is a synchronization primitive that serializes access to shared state so concurrent threads cannot corrupt it. The three you must distinguish differ by *what they count and who may release them*: a **mutex** grants exclusive access to one owner (only the locker unlocks); a **semaphore** is just a counter of N available permits with no owner (any thread may signal); a **read-write lock** admits many concurrent readers XOR a single writer. Picking the wrong one — e.g. a semaphore where you needed ownership — silently forfeits priority inheritance and death detection.

> [!tip] Recognition
> Reach for a **mutex** when exactly one thread may touch a resource at a time and the acquirer is the releaser (protecting a data structure). Reach for a **semaphore** when you are limiting concurrency to N (a connection pool of 10) or signaling between threads (producer posts, consumer waits) — the poster and waiter are different threads. Reach for an **RWLock** when reads vastly outnumber writes and reads don't mutate (a cache, a config object).
>
> **Not this card if:** the question is about two locks waiting on *each other* forever → [[deadlock]] (a failure *mode*, not a primitive). If it's about *why* unsynchronized access corrupts state or when a lock-free **atomic** suffices instead → [[race-conditions]]. This card is the menu of *which primitive to pick*; those cards are the hazard you're avoiding and the cheaper alternative.

## When to Use

**Mutex** — mutual exclusion of one:
- Guarding a critical section where any concurrent access corrupts state (shared counter, linked list, map)
- The same thread that acquires will release — ownership is meaningful
- You want the runtime's priority-inheritance / deadlock-detection help (only ownership enables it)

**Semaphore** — count or signal:
- Bounding concurrency to N: a pool of DB connections, a limit of 10 in-flight requests
- Signaling across threads where locker ≠ unlocker: producer/consumer, "resource is ready" handoff
- A binary semaphore (N=1) *can* mimic a mutex but lacks ownership — prefer a mutex for mutual exclusion

**RWLock** — read-heavy sharing:
- Reads greatly outnumber writes AND readers don't modify (config, in-memory cache, routing table)
- Concurrent readers must not block each other, but a writer needs exclusive access

**Do not use a lock when:**
- The access is a single word-sized read/write → an **atomic** (compare-and-swap, atomic int) is cheaper and lock-free
- Threads never share mutable state → make it immutable or thread-local; no lock needed
- Contention is extreme and the critical section is tiny → consider lock-free structures or sharding the lock

## Key Properties

- **Mutex = ownership + mutual exclusion.** One holder at a time; only the owning thread may unlock. Ownership is what lets the runtime add priority inheritance, recursion (re-entrant locks), and death detection. Unlocking from a non-owner thread is undefined behavior.
- **Semaphore = an atomic counter of permits, no owner.** `acquire`/wait decrements (blocks at 0); `release`/signal increments. Any thread may signal — that's the point for cross-thread signaling. **Binary** semaphore has 1 permit; **counting** semaphore has N. It has no concept of "who holds it," so no priority inheritance.
- **RWLock = many readers XOR one writer.** Multiple read holders concurrently, but a write holder is fully exclusive (no readers, no other writers). Only pays off when reads dominate; under balanced load its bookkeeping is slower than a plain mutex.
- **Spinlock vs. blocking lock:** a spinlock busy-waits (burns CPU) expecting a very short hold; a blocking lock parks the thread (context-switch cost) for longer holds. Spin only when the critical section is shorter than a context switch.

## Trade-offs

| Primitive | Holders | Who releases | Priority inheritance | Reach for it when |
|---|---|---|---|---|
| Mutex | exactly 1 | only the owner | yes | protecting a critical section (locker == unlocker) |
| Binary semaphore | 1 permit | any thread | no | signaling between two different threads |
| Counting semaphore | N permits | any thread | no | limiting concurrency to N (pool of resources) |
| RWLock | N readers XOR 1 writer | the holder | varies | read-heavy, reads don't mutate |

- **Mutex vs. binary semaphore:** identical count (1), but the mutex has an *owner*. Use a mutex for mutual exclusion (get ownership, priority inheritance, misuse detection); use a semaphore only when the signaler and waiter are genuinely different threads.
- **RWLock vs. mutex:** RWLock wins only when reads dominate; otherwise its extra bookkeeping and writer-starvation risk make a plain mutex faster and simpler.
- **Spinlock vs. blocking mutex:** spin trades CPU cycles for lower latency on very short holds; block trades a context switch for not burning a core on long holds.

## Common Pitfalls

- **Forgetting to unlock** on an early return, exception, or panic → the lock is held forever, deadlocking everyone after it. Use scope-bound release (RAII / `defer` / `try…finally` / `with`) so unlock is automatic.
- **Holding a lock across I/O or a blocking call** (network, disk, `sleep`) → serializes everyone behind a slow operation and destroys throughput. Do slow work *outside* the critical section; copy out what you need, unlock, then act.
- **Deadlock from lock-ordering:** two threads each hold one lock and wait for the other's. Prevent it by acquiring multiple locks in a single global order everywhere. (See [[deadlock]].)
- **Priority inversion:** a low-priority thread holds a lock a high-priority thread needs, and a medium-priority thread preempts the low one — the high thread stalls indefinitely. A mutex with *priority inheritance* fixes this (owner temporarily inherits the waiter's priority); a plain semaphore cannot, because it has no owner. (This bug froze the Mars Pathfinder rover.)
- **Contention:** one coarse lock over a hot path serializes all threads. Reduce hold time, shard the lock, or switch to lock-free/atomic operations.
- **Using a binary semaphore for mutual exclusion:** it works until you hit priority inversion or accidentally "unlock" from the wrong thread — silently gives up the mutex's safety guarantees.

## Implementation Notes

Prefer scope-bound acquisition so release is guaranteed on every exit path:

```python
# Python: `with` releases the lock even on exception
with lock:
    shared.value += 1          # critical section stays tiny

# Bounded concurrency with a counting semaphore (pool of 10)
pool = threading.Semaphore(10)
with pool:
    do_work()                  # at most 10 threads run this at once
```

```go
// Go: defer guarantees unlock; RWMutex for read-heavy state
mu.Lock()
defer mu.Unlock()

rw.RLock()   // many readers concurrently
defer rw.RUnlock()
```

Rules of thumb: keep critical sections minimal; never call out to unknown/blocking code while holding a lock; acquire multiple locks in one consistent global order; measure contention before optimizing.

## Resources

- Python `threading` (Lock, RLock, Semaphore) — https://docs.python.org/3/library/threading.html
- Go `sync` (Mutex, RWMutex) — https://pkg.go.dev/sync
- OSTEP, *Locks* (free chapter, Arpaci-Dusseau) — https://pages.cs.wisc.edu/~remzi/OSTEP/threads-locks.pdf
- Niall Cooling, *Mutex vs. Semaphores* — https://www.embeddedrelated.com/showarticle/1264.php

## Related

- [[deadlock]]
- [[race-conditions]]
- [[optimistic-vs-pessimistic-locking]]
- [[atomics-and-cas]]
