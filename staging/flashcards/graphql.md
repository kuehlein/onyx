---
id: graphql
type: flashcard
tags:
  - networking
  - api-design
tiers:
  networking: 2
created: 2026-09-08
confidence: high
priority: normal
---

# GraphQL

GraphQL is a query language and server runtime where the client sends a single request to a single endpoint declaring exactly which fields of a strongly-typed schema it wants, and the server returns precisely that shape — no more, no less. The core principle: move the choice of *what data to return* from the server (fixed per-endpoint in REST) to the client (per-request), which eliminates over-fetching (getting fields you don't need) and under-fetching (needing several round-trips to assemble one view). The cost is that many things REST gets for free from HTTP — URL-based caching, simple monitoring, cheap abuse protection — now become the API author's responsibility.

> [!tip] Recognition
> Reach for GraphQL when you see: **many different client shapes** hitting the same data (web + iOS + Android each needing different fields), a UI that today makes **3-5 REST calls to render one screen** (under-fetching), mobile clients wasting bandwidth on **fat REST payloads** (over-fetching), or a **BFF/aggregation layer** stitching several backend services into one graph. The tell is "one flexible graph, many consumers" — not "simple resource [CRUD](_meta/glossary.md#crud)."
>
> **vs. siblings (distinguishing signal):** GraphQL = *client picks the fields* of one typed graph over one endpoint (browser-facing, heterogeneous read shapes). **REST** = server fixes the shape per resource URL — pick it when you *want* HTTP/CDN cache-by-URL and clients are uniform. **gRPC + Protobuf** = fixed binary contract for *internal, high-throughput service-to-service* RPC and streaming, not browser-facing flexibility. If the pain is "each screen/client needs a different slice," it's GraphQL; if it's "cache-by-URL simple resources," REST; if it's "fast typed RPC between services," gRPC.

## When to Use

**Problem signals that suggest GraphQL:**
- Multiple client types (web, iOS, Android, partners) each need different subsets/shapes of the same underlying data
- A single screen currently requires several sequential REST calls to assemble (classic under-fetch → waterfall)
- Mobile/low-bandwidth clients receive large REST responses but use a fraction of the fields (over-fetch)
- You are building an aggregation layer / BFF that fronts multiple microservices or databases as one graph
- Rapidly evolving frontend where you want to add/remove fields without versioning or new endpoints

**Prefer GraphQL over alternatives when:**
- Over [REST](rest-api-design.md): client-driven field selection removes over/under-fetch and endpoint proliferation; choose REST when resources are simple, caching is critical, and clients are uniform
- Over [gRPC](_meta/glossary.md#grpc): GraphQL suits browser-facing, flexible-shape reads; gRPC suits high-throughput internal service-to-service RPC with fixed contracts (binary Protobuf, streaming)

**Do not use when:**
- Simple CRUD with one uniform client → REST is less machinery for the same result (GraphQL adds schema, resolvers, N+1 handling for no payoff)
- You rely heavily on HTTP/[CDN](_meta/glossary.md#cdn) caching of GET responses → REST's URL-based caching is far simpler (GraphQL needs persisted queries to get comparable caching)
- File upload/download or byte-range streaming is central → plain HTTP endpoints fit better

## Key Properties

- **Single endpoint, client-specified shape.** All operations POST to one URL (e.g. `/graphql`); the response mirrors the query's field structure exactly. This is the source of both its flexibility and its caching difficulty.
- **Strongly-typed schema is the contract.** Types, fields, and their nullability are declared in the SDL. The schema is the single source of truth between client and server.
- **Introspection.** The schema is queryable at runtime, which powers tooling (GraphiQL, autocomplete, codegen) — but should be disabled or locked down in production to avoid handing attackers a map of your API.
- **Three operation types.** Queries (reads), mutations (writes, executed serially), and subscriptions (server push over a persistent transport such as WebSockets).
- **Errors are in-band.** Over the legacy `application/json` transport a response is HTTP `200` even on field-level errors, which are reported in a top-level `errors` array alongside partial `data`. You cannot rely on HTTP status codes for success/failure the way REST does. (The newer GraphQL-over-HTTP `application/graphql-response+json` media type does let servers return 4xx/5xx for request-level failures, but field errors still ride in the `errors` array.)

## Trade-offs

| Concern | REST | GraphQL |
|---|---|---|
| Data fetching | Fixed per endpoint (over/under-fetch) | Client picks exact fields |
| Endpoints | Many (one per resource/view) | One |
| HTTP caching | Easy — cache by URL/verb | Hard — POST to one URL defeats it (needs persisted queries + GET) |
| Typing / discovery | External (OpenAPI, optional) | Built-in schema + introspection |
| Error signaling | HTTP status codes | `200` + in-band `errors` array |
| Abuse surface | Bounded per endpoint | Unbounded — a client can craft an arbitrarily deep/expensive query |
| Server complexity | Lower | Higher (resolvers, N+1 batching, cost limits) |

The decision boundary: GraphQL trades **server-side and operational complexity** for **client-side flexibility and payload efficiency**. If your clients are uniform and your caching needs are simple, that trade is a net loss.

## Common Pitfalls

- **N+1 resolver problem.** Resolving a list of N parents and then a nested field per parent naively fires 1 query for the list + N queries for the children. This is the single most common GraphQL performance failure. Fix with a per-request DataLoader that **batches** the N child lookups into one call and **caches** within the request. Create a fresh DataLoader per request so cached data never leaks across users.
- **No depth/complexity limit = DoS vector.** Because the client composes the query, a single request can nest deeply or fan out enormously (a "query bomb"). Enforce maximum depth, maximum node/complexity cost, and pagination before executing untrusted queries.
- **Assuming HTTP caching just works.** POST-to-one-endpoint bypasses URL-based HTTP/CDN caching. To regain it, use persisted queries (client sends a hash the server resolves) served over GET with cache headers, plus a client-side normalized cache.
- **Treating HTTP 200 as success.** Field-level failures come back as `200` with an `errors` array and partial `data`; clients that only check the HTTP status will silently miss errors.
- **Leaving introspection open in production.** It hands attackers a complete schema map; disable or restrict it outside development.
- **Serial mutations misunderstood.** Multiple mutations in one operation run sequentially (not parallel like query fields), which matters for ordering and side effects.

## Implementation Notes

Schema-first example (SDL) and a query showing client-specified shape:

```graphql
# Schema (server contract)
type User { id: ID!, name: String!, posts: [Post!]! }
type Post { id: ID!, title: String! }
type Query { user(id: ID!): User }

# Client query — asks for exactly these fields
query { user(id: "1") { name posts { title } } }
```

- **DataLoader** (batching layer) is the canonical N+1 fix — instantiate one per request in the context object.
- **Persisted / Automatic Persisted Queries (APQ):** client sends a query hash instead of the full string; server looks it up, enabling GET requests, smaller payloads, CDN caching, and an allowlist of permitted operations.
- Reference libraries: Apollo Server, GraphQL Yoga, `graphql-js` (JS); gqlgen (Go); Strawberry (Python). Apollo Federation composes multiple subgraphs into one supergraph for microservice aggregation.

## Resources

- GraphQL — Best Practices: https://graphql.org/learn/best-practices/
- GraphQL — Performance (persisted queries, caching): https://graphql.org/learn/performance/
- graphql-js — Solving N+1 with DataLoader: https://www.graphql-js.org/docs/n1-dataloader/
- DataLoader library: https://github.com/graphql/dataloader

## Related

- [[rest-api-design]]
- [[http-https]]
- [[load-balancing]]
- [[cdn]]
- [[rate-limiting]]
