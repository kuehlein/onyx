---
id: deadlock
type: flashcard
tags:
  - concurrency
  - databases
tiers:
  concurrency: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Deadlock

A deadlock is a state where a set of threads (or transactions) each hold a resource the next one needs, so none can ever proceed — a circular wait with no external intervention. The key mental model is the **four Coffman conditions**: a deadlock is possible **only if all four hold simultaneously**, so every prevention technique works by making at least one of them impossible. This is the generative principle — you reconstruct the whole toolbox from "which condition am I breaking?"

> [!tip] Recognition
> Reach for deadlock reasoning when: multiple threads/transactions each **acquire more than one lock**, the code shows **nested `lock` blocks** or a transaction touching **several rows/tables**, symptoms are a **hang with no CPU usage** (everyone blocked, not spinning), or a DB throws a **"deadlock detected, transaction rolled back"** error. Two agents grabbing the same two resources in **opposite orders** is the canonical smell.

## Key Properties

A deadlock requires **all four Coffman conditions at once**; remove any one and deadlock becomes impossible:

1. **Mutual exclusion** — a resource is held exclusively (only one holder at a time).
2. **Hold-and-wait** — a party holds one resource while blocking to acquire another.
3. **No preemption** — a resource can't be forcibly taken; only the holder releases it voluntarily.
4. **Circular wait** — a cycle exists: A waits on B, B waits on C, … waits back on A.

Because the conditions are conjunctive (all-or-nothing), the four also *are* the map of prevention strategies — each technique in Trade-offs targets exactly one.

## When to Use

This is a hazard to **prevent/handle**, not a tool to reach for — "when to use" = when to apply each countermeasure.

**Signals you must design against deadlock:**
- A code path acquires **two or more locks/mutexes**, especially nested.
- A transaction updates **multiple rows or tables** under [pessimistic locking](_meta/glossary.md#pessimistic-locking) (`SELECT ... FOR UPDATE`).
- Different call sites can lock the **same resources in different orders**.

**Pick a countermeasure by cost:**
- **Global lock ordering** (break circular wait) → default choice inside one process; free at runtime, needs discipline.
- **Acquire-all-or-none** (break hold-and-wait) → when you know the full lock set up front; hurts concurrency.
- **Timeout / try-lock then back off** (break no-preemption) → distributed or cross-service locks where a global order is impractical.
- **Detection + abort a victim** (break circular wait after the fact) → what **databases do**; right when locks are dynamic and prevention is infeasible.

**Do not** try to prevent deadlock by "just being careful" with ad-hoc ordering across a large codebase — enforce a single documented order or use detection.

## Trade-offs

Each strategy breaks one Coffman condition; the cost differs:

| Strategy | Breaks | Cost / when it fits |
|---|---|---|
| **Lock ordering** (always acquire in a fixed global order) | Circular wait | Cheap, no runtime overhead; requires knowing all locks and enforcing order everywhere |
| **Acquire-all-or-none** (grab whole lock set atomically, else release all) | Hold-and-wait | Must know the full set up front; lowers concurrency, can starve |
| **Timeout / try-lock + backoff** | No preemption | Simple, works across services; risks **livelock** and wasted retries; needs [jitter](_meta/glossary.md#jitter) |
| **Preemption / rollback a victim** | No preemption + circular wait | Powerful but needs safe rollback (transactions have it; raw threads usually don't) |
| **Detection (wait-for graph) + abort victim** | Circular wait (post-hoc) | Allows deadlocks then recovers; cost of cycle-detection + losing the victim's work; used by DBs |

**vs. locks / mutex / semaphore:** those cards are about the *primitive that provides mutual exclusion*; deadlock is the *failure mode that emerges when you hold more than one of them*. One lock alone can never deadlock (needs ≥2 resources + a cycle) — reach for the locks card to pick the right primitive, this card to reason about acquiring several safely.

**vs. race conditions / atomicity:** opposite symptoms. A race is a **correctness bug from too little synchronization** — threads interleave and produce a wrong-but-completed result (nondeterministic, silent). A deadlock is a **liveness bug from too much / mis-ordered synchronization** — locking is correct but everyone blocks and nothing completes (a visible hang). Distinguishing signal: race = *wrong answer, keeps running*; deadlock = *no answer, frozen*.

**vs. livelock:** in a deadlock, blocked parties are **stuck and idle** (no progress, no CPU). In **livelock**, parties keep **actively changing state in response to each other and still make no progress** (e.g. two people stepping the same way in a corridor). Naive "detect conflict → both back off and retry" can convert a deadlock into a livelock; fix with randomized backoff.

**vs. starvation:** deadlock = a **specific cyclic set is permanently blocked**. Starvation = **one party is repeatedly passed over** while the system as a whole keeps making progress (e.g. unfair scheduling or priority inversion). Deadlock stalls a group forever; starvation indefinitely delays an individual.

## Common Pitfalls

- **Inconsistent lock order** is the #1 cause: one path locks `A` then `B`, another locks `B` then `A`. Fix by a total order (e.g. by memory address, ID, or a documented hierarchy) applied everywhere.
- **Assuming timeouts alone "solve" it** — timeouts avoid a permanent hang but can produce livelock or a [retry storm](_meta/glossary.md#retry-storm); add randomized/[exponential backoff](_meta/glossary.md#exponential-backoff).
- **Deadlocking on a single reentrant path** — re-acquiring a non-reentrant lock you already hold (self-deadlock); use a reentrant lock or restructure.
- **Ignoring DB deadlock errors** — the database aborts the **victim** transaction and returns an error (Postgres `40P01`, MySQL/InnoDB `1213`); the app **must catch it and retry the whole transaction**, since the victim's work was rolled back.
- **Lock upgrades** (shared → exclusive on the same row by two transactions) are a classic hidden cycle even when column-level order looks fine.
- **Holding a lock across a slow/blocking call** (I/O, network, or another lock) widens the window and invites cycles — keep critical sections narrow.

## Implementation Notes

Detection uses a **wait-for graph**: nodes are transactions/threads, an edge T1 → T2 means "T1 waits for a resource held by T2." A **cycle in this graph is a deadlock**, found with cycle detection (a [DFS](_meta/glossary.md#dfs) looking for a back edge). On detecting a cycle the system **aborts a victim** (often the transaction with the least work done / fewest locks / cheapest to roll back), releasing its locks so the rest proceed; the victim retries.

```
# Enforce a global lock order to prevent circular wait
def transfer(a, b, amount):
    first, second = sorted((a, b), key=lambda acct: acct.id)  # fixed order
    with first.lock:
        with second.lock:
            a.balance -= amount
            b.balance += amount
```

Databases run a background deadlock detector (InnoDB does automatic detection and rollback; it can be disabled in favor of `innodb_lock_wait_timeout`). Postgres detects after `deadlock_timeout` and cancels one transaction.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 7 (Transactions — two-phase locking & deadlocks)
- PostgreSQL docs — Explicit Locking / Deadlocks: https://www.postgresql.org/docs/current/explicit-locking.html#LOCKING-DEADLOCKS
- MySQL InnoDB deadlock detection: https://dev.mysql.com/doc/refman/8.0/en/innodb-deadlocks.html
- Coffman, Elphick, Shoshani (1971), *System Deadlocks*: https://dl.acm.org/doi/10.1145/356586.356588

## Related

- [[pessimistic-locking]]
- [[optimistic-concurrency-control]]
- [[mutex-vs-semaphore]]
- [[two-phase-commit]]
- [[database-transactions]]
