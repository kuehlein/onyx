---
id: api-gateway
type: flashcard
tags:
  - system-design
  - backend
tiers:
  system-design: 2
created: 2026-09-08
confidence: high
priority: normal
---

# API Gateway

An API gateway is a single entry point that sits in front of a set of backend services and handles cross-cutting concerns so individual services don't each reimplement them. It exists because in a microservices architecture, dozens of clients (web, mobile, third parties) talking to dozens of services would otherwise duplicate authentication, [rate limiting](_meta/glossary.md#rate-limiting), [TLS](_meta/glossary.md#tls) termination, and routing everywhere. The gateway centralizes that policy layer at the network edge, presenting one stable public contract while the internal topology stays free to change.

> [!tip] Recognition
> Reach for an API gateway when you hear: "one public endpoint for many microservices", "clients shouldn't need to know which service to call", "enforce auth / rate limits / API keys in one place", "aggregate several backend calls into one client response", "expose a public API from an internal service mesh", or "different response shapes for mobile vs web (BFF)".

## When to Use

**Problem signals that suggest an API gateway:**
- "We have many microservices and clients need one URL / one contract" — the gateway hides internal decomposition behind a stable facade
- "Enforce authentication, API keys, and rate limits consistently across all services" — centralize policy instead of duplicating it per service
- "The mobile app makes 8 calls to render one screen" — response aggregation / Backend-for-Frontend collapses fan-out into one round trip
- "We're exposing a public API in front of internal [gRPC](_meta/glossary.md#grpc)/legacy services" — protocol translation and request/response transformation happen at the edge
- "Third parties need metered, keyed access to our API" — usage plans, quotas, and per-key throttling live in the gateway

