---
id: design-url-shortener
type: system-design
tags:
  - system-design
  - url-shortener
  - read-heavy
  - caching
tiers:
  system-design: 2
created: 2026-09-11
confidence: high
priority: normal
---

# Design a URL Shortener

A service (TinyURL/bit.ly) that maps a long URL to a short, unique key and redirects any request for that key back to the original. The crux is not "storing a mapping" — it is generating collision-free short keys at scale and serving an enormously read-skewed redirect path with single-digit-millisecond latency.

> [!tip] Interview signals
> The interviewer is really probing two decisions: (1) **how you mint the short key** — do you reach for a random hash and handle collisions, a monotonic counter in base62, or a dedicated key-generation service? — and (2) **how you serve reads** given a 100:1+ read:write skew. Strong candidates make the read path almost entirely cache/CDN and treat writes as the rare, coordination-heavy operation. Classic curveballs: "what happens when two writers pick the same key?", "custom aliases and vanity URLs", "301 vs 302 and its effect on click analytics", "link expiry / deletion", and "how do you count clicks without slowing the redirect?". The junior answer hashes the URL and hopes; the senior answer names the collision/coordination trade-off explicitly and keeps analytics off the hot path.

## Problem & Requirements

**Clarifying questions a strong candidate asks first:**
- Do we support **custom aliases** (user-chosen keys) or only system-generated ones? (Changes the collision/uniqueness story.)
- Do links **expire**? Default TTL vs never?
- Do we need **click analytics** (counts, geo, referrer)? Real-time or batch?
- What key length / alphabet — how many URLs total over the product's life? (Sizes the keyspace.)
- Is the same long URL shortened once (dedupe) or does every request mint a new key?

**Functional:**
- `shorten(longUrl) -> shortUrl`; optional custom alias and expiry.
- `GET /{key}` redirects to the original long URL.
- Optional: click analytics; link deletion.

**Non-functional:**
- Scale: assume ~1B new links over ~5 years; redirects dominate traffic.
- Latency: redirect p99 < ~50ms (it gates every downstream page load).
- Availability: redirects should be **highly available** (99.99%) — a dead redirect breaks every shared link. Writes can tolerate slightly less.
- Consistency: a freshly created key must resolve almost immediately (read-your-writes for the creator); global replication lag of a few seconds elsewhere is acceptable.
- Keys must be **non-guessable enough** to not trivially enumerate, but this is not a security product.

## Estimation

Assume **100M new URLs/day** (generous, for a large provider).

- **Writes:** 100M / 86,400s ≈ **1,160 writes/s** average; peak ~3x ≈ **3,500 writes/s**.
- **Read:write skew:** redirects vastly outnumber creations. Take **100:1** → **~116K reads/s** average, peak ~3x ≈ **350K reads/s**. This skew is the single most important number: the read path must be cache-first.
- **Storage:** per record ≈ key (7 chars) + long URL (~500B) + metadata (userId, createdAt, expiry, counters) ≈ **~600B**. Over 5 years: 100M/day × 365 × 5 ≈ **1.8×10¹¹ records** — but that's unrealistically high; scope to **~1B lifetime links** → 1B × 600B ≈ **~600 GB**. Comfortably shardable; even with replicas and indexes call it **~2–3 TB**.
- **Keyspace:** base62 (`[A-Za-z0-9]`). 62⁷ ≈ **3.5 trillion** keys — 7 characters is plenty for 1B links (utilization << 0.03%), which keeps random-collision probability tiny.
- **Bandwidth:** redirect responses are tiny (a 3xx with a Location header, a few hundred bytes). 350K/s × ~500B ≈ **~175 MB/s** egress on redirects — trivial; the cost is request rate, not bytes.
- **Cache working set:** link popularity is Zipfian; the hot ~20% of keys serve ~80% of reads. Caching a few hundred million hot entries (~tens of GB) absorbs the vast majority of redirect traffic.

## API Design

