---
id: connection-pooling
type: flashcard
tags:
  - databases
  - connection-pooling
  - backend
tiers:
  databases: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Connection Pooling

A connection pool is a cache of pre-established database connections held open and handed out to application threads on demand, then returned rather than closed. It exists because opening a connection is expensive — [TCP](_meta/glossary.md#tcp) handshake, TLS negotiation, auth, and (in Postgres) forking a per-connection backend process with its own memory — while each open connection consumes fixed server RAM and a slot against a hard `max_connections` limit. The pool amortizes setup cost and, critically, caps concurrency so a spike in clients cannot exhaust the database.

> [!tip] Recognition
> Reach for connection pooling when you see: "we open a new connection per request/query", connection setup latency dominating fast queries, `too many clients already` / `FATAL: sorry, too many connections` errors, thousands of app instances (or serverless functions) fanning out to one database, or a Postgres box thrashing on backend-process memory. The tell is a mismatch between *client concurrency* (huge, bursty) and *useful database concurrency* (bounded by CPU/disk).

## When to Use

**Problem signals that suggest connection pooling:**
- "Connection setup is slower than the query itself" — short [OLTP](_meta/glossary.md#oltp) queries where handshake + auth + [TLS](_meta/glossary.md#tls) dominates latency
- "We hit `FATAL: too many connections`" — client count exceeds server `max_connections`
- "Postgres RAM climbs with idle connections" — each backend process reserves work_mem/temp buffers; hundreds of idle connections waste gigabytes
- "Lambda/serverless functions exhaust the DB under load" — many short-lived environments each open their own connection
- "We have N app pods × M threads each, all talking to one primary" — fan-in concurrency needs bounding

**Prefer pooling over alternatives when:**
- Over raw connect-per-request: always, for any server handling concurrent traffic — the only question is app-side pool (HikariCP, `pgpool` in the driver) vs. an external pooler (PgBouncer, RDS Proxy, Supavisor)
- Over just raising `max_connections`: raising the limit adds memory + scheduler pressure without adding useful throughput past ~(2×cores); a small pool + a queue is strictly better
- Over a bigger DB instance: pooling is nearly free; vertical scaling is not

**Do not use / be careful when:**
- Long-lived session state is required (session-level `SET`, `LISTEN/NOTIFY`, `WITH HOLD` cursors, advisory locks, plain SQL `PREPARE`) → transaction-mode pooling will break it; use session mode or pin
- A single client legitimately needs sustained parallelism greater than the pool → size the pool for it, don't starve it
- The workload is one long analytical query → pooling buys nothing; you're CPU/IO-bound inside one connection

## Key Properties

**Why connections are expensive (Postgres specifics):**
- Each connection = one forked backend **process** (not a thread), with its own memory footprint (~1.3–3 MB baseline plus `work_mem` per sort/hash). Idle connections still hold this.
- `max_connections` is a hard cap set at server start; hitting it returns `FATAL: sorry, too many clients already`.
- MySQL/InnoDB uses per-connection **threads**, which are cheaper than Postgres processes — but the same `max_connections` ceiling and pooling benefits apply.

**Useful concurrency is bounded, not unlimited:**
- A database can only *usefully* run as many simultaneous queries as it has CPU cores + spindles. Past that, connections just fight for CPU and cause context-switch thrashing → throughput drops while latency climbs.
- This is why a small pool feeding a [FIFO](_meta/glossary.md#fifo) wait queue beats a huge pool: it holds excess concurrency *outside* the DB.

**Pooling modes (PgBouncer terminology, the interview canon):**

| Mode | Server conn held for | Session state safe? | Throughput / multiplexing |
|---|---|---|---|
| **Session** | entire client connection | Yes (full) | Low — 1:1 client↔server for the session |
| **Transaction** | one transaction (BEGIN→COMMIT) | No | High — server returned after each COMMIT, reused across clients |
| **Statement** | one statement | No; also **breaks multi-statement txns** | Highest; rarely usable |

- **Transaction mode is the default choice** for web apps: it lets N clients share far fewer server connections because most clients are idle between transactions.
- The catch: because the next statement may land on a *different* backend, anything tied to a session breaks (see Pitfalls).

## Common Pitfalls

- **Transaction-mode + session state = silent breakage.** `SET search_path`, `LISTEN/NOTIFY`, `WITH HOLD` cursors, session advisory locks, and SQL-level `PREPARE`/`DEALLOCATE` assume one stable backend. In transaction mode the next statement may hit another server, so state vanishes or leaks to another client. Fix: use session mode, or use **protocol-level** prepared statements with PgBouncer's `max_prepared_statements > 0` (supported in PgBouncer 1.21+).
- **Pool-per-instance multiplication.** A 20-connection pool is fine — until you run 50 app pods (1000 connections) or 200 concurrent Lambdas. The DB sees the *sum*. Size pools against total instance count, or front everything with one shared external pooler.
- **Serverless connection storm.** Each Lambda execution environment opens its own connection and a warm environment can't share with another. 100 concurrent invocations × 5 conns = 500 connections instantly, blowing past `max_connections`. Fix: an external pooler that lives outside the functions — **RDS Proxy**, PgBouncer, or Supavisor — not an in-process pool.
- **Oversized pool as a "fix."** Bumping the pool to 500 to stop queue waits usually makes latency *worse* — the DB thrashes on CPU/locks. The correct move is often a *smaller* pool.
- **Leaked / long-held connections.** Not returning a connection (exception before `close()`, a transaction left open) permanently shrinks the pool until it deadlocks. Always release in `finally` / use RAII / context managers; set `idle_in_transaction_session_timeout`.
- **Idle-in-transaction connections.** A connection checked out mid-transaction and then blocked (waiting on the app) holds locks and a pool slot. Set a server-side timeout to kill these.
- **Pinning defeats multiplexing.** PgBouncer "pins" a client to a server for the rest of a transaction when it sees session-scoped operations; heavy pinning collapses transaction mode back toward session-mode connection counts.

## Trade-offs

**Pool size vs. throughput (the core tension):**
- Too small → clients queue, tail latency spikes, timeouts.
- Too large → DB CPU/lock contention, context-switch thrashing, *lower* total throughput.
- Sweet spot is small: start near `(cpu_cores × 2) + effective_spindles` (≈`2×cores + 1` on SSD), then measure. This is the PostgreSQL-wiki / HikariCP guidance, not the app-thread count.

**App-side pool vs. external pooler:**
- App-side (HikariCP, driver pool): one hop fewer, keeps session semantics, simplest. But each instance has its own pool → doesn't solve fan-in across many instances.
- External (PgBouncer/RDS Proxy/Supavisor): one shared pool caps total DB connections regardless of instance count, and enables transaction-mode multiplexing. Cost: an extra network hop, an extra thing to run/monitor, and session-state constraints.
- Common production pattern: **both** — small app-side pools *and* an external transaction-mode pooler in front of the DB.

**Session vs. transaction mode:**
- Session: full compatibility, low multiplexing (server conns ≈ active clients).
- Transaction: high multiplexing (server conns ≪ clients), but loses session state and prepared-statement guarantees unless configured carefully.

## Implementation Notes

**Sizing formula (state this in an interview):**
```
pool_size ≈ (cpu_cores × 2) + effective_spindle_count
# SSD → spindle term ≈ 1, so ~2×cores + 1
# 8-core SSD box → ~17, round to ~20. Tens, not hundreds.
```
Then tune empirically: raise only if CPU is idle *and* clients wait on the pool; lower if CPU is pinned and latency rises.

**PgBouncer config sketch:**
```ini
[databases]
appdb = host=127.0.0.1 port=5432 dbname=appdb

[pgbouncer]
pool_mode = transaction          ; session | transaction | statement
default_pool_size = 20           ; server conns per (user,db) pair
max_client_conn = 5000           ; client-side conns PgBouncer will accept
reserve_pool_size = 5            ; extra slots for bursts
max_prepared_statements = 200    ; enables protocol-level prepared stmts in txn mode (1.21+)
```
- `max_client_conn` (huge) is decoupled from `default_pool_size` (small) — that decoupling *is* the multiplexing.
- Diagnose with `SHOW POOLS;` — sustained `cl_waiting > 0` means the pool is undersized (or the DB is the bottleneck).

**Serverless:** put the pooler *outside* the function. AWS: RDS Proxy sits between Lambda and RDS, reuses backend connections across invocations, and caps DB connections. Postgres-on-edge stacks use Supavisor or a data-proxy/HTTP driver instead of a TCP pool.

**Health & safety knobs:** validate connections on checkout (test query / `SELECT 1` or driver keepalive), set `connectionTimeout` (wait-for-slot) and `maxLifetime` (recycle before the DB/LB drops them), and `idle_in_transaction_session_timeout` on the server to reap stuck transactions.

## Variants

- **Session pooling** — 1:1 for a client session; safest, least multiplexing.
- **Transaction pooling** — the default for stateless web apps; highest safe multiplexing.
- **Statement pooling** — per-statement; disallows multi-statement transactions; niche.
- **RDS Proxy / Supavisor / Supabase pooler** — managed external poolers, purpose-built for serverless fan-in.
- **HikariCP / driver-native pools** — in-process pools; keep full session semantics, one per instance.

## Resources

- PgBouncer features & pooling modes: https://www.pgbouncer.org/features.html
- AWS — Using Amazon RDS Proxy with AWS Lambda: https://aws.amazon.com/blogs/compute/using-amazon-rds-proxy-with-aws-lambda/
- PostgreSQL wiki — Number of Database Connections (sizing): https://wiki.postgresql.org/wiki/Number_Of_Database_Connections
- Kleppmann, *Designing Data-Intensive Applications* — Ch. 7 (Transactions) for the session/transaction boundary these pooling modes hinge on

## Related

- [[transaction-lifecycle]]
- [[transaction-isolation-levels]]
- [[database-indexing]]
- [[sql-vs-nosql]]
- [[load-balancing]]
- [[rate-limiting]]
