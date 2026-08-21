---
id: 7f3a1c2e-84b0-4d91-b5e7-9c0f6a3d2e18
type: flashcard
tags:
  - system-design
  - http
  - networking
tiers:
  system-design: 1
created: 2026-08-20
confidence: low
---

# HTTP and HTTPS

HTTP (Hypertext Transfer Protocol) is a stateless, request-response protocol for transferring data between clients and servers over TCP; HTTPS adds a TLS layer that encrypts the connection before any application data is exchanged, providing confidentiality, integrity, and server authentication. The stateless property means every request is independent — servers must not rely on prior connection state, which enables horizontal scaling.

## When to Use

**Problem signals that suggest HTTP/HTTPS is relevant:**
- Any system that serves web clients, mobile apps, or third-party developers via a public or internal API
- The prompt mentions browsers, REST APIs, webhooks, CDNs, load balancers, or reverse proxies
- Authentication, session management, or token exchange is part of the design
- You are asked to secure a data transfer path or comply with PCI-DSS/HIPAA (HTTPS is mandatory)
- The system must integrate with external SaaS providers (payment processors, identity providers, analytics)
- Rate limiting, request tracing, or API versioning are mentioned — these all live at the HTTP layer

**Prefer HTTPS over plain HTTP when:**
- Any user credentials, PII, or payment data are in transit — TLS prevents man-in-the-middle interception
- The API is public-facing — modern browsers flag mixed content and block insecure requests
- You need mutual authentication (mTLS) between services — HTTPS provides the certificate infrastructure

**Do not use when:**
- Ultra-low-latency internal service communication at high RPS → prefer gRPC over HTTP/1.1 (binary framing, multiplexing, header compression via HTTP/2 are available but gRPC tooling is optimized for it)
- Large binary streaming (video, game state) → WebSockets or QUIC reduce framing overhead
- Internal cluster traffic where the network is already encrypted (e.g. inside a mTLS service mesh) → adding HTTPS can be redundant, though defense-in-depth often still warrants it

## Key Properties

| Property | HTTP/1.1 | HTTP/2 | HTTP/3 |
|---|---|---|---|
| Transport | TCP | TCP | QUIC (UDP) |
| Multiplexing | No (head-of-line blocking) | Yes (streams) | Yes (independent streams) |
| Header compression | No | HPACK | QPACK |
| Server push | No | Deprecated (removed from all major browsers 2022) | No |
| TLS | Optional | Required in practice | Always (QUIC mandates TLS 1.3) |
| Typical latency (TLS handshake) | TLS 1.2: 2 RTT / TLS 1.3: 1 RTT | TLS 1.2: 2 RTT / TLS 1.3: 1 RTT | 1 RTT initial; 0-RTT resumption |

**TLS handshake cost:**
- TLS 1.2: 2 full RTTs before first application byte — ~200–400 ms on intercontinental paths
- TLS 1.3: 1 RTT; 0-RTT session resumption is possible (with replay-attack caveats)
- Both HTTP/1.1 and HTTP/2 can use TLS 1.2 or TLS 1.3; the RTT savings come from upgrading the TLS version, not the HTTP version
- HTTP/3 (QUIC) mandates TLS 1.3 and integrates the handshake into QUIC's own, achieving 1-RTT initial and 0-RTT on resumption
- HTTP/2 + TLS 1.3 is the current baseline for high-performance web APIs

**Statelessness implications:** Servers scale horizontally without sticky sessions. Sessions are re-attached per request via cookies, JWTs, or API keys carried in headers.

**Status code classes:**
- 2xx — success; 201 Created on resource creation, 204 No Content on deletion
- 3xx — redirect; 301 permanent (cacheable), 302 temporary
- 4xx — client error; 400 bad input, 401 unauthenticated, 403 unauthorized, 429 rate limited
- 5xx — server error; 503 Service Unavailable used for circuit-breaker responses

## Trade-offs

**HTTP vs gRPC (internal services):**
- HTTP/REST: human-readable, broad tooling, easy debugging with curl/Postman, language-agnostic
- gRPC: ~3–10x lower serialization overhead (Protobuf vs JSON), strict contracts via `.proto` schemas, bidirectional streaming native; harder to debug, requires code gen
- Decision: choose HTTP for external APIs and developer-facing integrations; gRPC for high-RPC internal microservice calls where latency and throughput matter

**HTTPS termination placement:**
- Terminate at load balancer (SSL offloading): simplest, central certificate management, inner traffic is plaintext — acceptable if network is trusted/segmented
- Terminate at the service (end-to-end TLS): stronger security, required for compliance in some industries; adds CPU cost (~1–5% at scale, mitigated by TLS 1.3 and hardware offload)
- mTLS (mutual): both sides present certificates — required for zero-trust service meshes; operationally complex (certificate rotation, PKI management)

