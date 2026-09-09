---
id: microservices-vs-monolith
type: flashcard
tags:
  - system-design
  - backend
  - microservices
tiers:
  system-design: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Microservices vs Monolith

Monolith vs microservices is a decision about *deployment and team topology*, not about code quality — a well-modularized monolith and a microservices system can share the same logical boundaries. A monolith is one deployable unit where modules call each other in-process; microservices split the system into independently deployable services, one per business capability, communicating over the network. The core trade is **simplicity and strong in-process guarantees (monolith)** against **independent deploy/scale/tech-choice per team, paid for with distributed-systems complexity (microservices)**. The dominant guidance is to start with a monolith and extract services only once a boundary has proven stable, because the network is the expensive part.

> [!tip] Recognition
> Reach for **microservices** when the pain is *organizational or scaling*, not technical: multiple teams blocking each other on a shared deploy, one component needing radically different scale/hardware (e.g. GPU inference) or an independent release cadence, or a section needing a different language/runtime. Reach for (or stay on) a **monolith** when the signals are a single/small team, an unproven or shifting domain, a need for strong transactional consistency across features, or "we want to move fast and can't afford ops overhead." The trigger for splitting is a *proven, stable boundary* — never "microservices are modern."

> [!warning] Don't confuse with (interference)
> This card is the **architecture decision** — split or not, and where. The siblings are *mechanisms inside* an already-microservices system:
> - **vs. Saga pattern:** *how* you keep data consistent across a boundary you already split (compensating transactions). This card decides *whether* to create that boundary at all.
> - **vs. Service discovery:** *how* one service finds another's live network address at runtime. This card decides *whether* there are multiple services to find.
> - **vs. API gateway:** the single client-facing entry point that fronts and routes to services. This card decides *whether* you need that fan-out.
>
> Distinguishing signal: if the question is "monolith or split it — and where?" you're on this card; if it's "given services already exist, how do I do X?" you're on a sibling.

## When to Use

**Signals that justify microservices:**
- Multiple teams repeatedly block on one shared deploy pipeline or release train — the constraint is coordination, not code
- One component's scaling profile diverges sharply (e.g. video transcoding, ML inference) and you want to scale/hardware it independently
- A subsystem needs an independent deploy cadence, isolated blast radius, or a different language/runtime
- The domain boundaries are *already well understood and stable* from running the monolith

**Prefer a monolith when:**
- Over microservices: single or small team, greenfield/unproven domain, or features that share strongly-consistent data — keep it in-process and refactor cheaply
- Over microservices: you cannot yet staff the operational surface (CI/CD per service, distributed tracing, service discovery, on-call for network failures)

