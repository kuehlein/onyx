# Card Review Manifest — Tier 1 DS&A

Generated: 2026-08-19
Cards staged: 10 / 10

---

## How to review

1. Open each card in `staging/flashcards/`
2. Cross-check accuracy against NeetCode, official docs, or a trusted reference
3. Fix any remaining issues directly in the file
4. Once satisfied, move to your Obsidian vault: `Flashcards/<slug>.md`
5. Copy `examples/vault/_meta/` to `Flashcards/_meta/` if not done yet

Legend:
- ✅ Passed verification — quick read-through before promoting
- ⚠️  Minor issues noted below — review those sections specifically  
- ❌ Major issues found and auto-corrected — verify the corrections carefully

---

## Card Status

### ⚠️ Array — `array.md`
  - "Do Not Use" bullet misleadingly recommends Deque for arbitrary-position inserts: 'Frequent insertions/deletions at arbitrary positions → use a Linked List or Deque (shifting costs O(n))'. Python's collections.deque has O(n) insert/delete at arbitrary positions (it rotates internally), identical asymptotically to a list. Deque only beats an array at the ENDS (O(1) push/pop from front or back). The fix is to remove 'or Deque' from this bullet; Deque already gets its own correct mention in the third 'Do not use' bullet ('Size is unknown and grows unboundedly at both ends'). Linked List is the right recommendation here (O(1) insert/delete given a pointer to the node).
  - Integer overflow pitfall wording implies (lo+hi)>>1 is unsafe in Python. The sentence reads: '(lo + hi) // 2 is safe in Python (arbitrary precision), but (lo + hi) >> 1 and C-style (lo + hi) / 2 overflow 32-bit signed integers when both are large'. Because Python integers have arbitrary precision, (lo+hi)>>1 is just as safe as (lo+hi)//2 in Python — the overflow concern applies only in C/Java with fixed-width 32-bit ints. The recommended formula lo+(hi-lo)//2 is correct and portable, but the sentence structure falsely groups >>1 with things that are problematic in the Python context being discussed.

### ⚠️ Hash Map — `hash-map.md`
  - Pitfall 3 (Two Sum self-pairing): The condition 'when the input has no duplicates' is incomplete. The insert-first bug causes wrong results in two cases: (a) no-duplicate input where target == 2*x produces a false positive [i, i], and (b) duplicate input like [3,3] target=6 produces wrong indices [0, 0] instead of [0, 1]. The phrase implies the bug is harmless when duplicates exist, which is incorrect.
  - Pitfall 5 (setdefault): The sentence 'd.setdefault(k, []) returns the *same* list for every new key — correct' is factually backwards. setdefault(k, []) creates a NEW [] for each distinct new key, so different keys get DIFFERENT list objects. What is actually true is that for the SAME key k, repeated setdefault calls return the same stored list (idempotent). The card conflates 'same key → same list' with 'every new key → same list'.

### ❌ (auto-corrected) Two Pointers — `two-pointers.md`
  - MAJOR — Complexity table row 2 space annotation is self-contradictory and wrong: 'O(1) — dominated by sort' cannot be correct. If sort dominates space, the space is O(n) for Python's Timsort (or O(log n) for a quicksort-based sort), not O(1). The annotation contradicts itself. The correct space for the two-pointer part alone is O(1) extra, but including the sort it is O(n) for Timsort. The annotation should say 'O(1) extra (O(n) for Timsort sort step)' or simply 'O(n)'.
  - MAJOR — Complexity table row 2 time annotation 'O(n log n)' is wrong when applied to k-Sum for k >= 3. The row is labelled 'Sorted pair / k-sum (after sort)', implying all k-sum variants run in O(n log n). In reality: 3-Sum is O(n^2) (outer O(n) loop times inner O(n) two-pointer scan), and k-Sum is O(n^(k-1)) generally. The three_sum code example in the same card is O(n^2), directly contradicting the table. A reader memorising this table would state 3Sum = O(n log n) in an interview — that is wrong.

### ❌ (auto-corrected) Sliding Window — `sliding-window.md`
  - Pitfall #2 is factually wrong: the text states 'the answer must be recorded when the window is still valid (before the while shrink loop runs)' for longest-window problems. This is incorrect and contradicts the code in the same card. The while-shrink loop only runs when the window is INVALID (len(freq) > k), so recording before the shrink loop means recording an invalid window — producing answers that are too large. Verified empirically: for 'abcba' with k=2 the 'record-before-shrink' variant returns 4 (wrong) while 'record-after-shrink' returns 3 (correct). The code is correct; the pitfall description teaches the opposite of what one should do. The correct rule: record the answer AFTER the shrink loop, once the window is guaranteed valid again.

### ✅ Binary Search — `binary-search.md`

### ⚠️ Stack — `stack.md`
  - Wording ambiguity in the 'Mutating the stack while iterating over it' pitfall: 'Python's for x in stack iterates a snapshot only if you convert to a list first' can be parsed as 'for x in stack sometimes creates a snapshot', which is backwards. The fact is that for x in stack NEVER creates a snapshot — it always iterates the live list object. Only list(stack) creates a snapshot. The correct phrasing would be: 'for x in stack iterates the live list, not a snapshot; wrap it in list(stack) to iterate a safe copy.'

