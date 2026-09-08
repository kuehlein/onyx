---
id: retries-and-timeouts
type: flashcard
tags:
  - backend
  - reliability
tiers:
  backend: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Retries and Timeouts

Every remote call can hang or fail, so a resilient client bounds each call with a **timeout** and recovers from *transient* failures with **retries**. The catch: naive retries turn a small blip into a self-amplifying outage (retry storm), and any retry can duplicate a side effect. The disciplined form is timeout + capped exponential backoff + jitter + a retry budget, applied at **one** layer of the stack, and only for operations that are **idempotent**. The governing principle: a retry trades one failure mode (a lost call) for another (extra load + duplicate effects), so it is only correct when the extra load is bounded and the duplicate is harmless.

> [!tip] Recognition — reach for this when you hear
> - "The call to service X sometimes **hangs forever** / no timeout is set" — every remote call needs a deadline
> - "A small downstream blip caused a **cascading / cascading-failure outage**" or "the dependency recovered but our fleet stayed down" — retry storm / metastable failure
> - "We **retry at every layer**" (client → gateway → service → DB) — multiplicative retry amplification
> - "Retrying the payment **charged the customer twice**" — retry without idempotency
> - "All clients retried **at the same instant** and hammered the recovering service" — missing jitter
> - Design-interview cues: "make this dependency call resilient," "handle a flaky/slow downstream," "at-least-once delivery"

## When to Use

