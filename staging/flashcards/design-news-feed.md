---
id: design-news-feed
type: system-design
tags:
  - system-design
  - feed
  - fan-out
  - timeline
  - distributed
tiers:
  system-design: 3
created: 2026-09-11
confidence: high
priority: normal
---

# Design News Feed / Timeline

A per-user home timeline that aggregates posts from everyone you follow, ranked and delivered in low tens of milliseconds. The crux is a write-vs-read tension: precompute each timeline on write (fast reads, brutal fan-out for high-follower accounts) or assemble it on read (cheap writes, expensive reads) — real systems do neither purely.

> [!tip] Interview signals
> The interviewer is really probing two decisions: (1) fan-out-on-write vs fan-out-on-read, and whether you reach for the **hybrid** unprompted, and (2) how you handle the **celebrity / hot-user** problem where one write must reach tens of millions of followers. Curveballs: "a celebrity with 90M followers posts — what happens?", "how does a new post appear without the user refreshing?", "how do you keep the feed consistent if fan-out is async and lands out of order?", "how do you rank without blowing the latency budget?". Junior answers pick one fan-out model and stop. Senior answers name the write-amplification cost with a number, split users by follower count, merge precomputed + pull-on-read paths at query time, and treat ranking as a separate stage with a cheap online model over a candidate set.

## Problem & Requirements