### ⚠️ Queue and Deque — `queue-deque.md`
  - The 'Jump game' problem signal under the Deque 'When to Use' section is misleading. The classic Jump Game (LeetCode 45/55) is solved greedily in O(n) — it is not a 0-1 BFS problem. A student who memorizes 'Jump game → deque with 0-1 BFS' will apply the wrong algorithm. The correct signal for 0-1 BFS is: a shortest-path problem where edge weights are literally 0 or 1 (e.g., LeetCode 1368 'Minimum Cost to Make at Least One Valid Path in a Grid', or any grid/graph where moving in one direction costs 0 and another costs 1). Recommend replacing 'Jump game — BFS with deque when edge weights are 0 or 1 (0-1 BFS)' with something like: 'Shortest path in a grid/graph where all edge weights are 0 or 1 (not 0-1 BFS)'.

### ❌ (auto-corrected) Linked List — `linked-list.md`
  - MAJOR — Skip list insert complexity is wrong. The Variants section states: 'achieves O(log n) average search with O(1) insert (probabilistic)'. Skip list insert is O(log n) expected, not O(1). Insertion must find the correct position at each level (O(log n) levels) and update the forward pointers at each, just like search. Reference: Pugh 1990 original paper; CLRS 4th ed. The correct statement is O(log n) expected for search, insert, and delete.
  - MINOR — The 'Delete at known node' row in the complexity table places 'O(1) doubly; O(n) singly' in the Singly Linked column. The O(1) doubly half belongs in the Doubly Linked column (which already correctly shows O(1)), not in the singly column. The singly column should read 'O(n)' with the explanation moved entirely to the Why column. The underlying values are correct; only the cell placement is confusing.

### ⚠️ Recursion and the Call Stack — `recursion.md`
  - In the 'When to Use' section, the bullet 'The problem says "merge/split and combine results" — divide-and-conquer structure (merge sort, quicksort, binary search)' incorrectly groups binary search under the 'combine results' signal. Binary search does NOT combine results from both halves — it eliminates one half and recurses only on the relevant half. Its recurrence is T(n)=T(n/2)+O(1) yielding O(log n), which is structurally different from merge sort's T(n)=2T(n/2)+O(n). Listing binary search as an example of the 'combine results' pattern could cause a learner to misunderstand the D&C combine step, which is a conceptual distinction interviewers probe. Fix: either remove binary search from this bullet or reword the signal to 'divide and recurse on one or both halves' and note that combining is optional (merge sort combines; binary search does not).

### ❌ (auto-corrected) String Manipulation Patterns — `string-patterns.md`
  - MAJOR — Variants section states 'expand-around-center in O(n) time'. This is wrong. Expand-around-center visits 2n-1 centers and each expansion can scan up to O(n) characters, giving O(n^2) time total and O(1) space. Only Manacher's algorithm achieves O(n) time (with O(n) space for the auxiliary array). A candidate who learns this card will confidently give the wrong complexity in an interview.

---

# Batch 2 — Tier 1 System Design

Generated: 2026-08-20
Cards staged: 12 / 12

### ❌ (auto-corrected) SQL vs NoSQL Databases — `sql-vs-nosql.md`
  - CAP Theorem misclassification (major): The card states 'SQL databases prioritize CP (consistency + partition tolerance)' but traditional single-node RDBMS like PostgreSQL are not distributed systems and do not meaningfully participate in CAP tradeoffs — they avoid the tradeoff by not partitioning at all. The CAP theorem applies to distributed systems. HBase and Zookeeper are the canonical CP systems (distributed, sacrifice availability during partitions). PostgreSQL is not CP in the same sense. Correct framing: single-node SQL sidesteps CAP; distributed SQL (Spanner, CockroachDB) chooses CP; Cassandra/DynamoDB choose AP by default.
  - 'Most NoSQL stores are AP' is too broad (major): MongoDB with majority write concern + majority read concern is CP by default recommendation. HBase is a widely-cited CP NoSQL system. The binary 'SQL=CP, NoSQL=AP' oversimplification will cause interview candidates to misclassify systems — the verification criteria explicitly calls out HBase and Zookeeper as CP systems alongside Cassandra/DynamoDB as AP.
  - Cassandra '~1 ms p99 writes at any scale' overstates durability of the latency claim (minor): p99 write latency degrades under compaction pressure, high write rates, and cross-datacenter replication. 'At any scale' is inaccurate. Should be qualified as 'under typical single-DC conditions' or 'at scale with tuned compaction'.
  - PostgreSQL throughput numbers are conservative to the point of misleading (minor): The card states '~10K–50K writes/sec per node' and '~50K–100K simple reads/sec'. Benchmarks (pgbench) on modern NVMe hardware with connection pooling routinely show 100K–500K+ simple reads/sec and 50K+ writes/sec. The numbers are not wrong as minimums but are low enough to incorrectly imply PostgreSQL cannot scale read workloads without NoSQL.
  - SQL read replica replication lag 'typically < 1 second' understates variability (minor): Under heavy write load, replication lag can reach seconds to minutes on a lagging replica. The claim is true for idle or lightly loaded systems but misleads candidates into not accounting for replication lag in their designs.

