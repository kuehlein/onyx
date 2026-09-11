---
id: design-chat-system
type: system-design
tags:
  - system-design
  - realtime
  - messaging
  - distributed
tiers:
  system-design: 3
created: 2026-09-11
confidence: high
priority: normal
---

# Design a Chat System

A messaging service (WhatsApp/Messenger-style) supporting 1:1 and group chats, delivered in near real time with ordering, delivery/read receipts, presence, and reliable offline delivery. The crux: keeping tens of millions of **stateful, long-lived connections** healthy while guaranteeing that every message is delivered **exactly once and in a sensible order** to recipients who may be on any of thousands of connection servers — or offline entirely.

> [!tip] Interview signals
> The interviewer is really probing two hard decisions. (1) **How do you route a message to a recipient's live connection** when senders and receivers are pinned to different connection servers? Weak answers hand-wave "send it to them"; senior answers name a session registry (which server holds which user) plus a per-user inbox as the durable source of truth. (2) **What is the durable delivery + ordering model** — is the message queue the storage, or is the DB the storage and the queue just a nudge? Classic curveballs: *group message to 100k members* (fan-out on write vs read), *user online on 3 devices* (multi-device sync + per-device cursors), *message sent while recipient offline then reconnects on a different server*, *two messages sent within the same millisecond* (ordering / ID generation), and *exactly-once vs at-least-once + client dedup*. The junior/senior split is treating the socket as reliable transport (it isn't) versus designing an ack'd, resumable, idempotent pipeline where the persistent store — not the WebSocket — is the source of truth.

## Problem & Requirements

**Clarifying questions a strong candidate asks first:**
- 1:1 only, or groups too? Max group size? (Assume both; groups up to ~500 members for full fan-out, "large groups"/broadcast handled separately.)
- Multi-device per user? (Yes — phone + web + tablet, must stay in sync.)
- Do we store full message history server-side, or is it E2E-encrypted / device-only? (Assume server stores history; E2E noted as a trade-off.)
- Are ordering guarantees per-conversation or global? (Per-conversation ordering only — global ordering is unnecessary and expensive.)
- Media (images/video/voice) in scope? (Yes but out-of-band via object storage + CDN; the chat path carries only pointers.)
- Delivery + read receipts and typing/presence indicators required? (Yes.)

**Functional**
- Send/receive 1:1 and group messages in near real time.
- Delivery receipts (sent → delivered → read) and typing indicators.
- Online/last-seen presence.
- Offline delivery: buffer messages and push (APNs/FCM) when the recipient is disconnected.
- Message history / sync across a user's devices.

**Non-functional**
- **Scale:** ~50M DAU, tens of millions of concurrent connections.
- **Latency:** message end-to-end p99 < ~300 ms when both parties online.
- **Availability:** high (99.99%); a chat outage is very visible.
- **Consistency:** per-conversation ordering + at-least-once delivery with client-side dedup ⇒ effectively exactly-once at the app layer. No message loss (durable before ack).
- **Durability:** messages persisted before the sender is told "sent."

## Estimation

Assume 50M DAU, each sending 40 messages/day.

- **Writes (messages/sec):** 50M × 40 = 2B messages/day ≈ **23K msg/s average**. Peak ≈ 5× ⇒ **~115K msg/s**.
- **Read:write:** with delivery/read receipts and group fan-out, reads dominate. Take a modest 1:1 conversational read ratio plus fan-out: effective delivered events ≈ 3–5× writes ⇒ **~70–115K delivered/s avg**, higher at peak.
- **Concurrent connections:** if ~40% of DAU are connected at once ⇒ **~20M concurrent WebSockets**. At ~100K stable connections per connection server (tuned kernel + epoll), that's **~200 connection servers** just for the front tier (plus headroom, call it 300–400).
- **Storage:** avg message ~200 bytes (text + metadata; media excluded). 2B/day × 200 B = **~400 GB/day** ≈ **~146 TB/yr** of message rows, before replication. Presence/receipt metadata adds ~20–30%. Media lives in object storage, sized separately.
- **Bandwidth:** 115K msg/s peak × ~300 B on the wire ≈ **~35 MB/s** for the message path (small); connection keep-alives/heartbeats dominate socket overhead, not payload.

Takeaway: message *payload* is cheap; the cost centers are **connection count** (fan-out of stateful sockets) and **storage growth** of history.

## API Design

Real-time path is over a persistent WebSocket after auth; a REST/HTTP surface handles setup and history.

