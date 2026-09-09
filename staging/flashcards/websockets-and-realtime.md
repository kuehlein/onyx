---
id: websockets-and-realtime
type: flashcard
tags:
  - networking
  - websockets
  - realtime
tiers:
  networking: 2
created: 2026-09-08
confidence: high
priority: normal
---

# WebSockets, SSE, and Long-Polling

Three techniques for pushing data to a client faster than it would arrive by re-fetching. They differ on one axis: **directionality and connection model**. Long-polling fakes push over ordinary request/response; [SSE](_meta/glossary.md#sse) streams one-way (server→client) over a single long-lived HTTP response; WebSockets open a full-duplex, persistent [TCP](_meta/glossary.md#tcp) channel after an HTTP `Upgrade` handshake. Pick the least powerful one that satisfies the data-flow requirement — each extra capability adds operational cost.

> [!tip] Recognition
> Reach for a realtime transport when the UI must reflect server-originated events *without user action*: live feeds, notifications, presence, chat, collaborative editing, dashboards, multiplayer state. The distinguishing signal is **who initiates**: if only the server ever pushes → SSE; if both sides send continuously at low latency → WebSockets; if you need a dead-simple fallback through hostile proxies → long-polling.

## When to Use

**Problem signals that suggest a realtime transport:**
- "Users should see new messages / prices / notifications instantly" — server has data the client didn't ask for
- "Show who's online / typing indicators / cursor positions" — presence and collaboration
- "Live dashboard, sports scores, order status" — a continuous stream of server updates

**Choose by directionality (the decision cue):**
- **SSE** — server→client only, text events, and you want it to ride plain HTTP: notification feeds, live scores, log/LLM token streaming, activity timelines. Client sends nothing back except the initial GET.
- **WebSockets** — both directions, continuously, at low latency: chat, multiplayer games, collaborative editors, trading UIs. The client emits events as often as the server does.
- **Long-polling** — fallback when SSE/WebSockets are blocked, or updates are infrequent and you want zero new protocol surface. Works through any HTTP proxy.

**Do not use any of them when:**
- The data changes rarely and staleness of a few seconds is fine → ordinary periodic polling is simpler and cheaper
- One request expects one response (a normal API call) → plain HTTP request/response; a persistent connection buys nothing
- You need pub/sub *between servers*, not to a browser → use a [message queue](message-queues.md) / broker, not a client transport

## Key Properties

| | Long-polling | SSE | WebSockets |
|---|---|---|---|
| Direction | Server→client (per request) | Server→client only | Full-duplex (both ways) |
| Protocol | Plain HTTP request/response | HTTP (one long-lived response) | `ws://`/`wss://` after HTTP `Upgrade` |
| Data type | Any | UTF-8 text only | Text or binary |
| Auto-reconnect | Manual (client re-requests) | Built in (browser `EventSource`) | Manual (app/library must implement) |
| Browser API | `fetch`/`XHR` | `EventSource` | `WebSocket` |
| Overhead | Full HTTP headers per cycle | One connection, minimal framing | One connection, ~2-byte frames |

- **Long-polling:** client sends a request; server *holds it open* until data is ready (or a timeout), responds, and the client immediately re-requests. It is normal HTTP — no special server, works everywhere — but every message pays full request/header overhead and there is a small gap between responses where events can queue.
- **SSE:** a single GET whose response body never ends; the server writes `data:` lines in the `text/event-stream` format. The browser `EventSource` **reconnects automatically** and replays via the `Last-Event-ID` header. Text-only; no client→server channel.
- **WebSockets:** begins as an HTTP request with `Upgrade: websocket`; on `101 Switching Protocols` the same TCP socket becomes a bidirectional message stream. No HTTP headers per message, supports binary, but you build reconnect/heartbeat/auth yourself.

## Trade-offs

**Don't confuse this card's siblings (different layer of the stack):**
- **vs. [tcp](_meta/glossary.md#tcp)/[udp](_meta/glossary.md#udp):** TCP vs. UDP is a *transport-layer* choice (reliable ordered stream vs. fire-and-forget datagrams). WebSockets/SSE/long-polling are *application-layer* patterns that all ride on top of TCP — the question there is "push shape," not "delivery guarantee."
- **vs. http-https:** HTTP is plain request/response (client asks, server answers once); TLS is the encryption layer. This card is about *keeping data flowing without the client asking again* — the distinguishing signal is **server-initiated push**, which vanilla HTTP request/response cannot do.

**SSE vs. WebSockets (the most-confused pair):**
- Direction is the deciding line: **SSE is one-way, WebSockets are two-way.** If the client never needs to stream data up, SSE is strictly simpler.
- SSE is *just HTTP*: it traverses proxies, works with standard HTTP auth/cookies/compression, and reconnects for free. WebSockets need proxy/load-balancer support for `Upgrade` and force you to reimplement reconnect, heartbeats, and auth.
- WebSockets carry binary and have lower per-message overhead — necessary for games, voice, or high-frequency bidirectional traffic; wasteful for a notification feed.

**HTTP version matters for SSE:** Over HTTP/1.1, browsers cap ~6 connections per domain, and each open SSE stream permanently consumes one — 6 tabs can starve the whole origin. Over HTTP/2+ this vanishes: many SSE streams [multiplex](_meta/glossary.md#multiplexing) onto one connection (default ~100 concurrent streams). Serve SSE over HTTP/2.

**Long-polling vs. the streaming options:** Long-polling maximizes compatibility (no persistent connection, no `Upgrade`) at the cost of latency and repeated header overhead. It is a fallback, not a first choice, now that HTTP/2 SSE and WebSockets are broadly supported.

## Common Pitfalls

- **Reaching for WebSockets when SSE suffices.** If traffic is server→client only, WebSockets add reconnect/heartbeat/proxy complexity for no benefit. Match the transport to the direction of data flow.
- **Serving SSE over HTTP/1.1.** The ~6-connections-per-domain cap means a few tabs each holding an SSE stream can block all other requests to that origin. Serve over HTTP/2.
- **Assuming SSE can send binary or receive from the client.** SSE is UTF-8 text, server→client only. Base64-ing binary bloats it ~33%; if you need either, use WebSockets.
- **Idle connections silently dropped.** Load balancers and proxies kill idle connections (often 30-60 s). Send periodic heartbeats/keep-alive frames (SSE comment lines `:`; WebSocket ping/pong) or the connection dies unnoticed.
- **Forgetting WebSocket reconnect and resume.** Unlike `EventSource`, WebSockets do not auto-reconnect; on drop you must reconnect *and* resync missed state (sequence numbers or a replay cursor), or the client shows stale data.
- **Auth on the upgrade only.** A long-lived connection authenticated once can outlive the token; enforce token expiry/revocation on the persistent connection, not just at connect time.

## Implementation Notes

**Scaling stateful connections (the interview crux):** all three keep connection state on one server, so you cannot round-robin freely.

- **Sticky sessions / affinity:** the load balancer pins a client to the backend holding its connection. Simple, but see [sticky session](_meta/glossary.md#sticky-session) downsides: uneven load and lost state if that node dies.
- **Pub/sub fan-out:** backends subscribe to a shared broker (Redis Pub/Sub, Kafka, NATS). When *any* node produces an event, the broker fans it out to every node, which pushes to its locally-connected clients. This decouples "which server holds the socket" from "which server produced the event" — the standard pattern for chat/presence at scale.
- Managed options (AWS API Gateway WebSocket API, Ably, Pusher) offload connection state and fan-out entirely.

```
# SSE response shape (text/event-stream)
id: 42
event: price
data: {"AAPL": 231.5}

:keep-alive comment prevents idle timeout
```

```
# WebSocket handshake (HTTP Upgrade)
GET /ws HTTP/1.1
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZQ==
# server replies: 101 Switching Protocols
```

## Resources

- MDN — Using Server-Sent Events: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events
- MDN — The WebSocket API: https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API
- RFC 6455 (The WebSocket Protocol): https://www.rfc-editor.org/rfc/rfc6455
- WHATWG HTML — Server-sent events spec: https://html.spec.whatwg.org/multipage/server-sent-events.html

## Related

- [[http-https]]
- [[load-balancing]]
- [[message-queues]]
- [[rest-api-design]]
- [[caching]]