### ⚠️ ACID Properties — `acid-properties.md`
  - Isolation level table: 'Repeatable Read — phantom reads possible (MySQL InnoDB default)' is misleading. MySQL InnoDB's RR implementation uses gap locking (and MVCC) to prevent phantom reads in most cases, going beyond the SQL standard's RR specification. A candidate citing this card in an interview could incorrectly state that InnoDB's default isolation level allows phantom reads. The SQL-standard definition of RR does allow phantoms, but InnoDB's behavior does not match the standard here. The fix is to separate the SQL-standard description from the InnoDB-specific note.
  - Serializable described as 'highest lock contention': PostgreSQL has implemented Serializable via Serializable Snapshot Isolation (SSI) since version 9.1. SSI is optimistic and conflict-detection-based, not lock-based, so the 'lock contention' framing does not apply to PostgreSQL. The trade-off table entry 'Isolation (Serializable) — Lock contention; throughput ≈ single-threaded' similarly overstates the cost for PostgreSQL specifically. The card should clarify that 'highest lock contention' applies to traditional lock-based implementations (Oracle, SQL Server), while PostgreSQL SSI uses conflict detection with lower contention at the cost of more transaction aborts/retries.

### ⚠️ CAP Theorem — `cap-theorem.md`
  - "ACID applies within a single node or single transaction" is a pedagogical simplification that overstates the boundary. Distributed ACID exists (Google Spanner, CockroachDB, 2PC protocols all provide ACID across nodes). The accurate distinction is that ACID defines transaction semantics (atomicity, isolation, etc.) while CAP defines a replication/coordination trade-off under partition — both can coexist, as Spanner demonstrates. For interview purposes the contrast is useful, but the framing could mislead a candidate who knows about distributed transactions.
  - "Typical staleness window: seconds to minutes" is slightly pessimistic for well-tuned single-datacenter AP deployments. Cassandra gossip within one DC typically propagates in milliseconds to low seconds, not minutes. Minutes is possible under severe replication lag or cross-region scenarios. Consider tightening to "milliseconds to seconds within a region, seconds to minutes across regions" to avoid overestimating staleness.

### ❌ (auto-corrected) Database Indexing — `database-indexing.md`
  - MAJOR — Write amplification claim is numerically wrong. The card states 'A table with 5 secondary indexes effectively doubles+ write I/O.' With 5 secondary indexes, each row write triggers 6 total B-tree writes (1 for the clustered PK + 5 for secondary indexes), which is 6x — not ~2x ('doubles+'). A candidate who memorizes this claim will give a concretely wrong answer when asked about index write cost. The preceding sentence ('each additional secondary index adds one B-tree insert per row write') is correct, making the following quantification plainly inconsistent with it.
  - MINOR — UUID v7 recommended alongside hash-sharded indexes as a solution to distributed hot spots in CockroachDB / Spanner. UUID v7 (per RFC 9562) is a k-sortable, time-ordered UUID: the most-significant bits encode a millisecond timestamp, so all inserts within the same time window map to the same key range. In a distributed DB that range-partitions by key (CockroachDB, Spanner), this concentrates writes on the trailing partition — the exact hot-spot pathology the card is trying to avoid. CockroachDB's own documentation recommends hash-sharded indexes or random UUIDs (v4) for this reason. UUID v7 is a good PK choice for single-node Postgres/MySQL (avoids InnoDB page splits while preserving insert-order locality) but should not be presented as a hot-spot mitigation for distributed databases.
  - MINOR — LSM-tree trade-off phrasing 'read amplification (compaction)' is backwards. Compaction is the process that mitigates read amplification by merging SSTables into fewer, larger files; it does not cause read amplification. The parenthetical implies compaction is the source of the cost. The correct framing: LSM-tree pays read amplification (must probe multiple SSTables/levels per read) and space amplification (duplicate keys across levels during compaction), while compaction is the background process that reduces both at the cost of write I/O.

### ❌ (auto-corrected) Caching — `caching.md`
  - MAJOR — Incorrect math on hit rate impact: The card states "Dropping to 90% doubles DB load" but the math is wrong by an order of magnitude. At 99% hit rate, 1% of requests reach the DB. At 90% hit rate, 10% of requests reach the DB — that is 10x the DB load, not 2x. 'Doubles DB load' would be correct only for a drop from 99% to 98% (miss rate 1% → 2%). This is a clear factual error that would embarrass a candidate in an interview.
  - MINOR — Redis instance cost estimate is low: The card states "64 GB Redis instance ≈ $200–400/month on cloud." As of current AWS ElastiCache pricing, a ~64 GB Redis instance (e.g., r7g.4xlarge at ~52 GB) costs roughly $500–900/month depending on region and commitment. The stated range ($200–400) is approximately 2x too low and may mislead candidates estimating costs in an interview. Acceptable for order-of-magnitude reasoning but the lower bound is off.
  - MINOR — Read-through vs. cache-aside stale data characterization: The card says read-through has the "Same stale data risk as cache-aside." This is broadly true but omits a nuance: read-through implementations often sit in a library layer (e.g., Spring Cache, AWS DAX) that can enforce consistent patterns, whereas cache-aside is fully application-controlled. The staleness risk is equivalent in theory but read-through libraries more often enforce TTL discipline. This is a simplification rather than an error, but could be improved.

