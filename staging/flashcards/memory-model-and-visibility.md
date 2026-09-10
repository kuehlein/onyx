---
id: memory-model-and-visibility
type: flashcard
tags:
  - concurrency
  - memory-model
  - happens-before
  - atomics
  - visibility
tiers:
  concurrency: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Memory Models & Visibility

A memory model is the contract between a programmer and the (language + compiler + CPU) about *when a write performed by one thread becomes observable to a read on another thread*. The naive mental model — "threads read and write one shared main memory in program order" — is false: compilers reorder instructions and CPU cores keep values in registers and per-core store buffers/caches, so a value one thread wrote may be invisible to another thread indefinitely, and operations may *appear* to happen in a different order to different observers. The model defines a **happens-before** partial order over memory operations; a read is only *guaranteed* to see a write if that write happens-before the read. Anything a thread does with shared mutable state that is **not** ordered by happens-before is unsafe — the correct fix is establishing that ordering (a lock, a `volatile`/atomic access, thread start/join, etc.), not adding sleeps or hoping. This is why "it worked on my machine" concurrency bugs exist: the code is *technically* undefined/unordered but happened to observe a convenient interleaving.

> [!tip] Recognition
> Reach for memory-model reasoning when you see: a flag one thread sets that another thread's loop **never notices** (spins forever), a "double-checked locking" or lazy-init that occasionally returns a half-constructed object, `volatile`/`atomic`/`memory_order`/`AtomicInteger`/`std::atomic` in the code, "why do I need a memory barrier / fence here?", "this works in debug but breaks under `-O2`", or reasoning about what one thread can *see* of another's writes without a lock. If the question is "is this read allowed to return a stale value?" it is a memory-model question.
>
> **vs. race conditions / mutual exclusion:** a *data race* (two unsynchronized conflicting accesses, ≥1 a write) is a memory-model / visibility bug and is **undefined behavior** in C/C++ (and unspecified-but-not-UB in Java). A *race condition* is a higher-level logic bug about interleaving that can exist even in fully synchronized code. Atomics/`volatile` fix **visibility and ordering**; they do **not** by themselves provide mutual exclusion over a multi-step critical section — that still needs a lock.

## When to Use

