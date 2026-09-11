---
id: design-unique-id-generator
type: system-design
tags:
  - system-design
  - distributed
  - unique-id-generation
tiers:
  system-design: 2
created: 2026-09-11
confidence: high
priority: normal
---

# Design a Unique ID Generator

A service that hands out globally unique identifiers across many machines with no central bottleneck. The crux is a three-way tension: **zero coordination** (nodes mint IDs alone), **rough time-sortability** (leading bits are a timestamp so IDs sort by creation and keep B-tree inserts local), and **compactness** (64 bits so they fit an integer PK). You cannot maximize all three — the whole problem is picking the scheme whose trade-offs match the access pattern.

> [!tip] Interview signals
> The interviewer is really probing two decisions: (1) **why not just UUIDv4?** — you must articulate that a random 128-bit PK scatters index inserts (page splits, write amplification) and can't be range-scanned; (2) **how do you stay coordination-free yet unique?** — the Snowflake answer: partition the ID space by embedding a machine ID. The classic curveballs: *"NTP steps the clock backwards — now what?"* (you must NOT emit a smaller timestamp than the last one), *"the per-ms sequence field overflows"* (spin-wait to the next ms), and *"how do machine IDs get assigned without a registry becoming the new SPOF?"* Junior answers reach for a DB auto-increment or a random UUID and stop; senior answers reason about clock skew, monotonicity guarantees, and the sortability-vs-coordination frontier explicitly.

## Problem & Requirements

**Clarifying questions a strong candidate asks first:**
- Must IDs be **globally unique**, or unique per table/tenant? (Assume global.)
- Do they need to be **sortable by time**, or just unique? (Assume roughly time-sortable — this drives everything.)
- **Size budget?** 64-bit (fits a BIGINT PK, index-friendly) vs 128-bit (UUID)? (Assume 64-bit target.)
- Is **strict monotonicity** required, or is "roughly increasing" enough? (Assume roughly — strict is far more expensive.)
- Can IDs be **guessable/sequential** (enumeration risk), or must they be opaque? (Assume internal IDs; guessability acceptable.)

**Functional**
- Generate unique IDs on demand; no two nodes ever collide.
- IDs are numeric and sort approximately by creation time.

**Non-functional**
- **Scale:** ~10K IDs/sec sustained, bursts to 100K/sec across the fleet.
- **Latency:** ID generation is a local in-process call — sub-microsecond; no network hop on the hot path.
- **Availability:** effectively 100% — a node can mint IDs even if every other service is down.
- **Uniqueness:** hard guarantee, even across node restarts and clock adjustments.

## Estimation

- Target sustained **10K IDs/sec**, peak **100K/sec**.
- With a **Snowflake 64-bit layout** (41 timestamp bits | 10 machine bits | 12 sequence bits):
  - **Sequence = 12 bits → 4,096 IDs per machine per millisecond** = ~4.1M IDs/sec/machine. One node alone dwarfs the 100K/sec peak, so throughput is a non-issue; the design is about correctness, not capacity.
  - **Machine = 10 bits → 1,024 nodes.** Plenty for a fleet.
  - **Timestamp = 41 bits of milliseconds ≈ 2^41 / (1000·60·60·24·365) ≈ 69.7 years** of lifespan from a custom epoch. Pick an epoch (e.g. 2024-01-01) so the clock doesn't exhaust until ~2094.
- **Storage per ID:** 8 bytes. At 10K/sec that's 80 KB/sec of raw ID bytes ≈ **2.5 TB/yr** if every ID were persisted — but IDs are usually PKs on rows you'd store anyway, so the marginal cost is the 8-byte column, not a separate store.

## API Design

Primary usage is an **embedded library** (no network call), with an optional service wrapper for polyglot fleets.

- Library: `long nextId()` — returns the next 64-bit ID; thread-safe; blocks only on sequence exhaustion within a millisecond.
- Service (optional): `POST /ids?count=N` → `{ "ids": [id1, ...] }` — batch-allocates N IDs to amortize the RPC (used by range/ticket schemes).
- Decode helper: `parse(id)` → `{ timestamp, machineId, sequence }` — the timestamp is extractable, which is handy for debugging and coarse time-bucketing.

## Data Model & Storage

The generator itself is largely **stateless** — its "data" is packed into the ID bits, not a table. Two things need durable-ish coordination:

- **Machine ID assignment.** Each node needs a unique 10-bit ID. Options: a small ZooKeeper/etcd ephemeral sequential znode per node (registry hands out 0–1023), or derive from a stable attribute (ordinal in a Kubernetes StatefulSet). This is the only coordination point and it happens **once at startup**, off the hot path.
- **Ticket-server fallback (if chosen):** a single-column table `Tickets(stub CHAR(1) PRIMARY KEY, id BIGINT AUTO_INCREMENT)` with `REPLACE INTO` to advance the counter — but this is a SPOF, discussed below.

**SQL vs NoSQL:** the generator needs no primary datastore. Where an ID lands, a **64-bit sortable ID is ideal as a B-tree clustered PK** — inserts append near the right edge instead of scattering, so it fits SQL/OLTP access patterns far better than a random UUID. The sharding/partitioning key of the *downstream* system is often this very ID (its high bits give time-locality; hashing it gives even spread) — see [[partitioning-sharding]].

## High-Level Design

**Snowflake (recommended baseline):**

