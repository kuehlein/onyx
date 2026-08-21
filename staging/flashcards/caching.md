---
id: 9a8b1c16-cc9e-4e09-a259-7678a730eacf
type: flashcard
created: 2026-08-21
confidence: high
tiers:
  system-design: 1
tags:
  - system-design
  - caching
  - performance
  - distributed-systems
  - cache-invalidation
---

# Caching

Caching stores the result of an expensive computation or fetch in faster, closer storage so subsequent identical requests are served cheaply. It is fundamentally a bet: **the cost of a miss + eviction + staleness is worth paying for a high hit ratio.** A cache only helps when access has *locality* (temporal or spatial) and the underlying data is read far more often than it changes.

## When to Use

**Problem signals that suggest caching:**
- The same expensive result is recomputed or re-fetched repeatedly (high read amplification on a small hot set).
- Read:write ratio is high (e.g. 100:1) — data is read many times between mutations.
- A downstream dependency (DB, third-party API, disk) is the latency or throughput bottleneck, and its responses are deterministic for a given input.
- P99 latency spikes trace to a slow backing store that returns identical answers.
- Traffic shows a skewed / Zipfian distribution — a few keys account for most requests.
- You need to shed load from an origin that cannot scale horizontally (rate-limited API, single-writer DB).

**Prefer caching over alternatives when:**
- Over **scaling the origin (bigger DB / more replicas)**: caching is cheaper per QPS when the hot set is small and reads dominate.
- Over **precomputing everything (materialized view)**: caching is lazy and self-tuning to actual access patterns; you only store what is asked for.
- Over **a CDN**: use an app/DB cache when data is dynamic, per-user, or must be invalidated precisely; use a CDN when content is static and geo-distribution matters (they compose — CDN in front, Redis behind).

**Do not use when:**
- Data changes as often as it is read (write-heavy, low reuse) -> the cache thrashes; go straight to the store or use a write buffer.
- Strong consistency / read-your-writes is mandatory and you cannot tolerate staleness -> read from primary, or use a cache with synchronous invalidation and accept the coupling.
- The working set does not fit and has no locality (uniform random access over huge keyspace) -> near-0% hit ratio; caching just adds a hop and memory cost.
- The computation is already cheap relative to a cache round-trip (a network Redis GET can be slower than an in-process calculation) -> compute directly or cache in-process.
- Results are non-deterministic or contain time-sensitive/security-scoped data that must never be shared across users -> caching risks correctness or data leaks.

## Key Properties

| Property | Meaning |
|---|---|
| Hit ratio | fraction of reads served from cache; the single most important metric. |
| Locality | temporal (recently used → reused soon) or spatial (nearby keys accessed together) — required for caching to pay off. |
| Eviction policy | which entry to drop when full (LRU, LFU, FIFO, ARC, TTL-based). |
| TTL / freshness | max staleness tolerated; bounds correctness risk independent of invalidation. |
| Consistency model | cache is a second copy → it can diverge from the source of truth. |
| Locality of the cache | in-process (fastest, per-node, not shared) vs remote/distributed (shared, network hop) vs CDN (edge). |

**Effective latency:** `avg = hit_ratio * hit_cost + (1 - hit_ratio) * (miss_cost + fill_cost)`. A cache with an 80% hit ratio but a very slow miss path can be *slower* than no cache — always compare against the uncached baseline.

## Common Pitfalls

- **Thundering herd / cache stampede:** a hot key expires and thousands of concurrent requests all miss and hit the origin simultaneously. Mitigate with request coalescing (single-flight), a mutex/lock per key on refill, probabilistic early expiration, or serving stale-while-revalidate.
- **Unbounded cache growth:** no eviction / no maxmemory → OOM. Always set a size bound *and* an eviction policy.
- **Stale reads after write:** updating the DB but forgetting to invalidate/update the cache. Decide the write strategy explicitly (below).
- **Invalidation races:** a concurrent read repopulates the cache with the old value in the window between DB write and cache delete. Delete-after-write plus short TTL, or versioned keys, reduce the window.
- **Cache penetration:** repeatedly querying keys that do not exist in the origin → every request misses and hits the DB. Cache negative results (with short TTL) or use a Bloom filter to short-circuit known-absent keys.
- **Hot-key overload (distributed):** one key on one shard saturates a single node. Replicate the hot key across nodes or add a small in-process tier in front.
- **Caching per-user data under a shared key:** leaks one user's data to another. Scope keys by tenant/user/permission.
- **Serializing large objects:** the (de)serialization cost can dwarf the origin fetch; measure end-to-end, not just the GET.

