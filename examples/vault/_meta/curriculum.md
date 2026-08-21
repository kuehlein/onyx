# Interview Curriculum

Tailored for: senior backend engineer targeting crypto/Web3 roles, 2-month
preparation window.

Tiers are **per-domain**, not global. A card can be tier 1 in `system-design`
and tier 2 in `ds-a` simultaneously. Readiness is computed per domain per tier.

```
Tier 1 — Foundational: asked at every level; must be airtight
Tier 2 — Core: expected at senior level; high frequency in loops
Tier 3 — Advanced: differentiates senior from mid; shows depth
Tier 4 — Specialist: staff-level depth or crypto-specific expertise
```

## Authoritative Sources

These books and resources define what "thorough" means per domain. Card content
should reflect the depth and framing used in these sources. Do not copy text
verbatim (copyright); use them to guide what concepts deserve cards and how
to frame sections.

| Source | Domain | Primary use |
|---|---|---|
| **NeetCode 150** (neetcode.io) | DS&A | Question list + pattern grouping for interview-question cards |
| **Blind 75** | DS&A | High-frequency subset of NeetCode 150 |
| **Alex Xu — System Design Interview Vol 1** | System Design | Tier 1–2 design problems (URL shortener, Twitter, etc.) |
| **Alex Xu — System Design Interview Vol 2** | System Design | Tier 2–3 design problems (Google Drive, Stock Exchange, etc.) |
| **Designing Data-Intensive Applications** (Kleppmann) | System Design | Tier 2–4 conceptual depth — why systems are built the way they are |
| **Design Patterns** (GoF) | General SWE | Tier 3 patterns — Factory, Observer, Strategy, etc.; low interview frequency |
| **PostgreSQL documentation** | lang-frameworks | SQL and PostgreSQL-specific features |
| **The Rust Book** (doc.rust-lang.org) | lang-frameworks | Ownership, borrowing, traits |
| Ethereum documentation | Blockchain | Smart contracts, EVM, protocol specs |

---

## Domain: DS&A

**Interview format:** Coding rounds, 45–60 min per problem, one or two problems.
At senior level, O(n log n) solutions are expected; interviewers probe trade-offs
and edge cases more deeply than at junior level.

### Tier 0 — Interview Meta (prerequisites)

Must be internalized before any algorithm study. These are not algorithm cards —
they are the operating assumptions every interview problem requires.

- [ ] Reading Constraints → Required Complexity — infer O(?) from input size n
- [ ] Interview & Competitive Programming Vocabulary — TLE, MLE, AC, amortized,
      in-place, auxiliary space, invariant, reduction, trade-off, sentinel

### Tier 1 — Foundations

Must be completely automatic. Any hesitation here signals a gap.

- [ ] Arrays — indexing, slicing, in-place operations
- [ ] Strings — immutability, common manipulations
- [ ] Hash Map — operations, collision handling conceptually, when to reach for it
- [ ] Hash Set — dedup, membership, set operations
- [ ] Two Pointers — pattern recognition (opposite ends vs. same direction)
- [ ] Sliding Window — fixed vs. variable window; when it applies
- [ ] Binary Search — on sorted arrays, on answer space
- [ ] Stack — LIFO, monotonic stack pattern
- [ ] Queue / Deque — BFS queue, sliding window maximum

### Tier 2 — Core

High interview frequency. Expected solid at senior level.

