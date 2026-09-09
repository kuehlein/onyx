---
id: two-phase-commit
type: flashcard
tags:
  - distributed-systems
  - transactions
tiers:
  distributed-systems: 3
created: 2026-09-08
confidence: high
priority: normal
---

# Two-Phase Commit (2PC)

Two-phase commit is an atomic commit protocol that makes a transaction spanning multiple nodes either commit everywhere or abort everywhere — never partially. A single *coordinator* runs the transaction in two rounds: a **prepare** phase where every participant durably promises it *can* commit, and a **commit** phase where the coordinator broadcasts the irrevocable decision. The guarantee it buys is atomicity across independent systems; the price is that once a participant votes "yes" it surrenders its autonomy and must block until the coordinator tells it the outcome — which is why 2PC does not survive coordinator failure gracefully and is avoided at scale.

> [!tip] Recognition
> Reach for 2PC (or recognize it in a design) when a single logical transaction must atomically touch **multiple independent systems** — two shards, a database plus a message broker, or heterogeneous [RDBMS](_meta/glossary.md#rdbms) instances via XA — and a partial outcome is unacceptable. Signals: "write to the DB *and* enqueue the event atomically", "transfer across two database partitions", "distributed transaction", "XA / `PREPARE TRANSACTION`". If you only need *replicas* of the same state to agree, that is consensus, not 2PC.

## When to Use

**Problem signals that suggest 2PC:**
- A single business operation must atomically mutate **two or more separate transactional resources** (e.g. debit in DB-A, credit in DB-B; or persist a row *and* publish to a broker) and you cannot tolerate one succeeding while the other fails
- The systems involved expose a prepare/commit interface (XA, JTA, `PREPARE TRANSACTION` in Postgres) and are all reachable on a low-latency network
- You genuinely need cross-resource **atomicity**, not merely agreement between copies of the same data

**Prefer 2PC over alternatives when:**
- Over a **[saga](_meta/glossary.md#saga) / outbox pattern**: when you truly need atomic all-or-nothing semantics *now* and cannot accept the temporary inconsistency + compensating-transaction complexity a saga introduces. (In practice most large systems accept the saga trade-off precisely to avoid 2PC's blocking.)
- Over **consensus (Raft/Paxos)**: when the nodes are doing *different* work that must all succeed together — consensus makes a *majority* of replicas do the *same* thing and is the wrong tool for heterogeneous cross-resource atomicity.

**Do not use when:**
- You need high availability under partitions — 2PC blocks on coordinator or participant loss → use a **saga with compensation**, an **outbox + idempotent consumer**, or eventual consistency instead
- The operation can be made [idempotent](_meta/glossary.md#idempotency) and retried — a single-writer + [at-least-once delivery](_meta/glossary.md#at-least-once-delivery) + [idempotency key](_meta/glossary.md#idempotency-key) is far cheaper and non-blocking
- You just need multiple copies of the same data to agree → that is replication/consensus ([[raft]], Paxos), not atomic commit
- Throughput is critical — the extra durable log forces + round trips and the locks held across the network kill concurrency

## Key Properties

- **Two phases, one coordinator.**
  - *Phase 1 (prepare / voting):* coordinator sends `prepare`; each participant does the work, acquires locks, force-writes enough to a durable log ([WAL](_meta/glossary.md#wal)) that it is *guaranteed* able to commit, then votes **yes** (prepared) or **no** (abort). A **yes** vote is an irrevocable promise — the participant may no longer unilaterally abort.
  - *Phase 2 (commit / completion):* if **all** votes are yes, the coordinator force-writes a **commit** record to its own log — this write is the single point of no return — then tells everyone to commit. Any **no** or timeout → global abort.
- **The commit point is the coordinator's log write.** Once the coordinator has durably logged "commit", the transaction *will* commit even across crashes; recovery replays the log and re-sends the decision.
- **In-doubt participants.** A participant that has voted yes but not yet heard the decision is *in doubt*: it holds its locks and cannot decide on its own. It must wait for the coordinator — potentially forever.
- **Unanimity for commit, unilateral for abort.** Commit requires every participant's yes; a single no (or unreachable participant during prepare) aborts the whole transaction. This is the opposite of consensus, which only needs a majority.
- **Not fault-tolerant by design.** 2PC assumes the coordinator can be recovered; it does not tolerate coordinator loss the way a majority-[quorum](_meta/glossary.md#quorum) protocol tolerates minority node loss.

**2PC vs. consensus (Raft/Paxos):**

| | Two-Phase Commit | Consensus (Raft / Paxos) |
|---|---|---|
| Goal | Atomic commit across *heterogeneous* resources doing *different* work | Get replicas to agree on the *same* value/log |
| Votes needed to proceed | **All** participants must vote yes | A **majority** (quorum) is enough |
| Availability under node loss | Blocks if coordinator or any prepared participant is unreachable | Tolerates a minority of failures (⌊n/2⌋ with 2f+1 nodes) |
| Single point of failure | Yes — the coordinator | No — leadership fails over via election |
| Progress guarantee | Can block indefinitely | Makes progress while a majority is up |

## Common Pitfalls

- **Coordinator crash after prepare = indefinite block.** If the coordinator dies after participants have voted yes but before delivering the decision, every in-doubt participant is stuck holding locks. It cannot safely commit (maybe someone voted no) nor abort (maybe the coordinator already logged commit). This is *the* blocking problem — the defining weakness of 2PC. A timeout does **not** let it decide safely.
- **Held locks cascade.** In-doubt participants keep their locks, which blocks *other* transactions touching those rows, so a single stalled coordinator can stall a growing fan-out of unrelated work — a latent availability outage.
- **Assuming a plain participant timeout is a fix.** During prepare, a participant that times out waiting can abort (it hasn't promised anything yet). But *after* voting yes it may **not** unilaterally decide — timing out and guessing breaks atomicity.
- **Heuristic decisions silently break atomicity.** XA's escape hatch lets a stuck participant make a *heuristic* unilateral commit/abort to release locks. If it guesses opposite to the coordinator's decision, you get a permanent, silent inconsistency. Reserved for operational emergencies only.
- **Coordinator log is mandatory and on the hot path.** If the coordinator doesn't force its decision to durable storage *before* announcing it, a crash loses the outcome and recovery is impossible. This fsync is unavoidable latency.
- **Confusing 2PC with 2PL or with consensus.** Two-phase *commit* (atomic commit) ≠ two-phase *locking* (concurrency control) ≠ consensus (replica agreement). Interviewers probe this.
- **3PC is not a production fix.** Three-phase commit adds a pre-commit phase to make it non-blocking, but it assumes bounded network delay and no network partitions — false in real systems — so it can still produce inconsistency and is rarely used.

## Trade-offs

- **Atomicity vs. availability.** 2PC buys strict cross-resource atomicity at the cost of availability: it is a CP-flavored, synchronous protocol that stops making progress rather than risk a partial commit. Sagas invert this — always available, but only eventually consistent with compensating actions.
- **Latency & throughput cost.** Two network round trips *plus* a durable log force at each participant and at the coordinator. Locks are held for the entire cross-network duration, sharply limiting concurrency versus a single-node transaction.
- **Coupling.** Every participant's availability is multiplied in: the probability the whole transaction can commit falls as you add participants, and the slowest/least-available node gates all others.
- **Why it's avoided at scale.** The coordinator is a single point of failure ([SPOF](_meta/glossary.md#spof)) whose crash blocks participants with locks held; large systems either (a) avoid distributed transactions entirely (partition so each op is single-node, use sagas/outbox), or (b) make the *coordinator itself fault-tolerant* by replicating its decision via consensus.
- **The standard fix — combine with consensus.** Google Spanner replicates the coordinator's (and participants') state with Paxos, so no single coordinator node can block the transaction; the "coordinator" role survives failure via [leader election](_meta/glossary.md#leader-election). Percolator/TiDB take a similar tack, storing the commit decision durably in a replicated store. The lesson: 2PC's logic is fine — its *single-node coordinator* is the flaw, and consensus removes it.

## Implementation Notes

Protocol sketch (coordinator C, participants P1..Pn):

```
# Phase 1 — PREPARE (voting)
C:  generate global txid; log "BEGIN txid"
C -> Pi: PREPARE(txid)
Pi: do work, acquire locks
    force-write redo/undo to WAL   # durable: "I can commit txid"
    reply YES            # irrevocable promise — cannot self-abort now
    (or reply NO / crash before replying)

# Phase 2 — COMMIT / ABORT (decision)
if all replies == YES:
    C: force-write "COMMIT txid" to log   # <-- COMMIT POINT (point of no return)
    C -> Pi: COMMIT(txid)
else:
    C: force-write "ABORT txid"
    C -> Pi: ABORT(txid)
Pi: apply decision, release locks, ACK
C:  once all ACK -> log "END txid" (forget txid)
```

**Recovery rules (what makes it correct):**
- *Coordinator recovers:* read its log. Any txid with a `COMMIT`/`ABORT` record → re-send that decision (idempotent) until all participants ACK. A txid that reached only `BEGIN` (no decision logged) → abort.
- *Participant recovers while in doubt:* it does **not** guess. It asks the coordinator for the outcome and stays blocked (locks held) until told — this is exactly where a dead coordinator causes indefinite blocking.
- Messages must be **idempotent** and retried; the commit decision is safe to re-deliver any number of times.

**Real interfaces:** the X/Open **XA** standard (`xa_prepare`, `xa_commit`, `xa_rollback`), Java's **JTA**, and Postgres's `PREPARE TRANSACTION 'gid'` / `COMMIT PREPARED 'gid'`. These prepared transactions hold locks and pin resources until resolved — an unresolved one is an operational hazard you must monitor.

## Variants

- **Three-Phase Commit (3PC):** inserts a *pre-commit* phase so participants can time out and reach a decision without the coordinator, making it non-blocking *under the assumption of a synchronous network with bounded delay and no partitions*. Because that assumption fails in practice, 3PC can violate atomicity during a partition and is essentially unused in production.
- **Paxos Commit / Spanner-style:** replaces the single coordinator with a consensus group. Runs Paxos on each participant's prepared/commit decision using 2f+1 acceptors, making progress as long as f+1 are up — removing the single-coordinator block. This is how modern strongly-consistent distributed databases get atomic commit without 2PC's fatal flaw.
- **Percolator-style (TiDB):** 2PC over a replicated key-value store where the commit decision is written to a single "primary" key whose durability is backed by consensus replication, so the outcome is recoverable without a live coordinator process.

## Resources

- Kleppmann, *Designing Data-Intensive Applications*, Ch. 9 — "Distributed Transactions and Consensus" (2PC, in-doubt/blocking problem, XA, heuristic decisions): https://dataintensive.net
- Gray & Lamport, *Consensus on Transaction Commit* (Paxos Commit; how consensus removes the coordinator SPOF): https://www.microsoft.com/en-us/research/publication/consensus-on-transaction-commit/
- Corbett et al., *Spanner: Google's Globally-Distributed Database* (2PC over Paxos-replicated coordinators): https://research.google/pubs/pub39966/
- PostgreSQL docs — `PREPARE TRANSACTION` (real 2PC interface): https://www.postgresql.org/docs/current/sql-prepare-transaction.html

## Related

- [[distributed-transactions]]
- [[saga-pattern]]
- [[raft]]
- [[paxos]]
- [[consensus]]
- [[cap-theorem]]
- [[acid]]
- [[quorum]]