### ❌ (auto-corrected) Content Delivery Network (CDN) — `cdn.md`
  - MAJOR — Cache-key security claim is inverted (Implementation Notes, "Cache-key design decisions" section). The card says: "Include session cookies in cache key → caches personalized responses for all users to see; critical security flaw". This is exactly backwards. INCLUDING session cookies in the cache key creates per-session cache entries — User A's cookie gives User A's cached response, User B's cookie gives User B's. That is inefficient (near-zero hit rate for personalized pages) but is not a security flaw. The actual security flaw is the OPPOSITE: serving personalized content WITHOUT excluding it from the shared cache — i.e., NOT setting Cache-Control: private or no-store on user-specific endpoints, so the CDN caches User A's /dashboard and serves that same response to User B. A candidate who memorizes the card as written would tell an interviewer the wrong thing.
  - MINOR — PoP count upper bound is significantly understated (Key Properties table). The card states "200–600 cities globally (Cloudflare, Akamai, Fastly)". Akamai alone operates in 1,000+ cities with 4,000+ PoPs; Cloudflare is at 330+ cities. Naming Akamai while citing 600 as the upper bound misrepresents the industry scale by nearly 2x for the largest named provider.
  - MINOR — The "10x cheaper" cost multiplier is unsupported by the card's own numbers. The card's cost table shows CDN egress at $0.01–0.08/GB versus origin egress at $0.08–0.20/GB. At typical/midpoint values (~$0.045 vs ~$0.14), the ratio is roughly 3x. Even at the most favorable extremes ($0.01 vs $0.20) it is 20x. "Typically 10x" is not supported; a more accurate claim is "typically 2–5x cheaper".

### ❌ (auto-corrected) Load Balancing — `load-balancing.md`
  - DNS TTL range stated as '60–300 s propagation delay' is too narrow. Real-world DNS TTLs commonly range from 60 s to 3600 s (or higher); 300–3600 s is typical for production records. The card's upper bound of 300 s understates actual client-side caching behavior and weakens the 'prefer LB over DNS round-robin' argument if a reviewer pushes back.
  - AWS autoscaling spin-up time stated as '~60 s on AWS' is a significant understatement. Cold-start time for an EC2 instance — including instance launch, AMI boot, user-data / cloud-init execution, application startup, and passing the LB health check threshold — typically runs 2–5 minutes (120–300+ s) in practice. Stating 60 s as the figure in a system design interview invites a direct challenge.
  - The claim 'a single ALB node supports ~100 K concurrent connections; if you exceed this, add more ALB capacity or use NLB' misrepresents AWS ALB. AWS ALB is a fully managed, elastic service that scales its underlying fleet automatically; AWS does not expose a per-node 100 K connection limit to operators, and users cannot manually 'add more ALB capacity' in the way described. The actionable advice is wrong: the real mitigation when hitting ALB throughput limits is to request a limit increase or switch to NLB, not to provision additional ALB instances.
  - Power of Two Choices (Random with two choices) is described as 'Standard in modern LBs (Nginx, Envoy).' Envoy does use this algorithm, but NGINX's standard and plus distributions use round-robin, least connections, IP hash, and simple random — not Power of Two Choices as a built-in option. This is a minor factual overstatement.

### ⚠️ DNS (Domain Name System) — `dns.md`
  - 'Plan for up to 2x TTL of stale traffic' (Implementation Notes, health-check-gated DNS failover section) is imprecise. After Route 53 detects a failure and updates the record, clients who cached the record just before the update can see stale traffic for at most 1x the remaining TTL — not 2x. The '2x' figure conflates two separate delays: (1) health check detection latency (polling interval, not TTL) and (2) cached TTL expiry. These are different quantities. Correct framing: 'Stale traffic window = health-check detection time (up to 30s on fast checks) + remaining TTL on already-cached records (up to 1x TTL).'
  - The blue/green deployment example uses '10.0.1.5' as the A record target for 'api.example.com', which is an RFC 1918 private address. A public-facing API cannot be reached via a private IP from external clients. The example should either use a public IP, a load balancer hostname via CNAME, or explicitly note this is an internal/VPC-only service.

### ❌ (auto-corrected) HTTP and HTTPS — `http-https.md`
  - MAJOR — HTTP/3 Server Push is marked 'Yes' in the table, but RFC 9114 (HTTP/3) does not include server push. It was deliberately omitted from the spec. All major browsers also removed HTTP/2 server push support (Chrome dropped it in v106, October 2022; Firefox followed). The HTTP/3 cell must be 'No', and the HTTP/2 cell should be 'Deprecated (removed from browsers 2022)'.
  - MAJOR — The 'Typical latency (TLS handshake)' table row conflates TLS versions with HTTP versions. The table implies HTTP/1.1 always uses TLS 1.2 (2 RTT) and HTTP/2 always uses TLS 1.3 (1 RTT), which is factually wrong. Both HTTP/1.1 and HTTP/2 can run over either TLS 1.2 or TLS 1.3; the RTT count belongs to the TLS version, not the HTTP version. HTTP/3 is the only one where the mapping is inherent, because QUIC mandates TLS 1.3. The row needs to be rewritten to show 'TLS 1.2: 2 RTT / TLS 1.3: 1 RTT' for both HTTP/1.1 and HTTP/2 columns, and '1 RTT initial; 0-RTT resumption' for HTTP/3.
  - MINOR — gRPC serialization overhead is stated as '~5–10x lower'. The more commonly cited and experimentally supported range for Protobuf vs JSON is ~3–10x (payload size) and 3–6x faster parse. '5–10x' skews to the optimistic end and may overclaim in interviews. '~3–10x' is more defensible.
  - MINOR — The Lambda/serverless 'Connection: close' pitfall is imprecisely explained. Lambda functions do not maintain persistent TCP connections themselves; the keep-alive problem manifests at the API Gateway or ALB layer, not in the Lambda runtime. The pitfall is real but the root cause described ('upstream has no persistent connection') misattributes where the connection management occurs.