**Statelessness vs. session cost:**
- Stateless HTTP scales perfectly horizontally but shifts state management to external stores (Redis for sessions, JWTs for bearer tokens)
- JWTs are self-contained but cannot be revoked without a blocklist (adds a lookup per request); server-side sessions are revocable but require shared storage

**Caching headers (HTTP-native scalability lever):**
- `Cache-Control: max-age=3600` + CDN can absorb 90–99% of read traffic for static or slowly-changing resources
- `ETag` / `Last-Modified` enable conditional requests (304 Not Modified) — reduces bandwidth, not server compute
- Over-caching stale data is a correctness risk; under-caching is a scalability risk

**Connection keep-alive vs. connection pooling:**
- HTTP/1.1 keep-alive reuses a TCP connection for multiple sequential requests — reduces handshake overhead
- HTTP/2 multiplexes many concurrent requests over a single connection — eliminates per-request TCP overhead; most reverse proxies (nginx, Envoy) handle this transparently

## Implementation Notes

**Reverse proxy / TLS termination pattern:**
- nginx or Envoy sits at the edge, terminates HTTPS, forwards plain HTTP (or gRPC) to upstream services over a trusted internal network
- Load balancer (AWS ALB, GCP HTTPS LB) handles certificate provisioning (ACM / Let's Encrypt) and TLS offload automatically at scale

**HTTPS certificate lifecycle:**
- Let's Encrypt: free, 90-day certificates, automated via ACME protocol (Certbot) — standard for internet-facing services
- Internal PKI (e.g. HashiCorp Vault CA, AWS Private CA): for internal mTLS; certificates can be short-lived (hours) to minimize revocation complexity
- Wildcard certs (`*.example.com`) reduce management overhead for multi-subdomain services

**Common API patterns over HTTP:**
- REST over HTTPS: resources as nouns, HTTP verbs for operations, JSON bodies, status codes for results — the default choice
- Webhooks: server-to-server HTTP POST on events; require HTTPS, HMAC signature verification on the receiver to authenticate the sender
- Long polling: client holds an HTTP connection open until the server has data — simpler than WebSockets, higher per-connection overhead

**Rate limiting at the HTTP layer:**
- Return `429 Too Many Requests` with `Retry-After` header
- Nginx / API Gateway enforce token-bucket or leaky-bucket limits per IP or API key before requests reach services
- Typical public API limits: 100–10,000 requests/minute depending on tier

**Observability hooks native to HTTP:**
- `X-Request-ID` / `X-Trace-ID` headers propagate distributed trace context (W3C `traceparent` header is the standard)
- Access logs contain method, path, status code, latency, bytes — the primary operational data source for HTTP services

## Common Pitfalls

- **Forgetting HTTPS for internal services:** Internal plaintext traffic is a common audit finding and a real risk in multi-tenant cloud environments
- **Caching POST/PUT responses:** Only GET (and HEAD) responses are cacheable by default; caching mutation responses causes stale state bugs
- **Ignoring TLS 1.3 0-RTT replay risks:** 0-RTT data can be replayed by attackers; never use it for non-idempotent endpoints
- **Over-relying on HTTP status codes for business logic:** 200 with `{"error": "not found"}` in the body is an antipattern that breaks client error handling and monitoring
- **Keep-alive mismatches at the API Gateway / ALB layer:** Serverless upstreams (Lambda) do not maintain persistent TCP connections; if clients or intermediaries assume keep-alive, idle connection timeouts at the gateway layer can cause unexpected errors — configure gateway idle timeouts and response headers accordingly

## Resources

- MDN Web Docs — HTTP: https://developer.mozilla.org/en-US/docs/Web/HTTP
- RFC 9110 (HTTP Semantics): https://www.rfc-editor.org/rfc/rfc9110
- RFC 9114 (HTTP/3): https://www.rfc-editor.org/rfc/rfc9114
- RFC 8446 (TLS 1.3): https://www.rfc-editor.org/rfc/rfc8446
- High Performance Browser Networking (Grigorik) — Chapter 4 (TLS) and Chapter 12 (HTTP/2): https://hpbn.co/
- Alex Xu — System Design Interview Vol. 1, Chapter 1 (scale from zero)

## Related

- [[load-balancing]]
- [[cdn]]
- [[rate-limiting]]
- [[api-design]]
- [[dns]]
- [[grpc]]
- [[authentication]]