- [ ] Linked List — reversal, cycle detection (Floyd's), merge
- [ ] Binary Tree — traversal (pre/in/post/level-order), height, diameter
- [ ] BST — search, insert, delete, in-order = sorted
- [ ] Heap / Priority Queue — top-K pattern, merge K sorted lists, median of stream
- [ ] BFS — level-order traversal, shortest path in unweighted graph
- [ ] DFS — backtracking framework, connected components, cycle detection
- [ ] Graphs — adjacency list/matrix, directed vs undirected
- [ ] Dynamic Programming (1D) — Fibonacci, climbing stairs, house robber patterns
- [ ] Dynamic Programming (2D) — grid paths, edit distance, LCS

### Tier 3 — Advanced

Differentiates senior candidates. Common in FAANG and top-tier companies.

- [ ] Tries — prefix search, autocomplete, word dictionary
- [ ] Union-Find — cycle detection in undirected graphs, connected components
- [ ] Topological Sort — task scheduling, course prerequisites (BFS + Kahn's, DFS)
- [ ] Dijkstra's Algorithm — weighted shortest path, when vs BFS
- [ ] Bellman-Ford — negative weights, detecting negative cycles
- [ ] Advanced DP — knapsack variants, DP on trees, interval DP
- [ ] Monotonic Stack — next greater element, largest rectangle in histogram
- [ ] Segment Tree — range queries with point updates (conceptual)
- [ ] Bit Manipulation — XOR tricks, bit masking, power of two checks

### Tier 4 — Specialist

Shows exceptional depth; relevant for staff-level or algorithmic-focused roles.

- [ ] Fenwick Tree (BIT) — prefix sums with updates
- [ ] KMP / Rabin-Karp — string pattern matching
- [ ] Network Flow — max flow / min cut (conceptual)
- [ ] Red-Black Tree / AVL Tree — balancing mechanics

---

## Domain: System Design

**Interview format:** 45–60 min open-ended design discussion. At senior level,
interviewers expect you to drive the conversation, identify trade-offs proactively,
and justify decisions with numbers (QPS, storage estimates, latency SLAs).

### Tier 1 — Foundations

Asked in virtually every system design round. Non-negotiable.

- [ ] Databases: SQL vs NoSQL — when to use each, trade-offs
- [ ] ACID properties — atomicity, consistency, isolation, durability
- [ ] CAP theorem — consistency vs availability vs partition tolerance
- [ ] Database indexing — B-tree indexes, when indexes help vs hurt, covering indexes
- [ ] Caching — cache-aside vs read-through vs write-through; eviction (LRU, LFU)
- [ ] CDN — what it does, when to use it, edge caching
- [ ] Load balancing — L4 vs L7, round robin vs least connections vs consistent hash
- [ ] DNS — resolution chain, TTL, why it matters for design
- [ ] HTTP/HTTPS — request/response, status codes, keep-alive, TLS handshake
- [ ] REST API design — resource naming, idempotency, versioning
- [ ] Rate limiting — token bucket vs leaky bucket vs fixed window vs sliding window
- [ ] Back-of-envelope estimation — QPS, storage, bandwidth estimation

### Tier 2 — Core

Expected at senior level. Appear in most design interviews.

- [ ] Database sharding — range vs hash sharding, hotspot problems
- [ ] Database replication — primary-replica, multi-primary, replication lag
- [ ] Consistent hashing — virtual nodes, ring structure, redistribution on change
- [ ] Message queues — pub/sub vs point-to-point, Kafka partitions, consumer groups
- [ ] Microservices — service discovery, API gateway, inter-service communication
- [ ] Distributed caching — Redis cluster, cache invalidation, thundering herd
- [ ] Authentication — JWT, OAuth 2.0, session tokens, when to use each
- [ ] gRPC / Protocol Buffers — when to use over REST
- [ ] Search — Elasticsearch conceptually, inverted index
- [ ] Object storage — S3-style, blob storage patterns

### Tier 3 — Advanced

Separates strong senior from mid-level. Especially relevant for backend roles.

- [ ] Consensus algorithms — Raft conceptually (leader election, log replication)
- [ ] Distributed transactions — 2-phase commit, Saga pattern
- [ ] Event sourcing and CQRS — when to use, trade-offs
- [ ] Eventual consistency patterns — vector clocks, conflict resolution
- [ ] Write-ahead log (WAL) — how databases guarantee durability
- [ ] Database internals — B-tree storage, LSM tree (RocksDB), MVCC
- [ ] Stream processing — Kafka Streams, Flink conceptually
- [ ] Observability — metrics, logging, tracing; what to instrument in a design

### Tier 4 — Specialist

Depth that stands out. Especially relevant for crypto/backend infrastructure.

- [ ] P2P networking — DHT (Kademlia), gossip protocols
- [ ] Custom protocol design — framing, serialization, versioning
- [ ] Advanced distributed systems — CRDT, hybrid logical clocks

---

## Domain: Blockchain

**Interview format:** Mix of technical screening (may include coding) and design
discussions specific to blockchain infrastructure. Crypto companies often ask
about protocols, on-chain/off-chain trade-offs, and security.

### Tier 1 — Foundations

Must know for any crypto role regardless of specialization.

- [ ] Cryptographic hash functions — SHA-256, Keccak, properties (collision resistance, preimage resistance)
- [ ] Digital signatures — ECDSA, sign/verify flow, public/private key relationship
- [ ] Merkle trees — structure, proof generation, why blockchains use them
- [ ] Blockchain data structure — linked blocks via parent hash, chain selection
- [ ] Public key cryptography — key pairs, address derivation, elliptic curve basics
- [ ] Transaction lifecycle — creation → broadcast → mempool → confirmation

### Tier 2 — Core

Expected for most backend roles at crypto companies.

- [ ] Consensus mechanisms — PoW (mining, difficulty), PoS (validators, slashing), BFT variants
- [ ] Account model vs UTXO model — Ethereum vs Bitcoin, trade-offs
- [ ] Smart contracts — EVM execution model, gas mechanics, storage layout
- [ ] P2P networking in blockchain — node discovery, gossip, block propagation
- [ ] Wallet architecture — HD wallets (BIP32/39/44), key derivation paths
- [ ] Mempool — transaction ordering, fee market, MEV introduction

### Tier 3 — Advanced

Differentiates candidates who understand protocols deeply.

- [ ] DeFi primitives — AMM (constant product formula), liquidity pools, impermanent loss
- [ ] Layer 2 scaling — optimistic rollups vs ZK rollups, data availability
- [ ] MEV — what it is, how searchers extract it, why it matters for protocol design
- [ ] Cross-chain bridges — lock-and-mint, liquidity networks, bridge security
- [ ] Token standards — ERC-20, ERC-721, ERC-1155 internals

### Tier 4 — Specialist

Deep protocol expertise; expected for core protocol or infrastructure roles.

- [ ] ZK proofs — conceptual (what they prove, what they don't), SNARKs vs STARKs
- [ ] Consensus security — long-range attacks, nothing-at-stake, finality guarantees
- [ ] Custom protocol design for blockchain environments

---

## Domain: Language & Frameworks

**Purpose:** Retain syntax and idioms for languages/frameworks you use
intermittently or with heavy AI/autocomplete assistance. Lower priority than
DS&A and System Design for interview prep but high value for day-to-day work.

### SQL / PostgreSQL

| Tier | Topics |
|---|---|
| 1 | SELECT, WHERE, JOIN types (INNER, LEFT, RIGHT, FULL), GROUP BY, ORDER BY, LIMIT |
| 1 | Aggregate functions (COUNT, SUM, AVG, MAX, MIN) |
| 2 | Window functions (RANK, ROW_NUMBER, LAG, LEAD, SUM OVER) |
| 2 | CTEs (WITH clauses), subqueries, correlated subqueries |
| 2 | Index types, EXPLAIN, query planning basics |
| 3 | JSONB operations (PostgreSQL), array types, full-text search |
| 3 | Transactions, isolation levels, locking |
| 4 | PostgreSQL internals — MVCC, WAL, vacuum |

### Rust

| Tier | Topics |
|---|---|
| 1 | Ownership, borrowing, lifetimes basics |
| 1 | Structs, enums, impl blocks, pattern matching |
| 1 | Result and Option types, `?` operator |
| 2 | Traits, generics, trait bounds |
| 2 | Closures, iterators, functional patterns |
| 2 | `async`/`await`, Tokio basics |
| 3 | Lifetimes advanced (variance, higher-ranked trait bounds) |
| 3 | Unsafe Rust — when and why |
| 4 | Rust internals — memory layout, fat pointers, vtables |

### Axum

| Tier | Topics |
|---|---|
| 1 | Router setup, handlers, extractors (Path, Query, Json, State) |
| 2 | Middleware, error handling, response types |
| 2 | Layered state management |
| 3 | Custom extractors, tower service composition |

### Dart / Flutter

| Tier | Topics |
|---|---|
| 1 | Dart types, null safety, async/await, Futures, Streams |
| 1 | StatelessWidget vs StatefulWidget, build lifecycle |
| 2 | Riverpod providers, state management patterns |
| 2 | Flutter layout (Column, Row, Flex, Stack, constraints) |
| 3 | CustomPainter, platform channels, performance profiling |

---

## Domain: Behavioral

Light coverage. Core STAR stories and common question types.

### Tier 1

- [ ] STAR framework — structure for any behavioral answer
- [ ] Technical decision with incomplete information — ambiguity, trade-offs
- [ ] Disagreement with a teammate or manager — how resolved
- [ ] Most impactful project — scope, your role, outcome
- [ ] Failure or mistake — what happened, what you changed
- [ ] Ownership example — going beyond your defined scope

---

## Suggested 8-Week Study Order

Assumes ~1–2 hours/day of active study (review + new cards).

| Week | DS&A | System Design | Blockchain |
|---|---|---|---|
| 1 | Tier 1 complete | Tier 1 (DB, caching, load balancing) | Tier 1 (hashing, signatures, Merkle) |
| 2 | Tier 2 start (trees, heaps) | Tier 1 (CDN, DNS, HTTP, rate limiting) | Tier 1 (blockchain structure, txn lifecycle) |
| 3 | Tier 2 (graphs, BFS/DFS) | Tier 2 (sharding, replication, consistent hashing) | Tier 2 (consensus, UTXO vs account) |
| 4 | Tier 2 (DP 1D + 2D) | Tier 2 (queues, microservices, distributed cache) | Tier 2 (smart contracts, mempool) |
| 5 | Tier 3 start (Trie, Union-Find, Topo sort) | Tier 2 (auth, search, object storage) | Tier 3 (DeFi, L2 scaling) |
| 6 | Tier 3 (Dijkstra, advanced DP, monotonic) | Tier 3 (consensus, distributed txns, event sourcing) | Tier 3 (MEV, bridges) |
| 7 | Tier 3 finish + weak area review | Tier 3 (WAL, DB internals, stream processing) | Tier 4 start if strong |
| 8 | Weak areas + Tier 4 if time | Tier 3 finish + system design practice problems | Behavioral cards + full review |

**FSRS handles the daily schedule automatically.** This table governs which
*new* cards to create each week. Once created, Onyx schedules reviews
optimally — just do your due cards every day.

---

## Readiness Targets (for dashboard)

| Domain | Minimum for interview | Target |
|---|---|---|
| DS&A Tier 1–2 | 80% stability | 90% stability |
| DS&A Tier 3 | 60% stability | 75% stability |
| System Design Tier 1–2 | 80% stability | 90% stability |
| Blockchain Tier 1–2 | 75% stability | 85% stability |
| Behavioral | 70% stability | 80% stability |