**Problem signals that suggest timeouts + backoff retries:**
- Any call over a network — RPC/HTTP, DB query, cache, queue. If it leaves the process, it needs a timeout.
- The downstream is *usually* healthy but occasionally throws **transient** errors: connection reset, [TCP](_meta/glossary.md#tcp) timeout, 503, throttling (429).
- You need **at-least-once** delivery and can tolerate (or dedupe) duplicates.

**Prefer bounded retries with backoff over alternatives when:**
- Over retrying immediately in a tight loop: backoff + jitter prevents synchronized retry spikes that DDoS your own dependency.
- Over failing fast with no retry: when the fault is genuinely transient, one or two retries recover the request cheaply and hide the blip from the user.
- Over infinite retries: a retry budget / max-attempts cap turns "retry until success" (which never ends during an outage) into bounded, sheddable load.

**Do not retry when:**
- The error is a **client error (4xx)** — 400/401/403/404/422. It will *never* succeed on retry; retrying just wastes capacity. (429 is the exception — it is transient throttling.)
- The operation is **not idempotent** and you have no idempotency key — a retried non-idempotent write can double-charge, double-ship, or double-increment.
- The caller's **deadline has already passed** — retrying work the client no longer waits for is pure waste (see deadline propagation below).

## Key Properties

**Timeouts — every remote call needs one.**
- A missing timeout means a hung dependency exhausts your connection/thread pool and the hang propagates upward — one slow dependency stalls the whole service.
- Set the timeout from the downstream's **latency distribution**, not a guess: AWS picks an acceptable false-timeout rate (e.g. 0.1%) and uses the corresponding high percentile ([P99](_meta/glossary.md#p99) / p99.9) as the timeout. Too tight → false timeouts + needless retries (brownout); too loose → slow failure detection.
- Distinguish **connection timeout** (TCP/[TLS](_meta/glossary.md#tls) handshake — should be short) from **request/read timeout** (end-to-end response — sized from latency percentiles).

**Retryable vs. non-retryable errors.**

| Class | Example | Retry? |
|---|---|---|
| Transient network | connection reset, read timeout | Yes (with backoff) |
| Overload / throttle | HTTP 429, 503, `ThrottlingException` | Yes — longer backoff |
| Server error | HTTP 500, 502, 504 | Usually (verify idempotency) |
| Client error | HTTP 400/401/403/404/422 | **No** — never succeeds |
| Business rejection | insufficient funds, validation fail | **No** — deterministic |

**Backoff + jitter (the Marc Brooker / AWS formulas).**
- **Capped exponential backoff:** `sleep = min(cap, base * 2^attempt)` — spreads retries out and bounds the max wait.
- **Full jitter:** `sleep = random_between(0, min(cap, base * 2^attempt))` — the AWS-recommended default. Randomizing across the *whole* window de-synchronizes clients; the simulation showed Full Jitter minimizes both total client calls and server contention.
- Without jitter, N clients that failed together retry together — a synchronized **thundering herd** that re-overloads the recovering service.

**Retry budget (caps amplification).**
- **Token bucket (AWS SDK, built in since 2016):** each retry spends a token; success refills. When the bucket empties, stop retrying and fail fast — this locally rate-limits retries.
- **Server-wide budget (Google SRE):** allow retries only up to a small percentage of normal traffic (SRE's example: ~60 retries/min per process, or retries capped at ~10% of requests). Beyond that, don't retry.

**Retry amplification is multiplicative.** If a request fans out through layers that *each* retry, attempts multiply, not add. Google SRE's example: 4 layers each retrying to 4 attempts → 4×4×4 = **64** attempts hitting the leaf — precisely when the leaf is least able to serve them. **Retry at exactly one layer** (usually the client / highest layer that can meaningfully recover); lower layers should fail fast and surface the error.

## Common Pitfalls

- **No timeout at all.** The single most common failure: a call with no deadline hangs, pools exhaust, and the stall cascades upward into a full outage.
- **Retrying at every layer.** Client, gateway, service, and DB each "helpfully" retrying produces multiplicative load exactly during an incident. Pick one layer.
- **Retrying without jitter.** Plain exponential backoff still synchronizes: everyone who failed at T retries at T+base together. Jitter is not optional.
- **Retrying non-idempotent writes.** A `POST /charge` that times out *may have succeeded*; a blind retry double-charges. See idempotency below.
- **Retrying 4xx.** Burning attempts on a 400/404 that can never succeed — wasted capacity and slower failure.
- **Unbounded retries → metastable failure.** With no budget, retries during an outage keep the system pinned in overload even after the trigger clears (a metastable / retry-storm death spiral). The budget is what lets it drain.
- **Ignoring the deadline.** A retry that runs after the client's overall deadline has expired does work no one is waiting for. Propagate and check the remaining deadline before each attempt.
- **Retry backoff longer than the caller's timeout.** If `base * 2^attempt` exceeds the upstream deadline, the retry can never land in time — cap it below the budget.

## Trade-offs

- **Resilience vs. amplification.** Retries hide transient faults from users, but every retry is extra load on an already-struggling dependency. The retry budget is the knob that keeps recovery from becoming a self-inflicted DDoS.
- **Availability vs. duplicates.** Retrying gives at-least-once delivery (don't lose the request) at the cost of possible duplicates — acceptable only if the effect is idempotent or deduped.
- **Tight vs. loose timeouts.** Tight timeouts detect failure fast but cause false positives + retry load under normal jitter; loose timeouts tie up resources during real hangs. Derive from percentiles, don't guess.
- **Retry vs. circuit breaker.** Retries assume the fault is *transient*; when a dependency is *hard down*, retrying just wastes work. A circuit breaker complements retries: it stops calling a failing dependency entirely so you fail fast and let it recover (see Variants).
- **Client-side vs. server-side control.** Client backoff is cooperative and can be ignored by misbehaving clients; the server must *also* self-protect with load shedding and a clear "I'm overloaded" signal (429/503) so well-behaved clients back off.

## Implementation Notes

**Idempotency — the precondition for safe retries.**

A retry is only correct if repeating the operation is harmless. Reads and pure computations are naturally idempotent. Mutations are not — you make them idempotent with an **idempotency key**:

```
POST /charge
Idempotency-Key: 7c9e6679-...   # client-generated UUID, stable across retries

# Server:
#  1. look up key in a dedupe store (TTL, e.g. 24h)
#  2. if seen  -> return the STORED original response (no re-charge)
#  3. if new   -> execute, persist (key -> result) atomically, return result
```

The client uses the *same* key on every retry of the *same logical operation*, so at-least-once delivery + idempotent effect = duplicate-safe. Without this, a response lost after the server committed leads the client to retry and double-apply.

**Retry loop (capped exponential backoff + full jitter + budget):**

```python
def call_with_retry(op, budget, max_attempts=3, base=0.05, cap=2.0, deadline=None):
    for attempt in range(max_attempts):
        try:
            return op(timeout=remaining(deadline))     # ALWAYS pass a timeout
        except Error as e:
            if not is_retryable(e):        # 4xx / business errors -> raise now
                raise
            if attempt == max_attempts - 1 or not budget.try_spend():
                raise                       # out of attempts or out of budget
            expo  = min(cap, base * (2 ** attempt))
            sleep = random.uniform(0, expo)             # FULL JITTER
            if deadline and now() + sleep > deadline:
                raise                       # backoff would blow the deadline
            time.sleep(sleep)
```

**Deadline propagation (Google SRE).** Pass a *deadline*, not a fixed per-call timeout, down the RPC chain. If the top set 30s and 7s is already spent, the next hop gets 23s. Each hop shortens the budget so nobody works on requests the caller has already abandoned.

**Which layer retries.** Retry at the client / highest layer that can pick a different backend; make intermediate hops fail fast. This keeps attempts additive, not multiplicative.

## Variants

- **Circuit breaker.** A state machine wrapping a dependency: **Closed** (calls pass; count failures) → trips to **Open** when failures cross a threshold (e.g. 50% error rate) → after a cooldown moves to **Half-Open**, allowing a few probe calls → success closes it, failure re-opens. In Open state calls fail instantly, protecting a down dependency from retry pressure and giving it room to recover. (Nygard / Fowler.)
- **Jitter strategies.** *Full jitter* `random(0, min(cap, base·2^n))` is the default; *equal jitter* keeps half the backoff fixed to avoid near-zero sleeps; *decorrelated jitter* `min(cap, random(base, prev·3))` is a common AWS alternative.
- **Load shedding / brownout.** The server-side counterpart: under overload, shed low-priority work and return 429/503 so clients back off — protects the server when client cooperation isn't enough.
- **Kafka delivery semantics.** *At-least-once* (default: `acks=all`) can duplicate on producer retry; the **idempotent producer** (`enable.idempotence=true`, on by default since Kafka 3.0) dedupes retries per partition via a producer ID + sequence number; **transactions** extend that to atomic exactly-once across partitions for read-process-write pipelines. "Exactly-once" here is dedup on top of at-least-once, not magic.

## Resources

- AWS Builders' Library — Timeouts, retries, and backoff with jitter: https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/
- Marc Brooker — Exponential Backoff And Jitter (the Full Jitter simulation): https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
- Google SRE Book — Addressing Cascading Failures (retry budgets, amplification, deadlines): https://sre.google/sre-book/addressing-cascading-failures/
- Martin Fowler — CircuitBreaker: https://martinfowler.com/bliki/CircuitBreaker.html

## Related

- [[circuit-breaker]]
- [[idempotency]]
- [[rate-limiting]]
- [[load-balancing]]
- [[cascading-failures]]
- [[message-queue]]
