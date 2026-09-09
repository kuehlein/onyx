---
id: tcp-vs-udp
type: flashcard
tags:
  - networking
tiers:
  networking: 1
created: 2026-09-08
confidence: high
priority: normal
---

# TCP vs UDP

Two transport-layer protocols that sit on top of [IP](_meta/glossary.md#ip) and make opposite bets. [TCP](_meta/glossary.md#tcp) is a *connection-oriented, reliable, ordered byte stream*: it establishes a connection with a handshake, then guarantees every byte arrives exactly once and in order, paying for that with per-segment acknowledgements, retransmission, and rate control. [UDP](_meta/glossary.md#udp) is a *connectionless, unreliable datagram* service: it just sprays independent packets at a destination with a checksum and nothing else — no handshake, no ordering, no delivery guarantee, minimal overhead. The whole choice reduces to one question: does the application need the protocol to guarantee correctness, or does it need the lowest possible latency and will handle loss itself?

> [!tip] Recognition
> Reach for **TCP** when the wording implies *"every byte must arrive, in order"* — file transfer, a database wire protocol, HTTP/1.1 & HTTP/2, anything transactional. Reach for **UDP** when the wording implies *"stale data is worthless, don't wait for retransmits"* or *"one small request/response"* — live voice/video, multiplayer game state, [DNS](_meta/glossary.md#dns) lookups, telemetry, and QUIC. If you hear *"a slow/lost packet is holding up everything behind it,"* that is TCP [head-of-line blocking](_meta/glossary.md#head-of-line-blocking), and QUIC-over-UDP is the escape hatch.

## When to Use

**Signals that point to TCP:**
- "The data must be complete and correct" — file/object transfer, DB replication, RPC over a byte stream
- "Ordering matters" — a stream where byte N must precede byte N+1 (HTTP bodies, TLS records)
- The app wants the OS to handle reliability, congestion, and flow control so it doesn't reimplement them

**Signals that point to UDP:**
- "Low latency, loss-tolerant" — VoIP, live video, real-time game state, where a late packet is useless so retransmitting it is worse than dropping it
- "Small, single request/response" — DNS queries, NTP: one round trip, connection setup would double the cost
- "One-to-many" — multicast/broadcast (TCP is strictly point-to-point and cannot multicast)
- The app wants to build its *own* reliability/ordering semantics on top (this is exactly what QUIC does)

**Do not use TCP when:** the payload is a single small message or timeliness beats completeness — the 3-way handshake and in-order delivery add latency you can't recover.

**Do not use UDP when:** you actually need every byte in order and would just end up reimplementing acks, retransmit, and congestion control badly — use TCP (or QUIC) instead.

## Key Properties

| Property | TCP | UDP |
|---|---|---|
| Connection | Connection-oriented (3-way handshake: SYN, SYN-ACK, ACK) | Connectionless (no handshake) |
| Reliability | Guaranteed delivery via ACKs + retransmission | None — packets may be lost, silently |
| Ordering | In-order byte stream (reassembles/reorders) | None — datagrams arrive in any order |
| Boundaries | Byte stream — no message boundaries preserved | Datagram — each `send` = one discrete message |
| Flow control | Yes — receiver window prevents overrunning the receiver | None |
| Congestion control | Yes — backs off when the network is congested | None (app must implement if needed) |
| Header overhead | 20 bytes minimum (more with options) | 8 bytes |
| Communication | Point-to-point (unicast) only | Unicast, multicast, broadcast |

- **Flow control vs. congestion control** (often confused): flow control protects the *receiver* (don't send faster than it can consume, via the advertised window); congestion control protects the *network* (don't send faster than the path can carry, via the congestion window). TCP does both; UDP does neither.
- **Byte stream vs. datagram**: TCP has no concept of a "message" — your `send` boundaries are not preserved, so the app must frame messages itself. Each UDP `send` maps to exactly one datagram.

## Trade-offs

**Reliability vs. latency** — this is the whole trade. TCP buys correctness with round trips (handshake before any data) and with *waiting*: a lost segment must be detected and retransmitted before later data is delivered. UDP has zero setup and never waits, but you get no guarantees.

**Head-of-line (HOL) blocking** — TCP delivers a strict in-order byte stream, so a single lost segment stalls delivery of *every* byte received after it until the retransmission arrives, even bytes that are already in the receiver's buffer. This bites hardest when you [multiplex](_meta/glossary.md#multiplexing) independent logical streams over one TCP connection (HTTP/2): one lost packet blocks all streams. UDP has no ordering guarantee, so it has no HOL blocking by construction.

**vs. the siblings you'll confuse it with (different layer):** TCP/UDP is a *transport-layer* choice — it decides delivery semantics. HTTP/HTTPS, WebSockets, and gRPC are *application-layer* protocols that ride on top of a transport, so they are not alternatives to TCP; they *use* it. Distinguishing signal:

| If the question is about… | It's asking about | Not |
|---|---|---|
| "reliable stream vs. loss-tolerant packets," delivery/ordering guarantees | **TCP vs. UDP** (transport) | the app protocol |
| request/response semantics, headers, status codes, caching | **[HTTP/HTTPS](http-https)** (over TCP/QUIC) | transport choice |
| a persistent full-duplex channel after an HTTP upgrade | **WebSockets** (over TCP) | UDP |
| typed RPC, service methods, streaming, Protobuf on the wire | **[gRPC](_meta/glossary.md#grpc)** (over HTTP/2 → TCP) | UDP |

So "should I use TCP or UDP?" is answered by delivery needs; "should I use HTTP vs. WebSockets vs. gRPC?" is a layer up and assumes a transport underneath (almost always TCP, or QUIC for HTTP/3).

**vs. QUIC (the modern answer):** QUIC runs on top of UDP but rebuilds TCP's good parts — reliable, ordered, congestion-controlled *streams* — in user space, while giving each stream its own independent sequencing. A lost packet only stalls the stream it belonged to, not the others, so QUIC keeps reliability yet eliminates TCP-style head-of-line blocking across streams. It also folds the transport + TLS handshake together to cut setup round trips. HTTP/3 is HTTP over QUIC. Mental model: *UDP is the raw carrier; QUIC is "TCP done right" built on it.*

## Common Pitfalls

- **"UDP is faster so always use UDP."** Faster only because it does less. If your app then needs ordering and delivery, you must reimplement acks, retransmit, and congestion control — which is TCP, poorly. Choose UDP only when you genuinely tolerate loss or are using a protocol (QUIC) that already handles it.
- **Assuming TCP preserves message boundaries.** It's a byte stream: two `send`s can arrive coalesced in one `recv`, or one `send` split across several. You must length-prefix or delimit messages yourself.
- **Conflating reliability with security.** Neither TCP nor UDP encrypts or authenticates anything — that's [TLS](_meta/glossary.md#tls) (or QUIC's built-in TLS 1.3). "Reliable" means *delivered*, not *private*.
- **Thinking UDP has no error detection.** UDP has a checksum, so it can *detect and drop* a corrupted datagram — it just won't retransmit it. It drops silently rather than delivering garbage.
- **Confusing flow control with congestion control.** Flow control = don't overrun the receiver; congestion control = don't overrun the network. They solve different problems with different windows.

## Resources

- RFC 9293 — Transmission Control Protocol (TCP): https://www.rfc-editor.org/rfc/rfc9293.html
- RFC 768 — User Datagram Protocol (UDP): https://www.rfc-editor.org/rfc/rfc768.html
- RFC 9000 — QUIC: A UDP-Based Multiplexed and Secure Transport: https://www.rfc-editor.org/rfc/rfc9000.html
- RFC 9114 — HTTP/3: https://www.rfc-editor.org/rfc/rfc9114.html

## Related

- [[http-https]]
- [[dns]]
- [[tls]]
- [[websockets]]
- [[grpc]]
