---
id: http2-and-http3
type: flashcard
tags:
  - networking
  - http
  - quic
  - tls
  - performance
tiers:
  networking: 3
created: 2026-09-10
confidence: high
priority: normal
---

# HTTP/2 and HTTP/3

HTTP/2 and HTTP/3 keep HTTP *semantics* (methods, status codes, headers, bodies) identical to HTTP/1.1 but change the *wire format and transport* to eliminate the latency HTTP/1.1 imposed. HTTP/1.1 sends plaintext, request-at-a-time messages, so a single slow response blocks everything queued behind it on that connection — application-layer **[head-of-line blocking](_meta/glossary.md#head-of-line-blocking)** — forcing browsers to open ~6 parallel [TCP](_meta/glossary.md#tcp) connections per origin. HTTP/2 fixes the *application* layer with a **binary framing** protocol that [multiplexes](_meta/glossary.md#multiplexing) many concurrent **streams** over one TCP connection, but because those streams still ride a single ordered TCP byte-stream, one lost packet stalls *all* streams — HOL blocking simply moves down to the *transport* layer. HTTP/3 removes even that by running over **[QUIC](_meta/glossary.md#quic)**, a transport built on [UDP](_meta/glossary.md#udp) with independent per-stream delivery, so a loss on one stream never blocks the others.

> [!tip] Recognition
> Reach for this when you see: "many small assets, browser opens 6 connections," "one slow/large response blocks the others," "head-of-line blocking," "multiplexing over one connection," "packet loss on lossy/mobile networks tanks throughput," "TLS handshake round-trips hurt first-byte latency," "connection survives Wi-Fi→cellular switch," "[0-RTT](_meta/glossary.md#0-rtt) / early data," or a protocol running over **UDP on port 443**.
>
> **Which HOL blocking?** *App-layer* HOL (HTTP/1.1's one-response-at-a-time) → solved by **HTTP/2 multiplexing**. *Transport-layer* HOL (one TCP loss stalls all multiplexed streams) → solved only by **HTTP/3 / QUIC**. Naming the layer is the senior-level distinction.

## When to Use

**Problem signals that point to HTTP/2:**
- A page pulls many resources from one origin and you're paying per-connection setup cost (TCP + [TLS](_meta/glossary.md#tls) handshakes) or hitting the browser's ~6-connection-per-host cap
- You want request multiplexing and header compression but must stay on standard TCP infrastructure (middleboxes, load balancers, corporate firewalls that block UDP)
- gRPC — its default transport is HTTP/2 (streams map cleanly to gRPC streaming)

**Problem signals that point to HTTP/3 / QUIC:**
- Users are on **lossy or high-latency networks** (mobile, satellite) where TCP-level HOL blocking dominates — QUIC's per-stream independence is the whole point
- Connections must **survive a network change** (Wi-Fi ↔ cellular, IP change) without a new handshake — QUIC [connection migration](_meta/glossary.md#connection-migration) via connection IDs
- You want the **fastest possible handshake**: QUIC folds transport + TLS 1.3 into one round trip (1-RTT), or 0-RTT for resumed connections

**Prefer one over the other / do not use when:**
- Over HTTP/1.1: prefer HTTP/2+ almost always for browser traffic; HTTP/1.1 is still fine for simple single-request APIs and is the lowest-common-denominator fallback
- HTTP/2 over HTTP/3: when the network blocks/deprioritizes UDP, when middleboxes need to inspect TCP, or when your stack lacks mature QUIC support — HTTP/2 is the safer default today
- HTTP/3 over HTTP/2: when the loss-sensitivity or mobility wins above are real; browsers only use it after discovering support (via the `Alt-Svc` header or HTTPS DNS records), so it is always an *upgrade* on top of an HTTP/2 or HTTP/1.1 baseline, never the sole option

## Key Properties

- **Same semantics, new transport.** All three speak the same HTTP methods, status codes, and header semantics. What changes is framing (text vs. binary) and the underlying transport (TCP vs. QUIC/UDP).
- **HTTP/2 = one TCP connection, many streams.** A **stream** is an independent, bidirectional sequence of **frames** (HEADERS, DATA, etc.) identified by a stream ID; the browser interleaves frames from many requests on the single connection.
- **HPACK vs. QPACK header compression.** HTTP/2 uses **[HPACK](_meta/glossary.md#hpack)**; HTTP/3 uses **[QPACK](_meta/glossary.md#qpack)**. Both compress repetitive headers against a shared dynamic table, but QPACK is redesigned so header decoding does not require strict cross-stream ordering — using HPACK directly over QUIC would reintroduce HOL blocking.
- **QUIC bundles transport + security.** QUIC (RFC 9000) runs on UDP and has **[TLS 1.3](_meta/glossary.md#tls) built in** — there is no such thing as unencrypted QUIC/HTTP/3. The transport and crypto handshakes are combined into a single 1-RTT exchange.
- **QUIC streams are independently delivered.** Each stream has its own flow control and ordering; a lost UDP packet only stalls the stream(s) whose bytes it carried, not all of them. This is the property TCP structurally cannot provide.
- **Connection migration.** A QUIC connection is identified by a **connection ID**, not the 4-tuple, so it can survive a client IP/port change (Wi-Fi→cellular) without a new handshake.
- **HTTP/3 is RFC 9114 (2022); HTTP/2 is RFC 9113 (2022, obsoleting RFC 7540).**

## Common Pitfalls

- **Thinking HTTP/2 eliminates head-of-line blocking.** It removes it at the *application* layer only. Because all streams share one TCP byte-stream, a single dropped TCP segment blocks *every* multiplexed stream until retransmission — transport-layer HOL blocking. This is the #1 thing to get right, and the reason HTTP/3 exists.
- **Relying on HTTP/2 Server Push.** Server Push let a server preemptively send resources, but it was hard to use well, barely adopted (only ~1.25% of HTTP/2 sites used it, later ~0.7%, with no clear net performance win), and is now **deprecated / removed** — Chrome disabled it by default in v106 (Sept 2022) and Firefox removed it in v132. Use **`103 Early Hints`** instead to let clients start fetching critical resources early.
- **Enabling 0-RTT for non-idempotent requests.** QUIC/TLS 1.3 **0-RTT (early data)** is replayable: a network attacker can capture and resend the early-data flight. Only send safe, idempotent requests (e.g. GETs) as 0-RTT; never a non-idempotent `POST` that causes side effects.
- **Assuming HTTP/3 is always faster.** On clean, low-loss networks HTTP/2 and HTTP/3 perform similarly; QUIC's win is loss/mobility, and UDP can be *slower* where networks throttle or block it. Measure.
- **Forgetting UDP is often blocked.** Enterprise firewalls, some CGNATs, and older middleboxes drop or throttle UDP/443, so HTTP/3 must degrade gracefully to HTTP/2 — never assume it's available.
- **Conflating multiplexing with parallelism gains without prioritization.** Many interleaved streams can starve critical resources without stream prioritization; the response is bandwidth-shared, not magically parallel.

## Trade-offs

| | HTTP/1.1 | HTTP/2 | HTTP/3 |
|---|---|---|---|
| Transport | TCP | TCP | **QUIC over UDP** |
| Wire format | Text | **Binary framing** | Binary framing |
| Concurrency | 1 request/response at a time per conn (browsers open ~6 conns) | **Many streams / 1 conn** | Many streams / 1 conn |
| App-layer HOL blocking | Yes | **No** | No |
| Transport HOL blocking | Yes (per conn) | **Yes** (1 TCP loss stalls all streams) | **No** (independent streams) |
| Header compression | None (plaintext) | HPACK | QPACK |
| Encryption | Optional (TLS separate) | Optional in spec; effectively TLS in browsers | **Mandatory (TLS 1.3 built in)** |
| Handshake to first request | TCP + TLS (multiple RTT) | TCP + TLS | **1-RTT combined; 0-RTT on resume** |
| Connection migration | No (tied to 4-tuple) | No | **Yes (connection ID)** |

- **TCP maturity vs. QUIC agility.** TCP is offloaded to the kernel/NIC and universally supported; QUIC lives in **user space**, so it's easier to evolve and deploy but historically higher CPU cost and reliant on newer libraries.
- **Middlebox friendliness.** TCP-based HTTP/2 passes through legacy infrastructure that expects TCP; QUIC's UDP + encrypted transport headers defeat middlebox inspection (good for privacy/ossification-resistance, bad where inspection is required).
- **Complexity.** Each hop up trades protocol simplicity for latency: HTTP/1.1 is trivially debuggable text; HTTP/2 needs frame-aware tooling; HTTP/3 reimplements reliability, congestion control, and TLS in the application/user-space stack.

## Implementation Notes

- **Discovery.** A server advertises HTTP/3 via the **`Alt-Svc: h3=":443"`** response header (sent over HTTP/2 or HTTP/1.1) or via an **HTTPS/SVCB DNS record**; the client then races/upgrades to QUIC. HTTP/2 is negotiated during the TLS handshake via **ALPN** (`h2`).
- **Ports.** All run on 443 for HTTPS, but HTTP/3 is **UDP/443** while HTTP/1.1 and HTTP/2 are **TCP/443**.
- **Server support.** nginx, Apache, Caddy, Envoy, and major CDNs support HTTP/2; HTTP/3 support is broad on CDNs (Cloudflare, Google, Fastly) and increasingly in nginx/Caddy/Envoy.
- **0-RTT gate.** Frameworks require you to *opt in* to accepting 0-RTT early data and to mark handlers idempotent, precisely because of replay risk.

## Variants

- **gQUIC** — Google's original pre-standard QUIC (with an embedded HTTP/2-like mapping), superseded by IETF QUIC (RFC 9000) + HTTP/3.
- **HTTP/2 over cleartext (h2c)** — the rare unencrypted HTTP/2 profile; not used by browsers, occasionally seen for internal/gRPC hops.
- **103 Early Hints** — the successor to Server Push: an informational status that tells the client which resources to preload/preconnect before the final response.
- **WebTransport** — a newer browser API layered on HTTP/3/QUIC for low-latency bidirectional/datagram transport, an alternative to WebSockets.

## Resources

- RFC 9114 — HTTP/3: https://www.rfc-editor.org/info/rfc9114/
- RFC 9000 — QUIC: A UDP-Based Multiplexed and Secure Transport: https://www.rfc-editor.org/info/rfc9000/
- RFC 9113 — HTTP/2: https://www.rfc-editor.org/info/rfc9113/
- Removing HTTP/2 Server Push from Chrome (Chrome for Developers): https://developer.chrome.com/blog/removing-push

## Related

- [[tcp-vs-udp]]
- [[tls-handshake]]
- [[head-of-line-blocking]]
- [[grpc]]
- [[cdn]]
- [[dns]]
