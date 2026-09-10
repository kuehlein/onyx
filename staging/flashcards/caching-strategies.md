---
id: caching-strategies
type: flashcard
tags:
  - system-design
  - caching
  - performance
  - consistency
tiers:
  system-design: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Caching Strategies

A cache trades memory and *staleness* for latency and reduced load on a slow backing store. Choosing a caching strategy is choosing *who* populates and invalidates the cache and *when* — which directly determines the consistency and durability you get. There is no single "the cache" pattern: read paths (cache-aside vs read-through) and write paths (write-through, write-back, write-around) are chosen independently, and the two hardest operational problems — [cache stampede](_meta/glossary.md#cache-stampede) and stale reads from bad invalidation — fall out of those choices. Phil Karlton's adage frames the domain: "there are only two hard things in computer science: cache invalidation and naming things."

> [!tip] Recognition
> Reach for caching-strategy reasoning when you see: "reduce read latency / offload the database," "hot key," "read-heavy workload," "TTL," "stale data after an update," "thundering herd / everything hits the DB at once when the cache expires," "cache and DB disagree," or "how do we invalidate." When the question is *which* pattern, first split it into a **read path** and a **write path** — they are orthogonal choices.

## When to Use

**Problem signals that point to a cache at all:**
- Read-heavy, read-mostly access to data that is expensive to compute or fetch and tolerant of *some* staleness
- The same keys are requested far more often than they change (high read:write ratio, temporal locality)
- A slow or rate-limited backing store (DB, upstream API) is the bottleneck under read load

**Choosing the READ path:**
- **Cache-aside (lazy loading)** — the *default*. App checks cache; on miss it loads from the DB and populates the cache itself. Use when you want the cache to be optional (a cache outage degrades to slow, not broken) and only actually-requested data cached.
- **Read-through** — the cache library/layer fetches from the DB on a miss transparently; app only ever talks to the cache. Use when you want caching logic centralized (one place, not every call site) and the cache provider supports it.

**Choosing the WRITE path:**
- **Write-through** — write cache and DB synchronously in the same operation. Use when reads must see fresh writes immediately and you can pay write latency for it (cache and DB stay consistent).
- **Write-back / write-behind** — write cache now, flush to DB asynchronously (batched). Use only when write latency/throughput dominate *and* the cache tier is durable enough to survive a crash (or lost writes are acceptable).
- **Write-around** — write straight to the DB, bypass the cache (let the next read lazily populate it). Use for write-heavy data that isn't read soon after write, to avoid polluting the cache with cold entries.

**Do not cache when:**
- The workload is write-heavy or read-once → the cache is churned faster than it pays off (prefer write-around, or no cache)
- Data must be strongly consistent / linearizable on every read → a cache introduces a staleness window; read from the source or use a coherent store
- The dataset has no locality (every request is a unique key) → hit rate approaches zero and you pay memory + a miss penalty for nothing

## Key Properties

- **Read path and write path are orthogonal.** "Cache-aside" answers *how misses are filled*; "write-through/back/around" answers *how writes propagate*. You pick one of each (e.g. cache-aside reads + write-around writes is a common pairing).
- **Cache-aside is lazy and self-healing but has a first-request penalty.** Only requested keys get cached; a cache flush just causes misses, not errors. The cost is a cold-start miss for every key and a race window (see Pitfalls) where a stale value can be re-populated after a delete.
- **Invalidation vs. expiration are different tools.** *TTL* (time-to-live) bounds staleness passively — every entry is wrong for at most its TTL. *Explicit invalidation* (delete/update on write) bounds it actively but is hard to get right across many keys and derived data. Most systems use both: TTL as a safety net under explicit invalidation.
- **Write-through keeps cache and DB consistent; write-back does not, until it flushes.** Write-through's every acknowledged write is already in the DB. Write-back acknowledges before the DB is updated — a window of divergence and potential loss.
- **Eviction ≠ expiration.** Eviction (LRU/LFU/etc.) reclaims memory under pressure regardless of TTL; expiration removes entries whose TTL elapsed. A key can vanish early from eviction even if its TTL hasn't passed.
- **Hit rate is the headline metric.** Latency/load benefit scales with hit rate; a low-locality workload or an over-aggressive TTL/eviction quietly destroys it.

## Common Pitfalls

- **Cache stampede / thundering herd.** A hot key expires (or a cold cache starts) and thousands of concurrent requests all miss simultaneously and hammer the DB with the *same* recompute. Fixes: (1) **request coalescing / single-flight** — let one request recompute while the rest wait on its result; (2) **locking** — a per-key mutex/lease so only one recompute proceeds; (3) **probabilistic early expiration (XFetch)** — refresh *before* expiry with rising probability so one request refreshes early instead of all at once; (4) stagger TTLs with jitter so keys don't expire in lockstep.
- **The cache-aside delete race (stale re-population).** Classic sequence: writer updates DB then deletes the cache key, but a concurrent reader that missed *earlier* writes its now-stale value back *after* the delete → cache holds a stale value indefinitely. Mitigations: delete-after-write (invalidate, don't update, the key), short TTL as a backstop, or versioned/CDC-driven invalidation.
- **Update-the-cache-in-place on write (dual-write inconsistency).** Writing the new value into both cache and DB non-atomically means a crash or a race between two writers can leave them permanently disagreeing. Prefer *invalidate* (delete) over *update* on the write path so the next read reloads from the source of truth.
- **Unbounded / no-TTL entries.** Without a TTL (or invalidation you actually trust), a bug in invalidation means data is stale *forever*. Always have a TTL backstop even under explicit invalidation.
- **Caching negative results wrong.** Not caching "not found" invites a stampede of misses for nonexistent keys (cache penetration); caching it with too long a TTL hides a row that later appears. Cache negatives with a *short* TTL.
- **Assuming write-back is safe.** An acknowledged write-back write that hasn't flushed is lost if the cache node dies. Never use plain write-back for data you can't afford to lose.

## Trade-offs

**Write patterns — consistency, durability, latency:**

| Pattern | Write latency | Read-after-write freshness | Durability on cache crash | Best for |
|---|---|---|---|---|
| **Write-through** | High (cache + DB sync) | Fresh immediately | Safe (DB has every ack'd write) | Read-after-write correctness; cache = DB |
| **Write-back / behind** | **Low** (cache only, async flush) | Fresh (in cache) | **At risk** (unflushed writes lost) | Write-heavy, latency-critical, loss-tolerant *or* durable cache |
| **Write-around** | Normal (DB only) | Stale until next miss reloads | Safe (DB is source of truth) | Write-heavy data not read soon after write |

**Read patterns:**

| Pattern | Who fills the miss | Cache outage behavior | Coupling |
|---|---|---|---|
| **Cache-aside (lazy)** | Application code | Degrades to slow (app falls back to DB) | Cache logic in every call site |
| **Read-through** | Cache layer/provider | Can break reads if cache is the only path | Centralized in cache layer |

- **Freshness vs. load (the TTL knob).** Shorter TTL → fresher data but more misses and more backend load; longer TTL → higher hit rate but more staleness. TTL is the single dial trading consistency for offload.
- **Explicit invalidation vs. TTL.** Explicit invalidation gives near-zero staleness but is fragile (miss one write path or derived key and you serve stale data forever); TTL is dumb but robust. Real systems layer them.
- **Write-back throughput vs. durability.** Batching/coalescing writes to the DB is the whole point of write-back and can massively cut DB write load — paid for with a data-loss window and cache↔DB inconsistency. NVMe/replicated cache tiers narrow the durability gap.
- **vs. [[cdn]]:** a CDN is a *specific geographic* read cache for static/edge content addressed by URL; the strategies here are the general application/data-cache patterns a CDN is one instance of.

## Implementation Notes

**Cache-aside read + write-around, delete-on-write (the common safe default):**
```text
READ(key):
  v = cache.get(key)
  if v is not None: return v          # hit
  v = db.read(key)                    # miss -> load from source
  cache.set(key, v, ttl=T)           # populate (T includes jitter)
  return v

WRITE(key, val):
  db.write(key, val)                  # source of truth first
  cache.delete(key)                   # invalidate, don't update-in-place
  # next READ lazily reloads the fresh value
```

**Single-flight / request coalescing** (stampede fix): keep an in-flight map keyed by cache key; the first caller computes, concurrent callers await the same future. Go's `golang.org/x/sync/singleflight` and Redis distributed locks (`SET key val NX PX ttl`) are the canonical implementations.

**Probabilistic early expiration (XFetch, Vattani et al. VLDB 2015)** — refresh early so one request recomputes before mass expiry instead of the herd at expiry. Store the recompute cost `delta` with the value; on read, recompute if:
```text
now - delta * beta * ln(rand()) >= expiry
```
`delta` = time the last recomputation took; `beta` > 0 tunes eagerness — beta=1 is the default and works well, beta>1 refreshes earlier, beta<1 later; `rand()` ∈ (0,1] (exclude 0 to avoid `ln(0)`). Since `ln(rand())` is negative, the term is positive and grows the effective time past `expiry` probabilistically: the chance of an early refresh rises as `now` approaches `expiry`, and costlier-to-recompute keys (larger `delta`) refresh earlier.

**TTL jitter:** set TTL to `base ± random spread` (e.g. `T * (1 + rand*0.1)`) so keys inserted together don't expire together and re-create a stampede.

## Resources

- Vattani, Chierichetti, Lowenstein, *Optimal Probabilistic Cache Stampede Prevention*, VLDB 2015 — https://www.vldb.org/pvldb/vol8/p886-vattani.pdf
- AWS, *Caching strategies* (Lazy loading, Write-through, TTL) — https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/Strategies.html
- Redis, *Client-side caching / cache patterns* — https://redis.io/docs/latest/develop/reference/client-side-caching/
- Wikipedia, *Cache stampede* (locking, external recomputation, probabilistic early expiration) — https://en.wikipedia.org/wiki/Cache_stampede

## Related

- [[cdn]]
- [[consistent-hashing]]
- [[redis]]
- [[load-balancing]]
- [[eventual-consistency]]
- [[database-indexing]]