- `POST /api/v1/urls` — body `{ longUrl, customAlias?, expiresAt? }` → `201 { shortUrl, key, expiresAt }`. `409` if a custom alias is taken.
- `GET /{key}` — the redirect. Returns **302** (see deep dive) with `Location: <longUrl>`, or `404` if unknown/expired, `410 Gone` if explicitly deleted/expired.
- `GET /api/v1/urls/{key}` — metadata (owner, createdAt, expiry, click count) without redirecting.
- `DELETE /api/v1/urls/{key}` — soft-delete (authz'd to owner).

Writes are authenticated (API key / OAuth); the redirect `GET /{key}` is anonymous and must be the cheapest path in the system.

## Data Model & Storage

Core entity `url_mapping`:

| field | type | notes |
|---|---|---|
| `key` | varchar(7) | **primary key**, base62 |
| `long_url` | text | the destination |
| `user_id` | bigint | owner (nullable for anon) |
| `created_at` | timestamptz | |
| `expires_at` | timestamptz | null = never |
| `deleted` | bool | soft delete → `410` |

**SQL vs NoSQL:** the access pattern is a pure **key → value point lookup** by `key`, with no joins or range/analytical queries on the hot path. That is the canonical fit for a **wide-column / KV store** (Cassandra, DynamoDB, or Bigtable) — it gives horizontal scale, tunable consistency, and cheap point reads. A partitioned relational store works fine at this scale too and simplifies custom-alias uniqueness (a unique constraint), so it's a defensible choice; I'd pick NoSQL primarily for the operational simplicity of scaling reads. See [[sql-vs-nosql]].

**Partitioning:** shard by `key`. Because the key is effectively random (base62 of a counter run through an encoder, or a hash), hashing it distributes load evenly — [[consistent-hashing]] keeps rebalancing cheap when nodes are added. The primary index is the `key` itself; a secondary index on `user_id` supports "my links" listing (off the hot path). See [[database-indexing]] and [[partitioning-sharding]].

Analytics (click events) go to a **separate** append-only store / stream, never the mapping table, so counting never contends with the redirect read.

## High-Level Design

**Write (create) path:**
`client -> API gateway/LB -> Write Service -> key generation -> DB (+ cache warm)`
1. Request hits the [[api-gateway]] / [[load-balancing]] tier (also does auth + [[rate-limiting]] so one client can't exhaust the keyspace).
2. Write Service obtains a unique `key` (see deep dive), writes `{key, longUrl, ...}` to the DB.
3. Optionally warms the cache so the creator's immediate read hits ([[read-your-writes-consistency]]).
4. Returns the assembled short URL.

**Read (redirect) path — the hot one:**
`client -> CDN -> LB -> Read Service -> cache -> DB (only on miss)`
1. `GET /{key}` first hits the [[cdn]] / edge, which can serve a cached 3xx for popular keys without ever reaching origin.
2. On edge miss, the LB routes to a stateless Read Service that checks an in-memory cache ([[caching-strategies]], typically **cache-aside** with Redis/Memcached).
3. On cache hit → return the redirect immediately (the common case at ~116K rps).
4. On cache miss → point-read the DB by `key`, populate the cache with a TTL, return the redirect. If not found/expired → `404`/`410`.
5. Click analytics are emitted **asynchronously** (fire-and-forget onto a queue/stream) so counting never blocks the redirect.

## Deep Dives

### 1. Short-key generation
Three real approaches, with the trade-off that actually gets drilled:

- **Hash + collision handling:** hash the long URL (e.g. MD5/SHA), base62-encode, take the first 7 chars. Simple and gives free dedupe (same URL → same key), *but* truncated hashes collide, so every write needs a read-check-and-retry ("if key exists with a different URL, rehash/salt"). Under high write concurrency this read-before-write is a real cost and a race (two writers can both pass the check).
- **Counter + base62:** keep a global monotonic counter and base62-encode the integer → **guaranteed collision-free, no read-check**. A plain incrementing counter needs only ~6 base62 chars for 1B links (62⁶ ≈ 57B), so it fits the short-key budget easily. The catch is the counter is a coordination point: a single counter is a bottleneck/SPOF, so the standard fix is **ID ranges** — each write node leases a block of IDs (e.g. 1,000 at a time) from a coordinator (ZooKeeper/etcd or a DB sequence) and mints locally without per-write coordination. This is the [[unique-id-generation]] problem. Note a full timestamp-based Snowflake ID is 64-bit and base62-encodes to ~11 chars, so it's overkill for a 7-char key unless you want time-ordering; a leased-range counter is the leaner fit. Sequential IDs are also mildly guessable, so many services run the integer through a secret permutation (e.g. Feistel/multiply-by-coprime) before encoding to scatter the keyspace.
- **Key Generation Service (KGS):** a dedicated service **pre-generates** random unique keys offline into a "available keys" table and hands them out on demand (marking them used, ideally moving them between `unused`/`used` tables atomically). Writes become a single fast lookup with **no collision check on the hot write path**; the hard parts are making key hand-out concurrency-safe (don't hand the same key twice) and keeping the buffer replenished.

**Recommendation:** counter-in-ranges or a KGS. Both move collision handling *off* the per-request write path — the senior point. I'd default to **ranged counter → base62**: no separate service to run, no collision retries, trivially horizontally scalable via per-node ID blocks, and it fits the 7-char key with room to spare. Use a hash only if free dedupe of identical URLs is an explicit requirement, and a KGS if you specifically want opaque non-sequential keys without an encoding step.

### 2. Read-heavy serving & 301 vs 302
With ~100:1 skew, the design *is* the cache hierarchy: edge/[[cdn]] → distributed cache → DB. Cache-aside with a TTL handles the Zipfian hot set; the long tail falls through to a fast KV point read. For a genuinely hot key (a viral link), even a single cache shard can be hammered — mitigate with a small local (in-process) LRU in the Read Service in front of the shared cache, or replicate the hot entry across cache nodes.

**301 vs 302 — the analytics tension:** a **301 Permanent** redirect lets browsers and proxies cache the mapping, so subsequent clicks *skip our server entirely* → cheapest and fastest, but we **undercount clicks** (cached hits are invisible) and can't easily change/expire the destination. A **302 Found** (temporary) forces the client back to us every time → we can count every click, enforce expiry, and update targets, at the cost of serving every redirect ourselves. The engineering rule: **if you need per-click analytics, expiry, or mutable targets, use 302**; choose 301 only when the mapping is truly permanent and you want to shed load. (Real services vary — some, like Bitly, actually return 301 and rely on cache-control/no-cache headers to still funnel clicks back for counting, trading a little cacheability for analytics — a good thing to mention as the nuanced middle ground.)

## Trade-offs & Bottlenecks

| Decision | Option A | Option B | Choice & why |
|---|---|---|---|
| Key generation | Hash + collision retry | Counter/KGS (no hot-path collision) | **Counter-in-ranges** — moves coordination off per-write path |
| Redirect code | 301 (client-cached, fast) | 302 (server-hit, countable) | **302** — enables analytics, expiry, mutable targets |
| Store | Relational | Wide-column KV | **KV** — pure point lookups, easy read scaling |
| Analytics | Synchronous count | Async event stream | **Async** — never block the redirect |
| Consistency | Strong global | Read-your-writes + eventual | **RYW** — creator sees own link; others tolerate lag |

- **Primary bottleneck:** redirect read QPS (100K+/s). Mitigated by making it cache/CDN-first so the DB sees only misses; the DB is a horizontally-sharded KV so even miss traffic spreads evenly.
- **Secondary bottleneck:** the key-minting coordination point. Mitigated by ID ranges / a KGS buffer so no per-write global lock.
- **Hot-key risk:** a viral link overwhelming one cache shard — mitigated by local caches and hot-entry replication.
- **Write-path race:** concurrent custom-alias claims — mitigated by a unique constraint / conditional write (compare-and-set), returning `409` on conflict.

## Related
[[unique-id-generation]]
[[caching-strategies]]
[[database-indexing]]
[[sql-vs-nosql]]
[[cdn]]
[[consistent-hashing]]
[[rate-limiting]]
[[read-your-writes-consistency]]
[[load-balancing]]
[[api-gateway]]
[[partitioning-sharding]]
