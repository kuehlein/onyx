---
id: design-search-autocomplete
type: system-design
tags:
  - system-design
  - autocomplete
  - typeahead
  - read-heavy
  - low-latency
tiers:
  system-design: 2
created: 2026-09-11
confidence: high
priority: normal
---

# Design Search Autocomplete / Typeahead

The suggestion dropdown that appears as a user types into a search box, returning the top few completions for the current prefix (e.g. "sys" -> "system design", "system of a down"). The crux is not "match a prefix" — it is returning ranked top-k suggestions within a punishing **per-keystroke latency budget** while the underlying popularity data changes constantly.

> [!tip] Interview signals
> The interviewer is really probing two decisions: (1) **where does the ranking work happen** — do you rank/aggregate at query time, or precompute the top-k for every prefix so a request is a near-pure lookup? — and (2) **how do you meet a sub-100ms budget on every keystroke** at massive read QPS. The senior answer inverts the naive design: reads must be O(1)-ish cache/edge lookups, and all the expensive counting/ranking is pushed to an **offline (or near-line) aggregation pipeline** that rebuilds the index. Classic curveballs: "how fast do trending queries show up?" (freshness vs cost), "how do you handle typos / fuzzy matching?", "personalized vs global suggestions", "how do you shard when the whole English keyspace won't fit on one node?", and "how do you keep offensive/PII strings out of suggestions?". The junior answer walks a trie at request time; the senior answer names the precompute-vs-query-time trade-off and treats the trie build as a batch job.

## Problem & Requirements

**Clarifying questions a strong candidate asks first:**
- **Global or personalized** suggestions? (Personalization multiplies the cardinality and kills a shared cache.)
- Exactly **prefix** matching, or do we need fuzzy / mid-word / typo tolerance? (Changes the whole index.)
- How many suggestions per request — top **5? 10?** (Sizes the precomputed payload.)
- How **fresh** must trending terms be — seconds, minutes, hours? (Sets the pipeline cadence: stream vs batch.)
- Do we return suggestions from the **very first character**, or only after N chars? (First-char prefixes are the hottest and biggest.)
- Any content filtering (profanity, PII, legal takedowns)?

**Functional:**
- `suggest(prefix) -> [top-k completions]`, ordered by relevance (usually historical frequency).
- Suggestions update over time as query popularity shifts (trending).
- Optional: content filtering; per-locale/language results.

**Non-functional:**
- **Latency is the headline requirement:** each keystroke fires a request; end-to-end p99 must feel instant. Budget the server side at **~50ms p99** (network + render eat the rest of the ~100ms perceived budget).
- Scale: read-dominated, very high QPS (every keystroke of every searcher).
- Availability: high (99.9%+), but a missed/slow suggestion **degrades gracefully** (empty dropdown) rather than failing the page — it's an assistive feature.
- Consistency: **eventual** is fine. Nobody needs a query typed one second ago to appear in suggestions instantly; minutes-to-hours of lag on the ranking is acceptable.

## Estimation

Assume a large search product: a **100M DAU** typing base doing **~500M searches/day** (100M × ~5).

- **Read QPS (the number that matters):** ~100M DAU, each typing say ~5 searches/day averaging ~15 keystrokes, and we fire a request roughly every keystroke (after light client debounce, call it 1 request per 3 keystrokes → ~5 requests/search) → 100M × 5 × 5 ≈ **2.5B suggestion requests/day** → 2.5B / 86,400 ≈ **~29K rps** average, peak ~5x ≈ **~145K rps**. This read volume is why query-time ranking is a non-starter.
- **Read:write skew:** suggestion *lookups* (~2.5B/day) vs *completed searches* that feed the ranking pipeline (~500M/day) — already **~5:1** at the raw-log level, and the write side is a batch ingest, not a hot path. The gap that matters is on latency, not just volume: every lookup is a synchronous sub-100ms request, while the write side is amortized offline. (The count of *distinct* strings whose ranking actually shifts per rebuild is far smaller still.)
- **Client debounce** (fire only ~50ms after a keystroke pause, and cancel in-flight requests) cuts real request volume meaningfully — worth stating, since it directly reduces that 145K peak.
- **Trie / index size:** if we keep, say, the top ~10M distinct query strings, avg ~20 bytes each plus the precomputed top-k list per node (k=5 suggestions × ~20 bytes ≈ 100 bytes) → on the order of **a few GB** for the core structure. Small enough to hold **in memory**, which is mandatory to hit the latency budget — but big enough that with replicas and multiple languages it wants sharding.
- **Bandwidth:** each response is ~5 suggestions × ~30 bytes ≈ **~150–300 bytes**. 145K rps × ~300B ≈ **~40 MB/s** egress — trivial in bytes; the cost is request *rate*, not size.

