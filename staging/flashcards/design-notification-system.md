---
id: design-notification-system
type: system-design
tags:
  - system-design
  - notifications
  - fan-out
  - message-queues
  - distributed
tiers:
  system-design: 2
created: 2026-09-11
confidence: high
priority: normal
---

# Design a Notification System

A service that delivers push, SMS, and email notifications to hundreds of millions of users, triggered by internal events (a comment, an order shipped) or scheduled campaigns. The crux is not "send a message" — it is decoupling producers from unreliable third-party providers while honoring user preferences, and getting delivery semantics right (at-least-once transport, at-most-once *effect*) across channels that each have their own failure modes and rate limits.

> [!tip] Interview signals
> The two hard decisions the interviewer wants you to reach on your own: (1) put a durable queue between event producers and channel workers so a flaky Apple/Twilio endpoint can't back-pressure the whole system, and (2) idempotency — the same event must never dedupe into two pushes. Classic curveballs: "APNs is down for 20 minutes, where do the messages go?" (answer: retries with backoff, then a dead-letter queue, not dropped); "a viral event fans out to 10M users at once — how do you not melt your SMS provider?" (per-provider rate limiting + backpressure); "user opted out of marketing but this is a security alert — how do you know the difference?" (notification categories, not a single on/off). Junior answer wires producers straight to the provider SDK. Senior answer treats providers as failure domains and designs the queue/retry/dedup layer around that.

## Problem & Requirements

Scope-narrowing questions a strong candidate asks first:
- Which channels? (assume push/iOS+Android, SMS, email — extensible to more)
- Transactional vs marketing? (both; they have different urgency, opt-out, and rate rules)
- Delivery guarantee? (at-least-once delivery with dedup so users perceive at-most-once)
- Do we need read receipts / open tracking? (email opens + push delivery receipts — yes, best-effort analytics, not on the critical path)
- Is ordering required? (no strict global ordering; best-effort per-user is enough)
- Scale target?

Functional:
- Accept notification requests from many internal services via one API.
- Resolve recipient → device tokens / phone / email; apply user preferences and opt-out.
- Fan out to the right channels and hand off to third-party providers (APNs, FCM, Twilio, SES/SendGrid).
- Retry transient failures; dead-letter permanent ones.
- Template rendering + basic scheduling.

Non-functional:
- Scale: ~10M notifications/day baseline, bursty to campaign spikes.
- Latency: transactional push/SMS delivered p95 < a few seconds end-to-end; marketing can be minutes.
- Availability: 99.9%+; a single provider outage must not lose messages.
- Reliability: no lost transactional notifications; no duplicate *perceived* deliveries.

## Estimation

- Assume **10M notifications/day**. Average QPS = 10M / 86,400 ≈ **116/s**. Peak (campaign burst / evening spike, ~5x) ≈ **~600/s**.
- Channel mix, say push 70% / email 25% / SMS 5%. So peak push ≈ 420/s, email ≈ 150/s, SMS ≈ 30/s.
- Read:write — notifications are almost pure write from the system's view. Preference/token *reads* happen once per send (with caching): ~600 reads/s at peak, easily cached.
- Storage: log every notification for dedup + analytics. Row ≈ 500 B (ids, channel, status, timestamps). 10M/day × 500 B = **5 GB/day** ≈ **1.8 TB/yr**. Push tokens: 200M devices × ~100 B ≈ **20 GB**, hot, kept in a fast store.
- Bandwidth is trivial for the payloads themselves (a push is ~1 KB); the cost is per-message provider fees and connection management, not bytes.
- Takeaway: this is a **throughput + fan-out + reliability** problem, not a storage or bandwidth problem. Queues and worker pools dominate the design.

## API Design

- `POST /v1/notifications` — enqueue a notification.
  - body: `{ event_id, user_id, category, template_id, data{}, channels?[], dedup_key? }`
  - `dedup_key` (or `event_id`) makes the call idempotent.
  - returns: `202 Accepted { notification_id }` (async — we accept and durably enqueue, we do not deliver synchronously).
- `GET /v1/notifications/{id}` — status: `queued | sent | delivered | failed | suppressed`.
- `PUT /v1/users/{id}/preferences` — per-category, per-channel opt-in/out.
- `POST /v1/devices` — register/refresh a push token: `{ user_id, platform, token }`.

Internal/admin: `POST /v1/campaigns` for bulk fan-out (accepts a segment, expands server-side).

## Data Model & Storage

Core entities:
- **device_token**(user_id, platform, token, last_seen) — key store, sharded by user_id. Access pattern is point lookup by user_id; a KV/NoSQL store (or Cassandra/DynamoDB) fits — high write churn (tokens rotate), no joins.
- **preferences**(user_id, category, channel, enabled) — same shape, cached aggressively behind the send path.
- **notification_log**(notification_id, dedup_key, user_id, channel, status, provider_msg_id, attempts, created_at) — wide, append-heavy, queried by dedup_key and by id. NoSQL/wide-column, partitioned by `dedup_key`-hash for the dedup lookup and TTL'd (e.g. 30–90 days) since old rows have no value.
- **templates** — small, relational or a config store; low write volume.

