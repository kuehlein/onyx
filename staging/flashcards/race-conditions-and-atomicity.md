---
id: race-conditions-and-atomicity
type: flashcard
tags:
  - concurrency
tiers:
  concurrency: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Race Conditions and Atomicity

A race condition is any bug whose outcome depends on the *unsynchronized interleaving or timing* of concurrent accesses to shared mutable state — most classically a read-modify-write (like `x++`) that another thread interrupts between the read and the write. The fix is always to restore atomicity: make the composite operation appear indivisible via a lock (critical section), a hardware atomic (compare-and-swap), or by removing the sharing entirely (immutability / confinement). A *data race* is the narrower, formal sibling: two threads access the same location, at least one writes, and there is no synchronization ordering them. In C/C++ that is outright undefined behavior; Java and Go instead define *weak, bounded* semantics (no out-of-thin-air values, but you may still read stale/reordered data); Rust's safe subset makes data races a compile error. Either way it is a real defect, not merely a "maybe wrong answer."

> [!tip] Recognition
> Reach for this analysis when you see: shared mutable state touched by ≥2 threads; a **read-modify-write** (`count++`, `if (x == null) x = new()`, balance update); a **check-then-act** sequence (check a file/map/flag, then act on it); results that change under load or vanish under a debugger ("Heisenbug"); or a value that is written by one thread and never seen by another (a *visibility* bug, not an interleaving bug).

## When to Use

**Problem signals that you have (or must prevent) a race condition:**
- A composite read-modify-write on shared state: `counter++`, `balance -= amount`, lazy init `if (instance == null) instance = new()`
- Check-then-act: `if (!map.containsKey(k)) map.put(k, v)`, `if (file.exists()) file.delete()` — the state can change between the check and the act
- Time-of-check to time-of-use (TOCTOU): a security check (permissions, path) validated separately from the privileged use of that resource
- Symptoms: nondeterministic results, works in tests but fails under production concurrency, disappears when you add logging or attach a debugger

**Pick the right fix by matching it to the cause:**
- Composite operation must be indivisible → **lock** (critical section) around the whole read-modify-write
- Single-variable update on a hot path → **atomic / compare-and-swap** (lock-free, no blocking)
- State is only *read* concurrently → make it **immutable** (no writes = no data race, no lock needed)
- Each thread can own its own copy → **confinement** (thread-local, actor/message passing) so nothing is shared

**Do not reach for a lock when:**
- The data is never mutated after publication → immutability is simpler and faster
- Only one variable changes atomically → an atomic type avoids lock overhead and deadlock risk
- The "shared" state need not be shared → confine it and eliminate the problem at the root

## Key Properties

- **Race condition ≠ data race.** A *data race* is unsynchronized concurrent access with ≥1 write (a low-level, memory-model-defined UB). A *race condition* is a higher-level correctness bug about bad interleaving. You can have a race condition with *no* data race — e.g. two individually-atomic operations (`get` then `put`) that still interleave wrongly — and (in theory) a benign data race. Fixing all data races does not automatically fix all race conditions.
- **Atomicity means indivisible.** An atomic operation completes fully or not at all with no observable intermediate state; no other thread can see it half-done. `x++` is *three* operations (load, increment, store) and is therefore not atomic by default.
- **Atomicity ≠ visibility.** A lock or atomic also establishes a *happens-before* ordering that flushes writes so other threads can see them. A plain shared field can be written by one thread and never observed by another because of caching/reordering — this is a separate axis from interleaving.
- **A critical section serializes access.** Code holding a given lock runs mutually exclusively, so the enclosed read-modify-write behaves as one atomic step. Correctness requires *every* accessor to use the *same* lock.

## Trade-offs

| Mechanism | How it makes things atomic | Reach for it when | Cost / risk |
|---|---|---|---|
| **Lock / mutex** (critical section) | Serializes a whole code region | Multi-step invariant across ≥2 variables | Blocking, contention, **deadlock**, forgetting a lock |
| **Atomic / CAS** | Single hardware-atomic RMW, lock-free | One variable, hot path | Only one location; **ABA problem**; retry loop under contention |
| **Immutability** | No writes → nothing to race | State read-only after creation | Copy-on-change allocation cost |
| **Confinement** | State never shared | Thread-local / actor / per-request data | Restructures ownership; harder to share results |