- `POST /v1/connect` → issues a signed connection token; client then opens `wss://…/ws?token=…`. Server does a `service-discovery` lookup to place the client on a connection server.
- WebSocket frames (JSON/protobuf):
  - `send {clientMsgId, conversationId, type, body}` → server replies `ack {clientMsgId, serverMsgId, seq, ts}`.
  - `deliver {serverMsgId, conversationId, senderId, seq, ts, body}` (server → recipient).
  - `receipt {serverMsgId, state: delivered|read, byUserId}`.
  - `presence {userId, state: online|offline, lastSeen}`; `typing {conversationId, userId}`.
- `GET /v1/conversations/{id}/messages?after={seq}&limit=50` → history sync / catch-up (see [[api-pagination]], cursor by `seq`).
- `GET /v1/conversations` → conversation list with unread counts and last message.
- `POST /v1/media` → presigned upload URL to object storage; message then carries the media pointer.

`clientMsgId` (client-generated UUID) is the **idempotency key**: retries reuse it so the server dedups and the client dedups on `serverMsgId`.

## Data Model & Storage

Access patterns drive the store: (a) append a message to a conversation, (b) read the last N messages of a conversation in order, (c) read a user's conversation list, (d) sync-since-cursor per device. All are **partition-key point/range reads**, not ad-hoc queries ⇒ favor a **wide-column NoSQL store** (Cassandra/HBase-style) for messages: cheap high-volume writes, tunable replication, and range scans within a partition. Metadata (users, conversation membership) can live in a relational store.

**Core entities**
- `users(user_id PK, name, last_seen, …)` — relational.
- `conversations(conversation_id PK, type, created_at)` and `membership(conversation_id, user_id, joined_at, role)` — relational; membership is the fan-out list.
- `messages` — wide-column, **partition key = conversation_id**, **clustering key = seq (or message_id)** ascending. Columns: `sender_id, type, body/media_ref, created_ts`. This co-locates a conversation's messages on one partition and makes "last N in order" a single ordered range read.
- `user_inbox` / delivery cursors — per (user_id, device_id): `last_delivered_seq`, `last_read_seq` per conversation. This is how a reconnecting device knows what it missed.

**Keys & indexing:** partition by `conversation_id` for the message table (locality of the dominant access pattern). Hot large-group partitions are the risk — mitigate by capping full fan-out group size and treating very large groups as broadcast channels (read-fan-out). `message_id` from a distributed generator (see [[unique-id-generation]]) so IDs are **time-sortable per conversation**, giving free ordering.

## High-Level Design

Tiers: stateless HTTP API + **stateful connection tier** + routing/session registry + async delivery pipeline + storage.

- **Load balancer / gateway.** For WebSockets the LB must support long-lived connections and sticky upgrade routing. See [[load-balancing]].
- **Connection (session) servers.** Hold the live WebSocket for each connected device, do heartbeats, and translate frames. Because they're stateful, we track *which server holds which user* in a **session registry** (a fast KV store, e.g. Redis: `user_id/device_id → connection_server_id`), populated via [[service-discovery]] on connect and cleared on disconnect.
- **Chat/logic service.** Validates, assigns `seq`/`message_id`, persists, and enqueues delivery.
- **Message queue** ([[message-queues]], e.g. Kafka partitioned by conversation) — decouples ingest from fan-out and absorbs peaks with [[backpressure-and-bulkhead]].
- **Presence service** — tracks online/last-seen from heartbeats.
- **Push service** — APNs/FCM for offline recipients.
- **Object storage + [[cdn]]** — media stored out-of-band; chat carries only the pointer/URL, delivered fast from edge.

**Write path (A sends to B):** A's frame hits A's connection server → chat service assigns `message_id` + per-conversation `seq`, **writes to the message store (durable)**, then acks A (`sent`). The chat service resolves B's members, looks each up in the session registry: if B is online, route the `deliver` frame to B's connection server (which pushes it down B's socket, then B's client sends a `delivered` receipt); if B is offline, the message stays in the store, B's inbox cursor lags, and the push service fires an APNs/FCM notification.

**Read/reconnect path:** on connect, B's device sends its `last_delivered_seq` per conversation; the chat service range-reads everything after that cursor from the message store and streams it, then advances the cursor. The **store — not the queue or the socket — is the source of truth**; the socket is just a fast delivery hint.

## Deep Dives

