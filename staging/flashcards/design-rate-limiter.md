---
id: design-rate-limiter
type: system-design
tags:
  - system-design
  - rate-limiting
  - distributed
  - api-gateway
tiers:
  system-design: 2
created: 2026-09-11
confidence: high
priority: normal
---

# Design a Rate Limiter

A service that decides, for each incoming request, whether to **allow** or **reject** it based on how many requests a given client has made in a recent window. The crux is not the counting — it's doing that counting *accurately and cheaply across a fleet of servers* while surviving bursts, hot keys, and Redis latency without becoming the bottleneck it's meant to protect.

> [!tip] Interview signals
> The interviewer is really probing two decisions: (1) **which algorithm** — can you articulate why sliding-window-log is accurate but memory-heavy, why fixed-window is cheap but allows 2x bursts at the boundary, and land on token bucket or sliding-window-counter with reasons? (2) **where the state lives** — a per-node in-memory counter is fast but lets N nodes each allow the full limit (N x over-admission); a shared Redis counter is correct but adds a network hop and a read-modify-write race. The senior move is naming the **atomicity problem** (check-then-increment is not atomic) and reaching for a Redis Lua script or `INCR` semantics. Classic curveballs: "what happens when Redis is down?" (fail-open vs fail-closed), "how do you rate-limit by user AND by IP AND by endpoint at once?", "the limit is 10/s but a client sends all 10 in the first millisecond — is that ok?" (burst policy), and "how do you tell the client?" (`429` + `Retry-After` + `X-RateLimit-*` headers).

## Problem & Requirements

**Clarifying questions a strong candidate asks first:**
- What are we limiting on — user ID, API key, IP, or a tuple? (changes the key cardinality and storage)
- Is this a public API gateway limiter (millions of keys) or protecting an internal service (thousands)?
- What granularity — per second, per minute, per day, or multiple tiers at once?
- Hard limit or soft (throttle/degrade vs reject)?
- How accurate must it be? Is occasionally allowing 105 requests against a 100 limit acceptable, or is it billing-critical?
- Should it fail open (allow) or fail closed (reject) when the limiter's own store is unavailable?

**Functional:**
- Allow up to N requests per client per time window; reject the rest with HTTP `429 Too Many Requests`.
- Support multiple rules (e.g. 10/s and 1000/day) and multiple dimensions (user, IP, endpoint).
- Return `Retry-After` and `X-RateLimit-Limit/Remaining/Reset` headers so clients can back off.
- Rules configurable at runtime without redeploy.

**Non-functional:**
- **Low added latency** — the limiter runs on the hot path; budget < 1–2 ms p99.
- **High availability** — it must not be a single point of failure; degrade gracefully.
- **Horizontal scale** — correct behavior across many limiter/gateway nodes.
- **Memory efficient** — cardinality can be tens of millions of active keys.
- Accuracy: eventual-ish is fine for abuse prevention; near-exact if tied to paid quotas.

## Estimation

Assume a public API fronting **1 M DAU**, each user making **~50 requests/day** → 50 M req/day.

- Average QPS = 50M / 86,400 s ≈ **580 QPS**.
- Peak is spiky (business hours + retries): assume **5x** average → **~3,000 QPS peak**.
- Every request is a rate-limit decision, so the limiter itself handles **3k QPS**, each doing 1 read-modify-write against the counter store.

**Counter storage (token bucket / counter approach):** one small record per active key. Say `{tokens, last_refill_ts}` ≈ 20 bytes of value + key overhead ≈ **~100 bytes/key** in Redis.
- Active keys in a 1-minute window ≈ up to 1 M users → 1M x 100 B = **~100 MB**. Fits comfortably in a single Redis node's RAM; a small cluster gives headroom + HA.

**Sliding-window-log (contrast):** stores a timestamp per request in a sorted set. Each entry is not free — Redis sorted-set overhead is ~60–80 B/member (skiplist + dict). A light user at 10 req/window costs ~10 x 70 B ≈ 700 B (already ~7x the 100 B counter), and a heavy or abusive client with hundreds of in-window requests costs 10–50x more still — memory grows with *traffic*, not just *key count*. That unbounded, attacker-controllable memory footprint is exactly the trade-off to call out.

