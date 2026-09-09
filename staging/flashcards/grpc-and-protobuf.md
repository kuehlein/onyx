---
id: grpc-and-protobuf
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

# gRPC and Protocol Buffers

[gRPC](_meta/glossary.md#grpc) is a contract-first RPC framework that makes a network call look like a local method call: you define services and messages in a Protocol Buffers `.proto` file, a code generator emits type-safe client stubs and server skeletons in every supported language, and the call travels as a compact binary payload over HTTP/2. Two ideas do the heavy lifting. Protobuf is the *encoding*: a schema-first binary format where each field is identified on the wire by a small integer tag, not its name, so payloads are tiny and evolve safely. HTTP/2 is the *transport*: [multiplexing](_meta/glossary.md#multiplexing) many concurrent calls over one connection plus long-lived streams, which unlocks the four call types (unary, server-streaming, client-streaming, bidirectional). The result is low-latency, strongly-typed, cross-language service-to-service communication — at the cost of being binary (not human-readable) and awkward in browsers.

> [!tip] Recognition
> Reach for gRPC when you hear "internal service-to-service call," "east-west traffic between microservices," "low-latency polyglot backend (Go server, Java/Python clients)," "we need a strict, code-generated contract," "streaming updates in both directions," or "the JSON/REST overhead is too high for this hot path." If instead you hear "public-facing API," "must be callable from a browser with fetch," or "third parties need to curl it and read the response," that's a signal *against* gRPC (use REST/GraphQL).

## When to Use

**Problem signals that point to gRPC + Protobuf:**
- "Internal microservices call each other thousands of times per request fan-out" — east-west traffic where per-call CPU and payload size dominate
- "Polyglot backend: a Go service, a Java service, a Python service must share one contract" — the `.proto` IDL generates type-safe stubs in every language
- "We need the server to push a stream of updates" (or the client to upload a stream) — native server/client/bidirectional streaming over one connection
- "The [p99](_meta/glossary.md#p99) latency budget for this internal hop is tight" — binary encoding + HTTP/2 multiplexing beat text-over-HTTP/1.1
- "We want a breaking change to fail at compile time, not in production" — generated stubs turn contract drift into build errors

**Prefer gRPC over alternatives when:**
- Over REST/JSON: for *internal* calls where you control both ends, want a strict schema, smaller payloads, and streaming — REST wins for public, human-debuggable, cacheable, browser-native APIs
- Over GraphQL: gRPC is a fixed strongly-typed contract optimized for machine-to-machine latency; GraphQL is for flexible client-driven queries that shape their own response (typically browser/mobile → backend)
- Over raw WebSockets: gRPC gives you a typed, code-generated streaming contract and multiplexing for free, instead of hand-rolling a message framing/dispatch protocol

**Do not use when:**
- The API is public or browser-facing → browsers cannot speak raw gRPC (no direct access to HTTP/2 frames); you need a grpc-web proxy or just use REST/GraphQL
- You need human-readable, curl-able, easily-inspected traffic → binary Protobuf is opaque without the schema
- You rely on HTTP caching / [CDNs](_meta/glossary.md#cdn) / standard REST tooling → gRPC's POST-only, streaming model doesn't fit HTTP caching semantics

## Key Properties

**Protobuf encoding (the contract):**
- Schema-first: a `.proto` file is the single source of truth; `protoc` generates stubs — you never hand-write serialization
- On the wire each field is a `(field number, wire type)` tag + value; **field names are never sent**, which is what makes payloads compact
- Field numbers 1–15 encode their tag in a single byte — reserve them for the most frequent fields; 16–2047 take two bytes
- Compatibility comes from field *numbers*, not order or name: adding a new field with a new number is safe; **never reuse or renumber an existing field** (use `reserved` to retire one)

**HTTP/2 transport & the four call types:**
- One connection multiplexes many concurrent calls (no HTTP/1.1 head-of-line blocking *at the request level*)
- **Unary** — one request, one response (the RPC default)
- **Server-streaming** — one request, a stream of responses (e.g. live feed)
- **Client-streaming** — a stream of requests, one response (e.g. chunked upload)
- **Bidirectional** — both sides stream independently over the same connection (e.g. chat)

## Trade-offs

| Dimension | gRPC + Protobuf | REST + JSON |
|---|---|---|
| Payload | Compact binary (no field names) | Verbose text |
| Contract | Strict schema, codegen, compile-time checks | Loose / OpenAPI, runtime validation |
| Human-debuggable | No — needs the schema to decode | Yes — curl and read it |
| Browser support | Weak — needs grpc-web proxy | Native (`fetch`) |
| Streaming | First-class (4 modes) over HTTP/2 | Awkward ([SSE](_meta/glossary.md#sse)/long-poll/WebSocket bolt-ons) |
| Transport | HTTP/2 required | HTTP/1.1+ |
| Best fit | Internal, low-latency, polyglot service mesh | Public / browser / cacheable APIs |

- **vs. GraphQL:** gRPC = fixed typed contract for machine-to-machine latency; GraphQL = client picks the shape of the response, aggregating many resources in one round trip. Different axis: gRPC optimizes the *wire*, GraphQL optimizes *client query flexibility*.
- **vs. plain data-encoding choice:** choosing Protobuf is the *encoding* decision; choosing gRPC additionally buys you the *transport + RPC* layer (streaming, multiplexing, generated stubs). You can use Protobuf without gRPC, but rarely gRPC without Protobuf.

## Common Pitfalls

- **Reusing or renumbering a field tag.** Compatibility hinges on the field *number*. Changing a field's number, or reusing a deleted field's number for a different meaning, silently corrupts data for peers running the old schema. Mark retired numbers `reserved`.
- **Assuming multiplexing removes all head-of-line blocking.** HTTP/2 removes it at the *request* layer, but because HTTP/2 rides on [TCP](_meta/glossary.md#tcp), a single lost TCP segment still stalls *all* multiplexed streams on that connection ([TCP-level head-of-line blocking](_meta/glossary.md#head-of-line-blocking)) — this is why HTTP/3 moves to QUIC.
- **Expecting browsers to call gRPC directly.** Browser JS cannot access raw HTTP/2 frames, so a browser needs grpc-web plus a translating proxy (e.g. Envoy). Forgetting this breaks web front-ends.
- **Treating a missing scalar as "explicitly unset."** In proto3, unset scalar fields decode to their type default (0, "", false) and are indistinguishable from a value that equals the default; use explicit `optional`/wrapper types when you must tell "absent" from "zero."
- **Ignoring load balancing.** gRPC's long-lived HTTP/2 connections defeat naive connection-level ([L4](_meta/glossary.md#l4)) load balancers — all requests pin to one backend. You need request-level ([L7](_meta/glossary.md#l7)) balancing or client-side load balancing.

## Implementation Notes

A minimal `.proto` and the generated call shape — reconstruct this from the principle (schema-first + tagged fields), don't memorize it:

```proto
syntax = "proto3";

message GetUserRequest {
  string user_id = 1;        // low numbers (1-15) for hot fields
}

message User {
  string user_id = 1;
  string name = 2;
  reserved 3;                // retired field number — never reuse
}

service UserService {
  rpc GetUser (GetUserRequest) returns (User);                 // unary
  rpc StreamUsers (GetUserRequest) returns (stream User);      // server-streaming
}
```

- `protoc` (with a language plugin) generates the client stub and server base class; you implement the server method and call the stub like a local function.
- For browser access, generate grpc-web bindings and front the service with a proxy (Envoy / grpc-web).

## Resources

- gRPC official docs — Introduction & Core Concepts: https://grpc.io/docs/what-is-grpc/introduction/
- Protocol Buffers — Encoding (field tags, varints, wire types): https://protobuf.dev/programming-guides/encoding/
- Protocol Buffers — proto3 Language Guide: https://protobuf.dev/programming-guides/proto3/
- Kleppmann, *Designing Data-Intensive Applications*, Ch. 4 (Encoding & Evolution — Thrift/Protobuf/Avro)

## Related

- [[data-encoding-schema-evolution]]
- [[rest-api-design]]
- [[http-https]]