**1) Real-time delivery & routing across connection servers.** The core problem: sender and recipient are on different stateful servers. Options: (a) *broadcast* a message to all connection servers and let the right one match — simple but O(N) waste; (b) *central session registry* — on connect, each device registers `user → connection_server` in Redis; to deliver, look up B's server and forward via an internal RPC ([[grpc-and-protobuf]]) or an internal pub/sub topic keyed by connection server. Choose (b). Sockets are unreliable, so every `deliver` is **ack'd**; unacked messages are retried ([[retries-and-timeouts]]) and remain readable from the store, so a dropped socket never loses a message — the recipient re-pulls by cursor on reconnect. Heartbeats detect dead connections and evict stale registry entries.

**2) Ordering & message IDs.** Per-conversation ordering is enough. The chat service assigns a monotonically increasing `seq` per `conversation_id` (or uses a time-sortable distributed ID, see [[unique-id-generation]]) at persist time — this is the single serialization point per conversation, so concurrent sends get a total order within that conversation without global coordination. Clients sort by `seq`, not by device clock (clocks are unreliable). This sidesteps distributed clock-sync entirely.

**3) Group fan-out.** *Fan-out on write* (push a copy/pointer to each member's delivery path at send time) gives instant delivery and cheap reads — great for small/medium groups, but a single message to a 100k-member group is 100k routes. *Fan-out on read* (store once; members pull on open) is cheap to write but adds read latency and load. Recommended: **fan-out on write up to a cap (~500)**; above it, treat as a broadcast/channel with fan-out on read. Fan-out runs off the [[message-queues]] pipeline so a huge group can't stall the sender's ack.

**4) Delivery/read receipts & presence.** Receipts are just small messages on the same pipeline (`delivered` when B's device acks the frame, `read` when B opens the chat), updating B's cursor and notifying A. Presence is derived from heartbeats: a device online→offline transition publishes to the presence service; fan-out of presence to *all* contacts is expensive, so **compute presence on demand / for the visible conversation list only**, and debounce flapping. `last_seen` is eventually consistent — acceptable.

## Trade-offs & Bottlenecks

| Decision | Chosen | Alternative | Why |
|---|---|---|---|
| Transport | Persistent WebSocket | Long-poll / SSE | Full-duplex, low latency; server can push receipts/presence |
| Delivery guarantee | At-least-once + client dedup on `clientMsgId`/`serverMsgId` | Exactly-once in transport | True exactly-once is impractical over lossy sockets; dedup makes it exactly-once at the app layer |
| Message store | Wide-column NoSQL, partition = conversation | Relational | Write-heavy, key-based range reads; horizontal scale ([[partitioning-sharding]]) |
| Group delivery | Fan-out on write ≤ cap, else on read | Always one or the other | Balances write amplification vs read latency |
| Ordering | Per-conversation `seq` at persist | Global ordering / vector clocks | Cheapest guarantee that satisfies UX |
| Source of truth | Durable store | The queue / the socket | Sockets drop; reconnect re-pulls by cursor |

**Bottlenecks under scale:**
- **Connection count.** ~20M stateful sockets ⇒ the connection tier is the scaling axis; add servers and shard the session registry. Graceful drain on deploy so millions of clients reconnect gradually (thundering-herd on redeploy is a real hazard — stagger with jittered backoff).
- **Hot partitions.** Very large/active groups concentrate writes on one conversation partition — cap group size, split broadcast channels, and rate-limit ([[rate-limiting]]).
- **Session-registry availability.** It's on the delivery hot path; replicate it and tolerate stale entries via ack+retry (a miss just means re-pull on reconnect, not data loss).
- **Fan-out storms.** Big-group sends and presence updates can saturate the pipeline; isolate them on their own queue partitions with [[backpressure-and-bulkhead]].

Extensions an interviewer may push: **multi-device sync** (per-device cursors, one logical inbox), **E2E encryption** (server stores ciphertext + does key exchange; loses server-side search/history features), and **media** (presigned upload to object storage, delivered via [[cdn]], chat carries only the reference).

## Related
[[websockets-and-realtime]] [[message-queues]] [[service-discovery]] [[load-balancing]] [[partitioning-sharding]] [[unique-id-generation]] [[cdn]] [[sql-vs-nosql]] [[idempotency]] [[retries-and-timeouts]] [[backpressure-and-bulkhead]] [[grpc-and-protobuf]] [[consistency-models]] [[rate-limiting]] [[api-pagination]]
