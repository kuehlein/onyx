---
id: 7f3a2e1c-84b6-4d9f-a051-6c3e5b8d2f90
type: flashcard
tags:
  - system-design
  - scalability
tiers:
  system-design: 1
created: 2026-08-20
confidence: medium
priority: normal
---

# Back-of-Envelope Estimation

Rough-order-of-magnitude calculations that translate vague scale requirements into concrete numbers — [QPS](_meta/glossary.md#qps), storage, bandwidth, machine counts — before any architecture decisions are made. The numbers themselves matter less than demonstrating structured reasoning and knowing which assumptions to surface.

> [!tip] What the interviewer is grading
> State assumptions out loud, round to powers of 10, and always apply the **peak multiplier (≈2–3× average)** — magnitude is the answer, not precision.

## When to Use

**Problem signals that suggest back-of-envelope estimation:**
- Interviewer says "design a system for X million users" or "handle X requests per second"
- Any prompt mentioning scale: "Twitter-scale", "YouTube-scale", "billions of events per day"
- The problem involves storage growth over time (logs, user content, analytics)
- You need to decide between SQL vs. NoSQL, single DB vs. sharding, or whether a cache is even necessary
- The interviewer asks "is this feasible?" or "will this scale?" before diving into design
- Multi-region or multi-datacenter decisions are on the table

**Prefer back-of-envelope over skipping to architecture when:**
- Scale is ambiguous: estimation forces you to clarify assumptions out loud, which is itself the signal the interviewer wants
- You are about to propose expensive infra (e.g., sharding, Kafka): estimation justifies the choice
- You need to size a cache: knowing the working set size determines whether in-memory is viable

**Do not use when:**
- The interviewer explicitly says "skip the numbers, jump into the design" — read the room
- The problem is clearly toy-scale and estimation adds no information (e.g., a CLI tool for one user)

## Key Properties

**Reference numbers every engineer should internalize:**

| Quantity | Value |
|---|---|
| Seconds in a day | ~86,400 (≈ 10^5) |
| Seconds in a month | ~2.6 × 10^6 |
| Seconds in a year | ~3.15 × 10^7 |
| L1 cache latency | ~1 ns |
| L2 cache latency | ~10 ns |
| RAM access | ~100 ns |
| SSD random read | ~100 µs |
| HDD random read | ~10 ms |
| Round-trip within same datacenter | ~500 µs |
| Round-trip cross-continental | ~150 ms |
| Network bandwidth (server NIC) | 1–10 Gbps |
| SSD sequential throughput | ~500 MB/s |
| HDD sequential throughput | ~100–200 MB/s |
| Typical cache hit rate (hot data) | 80–99% |
| Typical DB read QPS (single node, indexed) | ~1,000–10,000 |
| Typical DB write QPS (single node) | ~1,000–5,000 |

**Storage size intuitions:**

| Object | Approximate size |
|---|---|
| ASCII character | 1 byte |
| UUID | 16 bytes |
| Integer (64-bit) | 8 bytes |
| Timestamp | 8 bytes |
| Typical metadata row | 100–500 bytes |
| Compressed image (thumbnail) | 50–200 KB |
| Full-resolution photo | 1–5 MB |
| 1-minute 720p video | ~50–100 MB |
| 1 TB | 10^12 bytes |
| 1 PB | 10^15 bytes |

## Implementation Notes

**Canonical estimation structure (use this in every interview):**

**Step 1 — Clarify the scale assumptions out loud**
- Daily Active Users ([DAU](_meta/glossary.md#dau))
- Read/write ratio
- Peak-to-average ratio (rule of thumb: peak ≈ 2–3× average)
- Data retention window

**Step 2 — Derive QPS**
```
QPS = DAU × requests_per_user_per_day / 86,400
Peak QPS ≈ QPS × 2–3
```

Example: Twitter-like feed, 100M DAU, 10 reads/user/day:
```
Read QPS = 100M × 10 / 86,400 ≈ 11,600 → round to ~12K reads/sec
Peak read QPS ≈ 36K reads/sec
```

**Step 3 — Derive storage**
```
Daily storage = writes_per_day × object_size
Total storage = daily_storage × retention_years × 365
```

Example: 1M photo uploads/day at 2 MB each:
```
Daily = 1M × 2 MB = 2 TB/day
5-year retention = 2 TB × 365 × 5 = ~3.6 PB
```

**Step 4 — Derive bandwidth**
```
Ingress = writes_per_sec × object_size
Egress = reads_per_sec × object_size
```

**Step 5 — Machine count (rough)**
```
Machines = peak_QPS / QPS_per_machine
```
A typical app server handles ~1,000–10,000 [RPS](_meta/glossary.md#rps) depending on workload. A cache node (Redis) handles ~100K–1M ops/sec.

**Common decision thresholds derived from estimation:**
- Peak QPS > ~5,000 on a write path → consider write sharding or async queuing
- Storage > ~5 TB → plan for distributed object storage (S3-compatible), not local disk
- Working set > ~100 GB → cannot fit in a single Redis node; plan for Redis Cluster or eviction policy
- Read QPS > ~10K → a single DB primary is likely a bottleneck; add read replicas or cache layer

## Common Pitfalls

- **Forgetting peak multiplier.** Average QPS will not saturate the system; peak will. Always multiply average by 2–3× and design for that.
- **Confusing MB and MiB / GB and TB.** Use powers of 10 consistently in estimates; switch only when the interviewer uses SI vs. binary explicitly.
- **Not stating assumptions.** The interviewer cannot validate your math if your inputs are invisible. Say "I'll assume 100M DAU and a 10:1 read/write ratio."
- **Over-precision.** Arriving at "11,574 QPS" signals you missed the point. Round aggressively: ~10K, ~100K. The magnitude is the answer.
- **Skipping the estimation entirely.** Jumping straight to "we need Kafka and 20 shards" without justification reads as pattern-matching, not engineering.
- **Ignoring replication factor.** If you need 3 PB of storage and you run 3× replication, your raw disk requirement is 9 PB. Always apply this multiplier.

## Trade-offs

**Estimation accuracy vs. speed:**
- More precise inputs (exact DAU, exact object sizes) → more credible numbers, but takes longer
- Rough powers of 10 → fast, usually sufficient to distinguish "one DB" from "sharded cluster"
- *Interview default:* round to the nearest power of 10 unless a precise number materially changes the architecture decision

**Optimistic vs. pessimistic assumptions:**
- Optimistic estimates can lead to under-provisioning; always bias toward the higher bound for capacity planning
- State which direction you are biasing: "I'll estimate conservatively on object size at 2 MB to leave headroom"

**When estimation changes the design:**
- Cache viability: if working set is 500 GB but you estimated 50 GB, the entire caching layer design changes
- Sharding trigger: the same design scales vertically to ~10K write QPS before horizontal sharding is necessary; estimation is the trigger

**Breadth vs. depth:**
- In a 45-minute system design interview, spend no more than 5–7 minutes on estimation
- Enough to justify your major architecture choices; skip sub-components that do not drive design decisions

## Resources

- *System Design Interview: An Insider's Guide*, Alex Xu — Chapter 2 (Back-of-Envelope Estimation)
- https://highscalability.com/google-pro-tip-use-back-of-the-envelope-calculations-to-choo/
- https://matthewstennett.com/posts/back-of-envelope
- Jeffrey Dean's latency numbers: https://gist.github.com/hellerbarde/2843375

## Related

- [[consistent-hashing]]
- [[database-sharding]]
- [[caching]]
- [[cap-theorem]]
- [[load-balancing]]