### ⚠️ REST API Design — `rest-api-design.md`
  - DELETE idempotency pitfall is self-contradictory: the card says 'not error on the second call' but then says it returns 404, which IS a 4xx error response. RFC 9110 §9.3.5 defines DELETE idempotency in terms of the *state effect* (the resource remains absent), not the status code — a second DELETE may legitimately return 404. The current wording conflates the two and misleads readers.
  - The rate limiting example '~1000 req/min per user is typical' is an unsupported specific number. No industry standard sets this default: GitHub uses ~83 req/min, Stripe uses 100 req/sec, Twitter used ~20 req/min. The number varies by orders of magnitude across services and should not be presented as 'typical.'
  - PATCH is listed in the HTTP verb table without an idempotency qualifier, while GET, PUT, and DELETE all have theirs stated. RFC 5789 explicitly states PATCH is neither safe nor idempotent. The omission creates an incomplete picture that could cause an interview error.

### ⚠️ Rate Limiting — `rate-limiting.md`
  - Redis latency stated as '~1–5 ms added latency per request' is conservative/high for typical same-datacenter deployments where round-trip latency is usually under 1ms (0.1–0.5ms). The range should be '~0.1–1 ms' for co-located Redis, or the phrasing should clarify this applies to cross-zone or high-load scenarios.
  - The sliding window counter '~10% over-burst at boundary' is an informal approximation. The actual worst-case over-burst is not capped at 10% — in adversarial cases (all N requests fired in the final moment of the previous window) the over-burst approaches the full previous window's quota. The 10% figure describes typical benign traffic patterns, not a guaranteed upper bound. The phrasing could mislead an interviewer into thinking the error is bounded at 10%.
  - Leaky bucket memory listed as 'O(queue depth)' is technically correct but in production implementations the queue is bounded (dropped when full), making practical memory O(max_queue_capacity) = O(1). This is a minor framing ambiguity rather than a factual error.
  - The claim 'most production systems choose fail-static' when Redis is unavailable is an overconfident generalization. Many production systems fail open (simpler to implement) or fail closed (for paid-tier enforcement). The claim is plausible but not verifiable as a majority position.

### ⚠️ Back-of-Envelope Estimation — `back-of-envelope.md`
  - SSD random read latency: Card states ~100 µs, but the Jeff Dean gist cited at the bottom of the card gives 150 µs. Modern NVMe SSDs can reach 20-100 µs, so the card's figure is defensible for NVMe hardware but inconsistent with its own cited source (which covers SATA-era SSDs). The card should either cite 150 µs and note that NVMe brings this closer to 20-100 µs, or drop the Jeff Dean gist citation for this number.
  - L2 cache latency: Card states ~10 ns; Jeff Dean's numbers give ~7 ns (other sources say 4-7 ns). Same order of magnitude but slightly inflated relative to the cited reference.
  - Cross-continental round-trip: ~150 ms is accurate for US-to-Asia but US-to-Europe is closer to 80-100 ms. The label 'cross-continental' is ambiguous enough that a learner could over-estimate US-Europe latency by 50-80%. Alex Xu's book uses 150 ms as the standard figure, so this is a convention issue more than a flat error, but the card should note the route dependency.
  - Optimistic vs. pessimistic trade-off is one-sided: the card warns that optimistic estimates cause under-provisioning but never states the downside of pessimistic estimates (over-provisioning wastes capacity and increases cost). A trade-off section should present both directions.
  - Breadth vs. depth trade-off: the card recommends 5-7 minutes and skipping sub-components, but does not articulate the cost of doing so (missing a bottleneck in a skipped component can invalidate the architecture). The depth side is absent.

---

# Batch 3 — Tier 1 Blockchain

Generated: 2026-08-20
Cards staged: 6 / 6

### ❌ (auto-corrected) Cryptographic Hash Functions — `cryptographic-hash-functions.md`
  - MAJOR — Incorrect cryptographic implication chain: The card states 'Collision resistance implies second-preimage resistance, which implies preimage resistance — but not vice versa.' This is technically wrong. These three properties are formally independent. It is possible to construct a function that is collision resistant but not second-preimage resistant (and vice versa). Boneh & Shoup — the very textbook cited in the card's Resources section — treats them as independent properties and explicitly warns against assuming this ordering. For a senior-engineer audience, stating this as a crisp implication chain is a precision error that will be confidently reproduced. The informal intuition that 'collision attacks tend to arrive before preimage attacks in practice' is a historical observation, not a formal implication. The sentence should be removed or replaced with: 'These three properties are formally independent; in practice, collision attacks against deployed functions have historically appeared before second-preimage or preimage attacks (e.g., SHA-1).'
  - MINOR — Avalanche effect listed as a co-equal 'security property': The card's Key Properties table presents four properties 'that define whether a hash function is cryptographic,' placing the avalanche effect alongside preimage resistance, second-preimage resistance, and collision resistance. The avalanche effect is a design criterion / desirable behavioral property, not a formal security definition. The three formal security properties are exactly the first three. The avalanche effect should be noted as a related design goal, not a defining security property at the same level.

