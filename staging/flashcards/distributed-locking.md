---
id: distributed-locking
type: flashcard
tags:
  - distributed-systems
  - locking
  - leases
  - fencing-tokens
  - redlock
tiers:
  distributed-systems: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Distributed Locking

A distributed lock lets independent processes agree that only one of them may act on a shared resource at a time. The hard part is that there is no shared memory and no reliable clock: the lock holder can be paused (GC, page fault, VM freeze) or partitioned away *after* it acquired the lock, so any lock granted for a fixed time — a **lease** — can silently expire while its holder still believes it holds it. The only robust fix is to stop trusting the lock in isolation and instead have every acquisition hand out a **fencing token** — a monotonically increasing number — that the *downstream resource* checks and uses to reject writes from a stale holder. Distributed locks are also frequently the wrong tool: for correctness you usually want [idempotency](_meta/glossary.md#idempotency) or a real [consensus](_meta/glossary.md#consensus) system (ZooKeeper/etcd), and for efficiency a best-effort lock is fine even if it occasionally fails.

> [!tip] Recognition
> Reach for this reasoning when you see: "only one worker should process this job/resource at a time," a lock with a **TTL / lease / auto-expiry**, "the lock expired but the job was still running," "two workers both held the lock," anything mentioning **Redlock** or "distributed lock on Redis," or "how do we make the lock safe under GC pauses / clock skew?" The interview tell is: *"we took a lock, so the write is safe"* — the correct instinct is to ask **"is there a fencing token, and does the resource enforce it?"**
>
> **vs. consensus:** consensus ([[consensus]]) is the general primitive for agreeing on one value/leader and it *is* how a correct lock service (ZooKeeper/etcd) is built; a "distributed lock" is one application of it. **vs. leader-election:** leader election is a long-lived "who is primary" decision (usually consensus-backed); a lock is typically a short-lived mutual-exclusion grant. Both need fencing to be safe.

## When to Use

**Problem signals that point to a distributed lock:**
- "Only one instance may run this cron / batch / migration / leader-only task at a time"
- "Serialize access to an external resource that has no locking of its own" (a file, a third-party API with no idempotency, a device)
- "Prevent duplicate work" — but note this is usually better solved by idempotency than by a lock

**First, classify the purpose (Kleppmann's key distinction):**
- **Efficiency lock** — avoiding *duplicate* work (e.g. don't compute the same thumbnail twice). A rare lock failure just wastes work; a simple lease-based lock (even single-instance Redis `SET NX PX`) is fine.
- **Correctness lock** — a failure *corrupts data or violates an invariant* (double-charge, double-write, two writers to one file). Here a bare lock is **not safe** — you need fencing tokens *and* a resource that enforces them, or a different design entirely.

**Prefer a distributed lock over alternatives when:**
- Over doing nothing: the resource genuinely cannot tolerate concurrent access and has no built-in serialization
- Over full consensus in your own code: when a managed lock service (ZooKeeper/etcd) already gives you a fenced, consensus-backed lock — use it, don't hand-roll

**Do not use a distributed lock when (prefer these):**
- The operation can be made **idempotent** → make writes safe to retry (unique keys, conditional writes, `INSERT ... ON CONFLICT`). Idempotency removes the need for mutual exclusion entirely and survives the pause problem for free.
- You need real correctness under failure → use a **consensus-backed** service (etcd/ZooKeeper) that also emits a fencing token, not a best-effort lock over a cache.
- The database can enforce the invariant directly → a unique constraint, `SELECT ... FOR UPDATE`, compare-and-set, or optimistic concurrency (version column) is simpler and safer than an external lock.
- You reach for it "for performance" on a hot path → a lock that requires a network round-trip (and a majority round-trip if it is safe) is a latency and availability cost; be sure it is warranted.

## Key Properties

- **A lease is a lock with a TTL.** Because a crashed holder can never release its lock, real distributed locks auto-expire after a lease time. This trades the deadlock-on-crash problem for the **early-expiry** problem: the lease can end while the holder is still working.
- **The process-pause hazard is unavoidable at the lock layer.** A holder can be stalled *after* acquiring — by a stop-the-world GC pause, page fault/swap, VM live-migration, or `SIGSTOP` — for longer than the lease. On resuming it still "thinks" it holds the lock while another client has already acquired it. No timeout tuning removes this; you can only make it rarer.
- **Clock skew breaks lease reasoning.** Lease safety depends on comparing elapsed time across machines; if clocks drift or jump (NTP step, VM pause), a lease can expire earlier or later than either side believes. Kleppmann's argument: an algorithm's *safety* must not rest on bounded clock error.
- **Fencing tokens are the actual safeguard.** Every lock acquisition returns a strictly increasing integer. The client sends that token with each write; the **storage/resource remembers the highest token it has seen and rejects any lower one**. A paused old holder resumes with a *stale* (smaller) token and its writes are refused. This makes the lock *service* safe even though individual holders can be wrong.
- **Fencing only works if the protected resource enforces it.** A token the downstream system ignores buys nothing. This is why fencing composes naturally with consensus-backed systems (which can issue monotonic tokens: ZooKeeper's `zxid` or a sequential znode's sequence number, etcd's `revision`, a Raft term) and poorly with a plain external resource that has no notion of a token.
- **Mutual exclusion is a safety property, not a liveness one.** "At most one holder" (safety) is the invariant you must never violate; "someone eventually gets the lock" (liveness) is desirable but secondary. Sacrifice liveness (block/abort) to preserve safety, never the reverse.

## Common Pitfalls

- **Trusting the lock without a fencing token.** The canonical failure: client 1 acquires, pauses (GC) past the lease, client 2 acquires, both then write. Without a monotonic token the storage cannot tell the stale writer from the current one. This is the heart of Kleppmann's Redlock critique.
- **Assuming a bigger TTL fixes it.** A longer lease makes early expiry rarer but slows recovery when a holder truly dies, and *still* cannot bound an arbitrarily long pause. It is a probability knob, not a correctness fix.
- **Releasing a lock you no longer own.** A naive `DEL lockkey` on release can delete a *different* client's lock that was acquired after your lease expired. Correct release must be conditional: store a unique owner value at acquire and delete only if it still matches (Lua compare-and-delete). Even then, this guards release, not the pause hazard.
- **Relying on wall-clock time for lease math.** Use a monotonic clock for elapsed-time checks; NTP steps and VM pauses make wall-clock differences meaningless and can make a lease look valid when it is not.
- **Treating "a majority granted the lock" as "the write is safe."** Redlock's majority acquisition still has no fencing token, so it does not protect a correctness-critical write against the pause problem.
- **Using a distributed lock where idempotency would do.** Most "prevent duplicate processing" needs are better met by idempotent writes/dedup keys; the lock adds a failure mode (early expiry) that idempotency does not have.

## Trade-offs

**Choosing the lock mechanism:**

| Approach | Safe for *correctness*? | Notes |
|---|---|---|
| Single-instance Redis `SET NX PX` + Lua release | No (no fencing; single point of failure) | Fine as a best-effort **efficiency** lock; simplest option |
| **Redlock** (N independent Redis, majority) | No — improves *availability*, not correctness | Still lacks fencing tokens; safety depends on bounded clock/pause (the disputed assumption) |
| **ZooKeeper** ephemeral sequential znode | Yes, with fencing | Session-based auto-release on disconnect; `zxid`/version is a natural monotonic fence |
| **etcd** lease + key | Yes, with fencing | `revision` is a natural monotonic fence; consensus-backed (Raft) |
| **Database** unique key / `FOR UPDATE` / CAS | Yes (within the DB) | Often the simplest correct answer; no extra system to run |

**The Redlock controversy (fair, high level):**
- **Kleppmann (2016):** Redlock is unsafe for correctness-critical use. Two lines of attack: (1) it provides **no fencing token**, so it cannot stop a stale holder's write after a pause; (2) its safety leans on **timing assumptions** (bounded clock drift and bounded pauses), which do not hold in real systems — so it is neither a good efficiency lock (too heavy) nor a good correctness lock (unsafe).
- **Antirez (creator of Redis), rebuttal:** Redlock's timing model is reasonable in practice and no worse than the assumptions other systems make; and if you truly need to survive a violation of mutual exclusion, a lock alone was never going to save you regardless of implementation.
- **The durable, non-partisan takeaways:** for a *correctness* lock, do not rely on any timing-based lock alone — add fencing tokens enforced by the resource, or use a consensus system that supplies them; for an *efficiency* lock, a simple lease-based lock is perfectly acceptable. The disagreement is mainly about which timing assumptions are acceptable, not about whether fencing is the right safeguard.

## Implementation Notes

**Fencing pattern (the thing to reconstruct in an interview):**
```text
token = lockService.acquire(resource)     # strictly increasing per acquisition
...do work...
storage.write(data, fencing=token)        # resource enforces the check:
    # if token < storage.max_token_seen: REJECT   <-- stale holder blocked
    # else: apply write, storage.max_token_seen = token
```
- The token source must be monotonic *across acquisitions*: ZooKeeper's `zxid` or a sequential znode's sequence number (Kleppmann suggests `zxid` or the znode `version`), etcd's `revision`, or a Raft term/index. Redis has no such construct out of the box, which is why fencing is awkward there.

**Best-effort Redis lock (efficiency only — never rely on it for correctness):**
```text
SET lock:<res> <random-uuid> NX PX 30000     # acquire iff absent, 30s lease
# release must be conditional so you never delete another owner's lock:
EVAL "if redis.call('get',KEYS[1])==ARGV[1]
      then return redis.call('del',KEYS[1]) else return 0 end" 1 lock:<res> <uuid>
```

**ZooKeeper recipe:** create an **ephemeral sequential** znode under a lock parent; you hold the lock if you have the lowest sequence number, else watch the next-lowest znode. Ephemeral means the lock auto-releases when your session dies, avoiding stuck locks; the sequence number doubles as a fencing token.

## Variants

- **Best-effort lease lock** — single-node Redis/DB row with TTL; efficiency only.
- **Redlock** — N independent Redis masters, acquire on a majority within the lease; adds fault tolerance but not fencing.
- **Consensus-backed lock** — ZooKeeper (ephemeral sequential znodes) or etcd (lease + revision); safe, auto-releasing, natively fenced.
- **Database lock** — advisory locks (`pg_advisory_lock`), `SELECT ... FOR UPDATE`, or a unique-constraint / CAS pattern that avoids an explicit lock entirely.

## Resources

- Kleppmann, *How to do distributed locking* (2016) — the fencing-token argument and the pause/clock critique: https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html
- antirez, *Is Redlock safe?* — the rebuttal: http://antirez.com/news/101
- Redis docs, *Distributed Locks with Redis* (Redlock spec): https://redis.io/docs/latest/develop/clients/patterns/distributed-locks/
- Kleppmann, *Designing Data-Intensive Applications*, Ch. 8 (The Truth Is Defined by the Majority — fencing tokens) & Ch. 9

## Related

- [[consensus]]
- [[leader-election]]
- [[zookeeper]]
- [[idempotency]]
- [[linearizability]]
- [[clock-synchronization]]
