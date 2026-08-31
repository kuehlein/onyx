---
id: 7f3a2d91-c84e-4b16-9e05-1d6f8c3a7b42
type: flashcard
tags:
  - system-design
  - rate-limiting
  - scalability
  - api-design
tiers:
  system-design: 1
created: 2026-08-20
confidence: medium
priority: normal
---

# Rate Limiting

Rate limiting constrains how often a client can invoke an operation within a time window — the core mechanism that prevents resource exhaustion, enforces fair use, and absorbs traffic spikes before they cascade into outages.

> [!tip] Default answer
> Reach for **token bucket** unless told otherwise: O(1) state, allows bounded bursts, cheap at scale. It's the most commonly chosen algorithm in practice.

## When to Use

**Problem signals that suggest rate limiting:**
- The prompt mentions a public-facing API, third-party developer access, or API keys — any public surface can be abused
- "Protect against DDoS / abuse / scraping" appears as a requirement
- [SLA](_meta/glossary.md#sla) or quota language: "each user gets X requests per day/hour/minute"
- The system has an expensive downstream (ML inference, external payment provider, database write path) that cannot absorb unbounded traffic
- Multi-tenancy is present — one noisy tenant must not starve others
- "Prevent [resource] from being exhausted" or "ensure availability under heavy load"
- Monetization tiers are mentioned (free: 100 req/min, paid: 10,000 req/min)

**Prefer rate limiting over alternatives when:**
- Over circuit breaking: you want to reject excess requests from a specific client rather than trip on downstream failure; rate limiting is client-scoped, circuit breaking is dependency-scoped
- Over load shedding: you need per-identity fairness guarantees rather than system-wide survival behavior; rate limiting is proactive, load shedding is reactive
- Over autoscaling alone: compute costs are unbounded or scale-up latency (minutes) is too slow to absorb sudden spikes

**Do not use when:**
- Traffic is entirely internal and trusted (service-to-service within a private [VPC](_meta/glossary.md#vpc)) → prefer backpressure or queue depth signals
- The bottleneck is a single global resource with no client attribution → use a semaphore or token bucket at the resource level without per-client state

## Key Properties

**The four canonical algorithms:**

| Algorithm | Memory per client | Burst behavior | Smoothness | Best for |
|---|---|---|---|---|
| **Fixed Window Counter** | O(1) | 2× burst at window boundary | Lumpy | Simple quotas, daily limits |
| **Sliding Window Log** | O(requests in window) | Exact | Smooth | Audit trails, low-volume premium APIs |
| **Sliding Window Counter** | O(1) | ~10% over-burst at boundary | Near-smooth | High-throughput APIs with acceptable approximation |
| **Token Bucket** | O(1) | Configurable burst up to bucket size | Smooth | APIs allowing short bursts ([CDN](_meta/glossary.md#cdn), mobile clients) |
| **Leaky Bucket** | O(queue depth) | No burst — strict constant rate | Perfectly smooth | Downstream protection, payment processors |

**Token bucket** is the most commonly chosen algorithm in practice: it naturally allows burst absorption (idle clients accumulate tokens up to capacity) while bounding the maximum burst, and O(1) state makes it cheap at scale.

**Sliding window counter** (hybrid of fixed window + log) is the second most common: it gives near-exact precision with O(1) memory by interpolating between two adjacent fixed-window buckets.

## Trade-offs

**Centralized store (Redis) vs. local in-process:**
- Redis (single counter): exact counts across all nodes, ~1–5 ms added latency per request, single point of failure risk; use Redis Cluster or Sentinel for HA
- Local in-process: zero added latency, no network hop, but counts diverge across replicas — each node sees only ~1/N of true traffic (N = replica count); acceptable only when over-counting by N× is tolerable or cluster size is small and stable

**Granularity of the rate limit key:**
- By IP: cheap, but shared IPs (NAT, corporate proxies) throttle legitimate users; trivially bypassed with IP rotation
- By user ID / API key: accurate per-identity but requires auth to be resolved upstream; preferred for authenticated APIs
- By IP + endpoint: finer control (e.g., login endpoint gets 5/min, feed endpoint gets 1000/min) at the cost of more Redis keys

**Where to enforce:**
- API gateway / edge (Nginx, Kong, Cloudflare): lowest latency rejection, protects all downstream services, but limits must be coarse-grained and stateless-friendly
- Application middleware: access to full auth context and business logic, easy per-tenant customization, but every app replica needs access to shared state
- Hybrid: edge enforces a coarse IP-level limit (DDoS protection), application enforces fine-grained per-user limits

**Failure mode — what happens when Redis is unavailable:**
- Fail open: allow all traffic through → vulnerable to abuse during outage
- Fail closed: reject all traffic → service becomes unavailable
- Fail static: fall back to local in-process limiter → approximate but safe; most production systems choose this

**HTTP response conventions:**
- `429 Too Many Requests` is the correct status code
- Return `Retry-After` (seconds) and `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` headers so clients can back off gracefully

## Implementation Notes

**Typical production architecture:**

```
Client → API Gateway (IP-level coarse limit, e.g., 10k req/min)
       → Auth Middleware (resolve user ID / API key)
       → Rate Limit Middleware (per-user fine-grained limit, Redis-backed)
       → Application Handler
```

**Redis data pattern for sliding window counter:**
Two keys per client per window: the current fixed-window count and the previous. On each request, compute the weighted interpolation:

```
effective_count = prev_count × (1 - elapsed_in_window / window_size) + curr_count
```

This gives ~99.97% accuracy vs. a true sliding log at O(1) memory.

**Token bucket in Redis with Lua (atomic):**
Use a Lua script executed atomically in Redis to read token count, compute elapsed time since last refill, add tokens (capped at bucket capacity), subtract one, and write back. The atomic script prevents race conditions that two-command (GET + SET) approaches suffer.

**Distributed rate limiting at scale (e.g., Twitter API, Stripe):**
- Shard rate limit keys across Redis Cluster by consistent hashing on the client key
- Each shard handles ~10–50k active client keys comfortably
- At 100M API keys with one Redis key each at ~64 bytes: ~6 GB — fits comfortably in a mid-sized Redis cluster
- Typical Redis throughput: 100k–1M ops/sec per node; rate limiting adds one round trip per request

**Multi-tier quotas:**
Implement a hierarchy of limits checked in order: per-second burst → per-minute sustained → per-day quota. Return the most restrictive violation with its specific `Retry-After`.

## Common Pitfalls

- **Fixed window boundary burst:** a client can fire N requests at 11:59:59 and another N at 12:00:00, doubling the effective rate. Use sliding window or token bucket to prevent.
- **Clock skew across nodes:** distributed counters that rely on wall-clock windows drift when nodes have unsynchronized clocks. Use Redis as the single time authority.
- **Forgetting the response headers:** clients without `Retry-After` will immediately retry, worsening the load. Always include backoff hints.
- **Same limit for all endpoints:** the login endpoint (5/min), password reset (3/hour), and read feed (500/min) should have independent limits. A single global limit is too coarse.
- **Not accounting for retry amplification:** if an upstream service retries on 429, a single user can generate O(retries × requests) load. Ensure callers implement exponential backoff with jitter.
- **Quota reset confusion:** clients expect quotas to reset at a predictable boundary (top of the hour, midnight UTC). Communicate the reset policy and include `X-RateLimit-Reset` as a Unix timestamp.

## Resources

- [RFC 6585 — 429 Too Many Requests](https://www.rfc-editor.org/rfc/rfc6585)
- [Stripe Rate Limiting Blog Post](https://stripe.com/blog/rate-limiters)
- [Redis documentation — Lua scripting for atomic operations](https://redis.io/docs/latest/develop/interact/programmability/lua-api/)
- Alex Xu, *System Design Interview Vol. 1*, Chapter 4 — Design a Rate Limiter

## Related

- [[consistent-hashing]]
- [[caching]]
- [[api-design]]
- [[load-balancing]]
- [[distributed-systems]]