### ❌ (auto-corrected) Digital Signatures and ECDSA — `digital-signatures.md`
  - MAJOR — EdDSA nonce derivation: The card states 'k derived via HMAC-DRBG from d and m' for EdDSA/ed25519. This is wrong. EdDSA (RFC 8032) derives the nonce r as H(nonce_key || M) using a simple cryptographic hash over the second half of the expanded private key and the message — no HMAC-DRBG involved. HMAC-DRBG is the mechanism used by RFC 6979 for deterministic *ECDSA*, not EdDSA. Conflating these is a meaningful factual error for a senior engineer audience studying cryptography.
  - MINOR — EIP-155 v value description: The card says 'v is the recovery parameter (27 or 28, or 0/1 in EIP-155 replay-protected form)'. EIP-155 does NOT use 0/1 — it uses v = CHAIN_ID * 2 + 35 or CHAIN_ID * 2 + 36 (e.g., v = 37 or 38 on Ethereum mainnet). The recovery id parity is 0 or 1 internally but the wire-level v is much larger under EIP-155.
  - MINOR — 'Signature aggregation: Native batch verify' for ed25519 in the trade-off table conflates two distinct properties. Batch verification (verifying many separate signatures together more efficiently) is not the same as signature aggregation (combining multiple signatures into a single shorter signature). ed25519 supports batch verification; native aggregation is a property of BLS signatures, not EdDSA.
  - MINOR — 'n is the number of valid points': n is the order of the cyclic subgroup generated by G, which equals the number of points in that subgroup (including the point at infinity). The total number of points on the secp256k1 curve is n * h where h is the cofactor; for secp256k1 h=1 so it coincides, but the phrasing 'number of valid points' is imprecise and could mislead on curves with h > 1.

