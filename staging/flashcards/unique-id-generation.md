---
id: unique-id-generation
type: flashcard
tags:
  - system-design
  - distributed-systems
tiers:
  system-design: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Unique ID Generation

Generating unique identifiers across many machines forces a choice: coordinate (a central allocator, slow and a single point of failure) or embed enough entropy/structure that independent nodes never collide. The modern default is a **structured, mostly-random 128- or 64-bit ID whose leading bits are a timestamp**, so nodes generate IDs with zero coordination *and* the IDs sort roughly by creation time — which keeps B-tree index inserts local instead of scattered. The core tension is **sortability (index locality) vs. coordination cost vs. clock-skew risk**.

> [!tip] Recognition
> Reach for a distributed ID scheme when you see: **"generate IDs across multiple servers/shards without a central sequence"**, **"auto-increment won't work once we shard"**, **"IDs should be roughly time-ordered"** (feed, timeline, tweet/message IDs), **"we need the PK before the DB round-trip"** (client-generated IDs, offline creation, idempotency), or **"random UUID primary keys are killing our insert throughput"** (page splits / write amplification on a random PK).
>
> **vs. the siblings (distinguishing signal):** this card answers *"what value do I stamp on a new row?"* — minting a unique key with no lookup. [Consistent hashing](_meta/glossary.md#consistent-hashing) answers *"which node owns this key?"* — a hash-ring placement function that minimizes remaps when nodes join/leave. **Partitioning/sharding** answers *"how do I split one dataset across many nodes?"* — the data-distribution strategy. Trigger word "collision-free / no central counter" → ID generation; "which server / minimal reshuffle on membership change" → consistent hashing; "split the table / shard key" → partitioning.

## When to Use

**Problem signals that suggest a distributed ID scheme:**
- Writes are spread across multiple app servers or DB shards, so a single auto-increment counter can't be the source of truth
- You need the ID *before* persisting (client-side generation, optimistic UI, [idempotency](_meta/glossary.md#idempotency) keys, merging offline-created records)
- IDs should be roughly time-sortable for pagination, feeds, or "recent first" ordering
- You want to avoid a network round-trip or lock on a central sequence per insert

**Choosing the scheme (the decision boundary):**
- Need **no coordination at all + treat ID as opaque** (session tokens, external-facing IDs where order must NOT leak) → **UUIDv4** (fully random)
- Need **no coordination + time-sortable + fits a UUID column/type** → **UUIDv7** or **ULID** (128-bit, timestamp-prefixed)
- Need a **compact 64-bit integer** (smaller index, fits a BIGINT, DB-friendly) and can run an ID service / assign machine IDs → **Snowflake**

**Do not use when:**
- Single database, no sharding, IDs need not hide count → plain `BIGINT AUTO_INCREMENT` is simpler and smallest; distributed schemes are premature
- IDs are user-facing and must be short/human-friendly (order numbers, coupon codes) → use a separate short-code scheme, not a 128-bit UUID

## Key Properties

Compare the four common options by their generative properties:

| Scheme | Bits | Coordination | Time-sortable? | Reveals info |
|---|---|---|---|---|
| Auto-increment | 64 | Central counter (per DB) | Yes (per counter) | Exact row count / order |
| UUIDv4 | 128 | None (pure random) | **No** | Nothing |
| UUIDv7 / ULID | 128 | None | **Yes** (ms-prefixed, k-sortable) | Approx creation time |
| Snowflake | 64 | Machine-ID assignment + clock | Yes (ms-prefixed) | Approx time + machine |

- **Sortable = timestamp in the most-significant bits.** UUIDv7, ULID, and Snowflake all lead with a millisecond timestamp, so lexical/numeric sort ≈ chronological sort. UUIDv4 has no time component, so it sorts randomly.
- **k-sortable, not strictly sortable:** two IDs from the same millisecond (different nodes, or the random tail) can order arbitrarily. Good enough for index locality; do NOT rely on it as a precise event ordering.

## Trade-offs

- **Sortability vs. write hotspot:** a time-ordered PK keeps inserts clustered at the "right edge" of the B-tree (great locality, avoids the random-UUID page-split pathology). But in a *range-partitioned distributed* DB (Spanner, CockroachDB) that same clustering makes all recent writes hit one partition — a hotspot. There the random spread of UUIDv4 is an advantage, or you hash-shard the key.
- **Coordination vs. simplicity:** UUIDv4/v7/ULID need zero setup — any node generates one offline. Snowflake needs a way to assign each node a unique machine ID (config, ZooKeeper/etcd, or an allocator service); getting two nodes the same machine ID silently produces duplicates.
- **Size vs. compatibility:** Snowflake's 64 bits are half the storage of a 128-bit UUID and fit a native `BIGINT` (smaller indexes, faster comparisons). UUIDs are 128-bit but map to a first-class `uuid` column type and carry far more entropy.
- **Opacity vs. structure:** UUIDv4 leaks nothing — safe as an external identifier. Time-ordered IDs leak approximate creation time (and Snowflake, the machine ID), which can be a business/enumeration concern for public IDs.

## Common Pitfalls

- **Clock skew and clock rollback break time-ordered schemes.** Snowflake/UUIDv7 assume a monotonic wall clock. If NTP steps the clock *backward*, a node can regenerate a timestamp it already used → collisions or out-of-order IDs. Mitigate: refuse to issue IDs while `now < lastTimestamp` (wait or error), and pin machine IDs so a rewind on one node can't collide with another.
- **Duplicate machine IDs.** Two Snowflake workers configured with the same machine ID will mint identical IDs in the same millisecond. The machine-ID assignment mechanism is the real hard part, not the bit-packing.
- **Sequence overflow in one millisecond.** Snowflake's 12-bit per-ms sequence caps at 4096 IDs/ms/node; a node exceeding that must block until the next millisecond. Under-sizing the sequence bits silently rate-limits or collides.
- **Using UUIDv4 as a clustered primary key.** Random 128-bit PKs scatter B-tree inserts, causing page splits, ~50% fill factor, and heavy [write amplification](_meta/glossary.md#write-amplification) at scale. Use UUIDv7/ULID (or a Snowflake) if the random ID must be the clustered PK.
- **Treating k-sortable as total order.** Sorting by a time-ordered ID does not give you exact insertion order within a millisecond or across skewed clocks. If precise ordering matters, carry an explicit logical clock / sequence, not the ID.

## Implementation Notes

- **Snowflake layout (64 bits):** `1 sign bit (unused, keeps it positive) | 41 timestamp (ms since a custom epoch, ~69 years) | 10 machine id (1024 nodes) | 12 sequence (4096/ms/node)`. The custom epoch (not Unix epoch) maximizes usable timestamp years — Twitter's original was 2010-11-04. Bit widths are tunable per deployment (Discord, Instagram, and Sonyflake use different splits).
- **UUIDv7 layout (128 bits, RFC 9562, 2024):** leading 48-bit Unix-ms timestamp, then the 4-bit version, then variant bits and ~74 bits of randomness. RFC 9562 obsoleted RFC 4122 and added v6/v7/v8; v4 (random) and v7 remain the recommended choices (v7 for new systems needing sortability). Prefer a maintained library over hand-rolling the bit/variant fields.
- **ULID:** 128-bit, 48-bit ms timestamp + 80 bits randomness, encoded as 26-char Crockford base32 — lexicographically sortable as a string. Predates UUIDv7 and solves the same problem; UUIDv7 is now the standardized equivalent.
- Snowflake-style generation is often exposed as a small ID service, or embedded in each app instance with the machine ID handed out at startup.

## Resources

- RFC 9562 — Universally Unique IDentifiers (UUIDs): https://www.rfc-editor.org/rfc/rfc9562.html
- Twitter Engineering — Announcing Snowflake: https://blog.twitter.com/engineering/en_us/a/2010/announcing-snowflake
- ULID specification: https://github.com/ulid/spec
- Alex Xu, *System Design Interview Vol. 1*, Chapter 7 — "Design a Unique ID Generator in Distributed Systems"

## Related

- [[database-indexing]]
- [[sharding]]
- [[consistent-hashing]]
- [[database-replication]]