## API Design

- `GET /api/v1/suggest?q={prefix}&limit=10&locale=en-US` → `200 { suggestions: [ {text, score?}, ... ] }`. This is the only hot endpoint; it is anonymous, idempotent, and heavily cached.
- `GET /api/v1/suggest?q={prefix}` responses are safe to cache at the [[cdn]]/edge and in the browser with a short TTL, keyed on `(prefix, locale)`.
- (Internal, not user-facing) `POST /internal/index/publish` — the pipeline swaps in a freshly built trie snapshot for the serving tier to load.

Design notes that earn signal: set aggressive `Cache-Control` on responses, and have the client **debounce + cancel stale in-flight requests** so a fast typist doesn't spray the backend.

## Data Model & Storage

There are two distinct stores because there are two distinct workloads:

**1. Serving index (read path) — the trie.**
Core structure is a **trie (prefix tree)** where each node represents a prefix. The senior move: **store the precomputed top-k suggestions *on each node*** (or on the terminal nodes for a prefix), so answering a request is "navigate to the prefix node, read its cached top-k list" — no subtree traversal at query time. In practice this is often materialized as a flat **prefix → top-k** key-value map (a hash map / KV store) derived from the trie, which is even cheaper to shard and cache than a live tree.

| entity | key | value | notes |
|---|---|---|---|
| `prefix_topk` | `(locale, prefix)` | ordered list of ≤k `{text, score}` | precomputed; the hot read |
| `query_counts` | `query_string` | aggregated frequency/score | pipeline input, not read-path |

**SQL vs NoSQL:** the read path is a pure **prefix → value point lookup** with no joins or ad-hoc queries — a textbook fit for an **in-memory KV store** (the trie itself, backed by Redis/Memcached or an embedded structure in each server). The raw query logs and aggregates live in a big-data store (object storage / a columnar warehouse) for the batch job, not a relational OLTP DB. See [[sql-vs-nosql]].

**Partitioning:** shard the trie **by prefix**, typically on the **first character(s)**. This keeps every completion for a prefix co-located on one shard, so a lookup touches exactly one node — but first-character distribution is skewed ("s"/"a" are huge, "z"/"q" tiny), so naive first-letter sharding creates hotspots. Mitigate by sharding on a **hash of the prefix** (even spread, [[consistent-hashing]]) or by splitting hot letters onto more shards with a routing map. See [[partitioning-sharding]].

## High-Level Design

**Read (suggest) path — the hot one:**
`client -> CDN/edge -> LB -> Suggest Service -> in-memory trie shard (cache) -> KV (fallback)`
1. Client debounces keystrokes and issues `GET /suggest?q=sys`. Popular `(prefix, locale)` responses are served straight from the [[cdn]] / browser cache — the request never reaches origin.
2. On edge miss, the [[load-balancing]] tier routes to a stateless Suggest Service, routed to the trie shard owning that prefix.
3. The shard holds the trie **in memory** with precomputed top-k per node → it reads the top-k list and returns it. This is the O(prefix length) walk to a node plus a copy of a tiny list — well inside the latency budget. See [[caching-strategies]].
4. If a node isn't warm, fall back to the backing KV; still a single point lookup.

**Write (index build) path — the cold one:**
`query logs -> stream/collector -> offline aggregation pipeline -> build ranked trie -> publish snapshot -> serving tier loads`
1. Every executed search is logged to a stream/collector and lands in a data lake ([[object-storage]]).
2. An **offline aggregation pipeline** ([[batch-vs-stream-processing]]) periodically (e.g. hourly) aggregates counts per query string (map-reduce / Spark), applies decay so recent activity weighs more, filters banned/PII strings, and computes the **top-k for every prefix**.
3. It builds a fresh trie / `prefix→top-k` snapshot and **publishes it atomically** — serving nodes load the new snapshot and swap it in (double-buffer so reads never see a half-built tree).
4. For faster trending, a lightweight **streaming** layer can nudge counts between full rebuilds — the classic freshness-vs-cost lever.