**Clarifying questions a strong candidate asks first**
- Home timeline (people you follow) or user/profile timeline (one author's posts)? We design the **home timeline** — that's the hard one.
- Chronological or ranked/relevance order? Assume **ranked**, with recency as the dominant signal.
- Posts only, or replies/reposts/quotes too? Scope to root posts + reposts.
- Read-heavy? Yes — pull-to-refresh and infinite scroll dominate.
- Eventual consistency on feed freshness acceptable? Yes (seconds of lag is fine); the post itself must be durable immediately.
- Follower distribution? Heavy power law — median user has hundreds of followers, top accounts have tens of millions.

**Functional**
- Publish a post (text + media refs).
- Follow / unfollow users.
- Fetch home timeline (paginated, ranked, newest-ish first).
- New posts surface into followers' feeds within seconds.

**Non-functional**
- Scale: ~200M DAU, ~500M posts/day.
- Latency: home-timeline read **p99 < 200 ms**; post publish acknowledged in < 500 ms.
- Availability > 99.9%; reads must stay up even if fan-out lags (favor availability + eventual consistency for feed delivery, per CAP).
- Feed freshness lag: seconds, not minutes.

## Estimation

- **DAU** 200M; each opens the feed ~10x/day → **2B feed reads/day** ≈ **23K read QPS avg**, peak ~3x ≈ **70K QPS**.
- **Writes (posts):** 500M/day ≈ **5.8K write QPS avg**, peak ~15K QPS. **Read:write ≈ 4:1** — read-dominated, which argues for precompute (fan-out-on-write).
- **Fan-out amplification (the number that matters):** average followers ≈ 300. Naive fan-out-on-write = 5.8K posts/s × 300 = **~1.7M timeline inserts/sec** at average. That's the baseline cost — and it's dominated by the tail: one celebrity post at 90M followers is 90M inserts, i.e. as much fan-out as ~50s of average traffic in a single event. This tail is exactly why pure fan-out-on-write fails and why hot users get pulled instead.
- **Storage — post bodies:** 500M/day × ~1 KB ≈ 500 GB/day ≈ **180 TB/yr** (metadata; media lives in object storage / CDN, far larger).
- **Storage — materialized feeds (cache):** keep ~800 post-IDs per active user in a Redis feed list. IDs+score ≈ 20 B → 16 KB/user × 200M active ≈ **3.2 TB** in RAM, sharded across the cluster. Store IDs only, hydrate bodies from a separate cache.
- **Bandwidth (read):** 70K QPS × ~20 posts/page × 1 KB ≈ **1.4 GB/s** egress for text; media served from CDN.

## API Design

- `POST /v1/posts` — body `{text, mediaIds[]}`; returns `{postId, createdAt}`. Idempotency-Key header to dedupe client retries.
- `GET /v1/feed?cursor=<opaque>&limit=20` — returns `{items:[{postId, authorId, score, ...}], nextCursor}`. Cursor-based (score + postId), never OFFSET.
- `POST /v1/follows` — `{targetUserId}` → `{status}`.
- `DELETE /v1/follows/{targetUserId}`.
- `GET /v1/users/{id}/posts?cursor=&limit=` — user/profile timeline (simple: query by author, always pull).

## Data Model & Storage

**Core entities**
- `posts(post_id PK, author_id, text, media_ids, created_at)` — **unique_id-generation** gives k-sortable IDs (Snowflake-style: time-ordered), so a feed sort by ID ≈ sort by time and pagination cursors are stable.
- `follows(follower_id, followee_id, created_at)` — the edge; queried both directions (who I follow; who follows me for fan-out).
- `user_feed` — the **materialized home timeline**: ordered list of `(post_id, score)` per user, held in Redis (sorted set), truncated to ~800 entries.

**Choices**
- Posts + follows: **NoSQL / wide-column (Cassandra-style)** partitioned by `author_id` (posts) and `follower_id` (follows). Reason: massive write volume, simple key-based access, horizontal scale, no cross-entity joins on the hot path. Partition/shard key = the ID you always read by. (SQL is fine at smaller scale; this is the tier-3 scale answer — see [[sql-vs-nosql]], [[partitioning-sharding]].)
- **follows** is stored twice — by follower and by followee — because fan-out needs "all followers of X" fast and feed-read needs "all I follow" fast. Denormalize to match both access patterns.
- Feed lists live in Redis for O(1) push and range reads; the durable source of truth is the posts store, so a lost cache is rebuildable.

## High-Level Design

Client → **load balancer** → API gateway → services:

**Write path (publish):**
1. Client `POST /posts` → **Post Service** writes to the posts store (durable ack here).
2. Post Service emits a `PostCreated` event to a **Kafka** topic (durable log; decouples publish latency from fan-out cost).
3. **Fan-out workers** (consumers) look up the author's followers and, for normal users, **push the post_id into each follower's Redis feed list** (fan-out-on-write). For **hot users, they do nothing** — those posts are pulled at read time.
4. A new-post signal is pushed to online followers via WebSocket/long-poll for the "N new posts" pill.

**Read path (fetch feed):**
1. Client `GET /feed` → **Feed Service**.
2. Read the user's precomputed Redis feed list (the fan-out-on-write portion).
3. **Merge in** fresh posts from the handful of **hot users** this person follows (fan-out-on-read for celebrities only): fetch each celebrity's recent posts (small, heavily cached) and k-way merge with the precomputed list.
4. **Hydrate** post_ids → bodies from the post-body cache (batch mget), fall back to store on miss.
5. **Rank** the merged candidate set, apply pagination cursor, return.

Media URLs point at **object storage** fronted by a **CDN**, so post bodies stay tiny and images/video never touch the feed services.

## Deep Dives

### Fan-out-on-write vs fan-out-on-read vs hybrid (the central trade-off)

- **Fan-out-on-write (push):** on publish, append the post to every follower's materialized feed. **Reads are trivial** (read one list) — great for a read-dominated (~4:1) workload. But **write amplification = follower count**, and a celebrity post = tens of millions of writes, causing latency spikes, hot shards, and wasted work on inactive followers.
- **Fan-out-on-read (pull):** store nothing precomputed; at read time gather posts from everyone the user follows and merge. **Writes are trivial**, but reads must scatter-gather across hundreds of authors — too slow for p99 < 200 ms at the median.
- **Hybrid (the answer):** classify authors by follower count against a threshold (e.g. > ~100K followers = "hot"). **Normal authors → push** (their fan-out is cheap and reads stay one-list-fast). **Hot authors → pull**: skip fan-out on write, and at read time fetch their recent posts (a short, aggressively-cached set — few thousand celebrities globally) and merge into the reader's precomputed feed. This bounds write amplification (no 90M-insert storms) while keeping reads to "read one list + merge a small pull set." Threshold is tunable per follower distribution; some systems also skip push to *inactive* followers to cut waste further.

### Feed caching

- **Two cache layers:** (a) per-user **feed lists** = Redis sorted sets of `(post_id, score)`, truncated to ~800; (b) **post-body cache** = post_id → rendered post, shared across all feeds so a viral post is stored once and hydrated by mget, not copied per follower.
- **Rebuild / cold start:** on a cold feed (new user, evicted list), fall back to pull-and-merge and lazily repopulate.
- **Truncation** caps memory and matches behavior — nobody scrolls past ~800; older pages fall through to the store.
- **Hot-body protection:** a viral post is a hot key in the body cache; replicate it across nodes / use a local in-process cache to avoid a single-node hotspot. See [[caching-strategies]].

### Ranking

- **Two stages: candidate generation then scoring.** Fan-out (push list + celebrity pull) produces a bounded candidate set (hundreds), so ranking never scans the world.
- **Online scoring** applies a cheap model over recency + affinity (past interaction with author) + engagement priors + media type. Keep it inside the latency budget — heavy ML features are precomputed offline and looked up, not computed per request.
- Store the score in the sorted set so pagination is score-ordered and stable; chronological is the degenerate case (score = timestamp).

## Trade-offs & Bottlenecks

| Decision | Option A | Option B | Choice & why |
| --- | --- | --- | --- |
| Feed assembly | Fan-out-on-write | Fan-out-on-read | **Hybrid** — push for normal users (fast reads), pull for hot users (bounds write amplification) |
| Feed store | Redis materialized lists | Compute from posts each read | **Redis lists** — read:write is ~4:1, precompute wins; posts store is the rebuildable source of truth |
| Post IDs | Auto-increment | **Snowflake k-sortable** | Time-ordered IDs give free chronological sort + stable cursors, no global counter bottleneck |
| Feed delivery consistency | Strong | **Eventual** | Seconds of lag acceptable; async fan-out via Kafka keeps publish fast and reads available (CAP: AP) |
| Media | Inline | **Object storage + CDN** | Keeps post bodies ~1 KB and offloads egress from feed services |

**Bottlenecks & mitigations**
- **Celebrity fan-out storm** — one post → tens of millions of writes. *Mitigation:* the hybrid pull path (no push for hot users); Kafka absorbs any remaining bursts with consumer backpressure.
- **Hot keys in the body cache** (viral post) — single-node overload. *Mitigation:* replicate hot entries / local caching; store body once, not per follower.
- **Fan-out lag / out-of-order landing** — async inserts can arrive late. *Mitigation:* order by k-sortable post_id at read time, so ranking is correct regardless of insert order; fan-out is idempotent (insert-if-absent) to tolerate retries.
- **Feed shard hotspots** — celebrities' followers cluster load. *Mitigation:* consistent hashing across the Redis cluster; hot users bypass push entirely.

## Related

- [[caching-strategies]]
- [[message-queues]]
- [[kafka-log-based-messaging]]
- [[partitioning-sharding]]
- [[cdn]]
- [[load-balancing]]
- [[object-storage]]
- [[unique-id-generation]]
- [[consistent-hashing]]
- [[cap-theorem]]
- [[sql-vs-nosql]]
- [[websockets-and-realtime]]
- [[backpressure-and-bulkhead]]