**Prefer an API gateway over alternatives when:**
- Over a plain [load balancer](_meta/glossary.md#lb): you need application-layer policy (authN/authZ, rate limiting, per-route transformation), not just spreading traffic across identical backends
- Over putting cross-cutting logic in each service: one enforcement point avoids drift and duplicated, inconsistent auth/limit code
- Over a service mesh alone: the gateway governs **north-south** (client↔system) traffic and public contracts; a mesh governs **east-west** (service↔service) traffic

**Do not use when:**
- A single service or monolith with one client → a load balancer (or nothing) is simpler; a gateway adds a hop and an operational component for no gain
- Purely internal service-to-service calls → use a service mesh sidecar, not a public gateway
- You only need to distribute traffic across identical replicas with no policy → an [L7](_meta/glossary.md#l7) load balancer suffices

## Key Properties

**Cross-cutting concerns the gateway centralizes (the principle: anything every service would otherwise reimplement at the edge):**
- **Routing** — map external paths/hosts to internal services
- **AuthN / AuthZ** — validate tokens ([JWT](_meta/glossary.md#jwt)), API keys, or [mTLS](_meta/glossary.md#mtls) before requests reach backends
- **Rate limiting & quotas** — protect backends and meter clients
- **TLS termination** — decrypt at the edge; often re-encrypt internally
- **Request/response transformation** — protocol translation (REST↔gRPC), header/body rewriting, versioning
- **Response aggregation** — fan out to several services and compose one response
- **Caching** — serve cacheable responses without hitting backends
- **Observability** — one place for logging, tracing, and metrics across all traffic

**vs. Load Balancer vs. Service Mesh (the highest-value distinction):**

| | API Gateway | Load Balancer | Service Mesh |
|---|---|---|---|
| Primary job | Application-layer policy + one public contract | Distribute traffic across backends | Service-to-service networking |
| OSI layer | L7 (application-aware) | L4 or L7 | L7 policy across all services |
| Traffic direction | North-south (client↔system) | Either (usually north-south) | East-west (service↔service) |
| Deployment | Centralized edge component | Centralized in front of a pool | Distributed data plane: a sidecar per service, or sidecarless (e.g. Istio ambient's per-node proxy) |
| Distinguishing signal | "auth / keys / aggregate / transform at the edge" | "spread requests, no single bottleneck" | "mTLS, retries, traffic policy *between* internal services" |

A gateway typically sits **behind** a load balancer (which spreads traffic across gateway replicas) and **in front of** a service mesh.

**vs. the features it composes (don't confuse the edge with its parts):**
- **vs. rate limiting** — rate limiting is *one policy* the gateway enforces (a mechanism: [token bucket](_meta/glossary.md#token-bucket) / [leaky bucket](_meta/glossary.md#leaky-bucket) over a shared counter); the gateway is the *place* that mechanism (plus auth, routing, transform) runs. "How do I cap requests?" is rate limiting; "where do I enforce it for all services?" is the gateway.
- **vs. service discovery** — service discovery answers "what is the current address of service X?" (a registry/[DNS](_meta/glossary.md#dns) lookup, mostly east-west); the gateway *consumes* discovery to route north-south traffic but is not itself the registry. Distinguishing signal: "find the instance" = discovery; "route + police the request at the edge" = gateway.

## Trade-offs

**Centralization benefit vs. bottleneck/SPOF risk:**
- One enforcement point means consistent policy and one place to observe traffic — but every request now passes through it, so it is a latency hop and a potential [single point of failure](_meta/glossary.md#spof). Mitigate by running it stateless and horizontally scaled behind a load balancer.

**Reduced client complexity vs. added operational component:**
- Clients get one contract and fewer round trips; you get another tier to deploy, secure, version, and monitor.

**God-object / coupling risk:**
- Piling business logic, per-client branching, and orchestration into the gateway turns it into a bloated chokepoint that every team must change and redeploy together — recreating a distributed monolith at the edge. Keep it to generic cross-cutting policy; push business logic into services. If per-client shaping grows, split into per-client BFF gateways instead of one mega-gateway.

**Gateway vs. mesh overlap:**
- Both can do retries, TLS, and observability. Use the gateway for the public edge and the mesh for internal traffic; duplicating full policy in both adds latency and confusion about where a rule lives.

## Common Pitfalls

- **Turning the gateway into a god-object.** Business logic, data joins, and per-client orchestration leaking into the gateway make it a fragile, high-churn chokepoint. It should own generic edge policy only.
- **Treating it as a plain load balancer (or vice-versa).** A gateway does application-layer policy; a load balancer distributes traffic. Confusing them leads to auth/rate-limit logic scattered across services, or an over-engineered gateway where a simple LB would do.
- **Ignoring it as a single point of failure.** A single non-replicated gateway means the whole API dies with it. Run multiple stateless instances behind a load balancer with health checks.
- **Chatty aggregation hiding backend latency.** Aggregating N backend calls means the response is as slow as the slowest call and fails if any hard dependency fails — add per-call timeouts, partial-response handling, and [circuit breakers](_meta/glossary.md#circuit-breaker).
- **Double-enforcing or under-enforcing auth.** Assuming "the gateway handles auth" while internal services trust any caller means anything past the edge is unauthenticated (defense-in-depth gap); enforce identity in the mesh/services too for sensitive operations.

## Implementation Notes

Common products: AWS API Gateway, Kong, Apigee, Envoy-based gateways (e.g. the Kubernetes Gateway API / Istio ingress), and NGINX. Typical placement:

```
client → DNS → load balancer → API gateway (auth, rate limit, route, transform)
       → [service mesh sidecars] → microservices
```

- Keep the gateway **stateless** (offload sessions/tokens to a store or use self-contained JWTs) so it scales horizontally and any replica can serve any request.
- Push rate-limit counters to a shared store (e.g. Redis) so limits are global across gateway replicas, not per-instance.
- BFF (Backend-for-Frontend) pattern: one gateway per client type (mobile, web) shaping responses for that client, instead of one gateway branching on every client.

## Resources

- Microsoft Azure Architecture Center — Gateway patterns (Gateway Routing / Offloading / Aggregation): https://learn.microsoft.com/en-us/azure/architecture/patterns/gateway-aggregation
- microservices.io — API Gateway / BFF pattern (Chris Richardson): https://microservices.io/patterns/apigateway.html
- Kong — What is an API Gateway: https://konghq.com/learning-center/api-gateway/what-is-an-api-gateway
- AWS API Gateway docs: https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html

## Related

- [[load-balancing]]
- [[rate-limiting]]
- [[service-discovery]]
- [[rest-api-design]]