**Bandwidth:** each decision is a tiny Redis round trip (~200 B request + response) x 3k QPS ≈ **~600 KB/s** to the counter store — negligible; latency, not bandwidth, is the constraint.

## API Design

The limiter is mostly an internal check, but it has a small surface:

- **Internal decision call** (invoked by gateway/middleware per request):
  `Allow(key, rule) -> { allowed: bool, remaining: int, reset_epoch: int, retry_after_s: int }`
- **Rule management** (control plane, admin-only):
  - `PUT /rules/{id}` body `{ dimension: "user|ip|endpoint", limit: 100, window_s: 60, algorithm: "token_bucket" }`
  - `GET /rules` → list active rules
- **On a rejected request**, the caller returns:
  `HTTP 429 Too Many Requests`
  headers: `Retry-After: 5`, `X-RateLimit-Limit: 100`, `X-RateLimit-Remaining: 0`, `X-RateLimit-Reset: 1694452800`

## Data Model & Storage

Access pattern is a **very high-QPS point read-modify-write keyed by an opaque string**, with tiny values and a natural TTL. That screams **in-memory key-value store, not SQL** — no joins, no scans, no need for durability of a transient counter.

**Choice: Redis** (single-digit-ms, atomic ops, Lua scripting, per-key TTL). SQL is wrong here: a row lock per request at 3k QPS would collapse, and durability of a per-second counter has no value.

- **Counter key (token bucket):** `rl:{rule_id}:{dimension_value}` → hash `{ tokens, last_refill_ts }`, with `EXPIRE` a few windows out so idle keys self-evict.
- **Sliding-window-counter:** two keys, current and previous fixed window: `rl:{rule}:{key}:{window_start}` → integer, with `EXPIRE`.
- **Sharding key:** the rate-limit key itself. Redis Cluster hashes the key across slots; because each client's counter is independent, keys shard cleanly. Use a **[[consistent-hashing]]** ring / cluster slots so adding nodes doesn't reshuffle everything.
- **Rules config:** low-volume, read-heavy → a small SQL table or a config service, cached in each node's memory and refreshed every few seconds. Different access pattern from counters, so different store.

## High-Level Design

```
Client -> LB -> API Gateway (rate-limit middleware) -> upstream services
                        |
                        v
                  Redis (counter store, clustered)
                        ^
                        |
                Rules config (cached locally, refreshed periodically)
```

Placement: the limiter runs **at the API gateway / as middleware**, before auth-heavy work but after cheap identity extraction (API key / user ID from token). Running it at the edge/gateway means abusive traffic is rejected before it consumes downstream capacity — see **[[api-gateway]]**.

**Path of an allowed request:**
1. Request hits the gateway; middleware extracts the key(s) (user, IP, endpoint).
2. For each applicable rule, call `Allow(key, rule)` → single atomic Redis Lua script that reads the counter, refills/increments, decides, and writes back — one round trip.
3. All rules pass → forward to upstream; attach `X-RateLimit-Remaining`.

**Path of a rejected request:**
1–2 as above; a rule returns `allowed=false`.
3. Gateway short-circuits with `429` + `Retry-After`; no upstream call. Optionally increment an abuse metric.

To shave the Redis hop off the hot path, nodes can keep a **local cache/token allotment** (see deep dive) and only consult Redis periodically — trading a little accuracy for latency.

## Deep Dives

### 1. Algorithm choice

| Algorithm | Memory | Burst behavior | Accuracy | Notes |
|---|---|---|---|---|
| **Fixed-window counter** | O(1)/key, tiny | **Bad** — up to 2x limit across a window boundary (all N at 0:59 + all N at 1:00) | Coarse | Simplest; one `INCR` + `EXPIRE`. |
| **Sliding-window log** | O(requests) — stores every timestamp | Exact, smooth | **Best** | Sorted set of timestamps; prune older than window. Memory grows with traffic; expensive under abuse. |
| **Sliding-window counter** | O(1)/key (two counters) | Smooth (approximated) | Very good | Weighted blend of current + previous fixed window; fixes the boundary spike cheaply. |
| **Token bucket** | O(1)/key (`tokens`,`ts`) | **Allows controlled bursts** up to bucket size, then steady refill rate | Good | Great UX for bursty-but-bounded clients; two fields. |
| **Leaky bucket** | O(1) + a queue | **Smooths** output to a fixed rate; no bursts | Good | Queue drains at constant rate; adds latency/queueing; good for shaping outbound. |