1. Each application node embeds the generator library and, at startup, acquires a **machine ID** from etcd/ZooKeeper (or its StatefulSet ordinal).
2. On `nextId()`, the node reads its **local monotonic clock**, packs `((now - epoch) << 22) | (machineId << 12) | sequence`, and returns it. No network hop, no lock contention beyond a per-node atomic.
3. Within the same millisecond, `sequence` increments; on overflow (4096) the node **busy-waits to the next millisecond**. Across milliseconds, `sequence` resets to 0.

**Representative "write" (generate an ID):** caller → in-process `nextId()` → read clock → compare to last-seen timestamp → pack bits → return. Everything is local; the only shared state is `(lastTimestamp, sequence)` guarded by a lightweight lock or CAS loop.

**Representative "read" (use an ID):** the ID is already a value in hand; a consumer can `parse(id)` to recover the embedded creation time without a lookup. Downstream, the ID becomes a sortable PK, so range queries ("newest N rows") walk the index right-to-left — no separate `created_at` index needed for coarse ordering.

For the optional service form, requests go client → [[load-balancing|load balancer]] → stateless ID-service nodes (each with its own machine ID) → response; batch allocation (`count=N`) amortizes the network cost.

## Deep Dives

### Snowflake bit layout and clock-skew handling

**Layout (64 bits):** `1 sign bit (0) | 41 timestamp ms | 10 machine id | 12 sequence`. The timestamp occupies the **high bits**, which is what makes IDs sort by time. Machine bits guarantee cross-node uniqueness with zero coordination at generation time. Sequence bits disambiguate multiple IDs in one millisecond on one node.

**The hard part — the backward clock.** NTP can *step* the wall clock backward. If you naively read `System.currentTimeMillis()` and it went back, you can emit an ID with a smaller timestamp than one you already handed out — breaking monotonicity and, worse, risking a **collision** (same ms + same sequence path). Mitigations, in order of preference:
- **Detect and refuse:** store `lastTimestamp`. If `now < lastTimestamp`, do **not** generate. If the drift is small (a few ms), **spin-wait until the clock catches up** to `lastTimestamp`, then proceed.
- **If drift is large,** fail loudly / mark the node unhealthy and let the LB drain it, rather than emitting bad IDs.
- **Run NTP in slew mode** (`ntpd -x` / chrony) so the clock is *slowed/sped*, never stepped backward. This makes backward jumps essentially impossible in normal operation.
- Use a **monotonic clock source** for the ordering check where the platform allows, reconciling to wall-clock only for the emitted timestamp.

### The alternatives it's chosen against

- **UUIDv4 (128-bit random):** truly zero coordination and dead simple, but **not sortable** (random inserts fragment B-tree indexes → page splits, write amplification) and **twice the size** (16 bytes vs 8) inflates every index and FK. Good when you need offline/client-side generation and don't care about ordering. *(UUIDv7 fixes sortability by putting a timestamp in the high bits — essentially Snowflake's idea in 128 bits — but still costs the extra 8 bytes.)*
- **DB auto-increment / ticket server:** perfectly sortable and compact, but the counter is a **single point of failure and a write bottleneck**. HA needs two servers on odd/even (or stepped) sequences, which sacrifices strict ordering and complicates ops. Doesn't scale writes.
- **Range/segment allocation (a.k.a. "leaf/segment"):** a central store hands each node a **block** (e.g. 1,000 IDs) at a time; the node serves that range locally and fetches a new block when it runs low. Amortizes coordination ~1000:1 and survives brief store outages (node still has its block), but IDs are **only monotonic within a block**, not globally time-sortable, and you can lose a block's worth of IDs on crash (usually fine).

## Trade-offs & Bottlenecks

| Scheme | Coordination | Sortable? | Size | Main risk |
|---|---|---|---|---|
| **Snowflake** | machine-id once at startup | roughly (time high-bits) | 64-bit | clock skew / backward clock |
| **UUIDv4** | none | no (random) | 128-bit | index fragmentation, size |
| **UUIDv7** | none | yes | 128-bit | size (16 B PK) |
| **DB auto-increment / ticket** | every ID (central) | strictly | 64-bit | SPOF, write bottleneck |
| **Range/segment allocation** | per block (~1000:1) | within-block only | 64-bit | ID loss on crash, weaker order |

**Why roughly-sortable + 64-bit matters (the senior point):** it's not aesthetic. A time-prefixed 64-bit ID used as the clustered PK means inserts append to the **right edge** of the B-tree — hot, cacheable pages, minimal splits. A random 128-bit UUID PK scatters inserts across the whole index, causing page splits and write amplification, and doubles the size of every index and foreign key that references it. On a high-write OLTP system this is the difference between a healthy insert path and one drowning in I/O.

**Bottleneck under scale:** with Snowflake there is essentially **no throughput bottleneck** (4M IDs/sec/node). The real limits are (1) **clock correctness** — mitigated by slew-mode NTP + refuse-on-backward-clock, and (2) **machine-ID exhaustion / reuse** — 1,024 nodes cap; mitigate by reclaiming IDs of dead nodes via the etcd registry, or steal bits from the sequence field (fewer IDs/ms, more machines) if the fleet grows past 1,024. Contrast the ticket server, whose bottleneck is the single writer — which is precisely why Snowflake is the default.

## Related
[[unique-id-generation]]
[[consistent-hashing]]
[[replication-models]]
[[sql-vs-nosql]]
[[partitioning-sharding]]
[[database-indexing]]
