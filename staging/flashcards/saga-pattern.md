---
id: saga-pattern
type: flashcard
tags:
  - distributed-systems
  - transactions
  - microservices
tiers:
  distributed-systems: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Saga Pattern

A saga models a long-lived distributed transaction as a sequence of *local* [ACID](_meta/glossary.md#acid) transactions, one per service, where each step publishes an event or message that triggers the next. There is no distributed lock and no global commit: if step _k_ fails, the saga runs **compensating transactions** for steps _k−1 … 1_ in reverse to semantically undo their effects. The price of dropping the two-phase commit lock is that a saga gives you ACD but **not Isolation** — intermediate state is visible to concurrent sagas, so anomalies must be handled in application design. Introduced by Garcia-Molina & Salem (1987) for single-database long transactions; adopted as the default cross-service transaction pattern in microservices.

> [!tip] Recognition
> Reach for a saga when a business operation spans **multiple services / databases that each own their data**, the operation is **long-lived** (holding locks across it is unacceptable), and you need **eventual atomicity** ("all steps commit, or all are compensated") without a distributed coordinator holding locks. Signals: "order → payment → inventory → shipping" across separate services; "we can't use a distributed transaction because each service has its own DB"; "the third-party API can't join our transaction."

## When to Use

**Problem signals that suggest a saga:**
- A single logical operation writes to **two or more services / databases** that do not share a transaction manager (classic e-commerce checkout: Order, Payment, Inventory, Shipping)
- The workflow is **long-lived** — it waits on human approval, a third-party API, or a queue — so holding row/table locks for its duration is unacceptable
- You need **eventual atomicity** and are willing to reason about intermediate, non-isolated states
- Steps have **natural business-level inverses** (refund a payment, restock inventory, cancel a reservation) so compensation is meaningful

**Prefer a saga over alternatives when:**
- Over two-phase commit (2PC / XA): when you need availability and low latency, services span heterogeneous datastores (an [RDBMS](_meta/glossary.md#rdbms) + a message broker + a third-party [RPC](_meta/glossary.md#rpc) call that can't enlist in XA), or a blocking coordinator is a [SPOF](_meta/glossary.md#spof). 2PC blocks all participants until the coordinator decides; a stalled coordinator holds locks indefinitely.
- Over a single local ACID transaction: only when the data genuinely spans service boundaries. If it all lives in one database, use one transaction — a saga is strictly more complex and weaker.
- Over "just retry the whole thing": when steps have side effects that can't be safely re-executed (charging a card twice) and instead must be compensated.

**Do not use when:**
- All the data fits in **one database** → use a plain ACID transaction; sagas add coordination and give up isolation for nothing.
- The operation is **short and low-contention** and all participants can enlist in XA and you truly need strict serializability → 2PC may be simpler to reason about.
- A step's effect is **physically irreversible** and has no acceptable business compensation (you literally cannot un-send a physical shipment) → redesign so the risky step is last (pessimistic ordering), or gate it behind a confirmation.

## Key Properties

- **ACD, not ACID.** A saga preserves Atomicity (via compensation), Consistency, and Durability, but sacrifices **Isolation**. Uncommitted-from-the-saga's-view intermediate results are visible to other transactions.
- **Compensation is semantic, not physical.** There is no `ROLLBACK`. A compensating transaction is a *new* forward transaction that logically reverses a committed one (issue a refund, not "un-charge"). It must be **idempotent** and (ideally) **commutative/retryable**, because it too can fail and be retried.
- **Not all steps are compensatable.** Richardson's taxonomy of step types:
  - *Compensatable* — can be undone by a compensating txn (reserve inventory).
  - *Pivot* — the point of no return; once it commits the saga must run to completion (charge the card, in many designs).
  - *Retriable* — steps after the pivot that are guaranteed to eventually succeed (send confirmation email); they are retried forward, never compensated.
  Order steps so all compensatable steps precede the pivot and all retriable steps follow it.
- **Coordination is either choreography or orchestration** (see table).

| Dimension | Choreography | Orchestration |
|---|---|---|
| Control flow | Decentralized — each service reacts to events and emits the next | Central orchestrator/state machine tells each service what to do |
| Coupling | Services couple to event contracts; no central component | Services couple to the orchestrator |
| Failure/compensation logic | Spread across services; hard to see the whole saga | Centralized in the orchestrator; explicit and inspectable |
| Best for | 2–4 steps, simple linear flows | Complex flows, branching, many steps, evolving logic |
| Risk | Cyclic event dependencies, no single place to reason about state | Orchestrator can become a god-service / SPOF if overloaded |

## Common Pitfalls

- **Assuming isolation.** Because a saga's intermediate writes are committed and visible, concurrent sagas see them. This produces classic anomalies: **lost updates** (one saga overwrites another's write), **dirty reads** (a saga reads data a not-yet-completed saga will later compensate away), and **non-repeatable/fuzzy reads** (two reads in the same saga differ because another saga wrote in between). You must add countermeasures explicitly.
- **Non-idempotent handlers.** At-least-once messaging means every step and every compensation can be delivered more than once. A non-idempotent "charge card" run twice double-charges. Deduplicate on a message/idempotency key.
- **Compensation that can fail permanently.** If a compensating transaction can hard-fail, the saga gets stuck in a half-completed state. Compensations must be retriable to completion (or escalate to a human/dead-letter queue).
- **Compensating a pivot.** Trying to undo an irreversible step. Classify steps and place the pivot correctly; never assume everything is compensatable.
- **Losing the saga's state on crash.** The saga log (orchestrator state or the event trail) must be durable so a crashed saga resumes correctly. Persist state transitions in the same local transaction that emits the message (transactional outbox), or you can commit a DB write and then fail before publishing — a dual-write bug.
- **Choreography sprawl.** Beyond a few steps, event-driven choreography becomes an implicit, untraceable state machine. Reach for orchestration before you can't answer "what state is order 123 in?"

## Trade-offs

**Saga vs. 2PC (two-phase commit / XA):**
- 2PC gives real atomic isolation across participants but is **blocking**: participants hold locks and stay in-doubt until the coordinator decides; a coordinator crash between phases can freeze resources. It also requires all participants to support XA — most message brokers, NoSQL stores, and third-party HTTP APIs do not.
- A saga is **non-blocking and available**, works across heterogeneous/opaque participants, but pushes isolation into application design and offers no automatic rollback.

**Isolation countermeasures (from Richardson, *Microservices Patterns* Ch. 4):** each trades complexity for a stronger isolation guarantee.

| Countermeasure | What it does | Anomaly addressed |
|---|---|---|
| Semantic lock | Set an application-level flag (e.g. `status = PENDING`) on records a saga is mutating; other sagas must handle/avoid pending rows | Dirty reads, lost updates |
| Commutative updates | Design operations so order doesn't matter (e.g. `credit`/`debit` deltas instead of absolute set) | Lost updates |
| Pessimistic view | Reorder steps so the riskiest/least-reversible work happens last, minimizing the window a dirty read can cause harm | Dirty reads (business impact) |
| Reread value | Re-read and verify a record is unchanged before writing (optimistic offline lock / compare-and-set) | Lost updates |
| By value / version file | Route by risk (use a saga only for low-risk requests, 2PC for high-risk), or record incoming ops and reorder to make them commutative | Multiple |

**Latency & coupling:** a saga adds message hops and per-step commit latency; choreography lowers central coupling but scatters logic; orchestration centralizes logic but adds an orchestrator to run and scale.

## Implementation Notes

**Orchestration sketch (state machine + compensation stack):**

```text
saga OrderSaga:
  steps = [
    (createOrder,      cancelOrder),        # compensatable
    (reserveInventory, releaseInventory),   # compensatable
    (chargePayment,    None),               # PIVOT — no compensation
    (scheduleShipping, None),               # retriable (after pivot)
  ]

run(ctx):
  done = []                                 # stack of executed compensatable steps
  for (action, compensate) in steps:
    try:
      action(ctx)                           # local ACID txn in that service
      if compensate: done.push(compensate)
      persist(ctx.state)                    # durable saga log after each step
    except:
      for c in reverse(done): retry(c, ctx) # compensate backwards, idempotently
      mark ABORTED; return
  mark COMPLETED
```

**Reliable messaging — transactional outbox (avoids dual-write):**
- In the *same* local DB transaction as the business write, insert a row into an `outbox` table.
- A relay (CDC on the [WAL](_meta/glossary.md#wal) via Debezium, or a poller) publishes outbox rows to the broker and marks them sent.
- Guarantees the event is published **iff** the local transaction committed. Consumers dedupe on message id for at-least-once → effectively-once.

**Idempotency:** every command and compensation carries a saga id + step id; handlers record processed ids and no-op on replay.

**Tooling:** orchestrators like Temporal, AWS Step Functions, Netflix Conductor, or Camunda persist workflow state and drive retries/compensation for you rather than hand-rolling the log.

## Variants

- **Choreography-based saga** — event-driven, no central coordinator; best for short linear flows.
- **Orchestration-based saga** — central orchestrator/state machine; best for complex, branching, or long flows.
- **Routing slip** — the message carries the ordered list of steps (and compensations) with it; each service executes its step and forwards the slip. A lightweight middle ground.
- **TCC (Try-Confirm/Cancel)** — a related pattern where each service first *reserves* (Try), then all are *Confirmed* or *Cancelled*. Two-phase like 2PC but non-blocking and application-level, giving better isolation than a plain saga at the cost of every service exposing try/confirm/cancel.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 9 (distributed transactions, 2PC, and why sagas avoid its blocking) — https://dataintensive.net
- Garcia-Molina & Salem, "Sagas" (ACM SIGMOD 1987, pp. 249–259), the original paper — https://dl.acm.org/doi/10.1145/38713.38742
- Chris Richardson, microservices.io — Saga pattern (isolation countermeasures, step classification) — https://microservices.io/patterns/data/saga.html
- Microsoft Azure Architecture Center — Saga design pattern — https://learn.microsoft.com/en-us/azure/architecture/patterns/saga

## Related

- [[two-phase-commit]]
- [[distributed-transactions]]
- [[microservices]]
- [[event-driven-architecture]]
- [[transactional-outbox]]
- [[idempotency]]
- [[cap-theorem]]
