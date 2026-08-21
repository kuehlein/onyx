# Tag Index

**Before adding a new tag, check this file.** If the tag doesn't exist, add
it here with a definition before using it on any card. This prevents drift.

## Conventions

- **Always kebab-case.** `binary-search`, not `Binary Search` or `binarySearch`
- **Be specific but not hyper-granular.** `bst` is right. `binary-search-tree-with-parent-pointer` is too narrow — use `bst` + a note in the card.
- **Tag at multiple levels.** A BST card gets both `bst` (specific) and `tree` (category). Both are useful for different quiz sessions.
- **Always include a domain tag** (`ds-a`, `system-design`, `blockchain`, `behavioral`) on every card. This is the primary axis for readiness tracking.
- **Check here before creating** any new tag. If it doesn't exist, add it.
- **Never use tags for tier.** Tier is frontmatter (`tiers: {ds-a: 2}`), not a tag.

---

## Domain Tags (required on every card)

| Tag | Definition |
|---|---|
| `ds-a` | Data structures & algorithms — coding interview content |
| `system-design` | Architecture, distributed systems, databases at scale |
| `blockchain` | Blockchain fundamentals, crypto protocols, DeFi, Web3 |
| `lang-frameworks` | Programming language syntax, idioms, and framework patterns |
| `behavioral` | Behavioral interview questions — STAR format responses |

---

## DS&A Tags

### Data Structures

| Tag | Definition | Notes |
|---|---|---|
| `array` | Fixed-size or dynamic contiguous storage | Use for both static arrays and dynamic arrays (ArrayList, Vec) |
| `string` | String manipulation and pattern problems | Often co-tagged with `array` or `two-pointers` |
| `hash-map` | Hash map / hash table data structure | Use for the structure; see also `hash-set` |
| `hash-set` | Hash set — unordered unique collection | |
| `linked-list` | Singly or doubly linked list | |
| `doubly-linked-list` | Doubly linked list specifically | Add alongside `linked-list` |
| `stack` | LIFO structure | |
| `queue` | FIFO structure | |
| `deque` | Double-ended queue | |
| `tree` | General tree structures | Use as the category tag for all tree variants |
| `binary-tree` | Tree where each node has at most two children | |
| `bst` | Binary search tree — ordered binary tree | Always co-tag with `binary-tree` and `tree` |
| `avl-tree` | Self-balancing BST maintaining height balance | Co-tag with `bst`, `binary-tree`, `tree` |
| `red-black-tree` | Self-balancing BST with color invariant | Co-tag with `bst`, `binary-tree`, `tree` |
| `heap` | Heap — general concept | |
| `min-heap` | Heap where root is minimum | Co-tag with `heap` |
| `max-heap` | Heap where root is maximum | Co-tag with `heap` |
| `trie` | Prefix tree for string keys | |
| `graph` | Graph data structure (nodes + edges) | Use for the structure; see traversal algorithm tags |
| `disjoint-set` | Union-Find / disjoint set union | Also tag with `union-find` |
| `segment-tree` | Range query tree structure | |
| `monotonic-stack` | Stack maintaining monotonic order | Co-tag with `stack` |

### Algorithms & Patterns

| Tag | Definition | Notes |
|---|---|---|
| `sorting` | Sorting algorithms (merge sort, quick sort, etc.) | |
| `binary-search` | Binary search algorithm or pattern | Distinct from `bst` |
| `two-pointers` | Two-pointer technique on arrays/strings | |
| `sliding-window` | Sliding window over arrays/strings | |
| `bfs` | Breadth-first search | Always co-tag with `graph` or `tree` |
| `dfs` | Depth-first search | Always co-tag with `graph` or `tree` |
| `dynamic-programming` | Dynamic programming | |
| `memoization` | Top-down DP with caching | Co-tag with `dynamic-programming` |
| `tabulation` | Bottom-up DP with table | Co-tag with `dynamic-programming` |
| `greedy` | Greedy algorithm paradigm | |
| `divide-and-conquer` | Divide and conquer paradigm | |
| `backtracking` | Exhaustive search with pruning | |
| `bit-manipulation` | Bit-level operations | |
| `union-find` | Union-Find algorithm | Co-tag with `disjoint-set` |
| `topological-sort` | Topological ordering of DAG | Co-tag with `graph`, `dfs` or `bfs` |
| `dijkstra` | Dijkstra's shortest path algorithm | Co-tag with `graph`, `shortest-path` |
| `shortest-path` | Shortest path problems in general | |
| `minimum-spanning-tree` | MST algorithms (Kruskal, Prim) | Co-tag with `graph` |

### Complexity

| Tag | Definition |
|---|---|
| `time-complexity` | Time complexity analysis |
| `space-complexity` | Space complexity analysis |
| `big-o` | Big-O notation concepts |
| `amortized` | Amortized complexity analysis |

---

## System Design Tags