## Trade-offs

- **Freshness vs hit ratio:** short TTL → fresher but more misses and origin load; long TTL → higher hit ratio but staler data.
- **Consistency vs latency:** synchronous write-through/invalidation keeps the cache correct but adds latency and couples the write path to the cache's availability; async keeps writes fast but widens the staleness window.
- **Memory vs hit ratio:** bigger cache → higher hit ratio with diminishing returns; cost grows linearly while hit-ratio gains flatten.
- **In-process vs distributed:** in-process is nanosecond-fast and dependency-free but duplicates memory per node and is hard to invalidate cluster-wide; distributed (Redis/Memcached) is shared and centrally invalidated but adds a network hop and a new failure domain.
- **Complexity:** every cache is a second source of truth you must keep coherent, monitor, size, and warm — real operational cost, not free speed.

## Implementation Notes

**Write strategies (pick per data set):**

| Strategy | Read path | Write path | Use when |
|---|---|---|---|
| Cache-aside (lazy) | on miss, load from DB then populate | write DB, then invalidate/delete key | default; general-purpose; app controls the cache. |
| Write-through | always in cache | write cache and DB synchronously | reads must always hit warm cache; tolerate write latency. |
| Write-back (write-behind) | always in cache | write cache now, flush to DB async | write-heavy, can tolerate loss window on crash. |
| Read-through | cache library loads on miss transparently | via write-through | want the cache layer, not app code, to own loading. |

```js
// Cache-aside read with single-flight to prevent stampede.
const inflight = new Map(); // key -> Promise, dedupes concurrent misses

async function get(key) {
  const cached = await cache.get(key);
  if (cached !== undefined) return cached;      // hit

  if (inflight.has(key)) return inflight.get(key); // coalesce concurrent misses

  const p = (async () => {
    try {
      const val = await db.load(key);
      // negative-cache misses briefly to blunt cache penetration
      await cache.set(key, val, { ttlMs: val == null ? 5_000 : 300_000 });
      return val;
    } finally {
      inflight.delete(key);
    }
  })();
  inflight.set(key, p);
  return p;
}

// Write: update source of truth first, THEN invalidate.
// Deleting (not updating) the key avoids caching a value a
// concurrent reader may have made stale mid-write.
async function put(key, val) {
  await db.write(key, val);
  await cache.del(key);
}
```

**Sizing / eviction:** set an explicit `maxmemory` (Redis) or entry cap and choose a policy: `LRU`/`allkeys-lru` for general locality, `LFU` when frequency matters more than recency, `TTL`-only when time-boundedness is the natural bound. Add jitter to TTLs so keys do not all expire in the same instant (avoids synchronized stampedes).

## Variants

- **In-process / local cache** — e.g. an LRU `Map`, Guava/Caffeine: fastest, no network, but per-node and not coherent across a cluster.
- **Distributed cache** — Redis, Memcached: shared, centrally invalidated, survives app restarts; adds a hop and a dependency.
- **CDN / edge cache** — caches static or cacheable responses near users; keyed by URL + headers; controlled by `Cache-Control`/`ETag`.
- **HTTP caching** — `Cache-Control`, `ETag`/`If-None-Match`, `Last-Modified` enable conditional requests and 304s (browser, proxy, CDN).
- **Read replica / materialized view** — a "cache" that is eagerly maintained and queryable, trading storage and write cost for guaranteed availability of the derived data.
- **Multi-tier (near + far)** — small in-process L1 in front of a shared L2 (Redis) to absorb hot keys and cut network hops.

## Resources

- AWS: [Caching Best Practices](https://aws.amazon.com/caching/best-practices/)
- Redis docs: [Key eviction / maxmemory policies](https://redis.io/docs/latest/develop/reference/eviction/)
- MDN: [HTTP caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching)
- "Caching at Netflix (EVCache)" and Meta's memcache paper (*Scaling Memcache at Facebook*, NSDI '13) for production-scale patterns.

## Related

- [[Content Delivery Network (CDN)]]
- [[Cache Invalidation Strategies]]
- [[LRU Cache]]
- [[Redis]]
- [[Consistency Models]]
- [[Load Balancing]]
- [[Read Replicas]]
- [[Bloom Filter]]
