---
id: idempotency
type: flashcard
tags:
  - distributed-systems
  - reliability
tiers:
  distributed-systems: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Idempotency

An operation is **idempotent** if performing it multiple times has the same effect on system state as performing it once. In distributed systems every network call can be lost, duplicated, or delayed, and a client that times out cannot tell whether its request succeeded — so it must retry. Retries turn "did this happen?" ambiguity into duplicate delivery, and idempotency is what makes those duplicates harmless. It is the practical foundation of "exactly-once" semantics: since a message being processed *exactly once* over an unreliable channel is impossible to guarantee end-to-end, real systems deliver [at-least-once](_meta/glossary.md#at-least-once-delivery) and make the *effect* [exactly-once](_meta/glossary.md#exactly-once-semantics) by deduplicating idempotent operations (DDIA calls this "effectively-once").

> [!tip] Recognition
> Reach for idempotency when you see **retries over an unreliable channel**, **at-least-once delivery**, **"charge the card exactly once"**, **consumer restarts replaying a message log**, **client timeout with unknown outcome**, or a **webhook/[gRPC](_meta/glossary.md#grpc) call that may fire twice**. Whenever an operation both mutates state and can be retried, the design question is "how do I make the second execution a no-op?"

## When to Use

**Problem signals that suggest designing for idempotency:**
- "The client got a timeout — did the payment go through or not?" — the classic unknown-outcome case; the only safe recovery is a retry, which requires idempotency
- "Our [TCP](_meta/glossary.md#tcp) connection dropped mid-RPC" — a network fault after the server committed but before the client got the response is indistinguishable from total failure
- "Messages from the queue are being processed twice" — every mainstream broker (Kafka, SQS, RabbitMQ) is at-least-once by default; consumers *must* tolerate redelivery
- "A stream consumer crashed and restarted from its last checkpoint" — reprocessing between the last commit and the crash replays events (DDIA Ch. 11)
- "We need to charge a card / send one email / decrement inventory once" — non-idempotent side effects to external systems are the hard case
- "Webhook receiver may get the same event multiple times" — Stripe, GitHub, etc. explicitly warn receivers to dedupe

**Prefer idempotency over alternatives when:**
- Over distributed transactions ([2PC](_meta/glossary.md#two-phase-commit)/XA): idempotency needs no coordinator, no blocking on a prepared state, and survives partitions — DDIA presents idempotence as the lighter-weight alternative to distributed transactions for achieving exactly-once *effects*
- Over "just don't retry": not retrying trades a duplicate-execution risk for a lost-write risk, which is usually worse; retries + idempotency give you both safety and liveness
- Over [at-most-once](_meta/glossary.md#at-most-once-delivery) delivery: at-most-once (fire and forget, no retry) is only acceptable when losing the operation is tolerable (e.g. best-effort metrics)

**Do not use / not needed when:**
- The operation is *naturally* idempotent — absolute `SET x = 5`, `PUT /users/42 {...}`, adding to a set — no dedup machinery required
- Reads / safe methods — GET, HEAD, OPTIONS have no side effects (RFC 9110: safe ⇒ idempotent)
- You have true at-most-once requirements where a duplicate is worse than a loss *and* loss is acceptable (rare)

## Key Properties

**Delivery semantics — the three guarantees:**

| Semantic | Guarantee | Retries? | Duplicates? | Losses? | Cost |
|---|---|---|---|---|---|
| **At-most-once** | delivered 0 or 1 times | no | never | possible | cheapest; fire-and-forget |
| **At-least-once** | delivered 1+ times | yes | possible | never | needs dedup for correctness |
| **Exactly-once** | effect applied exactly once | yes | de-duplicated | never | needs idempotency or a transaction |

- **"Exactly-once delivery" is largely a myth at the message level.** Over an asynchronous network with crashes, a sender cannot know if a message arrived, so it must resend; you cannot both guarantee no-loss and no-duplicate delivery of the *raw message*. What is achievable is **exactly-once *processing* / effectively-once**: deliver at-least-once, then make the *observable effect* exactly-once via idempotency or an atomic commit. This is DDIA Ch. 11's framing.
- **Idempotency is a property of the *effect*, not the message.** `balance += 10` is not idempotent; `balance = 110` (absolute) or "apply transfer #abc123 if not already applied" (dedup-keyed) is.
- **HTTP method semantics (RFC 9110):** GET/HEAD/OPTIONS/TRACE are safe and idempotent; **PUT and DELETE are idempotent but not safe**; **POST is neither** (which is why POST endpoints that must be retried need an idempotency key).
- **DDIA's three preconditions for relying on idempotence** to get exactly-once effects: (1) retries must **replay the same messages in the same order** (a log-based broker like Kafka provides this via offsets); (2) processing must be **deterministic**; (3) **no other node may concurrently mutate the same value** while you retry. Break any one and idempotence alone is insufficient.

## Common Pitfalls

- **Confusing at-least-once with exactly-once.** Assuming your broker "won't deliver twice" — it will. Correctness must not depend on no-redelivery.
- **Idempotency key that doesn't survive a crash.** If the dedup record and the side effect aren't committed **atomically** (same transaction, or the effect is itself the dedup marker), a crash between them either double-applies (effect committed, key not recorded) or silently drops (key recorded, effect not applied).
- **Check-then-act race.** `if not seen(key): process(); mark(key)` has a TOCTOU window; two concurrent retries both pass the check. Use an atomic conditional insert (`INSERT ... ON CONFLICT DO NOTHING`, a unique constraint, or `SETNX`) so exactly one wins.
- **Non-deterministic reprocessing.** Using `now()`, a random ID, or reading mutable external state during a replay produces a *different* result the second time, so the "idempotent" write isn't. Capture such values in the original message.
- **Idempotency keys with no [TTL](_meta/glossary.md#ttl) / unbounded dedup store.** The dedup table grows forever; you need an expiry window (Stripe prunes keys after ~24h) — but a retry arriving after expiry re-executes, so size the window to your max retry horizon.
- **Idempotent request but different body.** Reusing a key with changed parameters should be rejected (Stripe returns an error), not silently served the old result — otherwise you mask a client bug.
- **Assuming PUT/DELETE dedupe side effects.** They're idempotent on the *primary resource's* state, but triggers, counters, audit-log appends, or downstream events fired per request are not — idempotency doesn't automatically extend to secondary effects.
- **Non-idempotent output operations.** Sending an email, calling a third-party charge API, or pushing to a non-transactional sink can't be rolled back; you must dedupe *before* the external call, ideally with an idempotency key passed *through* to the downstream provider.

## Trade-offs

- **Idempotency (dedup) vs. distributed transactions (2PC):** idempotency is cheaper, partition-tolerant, and non-blocking, but requires a dedup store and the DDIA preconditions (ordered replay, determinism, no concurrent writer). 2PC gives atomic all-or-nothing across systems but blocks on coordinator failure and couples availability to every participant.
- **vs. [saga](_meta/glossary.md#saga):** different scope. Idempotency makes a *single* operation safe to re-execute; a saga sequences a *multi-step* cross-service workflow with compensating actions when a later step fails. They compose — saga steps (and their compensations) should themselves be idempotent so the saga can safely retry each one.
- **Dedup store cost vs. natural idempotency:** rewriting an operation to be *naturally* idempotent (absolute writes, upserts keyed on a business ID) needs no extra storage. A generic idempotency-key table works for any operation but adds a write + read on the hot path and a GC job.
- **Client-generated vs. server-generated keys:** client-generated keys (UUID v4) let a retry reuse the *same* key so the server can dedupe; server-generated keys can't, because a retry after timeout would ask for a new key. Idempotency keys therefore essentially must originate at (or before) the client for the timeout case to be covered.
- **Retry aggressiveness vs. duplicate load:** shorter retry timeouts recover faster but generate more in-flight duplicates hammering the dedup layer; pair retries with [exponential backoff](_meta/glossary.md#exponential-backoff) + [jitter](_meta/glossary.md#jitter), and consider request hedging only for idempotent reads.
- **Dedup window length:** longer windows catch late retries but cost storage; shorter windows are cheap but risk re-execution of a delayed duplicate.

## Implementation Notes

**1. Idempotency-key pattern (synchronous APIs, e.g. payments):**
```
POST /charges
Idempotency-Key: 9f8b...   # client-generated UUID v4, stable across retries

server:
  # atomic claim — only one concurrent request wins the key
  row = INSERT INTO idempotency (key, status, request_hash)
        VALUES (:key, 'in_progress', hash(body))
        ON CONFLICT (key) DO NOTHING RETURNING *
  if row is null:                      # key already exists
      existing = SELECT * FROM idempotency WHERE key = :key
      if existing.request_hash != hash(body): return 422  # key reuse w/ diff params
      if existing.status == 'done':    return existing.response   # replay saved result
      else:                            return 409 / poll          # still in progress
  # first time through:
  result = do_the_work()               # ideally same txn as the row update
  UPDATE idempotency SET status='done', response=result WHERE key=:key
  return result
```
Key rules: (a) the key claim and the effect commit in **one transaction** (or the effect *is* the dedup record); (b) persist the response so retries replay it verbatim, including error status codes; (c) validate the request body matches; (d) expire keys past your retry horizon.

**2. Consumer-side dedup (at-least-once message queues):**
- Attach a stable message/event ID at production time. On consume: `INSERT INTO processed(event_id) ON CONFLICT DO NOTHING`; if the insert affected 0 rows, skip. Do this **in the same transaction** as the state change, then commit the offset.
- Or make the write naturally idempotent: upsert keyed on the event's business key, or use a monotonic sequence/version and ignore out-of-order/replayed lower versions.

**3. Kafka "exactly-once" (transactional producer):**
- Kafka provides *idempotent producers* (dedup on `(producer-id, sequence-number)` to avoid duplicates from producer retries) and *transactions* (atomically write output records **and** commit consumer offsets). This yields exactly-once **within** Kafka's read-process-write loop — it does **not** magically extend to arbitrary external side effects, which still need their own idempotency.

**4. Naturally idempotent designs (preferred when possible):**
- Absolute sets over deltas: `SET status='shipped'` not `increment(shipped_count)`.
- Upsert on a business identity: `PUT /orders/{client_order_id}`.
- Fencing / versioning: reject a write carrying a version ≤ the stored version (also guards against the "no concurrent writer" precondition and stale/duplicate retries).

## Variants

- **Natural idempotency** — the operation is inherently repeatable (absolute writes, upserts, set insertion, PUT/DELETE).
- **Idempotency key (client token)** — an opaque unique token deduped server-side; the general-purpose retrofit for non-idempotent operations (Stripe, PayPal, Square).
- **Dedup by message/event ID** — consumer keeps a table/bloom filter of processed IDs (bounded by a window).
- **Transactional / exactly-once processing** — atomic output + offset commit (Kafka transactions, Flink checkpoints) makes reprocessing effectively-once without an explicit key.
- **Fencing tokens** — monotonic tokens that let a resource reject stale/duplicate/zombie writes, complementing idempotency under concurrency.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 11 (Stream Processing) — "Exactly-once execution" / idempotence and Ch. 8–9 on faults and unreliable networks — https://dataintensive.net
- RFC 9110, HTTP Semantics §9.2.2 (Idempotent Methods) and §9.2.1 (Safe Methods) — https://www.rfc-editor.org/rfc/rfc9110#name-idempotent-methods
- Stripe API — Idempotent requests — https://docs.stripe.com/api/idempotent_requests
- Kafka — Exactly-Once Semantics (KIP-98 transactions, idempotent producer) — https://www.confluent.io/blog/exactly-once-semantics-are-possible-heres-how-apache-kafka-does-it/

## Related

- [[message-queue]]
- [[distributed-transactions]]
- [[exactly-once-delivery]]
- [[at-least-once-delivery]]
- [[kafka]]
- [[two-phase-commit]]
- [[cap-theorem]]
- [[retries-and-backoff]]