**vs. atomic-per-operation:** making each individual operation atomic (an atomic map, a synchronized method) is *not* enough when the *composite* is the invariant. `map.putIfAbsent(k, v)` (one atomic op) is correct; `contains(k)` then `put(k, v)` (two atomic ops) still races. The atomic boundary must wrap the whole invariant, not each step.

**Disambiguation — this card is the *problem*, the siblings are *solutions*:**

| If the question is about… | Use this card | Not |
|---|---|---|
| *What the bug is* — bad interleaving of shared mutable state, why `x++` loses updates, race vs. data race, atomicity vs. visibility | **Race Conditions and Atomicity** | — |
| *Which in-memory primitive to grab* — mutex vs. semaphore, ownership, counting-permits, blocking mechanics | — | **locks-mutex-semaphore** |
| *Which DB/distributed strategy* — version compare-and-set vs. row locks, contention assumptions, retry-on-conflict | — | **optimistic-vs-pessimistic-concurrency** |

Distinguishing signal: reach for *this* card when you are diagnosing **why** concurrent code is wrong; reach for the siblings when you have already decided to serialize and are choosing **which** tool.

## Common Pitfalls

- **Assuming a single statement is atomic.** `x++`, `x += 1`, and 64-bit reads/writes on 32-bit platforms are multi-step under the hood; two threads lose updates. Use an atomic type or a lock.
- **Locking with the wrong / a different lock object.** Mutual exclusion only holds if all accessors share one lock. Guarding writes but not reads (or using two different locks) leaves the race open.
- **Ignoring visibility.** Correctly serializing writes but reading the field with no synchronization can still return a stale value; the reader needs a *happens-before* edge (via the same lock, or an atomic/`volatile`-style guarantee).
- **Check-then-act / TOCTOU left non-atomic.** Any gap between validating state and using it is exploitable/buggy — collapse it into one atomic operation (`putIfAbsent`, `create-exclusive`, `SELECT ... FOR UPDATE` / compare-and-set) instead of check-then-act.
- **Over-broad locking that reintroduces bugs elsewhere.** Holding one lock while acquiring another, in inconsistent order across threads, converts a race into a **deadlock**. Fix the race without a lock-ordering hazard.
- **Trusting "it passed my tests."** Races are timing-dependent and often hide under a debugger or light load; passing tests is not evidence of correctness. Reason about the interleaving, or use a race detector (ThreadSanitizer, Go `-race`).

## Implementation Notes

Reference patterns — reconstruct these from the principle, do not memorize verbatim:

```java
// WRONG: read-modify-write is not atomic; two threads lose updates
count = count + 1;

// Fix A — lock the whole composite (critical section)
synchronized (lock) { count = count + 1; }

// Fix B — hardware atomic, lock-free
atomicCount.incrementAndGet();

// Fix C — collapse check-then-act into one atomic operation
map.putIfAbsent(key, value);   // not: if (!contains) put
```

```text
// Compare-and-swap retry loop (the core of most lock-free code)
do {
    old = atomic.load();
    new = f(old);
} while (!atomic.compareAndSwap(old, new));  // retries if another thread won
```

Note: Python's [GIL](_meta/glossary.md#gil) serializes bytecode but does *not* make `x += 1` atomic (it spans multiple bytecodes) — you still need a `Lock`. The database-layer analogue of this whole card is the [lost update](_meta/glossary.md#lost-update) anomaly, fixed by [pessimistic locking](_meta/glossary.md#pessimistic-locking) (`SELECT ... FOR UPDATE`) or [optimistic concurrency control](_meta/glossary.md#optimistic-concurrency-control) (version compare-and-set).

## Resources

- Java Language Specification, Ch. 17 "Threads and Locks" (happens-before, data races) — https://docs.oracle.com/javase/specs/jls/se21/html/jls-17.html
- Go Memory Model (data race definition, happens-before) — https://go.dev/ref/mem
- OWASP — Time-of-check to time-of-use (TOCTOU) — https://owasp.org/www-community/vulnerabilities/Time_of_check_to_time_of_use
- Herlihy & Shavit, *The Art of Multiprocessor Programming* (atomics, CAS, lock-free) — https://dl.acm.org/doi/book/10.5555/2385452

## Related

- [[mutex-vs-semaphore]]
- [[deadlock]]
- [[optimistic-vs-pessimistic-locking]]
- [[lost-update]]
- [[memory-model-happens-before]]