**Do not reach for microservices when:**
- The domain boundaries are still shifting → premature splits ossify the wrong seams and are painful to move; extract later
- The real problem is a messy codebase → a modular monolith (enforced module boundaries in one deployable) fixes coupling *without* adding the network
- You need multi-entity transactional consistency as the norm → crossing a service boundary turns a local [ACID](_meta/glossary.md#acid) transaction into a [saga](_meta/glossary.md#saga)

## Key Properties

- **Unit of independence is the differentiator.** Monolith = one build/deploy/scale unit; microservices = each service deploys, scales, and can be rewritten in a different stack independently. This independence is the entire point — and the entire cost.
- **Failure model differs.** In a monolith an internal call either returns or throws in-process. Across a service boundary a call can also *time out, partially succeed, or be duplicated* — every caller must handle partial failure, retries, and timeouts.
- **Consistency model differs.** Monolith uses local ACID transactions across features. Microservices generally cannot span a transaction across services → outcomes become [eventually consistent](_meta/glossary.md#eventual-consistency), coordinated by a [saga](_meta/glossary.md#saga) (or a blocking [two-phase commit](_meta/glossary.md#two-phase-commit), usually avoided).
- **Conway's Law is load-bearing.** A system's architecture tends to mirror the communication structure of the org that builds it. Service boundaries that don't match team boundaries generate constant cross-team coordination — so you often design the teams (via the "inverse Conway maneuver") to get the architecture you want.
- **Data ownership.** Each microservice owns its own datastore; other services must go through its API, never its database. A shared database silently recouples services into a distributed monolith.

## Trade-offs

| Dimension | Monolith | Microservices |
|---|---|---|
| Deploy | One artifact, one pipeline; small change redeploys everything | Per-service, independent cadence; a change ships alone |
| Scaling | Scale the whole app as a unit | Scale each service to its own load profile |
| Inter-module calls | In-process, fast, reliable | Network: latency, timeouts, partial failure |
| Transactions | Local ACID across features | [Saga](_meta/glossary.md#saga)/eventual consistency across services |
| Tech stack | Uniform | Polyglot per service |
| Fault isolation | A bad module can take down the process | Blast radius contained *if* boundaries + [bulkheads](_meta/glossary.md#bulkhead) are right |
| Ops / observability | Simple: one log, one trace | Distributed tracing, service discovery, mesh, per-service on-call |
| Team fit | 1 small team | Many teams owning services (Conway) |
| Refactoring boundaries | Cheap — move code in-process | Expensive — network contract + data migration |

**The central tension:** microservices trade the *simplicity* and strong guarantees of a monolith for *organizational scalability* and independent evolution. You pay that cost in distributed-systems complexity whether or not you actually needed the independence — so the win only materializes when team/scale pressure is real.

## Common Pitfalls

- **Distributed monolith.** Services that must be deployed together, share a database, or chatter synchronously in tight request chains get *all* the network cost with *none* of the independence — the worst of both worlds. Test: can each service deploy alone without lockstep? If not, it's a distributed monolith.
- **Premature decomposition.** Splitting before the domain is understood freezes the wrong boundaries into network contracts, which are far costlier to move than in-process code. Prefer a modular monolith first; extract on a *proven* boundary.
- **Shared database across services.** The most common recoupling: two services reading/writing the same tables can't evolve schemas independently and are effectively one unit. Each service owns its data; access others only via their API.
- **Ignoring partial failure.** Treating a network call like a local method call — no timeout, retry, [idempotency](_meta/glossary.md#idempotency), or [circuit breaker](_meta/glossary.md#circuit-breaker) — turns one slow dependency into a [cascading failure](_meta/glossary.md#cascading-failure) across the graph.
- **Assuming transactions still work.** Business flows that were one ACID transaction now span services; forgetting to design a [saga](_meta/glossary.md#saga) with compensating actions leaves the system in partially-committed, inconsistent states.
- **Distributed monolith via synchronous chains.** Long synchronous A→B→C→D call chains multiply latency and failure probability; prefer async messaging or aggregation to decouple.

## Implementation Notes

- **Decompose by bounded context, not by technical layer.** Split along business capabilities (Orders, Payments, Inventory) — DDD "bounded contexts" — so each service is cohesive and boundaries are stable. Never split into "the database service," "the API service" (horizontal layers all change together).
- **Strangler-fig migration.** To move from monolith to services, route traffic through a facade and peel off one capability at a time behind it, rather than a big-bang rewrite.
- **Resilience is mandatory, not optional:** timeouts on every remote call, retries with [jitter](_meta/glossary.md#jitter) + [idempotency keys](_meta/glossary.md#idempotency-key), circuit breakers, and bulkheads to bound blast radius.
- **Prefer async where you can:** event-driven / message-queue communication decouples services in time and reduces synchronous coupling; reserve synchronous request/response for reads that truly need it.

## Resources

- Sam Newman, *Building Microservices*, 2nd ed. (O'Reilly) — the canonical treatment of boundaries, decomposition, and resilience
- Martin Fowler — Microservices guide: https://martinfowler.com/microservices/
- Martin Fowler — MonolithFirst: https://martinfowler.com/bliki/MonolithFirst.html
- Chris Richardson — Microservices patterns (Saga, database-per-service): https://microservices.io/patterns/index.html

## Related

- [[saga-pattern]]
- [[message-queues]]
- [[load-balancing]]
- [[cap-theorem]]
- [[consistency-models]]