**Recommendation:** **token bucket** as the default (natural burst allowance, tiny state, intuitive for API consumers), or **sliding-window counter** when you specifically want to forbid boundary bursts with minimal memory. Reserve **sliding-window log** for low-cardinality, correctness-critical limits (e.g. login attempts) where exactness beats memory. Leaky bucket when you need to *shape* a smooth downstream rate rather than merely cap it.

Sliding-window-counter formula: `estimate = prev_window_count * overlap_fraction + curr_window_count`; reject if `estimate >= limit`. Cheap and closely tracks a true sliding window.

### 2. Where it runs + distributed state & atomicity

**The race condition:** naive logic is `count = GET key; if count < limit: SET key count+1`. Between the GET and SET, another gateway node (or another request on the same node) does the same, so both read `count=99`, both allow, and the true count overshoots. This is a classic **[[race-conditions-and-atomicity]]** check-then-act bug.

**Fixes, in order of preference:**
- **Redis Lua script** — read, compute (refill/increment/decide), and write in one atomic server-side execution. This is the standard token-bucket implementation: the whole read-modify-write is a single atomic step, eliminating the interleave. One round trip, correct.
- **Atomic `INCR` + `EXPIRE`** for fixed/sliding-window counters: `INCR` returns the new value atomically; set `EXPIRE` on first creation. No read-then-write gap.
- **Sorted-set ops** (`ZADD`/`ZREMRANGEBYSCORE`/`ZCARD` in a `MULTI` or Lua) for sliding-window log.

**Sticky vs shared state:**
- **Shared central Redis** — correct across all nodes; the cost is a network hop and Redis becoming a hot dependency. Mitigate with a cluster + replicas and fail-open on timeout.
- **Per-node in-memory** — fastest (no hop) but each of N nodes independently allows up to the limit → up to **N x over-admission**. Only acceptable if traffic is sticky-routed per key (LB pins a client to one node) or the limit is soft.
- **Hybrid (local token lease):** each node periodically leases a slice of the global budget from Redis (e.g. grabs 20 tokens at a time) and serves locally until depleted, then re-leases. Cuts Redis QPS ~20x at the cost of slight imprecision at boundaries — a common production pattern for very high QPS.

**Failure handling:** if Redis is unreachable, **fail open** for availability-first public APIs (better to briefly under-protect than to reject everyone), or **fail closed** for abuse/security-critical limits (login, payment). Make it a per-rule policy, and use short timeouts + **[[caching]]** of the last-known decision so a slow Redis doesn't blow the latency budget.

## Trade-offs & Bottlenecks

| Decision | Option A | Option B | When to pick |
|---|---|---|---|
| Accuracy vs memory | Sliding-window log (exact, O(traffic)) | Sliding-window counter / token bucket (approx, O(1)) | B for high-cardinality gateways; A for security-critical low-volume |
| Consistency vs latency | Central Redis (accurate, +hop) | Per-node / leased (fast, over-admits) | A when quota tied to billing; B/hybrid at extreme QPS |
| Availability under store outage | Fail open | Fail closed | Open for public read APIs; closed for auth/payment |
| Burst policy | Token bucket (allow bursts) | Leaky bucket (smooth) | Token for API UX; leaky to protect a fragile downstream |

**Bottleneck under scale:** the counter store. At millions of keys and 10k+ QPS, a single Redis node saturates on either CPU (Lua execution) or a **hot key** (e.g. everyone hitting a shared `global` limit, or one whale client). Mitigations: (1) shard by key across a Redis Cluster with **[[consistent-hashing]]**; (2) for a genuine hot single key, use the **local-lease/hybrid** pattern so most decisions are made in-process; (3) keep Lua scripts tiny and values small; (4) put replicas behind reads and accept eventual consistency for soft limits. The limiter must add far less latency and far more availability than the traffic it drops is worth — if the limiter itself becomes the bottleneck, the design has failed.

## Related

- [[rate-limiting]]
- [[caching]]
- [[api-gateway]]
- [[consistent-hashing]]
- [[race-conditions-and-atomicity]]
