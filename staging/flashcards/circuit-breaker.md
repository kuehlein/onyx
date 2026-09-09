---
id: circuit-breaker
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

# Circuit Breaker

A circuit breaker wraps calls to a remote dependency in a state machine that trips OPEN after a failure threshold is crossed, then fails fast (returning an error or fallback immediately) instead of letting every caller block on a timeout. The principle: a slow or dead dependency is more dangerous than an absent one — blocked callers pile up, drain thread and [connection pools](_meta/glossary.md#connection-pooling), and take down the caller too. The breaker converts a *slow failure* (timeout per request) into a *fast failure* (immediate reject), which frees resources and gives the sick dependency room to recover. Its partner, the **[bulkhead](_meta/glossary.md#bulkhead)**, caps how many resources any one dependency can consume in the first place, so a failure is contained before the breaker ever needs to trip.

> [!tip] Recognition — reach for a circuit breaker when you hear
> - "One slow downstream service caused a cascading outage / took the whole cluster down"
> - "Threads / connection pool got exhausted waiting on a dependency that was already dead"
> - "We keep hammering a service that's clearly down — retries made it worse ([retry storm](_meta/glossary.md#retry-storm))"
> - "We need to fail fast and serve a degraded/fallback response instead of timing out"
> - Any **synchronous call across a network boundary** to a dependency that can be slow or unavailable ([gRPC](_meta/glossary.md#grpc)/HTTP to another service, a flaky third-party API, a database under load)

## When to Use

**Problem signals that suggest a circuit breaker:**
- A remote call can hang: the failure mode you fear is *latency*, not just errors. Every blocked caller holds a thread + socket for the full timeout.
- [Cascading failure](_meta/glossary.md#cascading-failure) / correlated: "service B slowed down and callers A, C, D all fell over behind it." Classic [SPOF](_meta/glossary.md#spof) amplification through shared pools.
- Retries are making an outage worse — a retry storm keeps a struggling service pinned. A breaker is the governor that stops the herd.
- You have a meaningful **fallback**: cached/stale data, a default, a queued write, or a fast "try later" error that's better than a 30s hang.

**Prefer a circuit breaker over alternatives when:**
- Over a plain **timeout**: a timeout bounds *one* call; it does nothing about the 10,000 callers all timing out at once. The breaker adds memory across calls and stops sending doomed requests. (You still need the timeout underneath — see Pitfalls.)
- Over **retry with backoff**: retries assume a *transient* blip. When a dependency is hard-down, retries add load. Breaker + retry compose: retry the blip, trip on the sustained failure.
- Over a **bulkhead alone**: a bulkhead limits concurrency but callers still wait for a permit and still hit a dead service. The breaker short-circuits so they don't even try.

**Do not use when:**
- The call is **local / in-process** with no network and no unbounded latency → nothing to protect against.
- You have **no acceptable fallback and the operation must complete** (e.g. the actual payment must go through) → a breaker just converts one failure into another; fix availability instead, or queue the work.
- **Low traffic**: rate-based breakers need volume to compute a meaningful rate. A handful of calls can trip on statistical noise, or never sample enough to trip at all (see `minimumNumberOfCalls`).

## Key Properties

**The three states (finite state machine):**

| State | Behavior | Exit condition |
|---|---|---|
| **CLOSED** | Normal — all calls pass; outcomes recorded in a sliding window | Failure rate ≥ threshold (over ≥ min calls) → **OPEN** |
| **OPEN** | Fail fast — reject immediately (no call made), throw / return fallback | Wait duration elapses → **HALF_OPEN** |
| **HALF_OPEN** | Probe — allow a limited number of trial calls through | Probes succeed → **CLOSED**; probes fail → back to **OPEN** |

- **Rate-based, not consecutive-count** (modern libraries). Resilience4j and Polly v8 trip on a **failure *rate*** over a sliding window (count- or time-based), guarded by a minimum sample size — not on N failures in a row. This is more robust to interleaved successes than the naive "5 consecutive failures" breaker.
- **The breaker is memory across calls.** Its whole value is that call #1001 benefits from what calls #1..#1000 observed. A per-request timeout has no memory.
- **Trip and recovery are asymmetric on purpose.** Tripping is aggressive (protect yourself fast); recovery is cautious (one/few probes, not a flood) so you don't re-overload a service that just came back.
- **Separation of concerns.** The breaker only decides *permit vs. reject*. It provides **neither retries nor fallbacks** itself — those are the caller's job (or a separate decorator). Composed order matters (see Implementation Notes).
- **Half-open is a limited gate,** not a floodgate. It admits a small, bounded number of probes and evaluates their outcome; excess calls during half-open are rejected.
- **vs. [rate limiting](_meta/glossary.md#rate-limiting):** both reject requests, but the trigger and direction differ. A breaker protects the *caller* from a *failing dependency* — it trips on observed **health** (failure/slow-call rate) and is reactive. A rate limiter protects the *callee* from *excess load* — it rejects on **volume** (requests per window) regardless of health, and is proactive/preventive. Health-based fast-fail vs. load-based admission control.

## Common Pitfalls

- **No timeout under the breaker.** A rate-based breaker measures failures; if calls *hang forever* they never resolve to failures and the rate never crosses the threshold — the breaker never trips. Always put a per-call **timeout** (and ideally slow-call detection) beneath it. This is the #1 real-world failure.
- **Retry *outside* the breaker.** If you wrap `retry(breaker(call))`, every retry that hits an OPEN breaker still consumes a retry attempt and can defeat the fast-fail. Put the breaker *outside* the retry so once it's OPEN, the whole retry chain is short-circuited. (Order: fallback → breaker → retry → timeout → call.)
- **One breaker for many dependencies.** A shared breaker means a failing dependency C trips the breaker and blocks healthy dependencies A and B. Use **one breaker per dependency** (per host/endpoint), and pair with per-dependency bulkheads.
- **`minimumNumberOfCalls` too high for the traffic.** Resilience4j defaults to 100. On a low-QPS endpoint the window never fills, so the breaker never evaluates and never trips. Tune to actual [QPS](_meta/glossary.md#qps).
- **Assuming OPEN → HALF_OPEN happens on a timer.** In Resilience4j the default (`automaticTransitionFromOpenToHalfOpenEnabled=false`) transitions to HALF_OPEN **only when the next call arrives** after the wait duration — no background thread flips it. If traffic stops entirely, the breaker sits OPEN until someone calls again.
- **Fallback that hides the outage / lies.** Returning cached data silently can mask a real incident or serve dangerously stale state. Emit metrics on breaker trips and fallback usage; alert on OPEN.
- **Ignoring "expected" failures.** A 404 or a validation 400 is *not* a dependency-health signal. Configure which exceptions/statuses count as failures (`recordExceptions` / `ignoreExceptions`), or a burst of legitimate 4xx will trip the breaker.

## Trade-offs

| Concern | Circuit breaker | Naive timeout only | Bulkhead only |
|---|---|---|---|
| Bounds single-call latency | Only if timeout added | Yes | No |
| Protects across many callers | **Yes** (shared memory) | No | Partially (caps concurrency) |
| Stops load on a dead service | **Yes** (fails fast) | No (keeps calling) | No (keeps calling up to limit) |
| Complexity / tuning burden | Higher (thresholds, windows) | Low | Medium |
| Risk of its own misfire | Trips on transient blip; masks partial availability | — | Rejects when pool full |

- **Availability vs. correctness of state:** an OPEN breaker will reject calls to a dependency that may have *partially* recovered (false negative) until the next probe. You trade a little availability for a lot of protection.
- **Fails fast, but fails.** The breaker doesn't make the dependency work — it makes *your* service survive the dependency being down. Without a fallback, the user still sees an error (just a fast one).
- **Tuning is workload-specific.** Threshold, window size/type, minimum calls, and wait duration all interact. Too sensitive → flaps and hurts availability; too lax → cascades before it trips.

## Implementation Notes

**Resilience4j (Java) — verified defaults:**

| Param | Default | Meaning |
|---|---|---|
| `failureRateThreshold` | 50 (%) | Trip when failures ≥ this % of the window |
| `slowCallRateThreshold` | 100 (%) | Count "slow" calls (over `slowCallDurationThreshold`) as failures |
| `slidingWindowType` | `COUNT_BASED` | vs. `TIME_BASED` (last N seconds) |
| `slidingWindowSize` | 100 | N calls (or N seconds) aggregated |
| `minimumNumberOfCalls` | 100 | Don't evaluate the rate until this many calls recorded |
| `waitDurationInOpenState` | 60000 ms | How long to stay OPEN before allowing a probe |
| `permittedNumberOfCallsInHalfOpenState` | 10 | Probe calls admitted in HALF_OPEN |
| `automaticTransitionFromOpenToHalfOpenEnabled` | false | If true, a thread flips OPEN→HALF_OPEN on a timer instead of on next call |

**Polly v8 (.NET) — verified defaults:** `FailureRatio = 0.1` (10%), `SamplingDuration = 30s`, `MinimumThroughput = 100`, `BreakDuration = 5s`. Polly adds an `Isolated` state (manual hold-open via `CircuitBreakerManualControl`) and uses a **single probe** in half-open.

**Correct composition order (outer → inner):**
```
Fallback( CircuitBreaker( Retry( Timeout( remoteCall ) ) ) )
```
- Timeout innermost: bounds each attempt so slow calls become recordable failures.
- Retry next: absorbs *transient* blips only.
- Breaker outside retry: once OPEN, the entire retry chain short-circuits — no wasted attempts.
- Fallback outermost: catches both `CallNotPermittedException` (OPEN) and exhausted retries, returning degraded output.

**Minimal state-machine sketch (the underlying rule, reconstructable):**
```text
onResult(success|failure):
  record outcome in sliding window
  if state == CLOSED and window.size >= minCalls
       and window.failureRate >= threshold:
    state = OPEN; openedAt = now
  if state == HALF_OPEN:
    if probe succeeded: successes++; if successes >= permitted: state = CLOSED (reset window)
    else: state = OPEN; openedAt = now   # one failed probe re-opens

onCallRequested():
  if state == OPEN:
    if now - openedAt >= waitDuration: state = HALF_OPEN   # (lazy, on-call, by default)
    else: reject -> CallNotPermittedException  # caller's fallback fires here
  # CLOSED or HALF_OPEN: permit the call (HALF_OPEN only up to `permitted`)
```

**Bulkhead (the isolation partner):**
- **Semaphore bulkhead** — a permit count (`maxConcurrentCalls`) on the *calling* thread; cheap, no thread hop, but can't interrupt a hung call.
- **Thread-pool bulkhead** — a dedicated bounded pool + queue per dependency; true isolation (a hung dependency exhausts only *its* pool, not the shared web-server threads) at the cost of a thread hop and context-switch overhead.
- Rule: give each downstream dependency its own bounded pool/permit set so one dependency's slowness can never consume the resources the others need. Bulkhead contains; breaker short-circuits — use both.

## Variants

- **Rate-based vs. consecutive-count breaker:** modern (Resilience4j/Polly v8) trip on failure *rate* over a window; the classic Nygard/Hystrix-era description often uses a consecutive-failure count. Rate-based tolerates interleaved successes better.
- **Slow-call breaker:** trips on calls exceeding a latency threshold even if they eventually succeed — catches the "everything is slow but not erroring" degradation that a pure error-rate breaker misses.
- **Semaphore vs. thread-pool bulkhead** (above): concurrency limit on the current thread vs. full thread isolation.
- **Adaptive / concurrency-limiting** (e.g. Netflix concurrency-limits, AIMD): dynamically sizes the permit limit from observed latency instead of a static `maxConcurrentCalls`.

## Resources

- Michael Nygard, *Release It!* (2nd ed.) — Stability Patterns: Circuit Breaker, Bulkhead, Timeouts (the origin of these patterns)
- Resilience4j CircuitBreaker docs: https://resilience4j.readme.io/docs/circuitbreaker
- Resilience4j Bulkhead docs: https://resilience4j.readme.io/docs/bulkhead
- Polly v8 Circuit Breaker strategy: https://www.pollydocs.org/strategies/circuit-breaker.html

## Related

- [[bulkhead]]
- [[retry-backoff]]
- [[timeouts]]
- [[rate-limiting]]
- [[graceful-degradation]]
- [[cascading-failure]]
