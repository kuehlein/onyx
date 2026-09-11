---
id: cqrs
type: flashcard
tags:
  - distributed-systems
  - backend
  - system-design
tiers:
  distributed-systems: 3
created: 2026-09-10
confidence: high
priority: normal
---

# CQRS (Command Query Responsibility Segregation)

CQRS splits the model that **changes** state (commands/writes) from the model that **reads** it (queries), so each can be shaped, stored, and scaled for its own workload instead of forcing one model to serve both. The core insight: reads and writes usually have very different shapes — reads are far more frequent and want denormalized, query-optimized views, while writes want a normalized, validated, consistency-enforcing model — and a single shared model is a compromise that serves neither well. The price is that the read side becomes a *separate*, usually asynchronously-updated copy, so it is [eventually consistent](_meta/glossary.md#eventual-consistency) with the write side.

> [!tip] Recognition
> Reach for CQRS reasoning when you see: "reads massively outnumber writes," "the read and write models look nothing alike," "we need many different read views / a search index / a denormalized dashboard off the same data," "scale reads independently of writes," "the write side needs strict validation but reads just need to be fast," or it's paired with "[[event-sourcing]] / project events into read models." Red flag *against* it: "simple CRUD" or "reads must always reflect the latest write."

## When to Use

**Problem signals that suggest CQRS:**
- A large **read/write asymmetry** — reads dominate and you want to scale, cache, or replicate the read path without touching write capacity.
- The **read and write models genuinely diverge**: the write side enforces invariants over a normalized aggregate, while consumers want denormalized, per-view shapes (a dashboard, a search index, a materialized report).
- You already need multiple **[materialized read views](_meta/glossary.md#materialized-view)** of the same underlying data, each optimized for a different query.
- A complex or collaborative domain where write-side business rules are elaborate but queries are simple lookups.
- You're doing event sourcing and need queryable state — read-side **projections** off the event log are the natural query model.

**Prefer CQRS over alternatives when:**
- Over a **single shared model (plain CRUD)**: when one model can't be tuned for both sides without hurting one — e.g. heavy joins for reads slowing the write schema, or write-side normalization making reads expensive.
- Over just **read replicas**: read replicas scale read *throughput* of the *same* schema; CQRS additionally lets the read side have a *different, denormalized shape* (and its own store type — e.g. Elasticsearch for search, a cache for hot lookups).

**Do not use when:**
- The domain is simple **CRUD** with symmetric read/write needs → one model is simpler and CQRS is pure overhead. This is the most common misuse.
- You need **read-your-writes / strong read-after-write** everywhere → the async read side introduces a staleness window; don't fight it, avoid CQRS there (or serve those specific reads from the write model).
- Small scale / early product → the extra moving parts (sync pipeline, two stores) aren't justified yet.

## Key Properties

- **Two models, not necessarily two databases.** At minimum CQRS separates the write *model* from the read *model* in code. Often it also means separate *stores* (a normalized OLTP write DB + a denormalized read store / cache / search index), but that's a scaling choice, not the definition.
- **The read side is a derived, asynchronously-updated copy.** Writes update the write store, then a sync mechanism (events, [CDC](_meta/glossary.md#change-data-capture), a projection worker) updates the read store. This makes reads eventually consistent — there is a lag window where a read won't reflect a just-committed write.
- **CQRS and [[event-sourcing]] are independent, and pair well.** You can do CQRS *without* event sourcing (e.g. dual writes, CDC, or trigger-updated views) and event sourcing *without* CQRS. They're combined so often people conflate them, but they solve different problems: event sourcing is *how you store write history*; CQRS is *how you separate read from write*. (This is the #1 point of confusion.)
- **Commands vs queries.** Commands express intent to change state and can be rejected (validation); they ideally return little. Queries never mutate and return data. This is CQRS taken to the API/method level (a stricter cousin of CQS — Command-Query Separation at the method level).
- **Independent scaling and technology choice.** Read and write sides can use different databases, scaling strategies, and even deployment units.

## Common Pitfalls

- **Applying CQRS everywhere (over-engineering).** It's a targeted pattern for asymmetric or complex sub-domains, not a default architecture. Blanketing a CRUD app in CQRS multiplies stores, code, and failure modes for no benefit — the most common and costly mistake.
- **Ignoring the eventual-consistency gap.** Teams add an async read model, then a user updates something and immediately re-reads a stale value. Either surface the lag (optimistic UI, versioning), route read-after-write to the write model, or accept and document the window — don't pretend reads are strongly consistent.
- **Dual-write inconsistency.** Writing to the write store and the read store as two separate operations (no shared transaction / no log) means a crash between them permanently desyncs them. Drive the read side from a single source of truth — the event log or CDC stream — not a second synchronous write.
- **Unbounded projection lag / no rebuild path.** If the projection worker falls behind or a read model gets corrupted, you need a way to measure lag and *rebuild* read models from the source (log/events). Not planning for rebuild is a trap.
- **Conflating CQRS with event sourcing.** Adopting the full event-sourced, eventually-consistent, multi-store stack when you only needed a denormalized read view — pick the lightest mechanism (a materialized view or read replica) that meets the need.

## Trade-offs

| Axis | Single model (CRUD) | CQRS |
|---|---|---|
| Simplicity | High — one model, one store, one transaction | Low — two models, sync pipeline, more ops |
| Read/write scaling | Coupled | **Independent** |
| Read model shape | One schema serves all | **Many optimized views** (denormalized, search, cache) |
| Consistency of reads | Strong (same store) | Usually **eventual** (async read side) |
| Write-side validation | Mixed with read concerns | Clean, focused write model |
| Best fit | Simple/symmetric CRUD | Read-heavy, complex domain, divergent read/write needs |

- **Complexity vs independent optimization** is the central trade: you accept more moving parts and eventual consistency in exchange for a read path and write path that are each optimal.
- **How much CQRS?** It's a spectrum: separate models in one DB (light) → separate read store updated by CDC (medium) → full event-sourced write log with multiple projections (heavy). Choose the lightest point that solves the problem.
- **vs [[event-sourcing]]:** orthogonal — event sourcing gives you the write-side log and audit/history; CQRS gives you the read/write split. Combined, events feed the read projections.

## Resources

- Greg Young — *CQRS Documents* (the origin of the term) — https://cqrs.wordpress.com/documents/
- Martin Fowler — *CQRS* — https://martinfowler.com/bliki/CQRS.html
- Microsoft — *CQRS pattern* (Azure Architecture Center) — https://learn.microsoft.com/azure/architecture/patterns/cqrs

## Related

- [[event-sourcing]]
- [[change-data-capture]]
- [[replication-models]]
- [[caching-strategies]]
- [[read-your-writes-consistency]]
- [[saga-pattern]]
