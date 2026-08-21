# Card Generation Status

Tracks which cards have been generated and staged, and what remains.
All generated cards are in `staging/flashcards/` — promote to your Obsidian
vault after review. See `staging/REVIEW.md` for per-card verification notes.

## How to generate future batches

The same generate → verify → stage workflow pattern is used for every batch.
Past workflow scripts are saved in the Claude session and can be reused with
`Workflow({ scriptPath: "...", resumeFromRunId: "..." })`. For new batches,
describe the topics and domain to Claude and it will write and run the script.

Key workflow parameters per batch:
- Topics array with slug, name, tags
- Domain-specific verification facts (passed to the verifier agent)
- Output directory: `staging/flashcards/`
- Manifest appended to `staging/REVIEW.md`

---

## Generated (staged, awaiting promotion to vault)

### Tier 0 — Interview Meta (2 cards)
- [x] `reading-constraints.md` — Constraint → required complexity table
- [x] `interview-vocabulary.md` — TLE, MLE, AC, amortized, in-place, etc.

### Tier 1 DS&A (10 cards)
- [x] `array.md`
- [x] `hash-map.md`
- [x] `two-pointers.md`
- [x] `sliding-window.md`
- [x] `binary-search.md`
- [x] `stack.md`
- [x] `queue-deque.md`
- [x] `recursion.md`
- [x] `string-patterns.md`
- [x] `linked-list.md` ← generated in Tier 1 batch; curriculum places this in Tier 2

### Tier 1 System Design (12 cards)
- [x] `sql-vs-nosql.md`
- [x] `acid-properties.md`
- [x] `cap-theorem.md`
- [x] `database-indexing.md`
- [x] `caching.md` — regenerated 2026-08-21 (confidence: high)
- [x] `cdn.md`
- [x] `load-balancing.md`
- [x] `dns.md`
- [x] `http-https.md`
- [x] `rest-api-design.md`
- [x] `rate-limiting.md`
- [x] `back-of-envelope.md`

### Tier 1 Blockchain (6 cards)
- [x] `cryptographic-hash-functions.md` — regenerated 2026-08-21 (confidence: high)
- [x] `digital-signatures.md` — regenerated 2026-08-21 (confidence: medium)
- [x] `merkle-tree.md` — regenerated 2026-08-21 (confidence: medium)
- [x] `blockchain-data-structure.md`
- [x] `public-key-cryptography.md`
- [x] `transaction-lifecycle.md`

### Blind 75 Tier 1 — Interview Questions (5 cards)
- [x] `two-sum.md`
- [x] `valid-parentheses.md`
- [x] `best-time-to-buy-sell-stock.md`
- [x] `contains-duplicate.md`
- [x] `product-of-array-except-self.md`

### Tier 2 DS&A (9 cards)
- [x] `hash-set.md`
- [x] `binary-tree.md`
- [x] `bst.md`
- [x] `heap.md`
- [x] `bfs.md`
- [x] `dfs.md`
- [x] `graphs.md`
- [x] `dynamic-programming-1d.md`
- [x] `dynamic-programming-2d.md`

**Total staged: 44 cards**

### Regenerated after corruption (2026-08-21)

The vault parser's smoke test caught 4 cards that had been overwritten with
fragments/diff-notes during the low-confidence auto-correction step (no
frontmatter, unparseable). They were regenerated fresh via the generate→verify
workflow and adversarially fact-checked — the pass caught 3 real code bugs in
the merkle-tree card (RFC 6962 empty-tree convention, `Uint8Array` reference
equality, prefix-byte types) and a citation error in digital-signatures
(BIP-146, not the withdrawn BIP-62). The corrupted originals are preserved in
`staging/corrupted/` and can be deleted once these are promoted to the vault.

- `caching.md` (high) · `cryptographic-hash-functions.md` (high) · `digital-signatures.md` (medium) · `merkle-tree.md` (medium)

**Follow-up:** the regenerated cards use Title-Case `[[Wikilinks]]` (e.g.
`[[Merkle Trees]]`) rather than the kebab-case filename slugs the other cards
use (`[[merkle-tree]]`). Normalize them so links resolve within Onyx.

---

## Remaining (not yet generated)

Generate these in order once the current batch is reviewed and promoted.
Follow the 8-week study schedule in `_meta/curriculum.md`.

### Tier 2 System Design (~10 cards)
- [ ] Database sharding — range vs hash, hotspot problems
- [ ] Database replication — primary-replica, replication lag
- [ ] Consistent hashing — virtual nodes, ring, redistribution
- [ ] Message queues — Kafka partitions, pub/sub vs point-to-point
- [ ] Microservices — service discovery, API gateway, inter-service comms
- [ ] Distributed caching — Redis cluster, thundering herd
- [ ] Authentication — JWT, OAuth 2.0, sessions
- [ ] gRPC / Protocol Buffers — when to use over REST
- [ ] Search — Elasticsearch conceptually, inverted index
- [ ] Object storage — S3-style, blob patterns

### Tier 2 Blockchain (~6 cards)
- [ ] Consensus mechanisms — PoW, PoS, BFT variants
- [ ] Account model vs UTXO — Ethereum vs Bitcoin
- [ ] Smart contracts — EVM execution, gas, storage layout
- [ ] P2P networking in blockchain — node discovery, gossip
- [ ] Wallet architecture — HD wallets, BIP32/39/44
- [ ] Mempool — transaction ordering, fee market, MEV intro

### Blind 75 — Remaining Interview Questions (~70 cards)
Generate in waves aligned to the pattern groups:
- Arrays & Hashing (next ~10)
- Two Pointers (~5)
- Sliding Window (~4)
- Stack (~7)
- Binary Search (~7)
- Linked List (~6)
- Trees (~11)
- Tries (~3)
- Heap / Priority Queue (~6)
- Backtracking (~9)
- Graphs (~6)
- Advanced Graphs (~6)
- 1D DP (~10)
- 2D DP (~11)

### Tier 3 DS&A (~9 cards, after Tier 2 complete)
- [ ] Trie
- [ ] Union-Find / Disjoint Set
- [ ] Topological Sort
- [ ] Dijkstra's Algorithm
- [ ] Advanced DP patterns
- [ ] Monotonic Stack
- [ ] Bit Manipulation
- [ ] Segment Tree (conceptual)
- [ ] Bellman-Ford

### Language & Frameworks (~varies, generate as needed)
- [ ] SQL — JOINs, window functions, CTEs, indexing
- [ ] PostgreSQL — JSONB, explain, specific features
- [ ] Rust — ownership, borrowing, traits, async
- [ ] Axum — routing, extractors, middleware
- [ ] Dart — null safety, async, streams
- [ ] Flutter — state management, layout, Riverpod

### Behavioral (~6 cards)
- [ ] STAR framework
- [ ] Technical decision under uncertainty
- [ ] Disagreement with manager/teammate
- [ ] Most impactful project
- [ ] Failure or mistake
- [ ] Ownership example