SQL vs NoSQL: the two high-volume tables (tokens, log) are point-access, schemaless-ish, and need horizontal write scaling with no cross-entity joins — [[sql-vs-nosql]] favors NoSQL here. Templates/campaigns are low-volume relational config; a small SQL store is fine. Sharding key throughout is `user_id` (co-locates a user's tokens + prefs) except the dedup table which shards on `dedup_key` so the idempotency check is a single-partition read.

## High-Level Design

```
producers → Notification API → [ingest queue] → Fan-out service → per-channel queues → channel workers → providers → devices
                                     │                                                      │
                              preference/token store                              retries + dead-letter queue
```

Write path (a service emits an event):
1. Producer calls `POST /v1/notifications`. The API validates, computes/accepts a `dedup_key`, does the idempotency check (see deep dive), and **durably enqueues** to an ingest topic ([[message-queues]] / [[kafka-log-based-messaging]]). It returns `202` immediately — providers are slow and unreliable, so nothing blocks on them.
2. The **Fan-out service** consumes ingest events. For each, it resolves recipient tokens + preferences (cached), filters channels by opt-out and category rules, renders templates, and emits one message per (recipient, channel) onto the **per-channel queue** (push-queue, sms-queue, email-queue). Separate queues per channel = independent scaling and blast-radius isolation.
3. **Channel workers** (one pool per channel) consume their queue and call the third-party provider. On success, mark `sent`/store `provider_msg_id`. On transient failure, retry with backoff ([[retries-and-timeouts]]); on permanent failure or retry exhaustion, route to a dead-letter queue.

Read path: `GET /notifications/{id}` is a single point read against notification_log. Delivery receipts / email opens arrive via provider webhooks and asynchronously update status — off the critical path.

Building blocks in play: [[load-balancing]] in front of the API, [[caching]] for tokens/prefs, [[message-queues]] as the decoupling spine.

## Deep Dives

### 1. Fan-out + provider integration behind queues

Fan-out is 1 event → N recipients → up to N×channels messages. Doing this inline in the API request would couple request latency to provider latency and let one slow provider stall everything. Instead: ingest queue → fan-out workers → **per-channel queues** → channel worker pools. Each channel worker owns a persistent connection pool to its provider (e.g. HTTP/2 multiplexed streams to APNs) and enforces a **per-provider rate limit** so a burst never exceeds what Twilio/SES will accept. When a channel's provider slows or 429s, that channel's queue absorbs the backlog ([[backpressure-and-bulkhead]]) while other channels keep flowing — the bulkhead. Workers scale independently by queue depth.

Retries: on `5x`/timeouts, retry with exponential backoff + jitter ([[retries-and-timeouts]]); respect provider `Retry-After` on [[rate-limiting]] responses. Cap attempts (e.g. 5); on exhaustion move the message to a **dead-letter queue** for inspection/manual replay — never silently drop a transactional notification.

### 2. Idempotency / dedup (at-most-once *effect*)

Queues give at-least-once delivery: the same message can be consumed twice (redelivery after a worker crash, or a producer retrying `POST`). Users must not see the notification twice. Two guards:
- **At ingest:** every request carries a `dedup_key` (natural: `event_id`, or client-supplied). The API does a conditional write (`INSERT IF NOT EXISTS` / `SETNX`) into the dedup table keyed by `dedup_key`. Duplicate → we return the existing `notification_id` and don't re-enqueue. This is standard [[idempotency]].
- **At the worker:** before calling the provider, check/mark `(dedup_key, channel)` as sent with a conditional write; only the winner calls the provider. This closes the window where two workers pick up redeliveries of the same message.

Alternatives considered: relying on provider-side dedup (APNs `collapse-id`, SES) — helps but is per-provider and doesn't cover cross-channel or the enqueue path, so it's a supplement, not the primary mechanism. Exactly-once *transport* is effectively impossible across third parties; we get at-least-once transport + idempotent effect, which is the honest senior answer.

## Trade-offs & Bottlenecks

| Decision | Choice | Trade-off |
|---|---|---|
| Sync vs async send | Async (`202`, enqueue) | Decouples from slow providers, absorbs bursts; cost: caller can't know delivery synchronously (status via GET/webhook) |
| One queue vs per-channel | Per-channel queues + worker pools | Isolation + independent scaling; cost: more infra/ops surface |
| Delivery guarantee | At-least-once + idempotent dedup | Simple, robust; cost: dedup store + conditional writes on the hot path |
| Token/pref store | NoSQL, sharded by user_id | Horizontal write scaling, point reads; cost: no ad-hoc joins/analytics |
| Retry policy | Backoff + jitter, cap, then DLQ | No lost messages, no retry storms; cost: latency tail on failures, DLQ to operate |

Bottlenecks under scale:
- **Third-party provider limits** are the real ceiling. Mitigate with per-provider rate limiting, connection pooling, multiple provider accounts/regions, and fallback providers (e.g. secondary SMS gateway).
- **Hot fan-out** (one campaign → 10M recipients) can flood a channel queue. Mitigate by expanding campaigns in batches (chunked producers), prioritizing transactional over marketing via separate high/low-priority queues, and shedding/deferring marketing load first.
- **Dedup store on the hot path** — every send does a conditional write. Mitigate by sharding on `dedup_key`, keeping it in a fast KV store with TTL, and sizing for peak write QPS.
- **Preference/token lookups** — cache with short TTL; a token-store outage should fail safe (retry, don't drop transactional).

## Related
[[message-queues]]
[[kafka-log-based-messaging]]
[[retries-and-timeouts]]
[[idempotency]]
[[rate-limiting]]
[[backpressure-and-bulkhead]]
[[caching]]
[[sql-vs-nosql]]
[[load-balancing]]