| Tag | Definition | Notes |
|---|---|---|
| `database` | Database concepts — general | |
| `sql` | Relational databases and SQL | Co-tag with `database` |
| `nosql` | Non-relational databases | Co-tag with `database` |
| `database-indexing` | Index structures (B-tree, etc.) | Co-tag with `database` |
| `acid` | ACID properties of transactions | Co-tag with `database` |
| `cap-theorem` | CAP theorem and trade-offs | |
| `replication` | Database/service replication | |
| `sharding` | Horizontal partitioning strategies | Co-tag with `database` |
| `caching` | Caching systems, strategies, patterns | |
| `cdn` | Content delivery networks | |
| `load-balancing` | Load distribution strategies | |
| `consistent-hashing` | Consistent hashing technique | Co-tag with `load-balancing` or `sharding` |
| `api-design` | API design patterns and principles | |
| `rest` | RESTful API design | Co-tag with `api-design` |
| `grpc` | gRPC / protocol buffers | Co-tag with `api-design` |
| `rate-limiting` | Rate limiting patterns and algorithms | |
| `message-queue` | Message queue systems and patterns | |
| `kafka` | Apache Kafka specifically | Co-tag with `message-queue` |
| `microservices` | Microservice architecture patterns | |
| `distributed-systems` | Distributed systems fundamentals | |
| `consensus` | Consensus algorithms (Raft, Paxos) | Co-tag with `distributed-systems` |
| `networking` | Networking fundamentals | |
| `dns` | Domain Name System | Co-tag with `networking` |
| `http` | HTTP protocol | Co-tag with `networking` |
| `authentication` | Auth mechanisms (JWT, OAuth, sessions) | |
| `scalability` | Horizontal/vertical scaling concepts | |

---

## Blockchain Tags

| Tag | Definition | Notes |
|---|---|---|
| `blockchain` | Blockchain data structure and fundamentals | Also a domain tag |
| `cryptography` | Cryptographic primitives (hash, signatures, keys) | Distinct from `blockchain` — use for CS crypto concepts |
| `merkle-tree` | Merkle tree structure and proofs | Co-tag with `tree`, `cryptography` |
| `consensus-mechanism` | Blockchain consensus (PoW, PoS, BFT) | Distinct from `consensus` (distributed systems) |
| `smart-contract` | Smart contract architecture and patterns | |
| `evm` | Ethereum Virtual Machine | Co-tag with `smart-contract` |
| `defi` | Decentralized finance protocols | |
| `p2p` | Peer-to-peer networking | Co-tag with `networking` |
| `wallet` | Cryptocurrency wallet concepts (HD wallets, keys) | Co-tag with `cryptography` |
| `layer-2` | Layer 2 scaling solutions | |
| `zero-knowledge` | Zero-knowledge proof concepts | Co-tag with `cryptography` |

---

## Language & Framework Tags

Use the language or framework name as the specific tag. Always co-tag with
`lang-frameworks`. Add the specific implementation where relevant (e.g. `postgresql`
alongside `sql`).

| Tag | What it covers |
|---|---|
| `sql` | SQL language — queries, joins, aggregates, window functions |
| `postgresql` | PostgreSQL-specific features (JSONB, CTEs, extensions, etc.) |
| `sqlite` | SQLite-specific behavior and constraints |
| `rust` | Rust language — ownership, borrowing, lifetimes, traits |
| `axum` | Axum web framework for Rust |
| `dart` | Dart language features |
| `flutter` | Flutter framework — widgets, state, rendering |
| `python` | Python language features and idioms |
| `go` | Go language — goroutines, channels, interfaces |
| `javascript` | JavaScript language and async patterns |
| `typescript` | TypeScript type system and patterns |
| `solidity` | Solidity smart contract language |

**Tier meanings for `lang-frameworks`:**
- Tier 1: Core syntax and concepts used daily; easy to forget without practice
- Tier 2: Common patterns, idiomatic usage, performance considerations
- Tier 3: Advanced features, language internals, edge cases
- Tier 4: Expert-level (spec-level details, compiler internals, optimization)

---

## Behavioral Tags

| Tag | Definition |
|---|---|
| `behavioral` | Behavioral interview — also a domain tag |
| `star-format` | STAR method responses |
| `leadership` | Leadership and ownership stories |
| `conflict` | Conflict resolution scenarios |
| `technical-decision` | Technical decision-making stories |

---

## Interview Meta Tags

For tier-0 cards covering interview process knowledge rather than specific
algorithms or data structures.

| Tag | Definition |
|---|---|
| `interview-meta` | Meta-knowledge about the interview process: constraint reading, vocabulary, problem-solving frameworks |

---

## Interview Question Tags

These apply only to `type: interview-question` cards — not to concept cards.

| Tag | Definition |
|---|---|
| `neetcode-150` | Part of the NeetCode 150 question set |
| `blind-75` | Part of the Blind 75 question set (subset of NeetCode 150) |
| `alex-xu` | Based on a problem from Alex Xu System Design Interview Vol 1 or 2 |

---

## Tag Conflict Guide

Common ambiguities and how to resolve them:

| Situation | Rule |
|---|---|
| `bst` vs `binary-tree` | Use both. `binary-tree` = general concept, `bst` = specific variant |
| `graph` vs `bfs`/`dfs` | `graph` for structure cards; `bfs`/`dfs` for algorithm cards; add `graph` to algorithm cards too |
| `heap` vs `priority-queue` | `heap` for the data structure; add `priority-queue` if the card focuses on usage patterns |
| `blockchain` (domain) vs `blockchain` (topic) | Same tag; context is clear from the card content |
| `consensus` vs `consensus-mechanism` | `consensus` = distributed systems (Raft, Paxos); `consensus-mechanism` = blockchain (PoW, PoS) |
| `cryptography` vs `blockchain` | `cryptography` = CS primitives (SHA-256, ECDSA); `blockchain` = blockchain applications of those primitives |
| `database` vs `system-design` | Always co-tag database cards with both |
