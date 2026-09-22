# Study Curriculum — Senior Backend FAANG

**Target:** senior-level backend software engineer, FAANG / big-tech, 2026.
**Priority order:** data-intensive/distributed systems → databases → backend/API
& reliability → system-design components → DS&A → networking → concurrency/OS →
security → behavioral → (architectural/design patterns, minimal).

**Grounded in:** *Designing Data-Intensive Applications* (Kleppmann) [primary],
*System Design Interview* Vol 1 & 2 (Xu), *Design Patterns* (GoF), the
NeetCode-150 / Blind-75 taxonomy, plus a research-backed + adversarially-verified
pass (see the deep-research run, 2026-09-08).

**Legend:** `✓` already a card · `➕` to create · `✂` prune/archive ·
`↻` reclassify. Backend relevance: **CORE** / **IMPORTANT** / *peripheral*.

> This is the concept-card curriculum (the "what is X / when to use X"
> recognition layer). Coding problems live in the separate **Algorithms track**
> (NeetCode-150). System-design *case studies* (Xu Vol 2) are practice problems,
> not concept cards — see "Structural recommendations" below.

---

## Strategic decisions (from the research)

1. **Prune the blockchain cluster.** A blockchain/crypto-specific cluster (UTXO,
   smart contracts/EVM/gas, PoW/PoS consensus, wallets/BIP32, mempool/MEV,
   on-chain tx lifecycle) is **extraneous for a general backend FAANG target** —
   it's material for specialized Blockchain-Engineer roles. `✂` the 3
   blockchain-specific cards; **keep** the 3 crypto-*fundamentals* cards and
   `↻` reclassify them under Security (they're backend-security-relevant).
2. **GoF Design Patterns are low-yield for the interview loop.** The
   distinguishing senior skill is recognizing *distributed-systems* patterns,
   not GoF. Keep at most **one** "essential GoF patterns" reference card + a
   couple architectural-pattern cards; do not build out the 23 GoF patterns.
3. **Retarget** `onyx-target.json` `general` → `backend` — **DONE** (2026-09-08).
   At senior×backend this weights system-design ×1.84 and de-weights pure algo,
   matching the goal. (Applying broadly — mid-level, other cos, startups,
   backend-flavored blockchain — but backend-FAANG is the aim; the CORE tier is
   what transfers across all of them, so build CORE-first.)
4. **Back-of-envelope estimation** and **interview scoping/framework** are
   meta-skills, tagged CORE.
5. **Commonly-omitted-but-CORE** for senior backend: idempotency/exactly-once,
   change-data-capture, data-encoding & schema-evolution, observability/SLO.

---

## 0. Interview meta — CORE
- `✓` reading-constraints — constraint → required complexity
- `✓` interview-vocabulary — TLE/MLE/AC/amortized/in-place…
- `✓` back-of-envelope — estimation (latency/throughput/storage numbers) `↻` meta
- `➕` **system-design interview framework** — scope → estimate → high-level →
  deep-dive → bottlenecks (CORE)

## 1. Data structures & algorithms (concept layer) — supports the algo track
Structures: `✓`array · `✓`string-patterns · `✓`linked-list · `✓`stack ·
`✓`queue-deque · `✓`hash-map · `✓`hash-set · `✓`binary-tree · `✓`bst · `✓`heap ·
`✓`graphs · `➕`**trie** (IMPORTANT) · `➕`**union-find / disjoint-set** (CORE)
Patterns/algorithms: `✓`two-pointers · `✓`sliding-window · `✓`binary-search ·
`✓`bfs · `✓`dfs · `✓`recursion · `✓`dynamic-programming-1d · `✓`dynamic-programming-2d ·
`➕`**backtracking** (CORE) · `➕`**greedy** (CORE) · `➕`**intervals** (CORE) ·
`➕`**topological-sort** (CORE) · `➕`**monotonic-stack** (CORE) ·
`➕`**heap / top-K** (CORE) · `➕`**dijkstra & shortest-paths** (IMPORTANT) ·
`➕`**MST / advanced graphs** (IMPORTANT) · `➕`**prefix-sum** (IMPORTANT) ·
`➕`**fast & slow pointers** (IMPORTANT) · `➕`**big-O / complexity analysis** (CORE)
*peripheral:* `➕`bit-manipulation · (skip math/geometry)

## 2. Databases — CORE (DDIA Ch. 3, 7)
- `✓` sql-vs-nosql
- `✓` acid-properties
- `✓` database-indexing (B-tree indexes, sargability)
- `➕` **storage engines: B-tree vs LSM-tree** — write/read tradeoff, SSTables, hash indexes (CORE)
- `➕` **transaction isolation levels** — read-committed → snapshot → serializable (CORE)
- `➕` **MVCC** — how snapshot isolation is implemented (CORE)
- `➕` **OLTP vs OLAP** — row vs columnar, workloads (IMPORTANT)
- `➕` **query optimization / planner** — how the DB chooses a plan (IMPORTANT)
- `➕` **normalization vs denormalization** (IMPORTANT)
- `➕` **connection pooling** — practical backend concern (IMPORTANT)

## 3. Distributed systems / data-intensive — CORE (DDIA Ch. 5–9) [TOP PRIORITY]
- `✓` cap-theorem — `➕` extend with **PACELC**
- `➕` **replication models** — single-leader / multi-leader / leaderless (CORE)
- `➕` **replication lag & read-your-writes / monotonic reads** (IMPORTANT)
- `➕` **partitioning / sharding** — range vs hash, rebalancing, request routing (CORE)
- `➕` **consistent hashing** — ring, virtual nodes (CORE; shared w/ §4)
- `➕` **consistency models** — linearizability / causal / eventual (CORE)
- `➕` **consensus** — Paxos & Raft, leader election, quorums (CORE)
- `➕` **distributed transactions: 2-phase commit** (CORE)
- `➕` **saga pattern** — long-lived txns, compensation (CORE)
- `➕` **idempotency & exactly-once semantics** (CORE, commonly omitted)
- `➕` **data encoding & schema evolution** — Avro/Protobuf/Thrift, back/forward compat (CORE, commonly omitted)
- `➕` **change data capture (CDC)** (IMPORTANT, commonly omitted)
- `➕` **batch vs stream processing** — MapReduce vs Kafka Streams/Flink (IMPORTANT)
- `➕` **event sourcing** (IMPORTANT; shared w/ §9)
- `➕` *CRDTs* (peripheral)

## 4. System-design components — CORE (Xu Vol 1 & 2)
- `✓` caching — strategies, eviction, invalidation, thundering herd
- `✓` cdn
- `✓` load-balancing — L4/L7, algorithms
- `✓` rate-limiting
- `➕` **message queues / Kafka** — pub-sub, partitions, delivery semantics, DLQ (CORE)
- `➕` **unique ID generation** — Snowflake, ULID (IMPORTANT)
- `➕` **object / blob storage** — S3-like design (IMPORTANT)
- `➕` **search / inverted index** — Elasticsearch conceptually (IMPORTANT)
- `➕` **API gateway** (IMPORTANT)
- `➕` **service discovery** (IMPORTANT)
- `➕` **microservices vs monolith** — boundaries, tradeoffs (IMPORTANT)

## 5. Networking & protocols — IMPORTANT
- `✓` http-https (HTTP/1.1/2/3)
- `✓` dns
- `➕` **TCP vs UDP** — reliability, ordering, when each (IMPORTANT)
- `➕` **TLS handshake / how HTTPS works** (IMPORTANT; overlaps §7)
- `➕` **gRPC / Protocol Buffers** — when over REST (IMPORTANT)
- `➕` **GraphQL** — over/under-fetch, when it fits (IMPORTANT)
- `➕` **WebSockets / SSE / long-polling** — realtime patterns (IMPORTANT)

## 6. Concurrency & OS foundations — IMPORTANT
- `➕` **threads vs processes** (IMPORTANT)
- `➕` **locks: mutex / semaphore / RWlock** (IMPORTANT)
- `➕` **deadlock** — 4 conditions, prevention (IMPORTANT)
- `➕` **race conditions & atomicity** (IMPORTANT)
- `➕` **optimistic vs pessimistic concurrency (OCC / locking)** (IMPORTANT; DB contention)
- `➕` **async / event loop / non-blocking I/O** (IMPORTANT)
- `➕` *memory model / happens-before* (peripheral)
- `➕` *virtual memory / paging* (peripheral)
- `➕` *process scheduling* (peripheral)

## 7. Security fundamentals — IMPORTANT (backend)
- `✓` cryptographic-hash-functions `↻` (CORE)
- `✓` public-key-cryptography `↻` (IMPORTANT)
- `✓` digital-signatures `↻` (IMPORTANT)
- `➕` **symmetric vs asymmetric encryption** (IMPORTANT)
- `➕` **TLS / PKI / certificates** (IMPORTANT; overlaps §5)
- `➕` **authN vs authZ** (CORE)
- `➕` **OAuth 2.0 / OpenID Connect** (CORE)
- `➕` **JWT / sessions / tokens** (CORE)
- `➕` **password storage** — bcrypt/argon2, salting (IMPORTANT)
- `➕` **OWASP top risks** — injection / XSS / CSRF (IMPORTANT)
- `➕` *secrets management* (peripheral)

## 8. Backend / API & reliability engineering — CORE
- `✓` rest-api-design — `➕` extend (idempotency keys, status codes)
- `➕` **idempotency & idempotency keys** (CORE; shared w/ §3)
- `➕` **API pagination** — offset vs cursor (IMPORTANT)
- `➕` **API versioning** (IMPORTANT)
- `➕` **webhooks** — delivery, retries, signing (IMPORTANT)
- `➕` **retries / timeouts / exponential backoff + jitter** (CORE)
- `➕` **circuit breaker** (CORE)
- `➕` **backpressure / bulkhead** (IMPORTANT)
- `➕` **observability — logs / metrics / traces** (CORE, commonly omitted)
- `➕` **SLI / SLO / SLA / error budgets** (IMPORTANT)
- `➕` *health checks / graceful degradation* (peripheral)

## 9. Architectural & design patterns — mostly *peripheral*
- `➕` **MVC / layered / hexagonal (ports & adapters)** — 1 card (peripheral)
- `➕` **CQRS** (peripheral)
- `➕` **event sourcing** (see §3)
- `➕` *essential GoF patterns* — one reference card naming Strategy/Factory/
  Observer/Builder/Adapter/Decorator; not a study priority (peripheral)

## 10. Behavioral / leadership (senior) — IMPORTANT
- `➕` **STAR framework** (IMPORTANT)
- `➕` senior signals — ownership · ambiguity · conflict/disagreement · impact ·
  failure/learning · mentorship (~5 cards) (IMPORTANT)

---

## Prune / archive (extraneous for backend FAANG)
- `✂` blockchain-data-structure
- `✂` transaction-lifecycle (Solana-specific)
- `✂` merkle-tree — *blockchain-framed; Merkle trees do appear in DBs/Git/replication,
  so optionally reframe generically instead of deleting.*
- Do **not** generate the planned Tier-2 Blockchain backlog (consensus/UTXO/smart
  contracts/P2P/wallets/mempool).
- Language/framework cards (Rust/Axum/Dart/Flutter) — your stack, not FAANG
  interview material; keep **SQL** and **PostgreSQL** (backend-relevant), defer
  the rest.

## Agreed app structure & sequencing (2026-09-08)

The app is **one concept-recall base + practice modes per interview round type**:

| Layer | What | Scheduling | Status |
|---|---|---|---|
| **Concept deck** | all knowledge cards, every domain (DS&A, DB, distributed, networking, security, backend…) + **SQL/Postgres** as a domain | FSRS recall (Learn/Review) | exists — this curriculum fills it |
| **Coding practice** | NeetCode-150 problems | two clocks (solve/explain) | exists (Algorithms track) |
| **System-design practice** | Xu Vol 2 case studies — design/explain | two-clock-like | **flow 3, future** |
| **Behavioral prep** | STAR story bank + coach mock; rehearse, don't memorize | its own light model, NOT FSRS recall | **flow 4, future** |

- **Language** folds into the concept deck as a domain (SQL/Postgres are recall
  material); framework specifics (Rust/Axum/Dart/Flutter) are the build stack,
  not interview prep — skip.
- **Behavioral** is different in kind (rehearsal + mock) → its own flow, later.
- Build order: **concept deck first** (foundation feeds every mode) → system-
  design practice → behavioral.

### DRY the practice flows (ties into #30 generalization)
When building flows 3 & 4, do NOT copy-paste the Algorithms track three times.
They share structure: a paced queue over items, one-or-more spaced "clocks", a
produce→grade interaction, and applied-attempts feeding per-domain readiness.
Extract a generalized **practice-track** core as the *second* instance
(system-design) is built — refactor the algo track onto it too — so by flow 4
the abstraction is proven (rule of three; avoid premature/​speculative
abstraction). That same `track = {content source, clocks, interaction, readiness
contribution}` shape is the substrate for making Onyx a configurable
multi-subject platform (task #30) — a new flow/subject becomes config, not code.
Note: `domainWeight()` currently hardcodes only `ds-a`/`system-design`; new
backend domains (databases, distributed, networking, security) either ride the
`system-design` umbrella tag for now or get added there — decide at card-gen time.

## Structural recommendations
- **System-design practice track** (parallel to the Algorithms track): the Xu
  Vol 2 case studies (URL shortener, web crawler, notification system, news feed,
  chat, autocomplete, metrics monitoring, ad-click aggregation, distributed
  message queue, object storage) are *practice problems*, not concept cards —
  worth their own spaced re-solve/explain track later.
- Fintech-specific Xu Vol 2 chapters (payment, digital wallet, stock exchange)
  are peripheral for a general backend target.

## Rough counts
- Existing concept cards: **39** → keep ~36 (prune 3 blockchain), reclassify 3 crypto.
- New cards proposed: **CORE ~34**, **IMPORTANT ~34**, *peripheral ~12*.
- **Recommended first scope: CORE + IMPORTANT ≈ ~105 concept cards total**
  (existing + new); defer *peripheral* (~12) and behavioral until later.
