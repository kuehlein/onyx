---
id: data-encoding-schema-evolution
type: flashcard
tags:
  - distributed-systems
  - encoding
  - schema
tiers:
  distributed-systems: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Data Encoding & Schema Evolution

Every time data crosses a process boundary — over a network, into a message queue, or onto disk — it must be *encoded* (serialized) from in-memory objects into a byte sequence and *decoded* on the other side. In any system large enough to deploy incrementally, old and new code run simultaneously, so the encoding must tolerate a version skew in *both* directions: new code reading old data ([backward compatibility](_meta/glossary.md#backward-compatibility)) and old code reading new data ([forward compatibility](_meta/glossary.md#forward-compatibility)). Schema-based binary formats (Thrift, Protocol Buffers, Avro) win over text formats (JSON, XML) for service and pipeline traffic because the schema is documentation, enables safe evolution rules, and shrinks the payload — the field-name strings never travel on the wire.

> [!tip] Recognition
> Reach for this when you hear "rolling upgrade," "two versions of the service are live at once," "we can't deploy producers and consumers atomically," "the message-queue payload changed," "we added a field and old clients broke," or "cross-language [RPC](_meta/glossary.md#rpc) contract." Any question about evolving a wire format or on-disk format without downtime is a [schema-evolution](_meta/glossary.md#schema-evolution) question.

## When to Use

**Problem signals that point to a schema-based binary encoding:**
- "We do a rolling deploy, so old and new code run at the same time" — you need both backward and forward compatibility guaranteed by evolution rules
- "This is the wire format for a high-[QPS](_meta/glossary.md#qps) internal service" — payload size and parse cost dominate; drop the field names, use [gRPC](_meta/glossary.md#grpc)/Protobuf or Thrift
- "Cross-language services (Go producer, Java consumer) must agree on a contract" — a shared schema/IDL generates type-safe stubs in every language
- "Analytics pipeline writes millions of records to Hadoop/S3/Kafka with a large, evolving schema" — Avro shines: no per-field tags, schema stored once per file, dynamically generated schemas
- "We need the payload to be self-describing / human-debuggable for a public API" — this is the case *against* binary; JSON stays

**Prefer binary schema-based (Thrift / Protobuf / Avro) over JSON when:**
- Over JSON/XML: the schema removes field-name repetition on every message, enables compact varint/tag encoding, and turns "hope both sides agree" into compiler-checked evolution rules
- Over language-native serialization (Java `Serializable`, Python `pickle`): native formats are tied to one language, are a well-known remote-code-execution attack surface, and give no versioning story — never use them for anything crossing a trust or version boundary

**Prefer Avro specifically when:**
- The schema is large and changes often, or is generated dynamically (e.g. one Avro schema per DB table dumped to a data lake) — Avro adds no field-tag bookkeeping
- You control a schema registry so reader and writer schemas can be matched by ID

**Prefer Protobuf/Thrift when:**
- You want mature, first-class [RPC](_meta/glossary.md#rpc) (gRPC), the tightest per-message CPU cost, and explicit human-assigned field tags as a stable contract

**Do not use a binary schema format when:**
- The payload is a browser-facing public API where debuggability and zero-tooling adoption matter → JSON (optionally validated with JSON Schema)
- Data is tiny and low-frequency and the ops cost of schemas/codegen isn't justified → JSON
- You genuinely need a self-describing document with no out-of-band schema → JSON/CBOR/MessagePack

## Key Properties

**Two independent compatibility directions (memorize the direction of the arrow):**

| Direction | Definition | Who upgrades first |
|---|---|---|
| **Backward** | New code can read data written by **old** code | Consumers/readers first |
| **Forward** | Old code can read data written by **new** code | Producers/writers first |

Backward compatibility is usually easy (new code knows about the old format). Forward compatibility is the hard, valuable one: old code must gracefully ignore data it doesn't understand. Databases need both — a row you wrote last year is read by today's code (backward), and a row written by the newly-deployed code may be read by an old process still finishing its rollout (forward).

**How each format achieves compatibility:**

| | JSON | Thrift / Protobuf | Avro |
|---|---|---|---|
| Schema required | No (self-describing) | Yes (IDL / `.proto`) | Yes (`.avsc` JSON) |
| Field identity on wire | field **name** string | numeric **field tag** | **positional order** (no tags, no names) |
| Unknown field from newer writer | kept as-is | **preserved** as unknown bytes (proto3), skipped by tag+type | resolved via reader vs writer schema |
| Field name change | breaking | free (tag is the identity) | free (name change ok; add alias for the reader) |
| Payload size | large (names repeat) | small | smallest (nothing but values + separate schema) |

**Protobuf/Thrift evolution rules (tag-number based):**
- Each field has a name, a type, and a **numeric tag** encoded on the wire. The tag — not the name — is the field's identity, so you may freely rename fields.
- **Add a field:** give it a *new, never-before-used* tag. Old readers skip the unknown tag (forward compat); new readers reading old data get the field's default / see it absent (backward compat). A new field **must be optional or have a default** — you cannot add a `required` field and keep backward compatibility, because old data has no value for it.
- **Remove a field:** only remove an optional field, and **reserve its tag number** (and name) forever so it is never reused. Never remove a `required` field.
- **Never change or reuse a tag number** — that silently corrupts decoding.
- proto3 dropped `required` entirely (required is considered harmful: it can never be safely removed). Type changes are limited to compatible ones; `optional` ↔ `repeated` is wire-compatible for a scalar field (a `repeated` field decodes an old single value as a length-1 list and old code reading a list takes the last element) — but only for the *non-packed* encoding; proto3 packs repeated scalars by default, so this needs `[packed=false]` to hold.

**Avro evolution rules (reader/writer schema resolution — no tags):**
- The bytes carry no field tags or names; the decoder walks fields in schema order. Decoding therefore *requires knowing the exact writer schema*. Avro's trick: the **writer's schema** and the **reader's schema** need only be *compatible*, not identical. The library resolves them field-by-field:
  - Field in writer but not reader → **ignored**.
  - Field in reader but not writer → filled from the reader's **default** (if none, it's a `SchemaResolutionException` — an error).
- **Add a field with a default** → both backward and forward compatible.
- **Remove a field that had a default** → both backward and forward compatible. (A field you might delete must have had a default; a field you might add must have a default — same rule.)
- Renaming is handled via **aliases** in the reader schema. Only a limited set of **type promotions** are allowed during resolution: `int → long / float / double`, `long → float / double`, `float → double`, and `string ↔ bytes`.
- How does the reader get the writer's schema without shipping it on every record? Three patterns: (1) large file with many records (Avro object container file / Hadoop) — schema written **once in the header**; (2) database of records each written with a possibly-different schema — store a **version number** per record and keep a schema registry; (3) [RPC](_meta/glossary.md#rpc) — negotiate the schema **once at connection setup**.

## Common Pitfalls

- **Confusing the two compatibility directions.** "Backward" is *new reads old*; "forward" is *old reads new*. Get the arrow right or you'll upgrade producers when you should upgrade consumers. Mnemonic: *backward* looks **back in time** at old data; *forward* means today's old code copes with data **from the future**.
- **Adding a `required`/no-default field.** Breaks backward compatibility: old records have no value for it, and there's no default to substitute. Always add fields as optional / with a default.
- **Reusing or renumbering a Protobuf/Thrift tag.** The tag is the field's on-wire identity. Reusing a retired tag makes a new field silently deserialize into old data's bytes. Always `reserved` the number.
- **Assuming renaming a JSON field is safe.** In JSON the *name string* is the identity — renaming is a breaking change with no compiler to catch it. (In Protobuf renaming is free; in Avro you add a reader-side alias.)
- **Losing unknown fields on a round-trip.** A service that decodes → mutates → re-encodes with an *older* schema can drop fields it didn't understand, silently corrupting data written by newer code. proto3 preserves unknown fields; naive JSON `struct` mapping in a statically-typed language often drops unknown keys — use a map or raw-message field to round-trip them.
- **Decoding Avro without the exact writer schema.** Avro has no self-describing tags; if you lose the writer schema (or the schema-registry ID), the bytes are unrecoverable. This is the cost of Avro's compactness.
- **Trusting language-native serialization across a boundary.** `pickle` / Java `Serializable` are RCE gadgets and have no evolution story. Never accept them from an untrusted source; never use them as a durable or wire format.
- **Assuming a type change is free.** Widening an `int32` to `int64` is safe in Protobuf; narrowing, or changing `int` to `string`, is not. Avro only permits the specific promotions listed above.

## Trade-offs

**Text (JSON) vs binary schema-based:**
- JSON: universal, self-describing, human-readable, zero codegen — but bulky (field names on every message), ambiguous number handling (no int/float distinction, precision loss > 2^53, no binary type), and *no enforced evolution rules* (compatibility is by convention, not compiler). Right choice for public/browser APIs.
- Binary schema-based: compact, fast, cross-language type safety, and *evolution rules that a build step enforces* — but requires an IDL/schema, codegen, and a schema-distribution story. Right for internal RPC and data pipelines.

**Protobuf/Thrift vs Avro:**
- Protobuf/Thrift use **explicit human-assigned tag numbers** → the schema and old data can drift independently and a reader tolerates unknown tags without any writer schema. Great for RPC and long-lived point-to-point contracts. Cost: humans must manage tag numbers forever.
- Avro uses **positional, tagless** encoding → smallest payload and painless for *dynamically generated* schemas (no manual tag assignment), which is why it dominates in data lakes. Cost: the reader must obtain the writer schema (registry / file header), so it's less convenient for ad-hoc point-to-point messages.

**Schema-on-write vs schema-on-read:**
- These formats give *schema-on-write* structure to messages/files while still allowing evolution — you get the documentation and safety of a schema without freezing the format. The evolution rules are precisely what let a single migration (add a column, bump a schema) roll out across services over hours or days without a coordinated big-bang deploy.

**Coordination cost:**
- A well-designed evolution story (all changes backward+forward compatible) means producers and consumers deploy **independently, in any order** — the whole point. Violating it forces a lock-step deploy, i.e. downtime or a maintenance window.

## Implementation Notes

**Protobuf message evolution (the safe pattern):**
```proto
// v1
message User {
  string user_id = 1;
  string email   = 2;
}

// v2 — safe, backward + forward compatible
message User {
  string user_id = 1;
  string email   = 2;
  string display_name = 3;          // NEW: new tag, optional/defaulted → old readers skip it
  // string phone = 4;              // removed a field →
  reserved 4;                       //   reserve the tag number...
  reserved "phone";                 //   ...and the name, so neither is ever reused
}
```
Rules in one breath: *new tag for new fields; never reuse or renumber; `reserved` on delete; no new `required`; only widening type changes.*

**Avro reader/writer resolution (the safe pattern):**
```json
// writer schema (v1), embedded in the Avro file header
{ "type": "record", "name": "User", "fields": [
    { "name": "user_id", "type": "string" },
    { "name": "email",   "type": "string" }
]}

// reader schema (v2) used by new consumer code
{ "type": "record", "name": "User", "fields": [
    { "name": "user_id", "type": "string" },
    { "name": "email",   "type": "string" },
    { "name": "display_name", "type": "string", "default": "" }  // default → back+fwd compatible
]}
```
Resolution: `display_name` is absent in the writer's data, so the reader supplies the default `""`. A field present only in the writer is silently ignored. No defaults, no compatibility.

**Schema registry (Confluent-style) compatibility modes to name-drop:**
- `BACKWARD` (default): new schema can read data written by the previous schema → **upgrade consumers first**. Allowed changes: delete fields, add optional/defaulted fields.
- `FORWARD`: previous schema can read data written by the new schema → **upgrade producers first**. Allowed changes: add fields, delete optional fields.
- `FULL`: both directions between adjacent versions → either side upgrades independently; only add/remove fields *with defaults*.
- `*_TRANSITIVE` variants check compatibility against **all** prior versions, not just the immediately previous one.

**Operational checklist for a rolling upgrade:**
1. Make the change backward+forward compatible (add optional/defaulted field; never mutate tags).
2. Register/validate the new schema against the registry's compatibility mode in CI — fail the build on a breaking change.
3. Deploy in the order the compatibility mode dictates (BACKWARD → consumers first; FORWARD → producers first; FULL → any order).
4. Only after every reader can handle the new field do you start *depending* on it.

## Variants

- **JSON / XML / CSV** — textual, self-describing, no schema enforcement; good for interop and public APIs.
- **MessagePack / CBOR / BSON** — binary but still schemaless (self-describing tags); more compact than JSON, no evolution rules or codegen. CBOR is an IETF standard (RFC 8949).
- **Protocol Buffers** — Google; tag-numbered; backbone of [gRPC](_meta/glossary.md#grpc); proto3 dropped `required`.
- **Apache Thrift** — Facebook/Meta; tag-numbered like Protobuf; ships its own RPC stack and multiple encodings (BinaryProtocol, CompactProtocol).
- **Apache Avro** — tagless reader/writer resolution; dominant in Hadoop/Kafka data pipelines; pairs with a schema registry.
- **Cap'n Proto / FlatBuffers** — zero-copy: the wire layout *is* the in-memory layout, so there's no parse step (fast reads, mmap-friendly), at the cost of larger, less flexible encoding.
- **Apache Parquet / ORC** — columnar *on-disk* formats for analytics; complementary to Avro (often Avro schema → Parquet storage).

## Resources

- Martin Kleppmann, *Designing Data-Intensive Applications*, Ch. 4 "Encoding and Evolution" — https://dataintensive.net/
- Protocol Buffers — "Updating a Message Type" (proto3 language guide): https://protobuf.dev/programming-guides/proto3/#updating
- Protocol Buffers — proto best practices (reserve deleted fields, never reuse tags): https://protobuf.dev/best-practices/dos-donts/
- Apache Avro spec — "Schema Resolution": https://avro.apache.org/docs/current/specification/#schema-resolution
- Confluent Schema Registry — compatibility types (BACKWARD/FORWARD/FULL/TRANSITIVE): https://docs.confluent.io/platform/current/schema-registry/fundamentals/schema-evolution.html

## Related

- [[rest-api-design]]
- [[sql-vs-nosql]]
- [[replication-models]]
- [[storage-engines]]
- [[consistency-models]]
- [[partitioning-sharding]]