## Deep Dives

### 1. Precompute top-k per prefix vs compute at query time
The naive design walks the subtree under the prefix node at request time, collects all completions, and sorts by score to get top-k. That is **far too slow** on the hot path: a short prefix like "a" has an enormous subtree, and you'd pay that cost on **every keystroke at ~145K rps**. It also makes latency wildly variable (short prefixes = huge subtrees).

The fix is to **precompute and cache the top-k list on each trie node** during the offline build. At request time the server navigates to the node (O(prefix length)) and returns the stored list — constant, tiny work regardless of subtree size. The cost is **space** (every node stores k entries) and **staleness** (the lists are only as fresh as the last build), both acceptable given the budget and eventual-consistency latitude. This is the single most important design decision in the problem: it converts an expensive top-k ranking query into a flat lookup. (Top-k computation itself is done once, offline, per node — typically with a bounded heap.)

### 2. Offline aggregation & the freshness/cost trade-off
Rankings come from historical query frequency, which changes constantly (breaking news, trends). You *cannot* recount on every read. Options:
- **Pure batch (e.g. hourly/daily):** cheap, simple, robust; trending terms lag by the rebuild interval. Good default.
- **Streaming top-k updates:** keep approximate counts (e.g. **count-min sketch** for heavy hitters) updated in near-real-time and patch the hottest prefixes between batch rebuilds; catches trends in seconds at higher complexity/cost.
- **Hybrid (recommended):** batch job owns the full, correct trie; a streaming layer overlays fresh trending terms. This is the realistic senior answer — most prefixes are stable and served from the batch snapshot; only the volatile head needs streaming.
Apply **time-decay** so a query popular last year doesn't outrank a current trend, and run **content filtering** (profanity/PII/legal) in this pipeline, never at read time.

### 3. Sharding the trie by prefix
The full multi-language trie won't fit or serve from one node, so shard it. Sharding **by prefix** keeps a prefix's completions on one shard (single-shard lookups), but first-character skew makes some shards hot. Mitigations: **hash-based sharding** of the prefix for even load (with a routing layer, since you lose the natural prefix locality and must route by exact prefix key), or keep first-char sharding but **split hot letters across more shards**. Replicate each shard for read QPS and availability; because data is immutable between publishes, replicas are trivially consistent and you can add read replicas freely to absorb the 145K-rps peak.

## Trade-offs & Bottlenecks

| Decision | Option A | Option B | Choice & why |
|---|---|---|---|
| Ranking work | Compute top-k at query time | **Precompute top-k per node** | **Precompute** — only way to hit the per-keystroke budget |
| Index freshness | Pure batch rebuild | Batch + streaming overlay | **Hybrid** — cheap base + fast trending head |
| Serving store | On-disk DB | **In-memory trie / KV** | **In-memory** — latency budget demands no disk on hot path |
| Shard key | First-character prefix | Hash of prefix | **Hash (or split hot letters)** — avoid "s"/"a" hotspots |
| Consistency | Strong/real-time | Eventual (minutes lag) | **Eventual** — suggestions tolerate staleness |
| Redirect of load | Server-only | CDN/edge + client debounce | **Edge + debounce** — shed most request volume before origin |

- **Primary bottleneck:** suggestion read QPS (100K+/s) against a strict latency budget. Mitigated by serving from an in-memory trie, precomputed top-k, heavy CDN/edge caching, and client-side debounce + request cancellation.
- **Secondary bottleneck:** the offline rebuild cost and lag. Mitigated by incremental/streaming updates for the trending head and time-decayed batch for the stable body.
- **Hotspot risk:** skewed prefix distribution overloading a shard — mitigated by hash sharding or splitting hot letters, plus read replicas.
- **Availability posture:** the feature degrades to an empty dropdown on failure rather than breaking search — so aggressive caching and best-effort serving are acceptable.

## Related
[[caching-strategies]]
[[search-and-inverted-index]]
[[batch-vs-stream-processing]]
[[cdn]]
[[load-balancing]]
[[partitioning-sharding]]
[[consistent-hashing]]
[[object-storage]]
[[sql-vs-nosql]]