### ❌ (auto-corrected) Merkle Trees — `merkle-tree.md`
  - MAJOR — Bitcoin misattributed as using 0x00/0x01 domain separation. The card states the second-preimage fix is 'Bitcoin's approach; also specified in RFC 6962 for Certificate Transparency.' This is factually reversed. Bitcoin does NOT use domain-separated leaf/internal-node prefixes — this is a documented weakness in Bitcoin's Merkle tree design (see Sergio Lerner's 2018 'Leaf-Node weakness in Bitcoin Merkle Tree Design'). The 0x00/0x01 prefix scheme originates from RFC 6962 (Certificate Transparency) and has been proposed but not adopted by Bitcoin. The parenthetical should be removed or corrected to avoid misattributing the fix to Bitcoin.

### ⚠️ Blockchain Data Structure — `blockchain-data-structure.md`
  - MINOR — Bitcoin Merkle tree second-preimage mitigation is wrong. The card states 'Bitcoin prevents this by different hash functions for leaves vs. internal nodes.' Bitcoin does NOT use different hash functions (or domain-separation prefixes) for leaves vs. internal nodes — it uses double-SHA-256 for both. The domain-separation technique (0x00 prefix for leaves, 0x01 for internal nodes) comes from RFC 6962 (Certificate Transparency), not Bitcoin. Bitcoin's Merkle tree actually has a known second-preimage vulnerability (CVE-2012-2459 / the duplicate-transaction attack), which Bitcoin Core mitigates at a higher level (rejecting blocks with duplicate txids), not via distinct hash functions. The card's claim will mislead senior engineers about Bitcoin's actual implementation.
  - MINOR — Post-Merge Ethereum field attribution is imprecise. The card says the PoW nonce is replaced by 'a BLS aggregate signature from the validator committee (randaoReveal, parentBeaconBlockRoot).' randaoReveal is the block proposer's individual BLS signature on the current epoch (not a committee aggregate). The committee's BLS aggregate is the syncAggregate field. parentBeaconBlockRoot (EIP-4788) is a beacon chain root included in the execution payload for smart-contract access — it is not a consensus signature field. These fields do exist in Ethereum post-Merge headers but the parenthetical misattributes their roles.
  - MINOR — Bitcoin UTXO set size overstated. The card cites '~10 GB (2025)' for Bitcoin's UTXO set. The UTXO set is approximately 4–7 GB as of 2024–2025. The full blockchain (all blocks) is ~600+ GB; the UTXO set is the compact subset of unspent outputs, substantially smaller than 10 GB.
  - MINOR — Ethereum L1 throughput upper bound is optimistic. The table lists '~15–100 TPS (L1)' for Ethereum. The broadly cited figure for Ethereum L1 is ~15–30 TPS; 100 TPS is more characteristic of specific conditions or Layer 2. The upper bound of 100 TPS could mislead engineers comparing L1 performance.

### ⚠️ Public Key Cryptography and Address Derivation — `public-key-cryptography.md`
  - Bitcoin P2PKH: the card claims double-hashing (RIPEMD-160(SHA-256(pubkey))) 'adds quantum resistance margin.' This is misleading and backwards. The RIPEMD-160 step reduces the digest to 160 bits, which gives only 80-bit quantum security under Grover's algorithm — weaker than a raw 256-bit hash (128-bit quantum security). The real rationale for the double-hash is defense-in-depth against a single hash function break and address-size reduction, not quantum resistance.
  - Compressed vs. uncompressed keys: the card states 'the same private key yields two different public keys depending on compression.' This is technically wrong. A private key maps to exactly one public key point (x, y) on the elliptic curve. Compressed and uncompressed are two encodings of the same point. What differs is the byte-string fed to the hash function, producing different address hashes. The distinction matters for senior engineers.
  - Zcash (Sapling) is listed in the Ed25519/EdDSA ecosystem row. This is incorrect. Zcash's Sapling shielded protocol uses the Jubjub curve with the RedJubjub signature scheme (a Schnorr variant), not Ed25519 or EdDSA. Zcash transparent addresses use secp256k1 (same as Bitcoin).
  - Polkadot is listed as using Ed25519. Polkadot's default and primary signature scheme is sr25519 (Schnorrkel/Ristretto25519), not Ed25519. Ed25519 is a supported but non-default option in Substrate. Listing Polkadot alongside Solana and Cardano as an Ed25519 chain is imprecise for a senior-engineer audience.

### ❌ (auto-corrected) Transaction Lifecycle — `transaction-lifecycle.md`
  - MAJOR — Signing section: "Collision resistance of keccak256 ensures that forging a signature requires breaking the discrete logarithm problem on secp256k1" conflates two distinct security properties. ECDSA signature unforgeability comes from the hardness of the elliptic-curve discrete logarithm problem (ECDLP) on secp256k1, not from keccak256 collision resistance. Collision resistance of the hash function is a separate, additional protection that prevents existential forgery via hash collisions (finding two messages with the same digest). The card incorrectly attributes the wrong mechanism to the wrong guarantee.
  - MAJOR — Mempool validation: "Nonce equals currentNonce + 1 for that account" is wrong by one. In Ethereum, eth_getTransactionCount (the standard way to read 'currentNonce') already returns the NEXT expected nonce (i.e., the count of confirmed transactions). A valid incoming transaction must have nonce == eth_getTransactionCount result, not +1. The card's own JS code correctly does NOT add 1 (provider.getTransactionCount(...) is used directly), creating a direct contradiction. The rule as written would cause an off-by-one error.
  - MAJOR — Common Pitfalls / SegWit section: "txid malleability allowed a third party to alter the witness without changing the economic content" is anachronistic and factually wrong. Pre-SegWit Bitcoin had no witness field at all — the witness data structure is a SegWit invention. The malleability in pre-SegWit transactions was in the scriptSig (unlocking script), where third parties could modify signature encoding (e.g., alternative DER encodings, OP_0 pushes) without changing economic content. SegWit fixes this by moving signatures to a separate witness field excluded from the txid hash.

---

## Next Batches (run after this one is reviewed and promoted)

1. **Tier 2 DS&A** — Linked List (advanced), Binary Tree, BST, Heap, BFS, DFS, Graphs, DP 1D, DP 2D
2. **Tier 1 System Design** — Databases, Caching, Load Balancing, CDN, DNS, HTTP, Rate Limiting, Back-of-envelope
3. **Tier 1 Blockchain** — Hash functions, Digital signatures, Merkle trees, Blockchain structure, Key pairs, Transaction lifecycle
4. **Interview Questions (Blind 75 Tier 1)** — Two Sum, Valid Parentheses, Best Time to Buy/Sell Stock, Contains Duplicate, Product of Array Except Self

---

# Batch 4 — Blind 75 Tier 1 Interview Questions

Generated: 2026-08-20
Cards staged: 5 / 5
Type: interview-question (self-graded; practice_url opens NeetCode after Good/Easy grade)

### ✅ Two Sum — `two-sum.md`

### ✅ Valid Parentheses — `valid-parentheses.md`

### ⚠️ Best Time to Buy and Sell Stock — `best-time-to-buy-sell-stock.md`
  - The `concepts` and `Related Concepts` fields include `sliding-window`. The algorithm is a running-minimum/greedy single pass — not a true sliding window with two pointers that shrink a window. NeetCode places this problem in its Sliding Window bucket, so the tag is not outright wrong relative to that curriculum, but it is an imprecise label that could mislead a reader who is specifically studying the sliding-window technique.

### ✅ Contains Duplicate — `contains-duplicate.md`

### ✅ Product of Array Except Self — `product-of-array-except-self.md`

---

# Batch 5 — Tier 2 DS&A

Generated: 2026-08-20
Cards staged: 9 / 9
Note: Linked List (Tier 2) was already generated in Batch 1.

### ⚠️ Hash Set — `hash-set.md`
  - Key Properties table — Ordering row says insertion order is 'not guaranteed by spec for all engines'. This is factually wrong: ECMA-262 (ES2015+) normatively requires Set iterators to follow insertion order. The correct nuance is that insertion order ≠ sorted order, not that the spec is silent on ordering.
  - Common Pitfalls — 'Assuming sorted output' bullet says insertion order is 'an implementation detail for primitive values'. This contradicts the spec: insertion order is required by the standard, not optional engine behaviour. The practical warning (do not expect sorted output) is correct, but the justification is wrong.
  - When to Use — 'Find the element that appears only once — XOR works too, but a set generalizes to k-unique variants'. A bare Set cannot count occurrences, so it cannot identify which element appears once without extra machinery (e.g. a second Set tracking seen-twice). The Do-Not-Use section correctly says use a Map for counting, making this bullet misleading and internally contradictory.
  - Do not use when — 'Values are large objects you need to associate data with → use a Map instead'. The qualifier 'large' is spurious; any object-to-data association needs a Map regardless of object size.

### ⚠️ Binary Tree — `binary-tree.md`
  - Inorder description overstates its reconstruction capability. The card says 'produces sorted output for a BST; reconstructs BST from scratch' — but inorder traversal alone cannot uniquely reconstruct the original BST. Multiple distinct BSTs share the same inorder sequence (e.g., [1,2,3] is produced by a left-skewed, right-skewed, and balanced BST). Unique structural reconstruction requires inorder combined with preorder or postorder. The valid use case for inorder-only is building A BST from sorted values (LeetCode 108), not reconstructing a specific existing tree.

### ⚠️ Binary Search Tree (BST) — `bst.md`
  - k-th smallest complexity table description says 'traverse down to the minimum, then step right k times' — 'step right k times' is imprecise. In-order traversal backtracks up the call stack and recurses into right subtrees; it does not literally step right. The O(h + k) complexity claim is correct, only the prose description of the mechanism is misleading.

### ❌ (auto-corrected) Heap and Priority Queue — `heap.md`
  - MAJOR — Trade-off table: 'Extract min | Sorted Array | O(1) pop from front' is wrong. Removing the first element of an array uses shift(), which is O(n) due to re-indexing. It is O(1) only with a pointer/index trick, which is a non-standard implementation not implied by 'sorted array'. An interviewer would penalize stating O(1) here.
  - MINOR — Complexity table includes 'decrease-key: O(log n)' without a clear caveat that this requires an indexed priority queue (position tracking per element). The card's own MinHeap implementation does not support decrease-key at all. The pitfalls section mentions this, but the table presents it as a standard heap operation, which could mislead a reader into thinking their MinHeap class has it.

### ⚠️ Breadth-First Search (BFS) — `bfs.md`
  - In the 'Why O(V+E)' explanation, the card states 'every edge is examined exactly once when its source vertex is dequeued.' For undirected graphs, each edge is examined from both endpoints (twice total), so the per-edge examination count is 2 for undirected graphs, not 1. The O(V+E) conclusion is still correct, but the stated reason is imprecise for undirected graphs. This does not affect any interview answer.

### ❌ (auto-corrected) Depth-First Search (DFS) — `dfs.md`
  - MAJOR — Backtracking template: `candidates` is used in the loop body (`candidates.length`, `candidates[i]`) but is never declared or passed as a parameter. The function signature is `backtrack(start, current, result, /* problem-specific params */)` and `candidates` only appears as a comment placeholder, not an actual parameter. Running this code throws `ReferenceError: candidates is not defined`. Fix: add `candidates` as an explicit parameter — `backtrack(start, current, result, candidates, /* other params */)` — and thread it through the recursive call.
  - MINOR — Pitfall 'Off-by-one on the visited mark timing' uses the word 'enqueue' ('or you may enqueue the same node multiple times in iterative DFS') but iterative DFS uses a stack, not a queue. The correct term is 'push onto the stack'. Using 'enqueue' conflates DFS with BFS terminology.
  - MINOR — The complexity table row for 'Graph (adjacency list)' lists Space as O(V), which omits the call stack depth. The Key Properties section correctly states 'O(V) for the visited set + O(H) for the call stack', but the table only shows O(V). This internal inconsistency could mislead a reader who only skims the table. The notes column should clarify 'O(V) visited + O(V) call stack worst case' or match the more precise wording used in the prose above.

### ✅ Graphs — `graphs.md`

### ⚠️ Dynamic Programming — 1D Patterns — `dynamic-programming-1d.md`
  - Minor — misleading placement in 'Do not use when' list: the bullet 'Problem asks for the actual path/choices, not just the value' is listed as a reason to avoid DP, but the explanation immediately clarifies 'DP still works but you must store parent pointers or backtrack through the table.' This contradicts the section heading and could mislead a learner into thinking DP is wrong here when it is actually the correct approach with an extra bookkeeping step. It should be moved to a 'Caveats / Pitfalls' note rather than a 'Do not use' bullet.

### ✅ Dynamic Programming — 2D Patterns — `dynamic-programming-2d.md`

---

## All Batches Complete

Total cards staged across all batches:
- Batch 1: Tier 1 DS&A — 10 cards (+ 2 Tier 0 meta cards written directly)
- Batch 2: Tier 1 System Design — 12 cards
- Batch 3: Tier 1 Blockchain — 6 cards
- Batch 4: Blind 75 Tier 1 Interview Questions — 5 cards
- Batch 5: Tier 2 DS&A — 9 cards

Next step: promote reviewed cards to your Obsidian vault Flashcards/ folder.
Copy examples/vault/_meta/ to Flashcards/_meta/ first.