**Problem signals that this is a memory-model / visibility issue:**
- A worker thread loops on a shared `boolean running` / `stop` flag and **never sees** the value another thread set — the compiler hoisted the read into a register (fix: make it atomic/`volatile`).
- Lazy initialization / singletons where a reader occasionally sees a **non-null but partially initialized** object (classic broken double-checked locking; the *publication* of the object was not ordered before the reference write).
- "Do I need a `volatile`, an atomic, or a full lock here?" — deciding the minimum synchronization that establishes the required happens-before edge.
- Code that behaves differently across optimization levels, compilers, or CPU architectures (x86 is strongly-ordered and hides many bugs that surface on ARM/POWER's weaker ordering).
- Implementing a lock-free structure or a one-time "publish this data, then set a ready flag" handoff between threads.

**Prefer the minimal ordering primitive when:**
- Over a mutex: when you only need **visibility/ordering of a single variable** (a status flag, a published pointer), an atomic/`volatile` acquire-release is far cheaper than a lock.
- Over `seq_cst`/full barriers: when a producer/consumer handoff only needs **release on the store, acquire on the load**, use acquire-release — it is cheaper than sequential consistency on weakly-ordered CPUs.

**Do NOT rely on atomics/`volatile` when:**
- You need an **atomic read-modify-write** or a multi-step invariant (`if (x) { ...use x... }`, `count++`) → that is a race condition; use a lock or a genuine atomic RMW (CAS/`fetch_add`), not a bare volatile read then write.
- You are tempted to "fix" a visibility bug with `sleep()`, extra logging, or a redundant read → these accidentally perturb timing; they do not create a happens-before edge and the bug remains.

## Key Properties

- **Happens-before is a partial order, not a timeline.** If A happens-before B, then A's effects are visible to B *and* A is ordered before B. Unordered operations may be seen in different orders by different threads. It composes transitively (A→B, B→C ⇒ A→C) and includes **program order within a single thread**.
- **Edges that establish happens-before** (the ones you actually use): unlock of a monitor → subsequent lock of the same monitor; a `volatile`/atomic-release **write → a subsequent read** of that same variable; `Thread.start()` → the first action of the started thread; a thread's last action → another thread's return from `join()` on it; writes to a `final` field in a constructor → their visibility to any thread that reads the object through a reference published *after* the constructor returns, i.e. the reference must not escape mid-construction (Java).
- **Data race, precisely:** two accesses to the same location, from different threads, **at least one a write**, **not ordered by happens-before**. In C/C++ a data race is **undefined behavior** (the whole program is meaningless, not just "returns a garbage value"). In Java it is not UB but yields no visibility/ordering guarantees.
- **Atomics/`volatile` give visibility + ordering, not exclusion.** A `volatile`/atomic access is itself indivisible and creates ordering edges, but a *sequence* of them (read-then-write) is not one atomic step. Mutual exclusion over a critical section needs a lock or a single atomic RMW.
- **Sequential consistency (SC)** = all threads observe **one single global total order** of operations consistent with each thread's program order. It is the intuitive model but is *not* what hardware/compilers give you by default — you get it only by using enough synchronization.
- **The DRF-SC guarantee:** a program with **no data races** ("correctly synchronized") is guaranteed to behave sequentially consistently. This is the whole point — synchronize enough to be race-free and you may reason as if SC holds.
- **A memory barrier/fence** constrains reordering of memory operations across it (compiler *and* CPU). Acquire/release semantics on atomics are the portable, per-variable way to get the barriers you need without hand-placing architecture-specific fence instructions.

## Common Pitfalls

- **Assuming a normal write is eventually visible.** Without an ordering edge, a spin on a non-atomic flag can loop **forever** because the compiler legally caches the read in a register. The bug is not timing; it is the missing happens-before.
- **Broken double-checked locking without atomics.** `if (inst == null) { lock; if (inst == null) inst = new T(); }` is broken if `inst` is not `volatile`/atomic: the store publishing the reference can be **reordered before** the object's fields are initialized, so another thread sees a non-null but half-built object. Fix: make the field `volatile` (Java 5+) / use acquire-release.
- **Thinking `volatile` gives atomicity.** `volatileCounter++` is still a race (read, add, write — three steps). `volatile` guarantees visibility/ordering of each single access, not that a compound op is indivisible. Use an atomic RMW.
- **Confusing C's/C++'s `volatile` with a threading tool.** In C/C++ `volatile` is for memory-mapped I/O / signals; it does **not** establish inter-thread happens-before or prevent data races. Use `std::atomic`. (Java's `volatile` *is* a threading construct — do not carry the intuition across languages.)
- **Testing on x86 and shipping to ARM.** x86 has a strong memory model (TSO) that masks many missing-barrier bugs; the same code can fail on weakly-ordered ARM/POWER. Absence of failure on one architecture is not correctness.
- **"Adding a print/sleep fixed it."** It only changed timing; the data race is still UB. It will resurface under load or a new compiler.

## Trade-offs

**Memory-ordering strength (weakest → strongest), the central lock-free dial:**

| Ordering | Guarantee | Cost | Use for |
|---|---|---|---|
| **Relaxed** (`memory_order_relaxed`) | Atomicity only; **no** cross-variable ordering | Cheapest | Independent counters/stats where only the final total matters |
| **Acquire / Release** | Release store → acquire load of the *same* var creates a one-way barrier; the acquirer sees everything the releaser did *before* the store | Moderate; cheap on x86 | Producer/consumer handoff, publishing a pointer + ready flag, most lock-free code |
| **Sequentially consistent** (`seq_cst`, Java default for `volatile`/atomics) | Single global total order over all such ops | Most expensive (full fences on weak CPUs) | When you need all threads to agree on one order (e.g. Dekker-style flags) |

- **Correctness vs. performance.** Stronger ordering is easier to reason about but forces more fences and inhibits compiler/CPU optimization. Weaker ordering is faster but each relaxation must be *proven* safe — a common source of subtle, rare, architecture-dependent bugs.
- **Atomics/`volatile` vs. a lock.** A lock is simpler and covers multi-step invariants but has contention and blocking cost; a single atomic is cheaper and non-blocking but only covers one variable's visibility/ordering. Reach for the lock unless the hot path demands lock-free.
- **`seq_cst` everywhere vs. tuned orderings.** Defaulting to `seq_cst` (as Java `volatile` does) trades some performance for large gains in reasoning safety — usually the right default; hand-tuned relaxed/acq-rel is an expert optimization to justify with benchmarks.

## Implementation Notes

Canonical safe publication — one thread fills data, then flips a flag; the reader that sees the flag is guaranteed (via release→acquire happens-before) to see the data:

```cpp
// Producer
data = 42;                                  // 1: ordinary write
ready.store(true, std::memory_order_release); // 2: release publishes (1)

// Consumer
while (!ready.load(std::memory_order_acquire)) {} // 3: acquire
assert(data == 42);                          // guaranteed: 1 happens-before 3
```

```java
// Java: 'volatile' write is a release, 'volatile' read is an acquire (seq_cst-strength).
volatile boolean ready;   // making ONLY this volatile publishes 'data' safely
int data;
// producer: data = 42; ready = true;
// consumer: while (!ready) {}  ->  data == 42 is guaranteed
```

- Do not memorize barrier instructions per architecture — express intent with acquire/release/seq_cst atomics and let the compiler emit the right fences.
- Java `final` fields have a special rule: values assigned in the constructor are visible to any thread that reads the object through a properly published reference, without extra synchronization.

## Variants

- **Hardware memory models:** x86-TSO (strong; only store→load reordering) vs. ARM/POWER (weak; needs explicit barriers). The language memory model abstracts over these.
- **Language memory models:** Java (JSR-133, since Java 5), C11/C++11 (`std::atomic` + `memory_order`), Go (`sync/atomic` + the Go memory model), Rust (`std::sync::atomic`, C++-derived orderings). All share the happens-before / DRF-SC foundation.
- **Fences vs. per-variable ordering:** `std::atomic_thread_fence` places a standalone barrier; per-operation `memory_order` tags are usually preferred and clearer.

## Resources

- JSR-133 (Java Memory Model) FAQ — https://www.cs.umd.edu/~pugh/java/memoryModel/jsr-133-faq.html
- cppreference — `std::memory_order` (acquire/release/relaxed/seq_cst semantics) — https://en.cppreference.com/w/cpp/atomic/memory_order
- The Go Memory Model — https://go.dev/ref/mem
- Preshing, "An Introduction to Lock-Free Programming" (acquire/release, barriers) — https://preshing.com/20120612/an-introduction-to-lock-free-programming/

## Related

- [[mutual-exclusion-and-locks]]
- [[race-conditions]]
- [[atomic-operations]]
- [[linearizability]]
- [[false-sharing-and-cache-coherence]]
