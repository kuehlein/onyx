---
id: 3f8a2c1d-7e4b-4f9a-b6c3-1d2e5f8a9b0c
type: flashcard
tags:
  - system-design
  - rest
  - api-design
tiers:
  system-design: 1
created: 2026-08-20
confidence: medium
---

# REST API Design

REST (Representational State Transfer) is an architectural style for distributed hypermedia systems that treats every resource as a URL-addressable entity operated on via a uniform interface (HTTP verbs). Its statelessness constraint forces all session context into each request, enabling horizontal scaling without server affinity.

## When to Use

**Problem signals that suggest REST API Design:**
- The prompt asks you to design an API layer for a web service, mobile backend, or microservice ("design a URL shortener," "design Twitter," "design a payment service")
- The problem involves external or third-party consumers where contract stability and developer experience matter
- The problem has clear resource entities (users, orders, posts, transactions) with [CRUD](_meta/glossary.md#crud) lifecycle operations
- The prompt explicitly says "HTTP API," "public API," or "REST endpoints"
- You are designing a service boundary between independently deployable components
- The problem involves read-heavy traffic where cacheability at the [CDN](_meta/glossary.md#cdn) or reverse proxy layer is a key scaling lever

**Prefer REST over alternatives when:**
- Over GraphQL: Clients are heterogeneous third parties; cache-ability at the HTTP layer is critical; the access patterns are well-known and stable; you want to avoid N+1 query risk from arbitrary client queries
- Over [gRPC](_meta/glossary.md#grpc): You need browser-native compatibility without a proxy; public developer APIs where SDK generation is not guaranteed; when HTTP/1.1 load balancers are in the path
- Over WebSockets: Communication is request-response (not push); idempotency and retryability matter; you need stateless horizontal scaling

**Do not use when:**
- Real-time bidirectional streaming is required (chat, live feeds) → use WebSockets or [SSE](_meta/glossary.md#sse)
- Internal service-to-service calls at high throughput where binary framing and multiplexing matter → use gRPC
- The client needs flexible, ad hoc field selection over complex object graphs → use GraphQL

## Key Properties

> [!tip] The one rule to remember
> The verb lives in the HTTP method, **not** the URL. `POST /orders` — never `POST /createOrder`. Nouns in paths, verbs in methods, status codes carry outcome.

**Uniform Interface — the central REST constraint:**
- Resources identified by stable URLs: `/users/{id}`, `/orders/{id}/items`
- HTTP verbs carry semantics, not the URL: `GET` (read, safe, idempotent), `POST` (create, not idempotent), `PUT` (full replace, idempotent), `PATCH` (partial update), `DELETE` (idempotent)
- Representations (JSON, XML) are separate from resource identity
- [HATEOAS](_meta/glossary.md#hateoas) (Hypermedia as the Engine of Application State): responses embed links to valid next actions — rarely implemented in practice but theoretically required for "full REST"

**Statelessness:**
Each request carries all context (auth token, session ID) needed to process it. No server-side session state. This is the property that makes REST horizontally scalable — any instance can serve any request.

**Cacheability:**
GET responses can be cached at CDN, reverse proxy, or client layers via `Cache-Control`, `ETag`, and `Last-Modified` headers. This is REST's primary performance advantage over stateful alternatives. A well-designed public API can serve 90%+ of GET traffic from cache.

**Layered System:**
Clients cannot tell whether they are talking to the origin server, a CDN edge node, or a load balancer. This enables transparent insertion of caching, security, and rate-limiting layers.

## Common Pitfalls

- **Verbs in URLs:** `/getUser` or `/createOrder` violates the uniform interface — the verb belongs in the HTTP method, not the path
- **Overloading POST:** Using POST for every mutation because "it's safe" destroys idempotency guarantees and makes client retry logic fragile
- **Non-idempotent DELETE or PUT:** A `DELETE /orders/123` called twice should return 204 then 404 — not error on the second call; ensure your implementation is idempotent
- **Ignoring HTTP status codes:** Returning `200 OK` with `{ "error": "not found" }` in the body breaks every HTTP-aware layer (CDN, monitoring, client error handling)
- **Flat URLs for nested resources:** `/getUserPosts?userId=123` instead of `GET /users/123/posts` — miss the navigability and cacheability of proper resource hierarchy
- **No versioning strategy:** Changing a response field without a versioning scheme (`/v1/`, `Accept: application/vnd.api+json;version=2`) breaks all existing clients
- **Pagination omitted on collection endpoints:** Returning unbounded lists (`GET /orders`) will cause timeout and [OOM](_meta/glossary.md#oom) issues at scale — always paginate (cursor-based preferred over offset for large datasets)

## Trade-offs

| Dimension | REST | GraphQL | gRPC |
|-----------|------|---------|------|
| Cacheability | Native HTTP caching (CDN-friendly) | Difficult — all queries are POST | None (HTTP/2 binary, no CDN cache) |
| Overfetch / underfetch | Common — fixed response shapes | Eliminated — clients select fields | Eliminated via Protobuf schemas |
| Type safety | Weak (JSON) — OpenAPI helps | Strong schema | Strong (Protobuf IDL) |
| Browser support | Native | Native | Requires grpc-web proxy |
| Streaming | Limited (SSE for server push) | Subscriptions | Full bidirectional streaming |
| Tooling / discoverability | Excellent (Swagger, Postman, curl) | Good | Moderate |
| Versioning | Explicit (`/v1/`, headers) | Schema evolution (additive) | Protobuf field numbering |

**Interviewer probe: "How do you handle breaking changes?"**
Maintain parallel versions (`/v1/`, `/v2/`) until clients migrate. Sunset old versions with `Sunset` and `Deprecation` response headers. Additive changes (new optional fields, new endpoints) are non-breaking and can ship without versioning.

**Interviewer probe: "How do you scale a REST API to 1M [RPS](_meta/glossary.md#rps)?"**
CDN for static + cacheable GETs (cache hit rate target: 80–95%), horizontal scaling of stateless API servers behind a load balancer, read replicas for DB, rate limiting at the API gateway layer (token bucket, ~1000 req/min per user is typical), async processing for expensive mutations via message queue.

## Implementation Notes

**URL structure conventions:**
- Plural nouns for collections: `/users`, `/orders`, `/transactions`
- Nested resources for containment: `/users/{userId}/addresses/{addressId}`
- Query parameters for filtering, sorting, pagination: `GET /orders?status=pending&sort=created_at:desc&limit=20&cursor=abc123`
- Actions that don't map cleanly to CRUD: use a sub-resource verb sparingly — `POST /orders/{id}/cancel` is acceptable; `POST /orders/cancelOrder` is not

**Authentication patterns:**
- Bearer token (`Authorization: Bearer <JWT>`) is the dominant pattern — stateless, verifiable without DB lookup if signed
- API keys for machine-to-machine: passed in header (`X-API-Key`) not query string (query strings appear in access logs)
- OAuth 2.0 for delegated third-party access

**Pagination strategies:**
- Offset (`?page=3&limit=20`): simple but inconsistent under concurrent writes; expensive at large offsets (DB scans rows 60–80)
- Cursor-based (`?cursor=<opaque_token>`): stable under mutations, O(1) DB seek to cursor position — preferred for large or frequently updated datasets
- Return pagination metadata in response: `{ "data": [...], "next_cursor": "xyz", "has_more": true }`

**Rate limiting placement:**
Apply at the API gateway or reverse proxy (Nginx, Kong, AWS API Gateway) before requests reach application servers. Token bucket allows burst; leaky bucket smooths traffic. Return `429 Too Many Requests` with `Retry-After` header.

**Idempotency keys:**
For non-idempotent operations (payments, order creation) clients pass a client-generated `Idempotency-Key` header. The server stores the key and result for a [TTL](_meta/glossary.md#ttl) (~24 hours) and returns the cached result for duplicate requests. This is essential for safe client retries.

**Versioning approaches (in order of industry preference):**
1. URL path prefix: `/v1/users` — most visible, easiest to route; creates API sprawl
2. Custom header: `API-Version: 2024-01-01` — cleaner URLs; harder to test with browser/curl
3. `Accept` header content negotiation: `Accept: application/vnd.myapi.v2+json` — most RESTfully correct; least used in practice

## Resources

- Fielding Dissertation (original REST definition): https://www.ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm
- [RFC](_meta/glossary.md#rfc) 9110 — HTTP Semantics: https://www.rfc-editor.org/rfc/rfc9110
- Google API Design Guide: https://cloud.google.com/apis/design
- OpenAPI Specification: https://swagger.io/specification/
- Alex Xu, *System Design Interview Vol. 1*, Ch. 1 (scale from zero); URL Shortener chapter (API design walkthrough)

## Related

- [[consistent-hashing]]
- [[rate-limiting]]
- [[caching]]
- [[api-gateway]]
- [[load-balancing]]
- [[grpc]]
