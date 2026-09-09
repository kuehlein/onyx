# Glossary

Tap-to-define reference for terms used across cards — both specialist **acronyms**
(TCP, MVCC, CAP…) and **nuanced technical terms** whose precise particulars are
worth a quick refresher (idempotency, consistent hashing, write skew, quorum…).
Cards link the first mention, e.g. `[idempotency](_meta/glossary.md#idempotency)`;
the anchor is the GitHub-style slug of the heading ("Consistent Hashing" →
`#consistent-hashing`). Edit freely in Obsidian — this note is the single source
of truth.

**What belongs here (be liberal, not exhaustive):** a term earns an entry if its
*particulars* are easy to misremember, or it isn't everyday vocabulary — e.g.
"consistent hashing", "linearizability", "idempotency", "write skew". Skip
trivially basic concepts a candidate uses daily (e.g. "binary search", "array",
"for loop").

Specialist terms were verified against primary standards — IETF RFCs, NIST FIPS,
vendor docs. Confidence is high; if you spot a slip, just fix it here.

## AAAA
A DNS record that maps a hostname to an IPv6 address.

## ABAC
Attribute-Based Access Control — an authorization model that grants access by evaluating policies over attributes of the subject, resource, action, and environment (e.g. "department == owner and time is business hours"), rather than fixed roles.

## Algorithm confusion
A JWT/JOSE attack that forces a verifier to use the wrong signature algorithm — classically switching an RS256 token to HS256 and signing it with the server's public RSA key as the HMAC secret, so the attacker forges valid tokens. Prevented by pinning the expected algorithm instead of trusting the token's `alg` header.

## Amortized analysis
Averaging the cost of an operation over a sequence, so occasional expensive steps are spread across many cheap ones (e.g. a dynamic array's push is O(1) amortized despite O(n) resizes). It bounds total worst-case work, not any single call.

## Anti-entropy
A background replica-synchronization process in leaderless systems that compares data between replicas (often via Merkle trees) and repairs divergence, ensuring replicas eventually converge even for keys that are rarely read.

## At-least-once delivery
A messaging guarantee that every message is delivered one or more times: no message is lost, but duplicates are possible, so consumers must be idempotent to be correct.

## At-most-once delivery
A messaging guarantee that a message is delivered zero or one times: no duplicates, but messages can be lost (e.g. fire-and-forget with no retries).

## Authentication
Verifying *who* a principal is — confirming the claimed identity via credentials such as a password, key, or token. Distinct from authorization (what they may do).

## Authorization
Deciding *what* an already-authenticated principal is allowed to do — enforcing permissions on resources and actions. Distinct from authentication (who they are).

## AC
Competitive-programming judge verdict "Accepted": correct output within the time and memory limits.

## ACID
Atomicity, Consistency, Isolation, Durability — the four guarantees that keep database transactions correct despite failures and concurrent access.

## AEAD
Authenticated Encryption with Associated Data — a cipher construction (e.g. AES-GCM) that provides both confidentiality and integrity/authenticity.

## AES
Advanced Encryption Standard — the widely used symmetric-key block cipher standardized by NIST.

## ALB
Application Load Balancer — AWS's Layer 7 load balancer that routes HTTP/HTTPS by content such as path, headers, and cookies.

## ALIAS
A provider-specific DNS record that behaves like a CNAME but is legal at the zone apex, resolving to another host's address at query time.

## ANAME
A provider-specific DNS record equivalent to ALIAS, letting an apex/root domain point at a hostname rather than a fixed IP.

## AP
In the CAP theorem, a system that favors Availability and Partition tolerance, staying available with possibly-stale data during a partition.

## ARC
Adaptive Replacement Cache — an eviction policy that dynamically balances recency (LRU) and frequency (LFU).

## AS
Autonomous System — a network under a single routing policy, identified by an AS number and advertised via BGP.

## AVL
A self-balancing binary search tree (Adelson-Velsky and Landis) that keeps subtree heights within one, guaranteeing O(log n) operations.

## AXFR
Authoritative zone transfer — the DNS operation that copies an entire zone's records from a primary to a secondary nameserver.

## Backpressure
A flow-control mechanism where a slow consumer signals upstream to slow or stop producing, so a fast producer cannot overwhelm buffers or memory. Absent backpressure, unbounded queues grow until OOM or latency collapse.

## Backtracking
A search technique that builds a candidate solution incrementally and abandons ("prunes") a partial path as soon as it cannot lead to a valid solution, then undoes the last choice and tries the next — a DFS over the decision tree.

## Backward compatibility
A schema/API change is backward-compatible if *new* readers can still process data written by *old* writers (e.g. adding an optional field). Contrast forward compatibility.

## BASE
Basically Available, Soft state, Eventual consistency — the availability-favoring counterpart to ACID common in NoSQL systems.

## Bloom filter
A space-efficient probabilistic set that answers membership with no false negatives but possible false positives; used in LSM-tree engines to skip SSTables that definitely lack a key. Cannot delete elements (a standard Bloom filter) and its error rate rises as it fills.

## Bulkhead
A resilience pattern that isolates resources (e.g. separate thread pools or connection pools per dependency) so that one failing or saturated component cannot exhaust shared capacity and sink the whole system — named after a ship's watertight compartments.

## BFS
Breadth-First Search — a traversal that uses a queue to explore all nodes at the current depth before going deeper, finding shortest paths in unweighted graphs.

## BGP
Border Gateway Protocol — the internet's inter-domain routing protocol that exchanges reachability between autonomous systems.

## BIP
Bitcoin Improvement Proposal — the design-document process for Bitcoin standards (e.g. BIP-32 HD wallets, BIP-340 Schnorr).

## BLAKE2
A fast, secure cryptographic hash (BLAKE2b/2s) that is immune to length-extension and often faster than SHA.

## BLAKE3
A very fast, parallelizable, tree-structured cryptographic hash that is length-extension immune and doubles as an extendable-output function.

## BLS
Boneh-Lynn-Shacham — a pairing-based signature scheme whose signatures can be aggregated and support threshold signing.

## BST
Binary Search Tree — an ordered binary tree (left < node < right) giving O(log n) search, insert, and delete when balanced.

## CAP
The theorem that a distributed data store can guarantee at most two of Consistency, Availability, and Partition tolerance simultaneously.

## Cache stampede
When a popular cache entry expires and many concurrent requests all miss and hit the origin at once (also "dog-piling" / thundering herd on the cache). Mitigated by request coalescing, early/probabilistic recomputation, or locking so one request refills while others serve stale.

## Cascading failure
A failure that propagates: one overloaded or dead component sheds load onto its neighbors, pushing them past capacity, until the whole system collapses. Retries, missing timeouts, and lack of bulkheads/circuit breakers accelerate it.

## Causal consistency
A model guaranteeing that operations with a causal (happens-before) relationship are seen in that order by all replicas, while causally-unrelated (concurrent) operations may be seen in different orders. Weaker than sequential consistency, stronger than eventual.

## CDN
Content Delivery Network — geographically distributed edge servers that cache content near users to cut latency and origin load.

## Change data capture
A technique (CDC) that streams a database's row-level changes — typically by tailing its replication log/WAL — so downstream systems (search indexes, caches, data warehouses) stay in sync without dual writes.

## Circuit breaker
A resilience pattern that stops calling a failing dependency after an error threshold: it "opens" to fail fast (protecting caller and callee), then periodically allows a trial call ("half-open") and "closes" again once the dependency recovers.

## Compaction
The LSM-tree background process that merges sorted SSTables, discarding overwritten values and tombstoned keys, to reclaim space and bound read amplification. Its strategy (size-tiered vs leveled) trades write vs read/space amplification.

## CID
Content Identifier — a self-describing, hash-based address (as in IPFS) derived from the content itself.

## CNAME
Canonical Name — a DNS record that aliases one hostname to another; not allowed at a zone apex.

## Connection pooling
Reusing a fixed set of pre-established database/service connections across requests instead of opening one per request, amortizing the expensive TCP+TLS+auth handshake and capping concurrent connections to protect the backend.

## Consistent hashing
A hashing scheme that maps both keys and nodes onto a ring so that adding or removing a node remaps only ~1/n of keys (its ring neighbors) rather than nearly all of them. Virtual nodes are used to smooth load imbalance.

## Consumer group
In a log-based broker (e.g. Kafka), a set of consumers that jointly subscribe to a topic and split its partitions among themselves so each message is processed by exactly one member of the group; multiple groups each get the full stream (pub-sub).

## CP
In the CAP theorem, a system that favors Consistency and Partition tolerance, refusing writes it cannot safely serve during a partition.

## CQL
Cassandra Query Language — Cassandra's SQL-like language that permits efficient filtering only on partition and clustering keys.

## CRC
Cyclic Redundancy Check — a fast non-cryptographic checksum (e.g. CRC32) for detecting accidental corruption, not deliberate tampering.

## CRDT
Conflict-free Replicated Data Type — a structure that replicas can update independently and merge deterministically without coordination.

## CRUD
Create, Read, Update, Delete — the four basic persistent-storage operations over a resource.

## CT
Certificate Transparency — append-only public logs of issued TLS certificates so misissuance can be detected.

## CVE
Common Vulnerabilities and Exposures — a catalog assigning unique identifiers to publicly disclosed security vulnerabilities.

## DAG
Directed Acyclic Graph — a directed graph with no cycles, used for dependency ordering and topological sort.

## DAU
Daily Active Users — unique users who engage with a system in a day, a common input to scale and QPS estimates.

## Dead-letter queue
A side queue (DLQ) that receives messages a consumer repeatedly fails to process (poison messages) so the main queue isn't blocked; the failures can be inspected, fixed, and replayed later.

## DER
Distinguished Encoding Rules — a canonical binary format used to encode ECDSA signatures; historically lax parsing enabled malleability.

## DFS
Depth-First Search — a traversal that follows each branch as far as possible (via recursion or a stack) before backtracking.

## DHT
Distributed Hash Table — a decentralized key-value store that partitions the keyspace across many nodes (typically via consistent hashing) so any node can locate the owner of a key without a central directory.

## Dirty read
A concurrency anomaly where one transaction reads another transaction's uncommitted writes, which may later be rolled back. Prevented by read committed isolation and above.

## DKIM
DomainKeys Identified Mail — email authentication that signs messages with a key published in a DNS TXT record.

## DLP
Discrete Logarithm Problem — the hard problem of recovering an exponent in a finite cyclic group, underpinning Diffie-Hellman.

## DNS
Domain Name System — the distributed hierarchy that translates human-readable hostnames into IP addresses.

## DNSSEC
DNS Security Extensions — cryptographic signatures on DNS records that let resolvers detect forgery and cache poisoning.

## DP
Dynamic Programming — solving problems with overlapping subproblems and optimal substructure by caching subproblem results.

## DPDK
Data Plane Development Kit — userspace libraries for fast packet processing that bypass the kernel network stack.

## DSS
Digital Signature Standard — the NIST standard (FIPS 186) specifying approved signature algorithms (RSA, ECDSA, EdDSA).

## ECDLP
Elliptic-Curve Discrete Logarithm Problem — the infeasibility of recovering a private scalar k from Q = k·G, the basis of elliptic-curve security.

## ECDSA
Elliptic Curve Digital Signature Algorithm — an elliptic-curve signature scheme (used by Bitcoin/Ethereum) whose per-signature nonce leaks the private key if reused.

## ECS
EDNS Client Subnet — a DNS extension that forwards part of the client's subnet so geo-based answers match the user's location.

## EdDSA
Edwards-curve Digital Signature Algorithm — a modern deterministic signature scheme (e.g. Ed25519) that avoids per-signature randomness.

## EDNS
Extension Mechanisms for DNS — a protocol extension enabling larger UDP responses and options such as Client Subnet.

## EIP
Ethereum Improvement Proposal — the standards process for proposing changes to Ethereum (e.g. EIP-155, EIP-1559).

## EIP-155
The Ethereum proposal adding a chain ID to signed transactions for cross-chain replay protection.

## EIP-1559
The Ethereum proposal that reformed the fee market with a burned, protocol-set base fee plus a priority-fee tip.

## EOA
Externally Owned Account — an Ethereum account controlled by a private key, as opposed to a smart-contract account.

## EUF-CMA
Existential Unforgeability under Chosen-Message Attack — the standard signature-security goal: even after obtaining signatures on chosen messages, an attacker cannot forge a valid signature on any new (never-queried) message.

## Eventual consistency
A weak model guaranteeing only that, absent new writes, all replicas eventually converge to the same value; reads may return stale data in the meantime and offer no ordering or recency guarantee on their own.

## EVM
Ethereum Virtual Machine — the stack-based runtime that executes smart-contract bytecode and applies state transitions.

## Exactly-once semantics
The guarantee that each message's *effect* is applied once despite retries and failures. Usually achieved not by delivering exactly once (impossible in general) but by at-least-once delivery plus idempotent/transactional processing ("effectively once"), e.g. Kafka's idempotent producer + transactions.

## Exponential backoff
A retry strategy that multiplicatively increases the wait between attempts (e.g. 1s, 2s, 4s, …), reducing load on a struggling dependency; typically capped and combined with jitter to avoid synchronized retry storms.

## FFG
Casper Friendly Finality Gadget — Ethereum's proof-of-stake finality mechanism where validators vote on checkpoints.

## FIFO
First-In, First-Out — an ordering where the earliest-inserted element is removed first (a queue).

## FNV
Fowler-Noll-Vo — a simple, fast non-cryptographic hash for hash tables where adversarial resistance isn't required.

## Forward compatibility
A schema/API change is forward-compatible if *old* readers can still process data written by *new* writers (e.g. by ignoring unknown fields). Contrast backward compatibility.

## FROST
Flexible Round-Optimized Schnorr Threshold — a protocol letting t of n parties jointly produce a Schnorr signature.

## GCM
Galois/Counter Mode — an AEAD block-cipher mode (e.g. AES-GCM) providing encryption plus Galois-field authentication tags.

## GIL
Global Interpreter Lock — CPython's mutex that permits only one thread to execute Python bytecode at a time.

## GIN
Generalized Inverted Index — a Postgres index type for composite values such as full-text, arrays, and JSONB.

## GiST
Generalized Search Tree — an extensible Postgres index framework supporting spatial, full-text, and custom query types.

## gRPC
A high-performance RPC framework over HTTP/2 using Protocol Buffers, supporting bidirectional streaming.

## Graceful degradation
Designing a system to keep serving reduced functionality when a dependency fails — e.g. showing cached or default results when the recommender is down — rather than returning an error for the whole request.

## GTM
Global Traffic Management — DNS-based routing of clients to the nearest or healthiest regional endpoint.

## HATEOAS
Hypermedia as the Engine of Application State — the REST constraint where responses embed links to the valid next actions.

## HD
Hierarchical Deterministic (wallet) — a wallet that derives a tree of keys from a single seed per BIP-32.

## Head-of-line blocking
When the first item in a queue/stream stalls everything behind it even though later items could proceed — e.g. one lost TCP segment holding up all multiplexed HTTP/2 streams on that connection (which HTTP/3 over QUIC avoids with independent streams).

## Hinted handoff
When a target replica is down during a write, the coordinator stores the write locally as a "hint" and replays it to the replica once it recovers, improving write availability during transient failures.

## HLC
Hybrid Logical Clock — timestamps combining physical time with a logical counter for causal, monotonic ordering in distributed databases.

## HMAC
Hash-based Message Authentication Code — a keyed hash construction (RFC 2104) that authenticates integrity and is immune to length-extension.

## HSRP
Hot Standby Router Protocol — a Cisco first-hop redundancy protocol where a group of routers share a virtual IP for gateway failover.

## Idempotency
The property that performing an operation multiple times has the same effect as performing it once. Critical under at-least-once delivery and retries (e.g. HTTP PUT/DELETE and safe methods are idempotent; POST generally is not).

## Idempotency key
A client-supplied unique token attached to a request so the server can detect and de-duplicate retries — recording the key with the result and returning the stored outcome on repeats — making a non-idempotent operation (e.g. "charge card") safe to retry.

## Inverted index
A search data structure mapping each term to the list (posting list) of documents containing it, enabling fast full-text lookup — the inverse of a forward document→terms mapping.

## IP
Internet Protocol — the network-layer protocol that addresses and routes packets between hosts (IPv4/IPv6).

## Jitter
Random variation added to retry/backoff delays (or scheduled tasks) so that many clients don't retry in lockstep after a shared failure, spreading load and preventing synchronized retry storms and thundering herds.

## JWT
JSON Web Token — a compact, signed token carrying claims that can be verified statelessly without a database lookup.

## KDF
Key Derivation Function — derives cryptographic keys from a secret input; password KDFs (bcrypt, scrypt, Argon2) are deliberately slow, and scrypt/Argon2 are also memory-hard, to resist GPU/ASIC cracking.

## KMP
Knuth-Morris-Pratt — an O(n+m) string-matching algorithm using a precomputed prefix table to skip redundant comparisons.

## KMS
Key Management Service — a system for securely generating, storing, and controlling access to cryptographic keys.

## Leader election
The process by which a distributed cluster agrees on a single node to coordinate (accept writes, sequence operations); on the leader's failure a consensus protocol (e.g. Raft, Paxos, ZooKeeper) elects a new one, ideally avoiding two simultaneous leaders (split-brain).

## Leaky bucket
A rate-limiting/traffic-shaping algorithm modeling requests as water poured into a bucket that leaks at a fixed rate; overflow is dropped. It smooths bursts into a constant output rate, unlike the token bucket which permits bursts up to the bucket size.

## L4
Layer 4 (transport) — where load balancers route TCP/UDP by IP and port without inspecting application content.

## L7
Layer 7 (application) — where load balancers inspect HTTP headers, URLs, and cookies to make routing decisions.

## LB
Load Balancer — a component that distributes incoming traffic across backends for scalability and availability.

## LCA
Lowest Common Ancestor — the deepest node in a tree that is an ancestor of two given nodes.

## LCS
Longest Common Subsequence — the classic 2D dynamic-programming problem of finding the longest subsequence shared by two sequences.

## LCU
Load Balancer Capacity Unit — AWS's usage-based billing unit for an Application Load Balancer, measuring the peak across new/active connections, rule evaluations, and data processed.

## LFU
Least Frequently Used — a cache eviction policy that discards the least-accessed entry.

## LIFO
Last-In, First-Out — an ordering where the most recently inserted element is removed first (a stack).

## LIS
Longest Increasing Subsequence — the dynamic-programming problem of finding the longest strictly increasing subsequence of an array.

## Linearizability
The strongest single-object consistency model: every operation appears to take effect atomically at some point between its invocation and response, and the order respects real (wall-clock) time — once a write completes, all later reads see it or a newer value. Stronger than sequential consistency, which drops the real-time requirement.

## Lost update
A concurrency anomaly where two transactions concurrently read-modify-write the same value and one silently overwrites the other's change. Prevented by atomic operations, explicit locks (SELECT FOR UPDATE), or compare-and-set; some snapshot-isolation engines detect it automatically.

## LRU
Least Recently Used — a cache eviction policy that discards the entry unused for the longest time.

## LSM
Log-Structured Merge-tree — a write-optimized store (RocksDB, Cassandra) that turns random writes into sequential I/O.

## LWW
Last-Write-Wins — a conflict-resolution strategy that keeps the write with the latest timestamp, potentially dropping concurrent updates.

## MAC
Message Authentication Code — a keyed tag proving a message's integrity and authenticity to holders of the shared secret.

## Materialized view
A query result stored physically (precomputed) rather than recomputed on each read, trading storage and refresh cost for fast reads; it can become stale and must be refreshed (fully or incrementally). Contrast a plain view, which is just a saved query.

## MD5
Message-Digest 5 — a 128-bit legacy cryptographic hash, broken for collision resistance and unsafe for security use.

## Memoization
Top-down dynamic programming: cache the result of each subproblem the first time it's computed (typically in recursion) so repeated calls return in O(1). Contrast tabulation, which fills a table bottom-up.

## Memtable
The in-memory, sorted write buffer of an LSM-tree engine; writes go to the memtable (plus the WAL for durability) and, once full, are flushed as an immutable SSTable on disk.

## MEV
Maximal Extractable Value — profit a block producer can capture by reordering, inserting, or censoring pending transactions.

## MLE
Memory Limit Exceeded — a competitive-programming judge verdict that a solution used more memory than allowed.

## ML-DSA
Module-Lattice Digital Signature Algorithm — the NIST post-quantum signature standard (FIPS 204) derived from CRYSTALS-Dilithium.

## MMR
Merkle Mountain Range — an append-only Merkle structure supporting cheap appends and consistency proofs.

## Monotonic reads
A session guarantee that if a client reads a value, later reads never return an *older* value (time doesn't go backwards for that client). Prevents flipping between an up-to-date replica and a lagging one.

## Monotonic stack
A stack kept sorted (strictly increasing or decreasing) by popping elements that violate the order as each new element is pushed; solves next-greater/next-smaller and span problems in amortized O(n).

## MPC
Multi-Party Computation — a technique letting parties jointly compute over secret inputs, used for distributed key custody and threshold signing.

## MPT
Merkle Patricia Trie — Ethereum's content-addressed trie that lets a block header commit to the entire world state via a single root hash.

## MST
Minimum Spanning Tree — the minimum-total-weight subset of edges connecting all vertices of a weighted graph.

## mTLS
Mutual TLS — a TLS mode in which both client and server present and verify certificates.

## Multiplexing
Carrying multiple independent logical streams over one physical connection (e.g. many HTTP/2 requests over a single TCP connection). Increases utilization but, over TCP, can suffer head-of-line blocking.

## MuSig
A Schnorr multi-signature protocol that aggregates signers' keys and signatures into a single key and signature.

## MVCC
Multi-Version Concurrency Control — a concurrency technique where a write creates a new version of a row instead of overwriting it, so each transaction reads a consistent point-in-time snapshot without readers and writers blocking each other. How most databases implement snapshot isolation.

## MX
Mail Exchange — a DNS record naming the mail servers that accept email for a domain.

## NLB
Network Load Balancer — AWS's Layer 4 load balancer for high-throughput, low-overhead TCP/UDP routing.

## Nonce
A number used once — a unique (often random or monotonically increasing) value included in a protocol message to guarantee freshness and prevent replay attacks, or, in ECDSA, the per-signature secret whose reuse leaks the private key.

## NS
Name Server — a DNS record delegating a zone to its authoritative nameservers.

## OLAP
Online Analytical Processing — read-heavy analytical workloads over large datasets, typically served by columnar stores.

## OLE
Output Limit Exceeded — a competitive-programming judge verdict that a program printed far more output than expected (often an infinite loop).

## OLTP
Online Transaction Processing — many short, low-latency read/write transactions on operational data.

## OOM
Out Of Memory — a failure where a process exhausts available memory, often from loading unbounded data such as an unpaginated result set.

## Optimistic concurrency control
A strategy that assumes conflicts are rare: transactions proceed without locking, then validate at commit (e.g. via a version number/timestamp compare-and-set) and abort/retry if the data changed underneath. Contrast pessimistic locking.

## P2P
Peer-to-Peer — a decentralized topology where nodes relay data directly without a central server.

## P2PKH
Pay-to-Public-Key-Hash — a standard Bitcoin output type that locks funds to the hash of a public key.

## P99
99th-percentile latency — the response time below which 99% of requests complete, used to characterize tail latency.

## PACELC
An extension of CAP: under a Partition, trade Availability vs Consistency; Else (normal operation), trade Latency vs Consistency.

## Path compression
A union-find optimization that, during find, re-points every node on the path directly to the root, flattening the tree; combined with union by rank/size it gives near-constant (inverse-Ackermann) amortized operations.

## PBKDF2
Password-Based Key Derivation Function 2 — stretches a password or seed into a key by iterating a pseudorandom function many times.

## Pessimistic locking
A concurrency strategy that assumes conflicts are likely and acquires locks up front (e.g. SELECT FOR UPDATE) so others block until the transaction finishes; safe but reduces concurrency and risks deadlocks. Contrast optimistic concurrency control.

## Phantom read
A concurrency anomaly where a transaction re-runs a range/predicate query and sees new rows inserted by another committed transaction that match the predicate. Requires predicate/index-range locking or serializable isolation to prevent (snapshot isolation stops read-only phantoms but not write skew via phantoms).

## PII
Personally Identifiable Information — data that can identify a specific person, requiring protection in transit and at rest.

## PKCE
Proof Key for Code Exchange — an OAuth 2.0 extension where the client sends a hashed `code_challenge` up front and reveals the original `code_verifier` when redeeming the auth code, so an intercepted authorization code is useless without the verifier. Defeats code interception/injection; mandatory in OAuth 2.1.

## PKI
Public Key Infrastructure — the certificate authorities, certificates, and policies that bind public keys to verified identities.

## PoP
Point of Presence — an edge location where a network places servers close to users.

## PoS
Proof of Stake — consensus that selects validators in proportion to staked capital that can be slashed for misbehavior.

## PoW
Proof of Work — consensus requiring miners to expend computation, giving Bitcoin its probabilistic finality.

## PSS
Probabilistic Signature Scheme — the randomized, provably secure RSA padding preferred over PKCS#1 v1.5.

## QPACK
HTTP/3's header-compression scheme, adapting HPACK to QUIC's independent-stream delivery.

## QPS
Queries Per Second — a throughput metric for how many requests or queries a system handles each second.

## Quickselect
A selection algorithm that finds the k-th smallest element by partitioning (like quicksort) but recursing into only one side, giving O(n) average time (O(n²) worst case, avoidable with median-of-medians).

## Quorum
A minimum number of replicas that must acknowledge an operation. In a leaderless system with N replicas, W write and R read replicas, choosing W + R > N forces read and write sets to overlap on at least one node, guaranteeing a read sees the latest write (a common config is N=3, W=R=2).

## Rate limiting
Capping how many requests a client/key may make per time window to protect a service and ensure fairness; common algorithms are token bucket (allows bursts), leaky bucket (smooths to a steady rate), and fixed/sliding windows.

## RBAC
Role-Based Access Control — an authorization model that assigns permissions to roles and roles to users, so access is granted via role membership rather than per-user rules. Coarser but simpler to administer than ABAC.

## RBF
Replace-By-Fee — a Bitcoin policy allowing an unconfirmed transaction to be replaced by a higher-fee version spending the same inputs.

## RDBMS
Relational Database Management System — a schema-enforced, SQL, ACID table store.

## RE
Runtime Error — a competitive-programming judge verdict that a program crashed during execution.

## Read amplification
The ratio of extra work a read does versus the logical data requested — e.g. an LSM-tree read may probe several SSTable levels (mitigated by Bloom filters). One of the three amplification trade-offs alongside write and space.

## Read repair
In leaderless replication, when a read detects that some replicas returned stale values, the coordinator writes the newest value back to the lagging replicas as a side effect of the read, healing divergence on hot keys.

## Read-your-writes
A session guarantee (read-after-write consistency) that a client always sees its own prior writes, even if other clients might not yet; prevents a user from submitting an update and then seeing the old value.

## Replay attack
An attack that captures a valid message (e.g. an auth token or signed request) and re-sends it later to impersonate or duplicate an action; defeated by nonces, timestamps, or single-use tokens.

## Replication lag
The delay between a write committing on the leader/source and it appearing on a follower/replica; asynchronous replication trades this staleness window (which can violate read-your-writes on the replica) for lower write latency.

## Retry storm
A failure amplification where clients simultaneously retry a struggling service, multiplying its load and keeping it down (a self-reinforcing cascade); mitigated by exponential backoff with jitter, retry budgets, and circuit breakers.

## RFC
Request for Comments — the IETF's numbered document series defining internet standards and protocols.

## RIPEMD-160
A 160-bit cryptographic hash used with SHA-256 to derive Bitcoin P2PKH addresses.

## RLP
Recursive Length Prefix — Ethereum's canonical serialization for arbitrarily nested binary data (transactions, blocks, and state), and the basis of a transaction's signed digest.

## RPC
Remote Procedure Call — a protocol/style where a client invokes a function that executes on a remote server as if it were local, hiding the network. gRPC and Thrift are RPC frameworks; contrast REST (resource-oriented).

## RPS
Requests Per Second — a throughput metric for how many requests a system handles each second.

## RSA
Rivest-Shamir-Adleman — a public-key cryptosystem whose security rests on the difficulty of factoring large integers.

## RTT
Round-Trip Time — the time for a packet to reach a destination and its reply to return.

## Saga
A pattern for a long-lived, cross-service "transaction" without distributed locking: a sequence of local transactions where each has a compensating action, so a failure partway is undone by running the compensations in reverse. Gives atomicity-of-outcome, not isolation.

## Salt
A unique random value added to a password before hashing so identical passwords produce different hashes, defeating precomputed rainbow tables and making each hash independently attackable. Stored alongside the hash (unlike a secret pepper).

## Sargable
Said of a query predicate the engine can satisfy with an index seek/range scan (Search-ARGument-ABLE). Wrapping the column in a function or applying a leading wildcard (e.g. `WHERE YEAR(ts)=2026` or `LIKE '%x'`) is non-sargable and forces a scan.

## SCC
Strongly Connected Component — a maximal set of a directed graph in which every vertex reaches every other.

## Schema evolution
Changing a data format over time while keeping producers and consumers interoperable — managed via backward/forward-compatible changes and formats (Avro, Protobuf) that tolerate added/removed fields.

## SegWit
Segregated Witness — a Bitcoin upgrade that moves signature data outside the txid-hashed portion of a transaction, eliminating malleability.

## Sequential consistency
A model where all operations appear in a single total order that every process agrees on, and each process's own operations keep their program order — but, unlike linearizability, that order need not match real (wall-clock) time across processes.

## Serializability
The strongest transaction isolation level: concurrent transactions produce a result equivalent to *some* serial (one-at-a-time) execution, ruling out all anomalies including write skew and phantoms. Concerns multi-object transactions; contrast linearizability, which concerns single-object real-time ordering.

## SHA
Secure Hash Algorithm — a NIST-standardized family of collision-resistant cryptographic hashes (SHA-2, SHA-3).

## SHA-256
A SHA-2 member producing a 256-bit digest, widely used in Bitcoin and Merkle trees.

## SLA
Service Level Agreement — a commitment to measurable service levels such as 99.99% uptime.

## Sloppy quorum
A leaderless availability tactic where, if some home replicas are unreachable, writes/reads use the first N reachable nodes on the ring (not necessarily the "home" ones), storing hints for later handoff. Boosts availability but weakens the W+R>N overlap guarantee, so a read can miss the latest write during a partition.

## Snapshot isolation
An isolation level where each transaction reads from a consistent snapshot taken at its start (usually via MVCC), so readers never block writers; it prevents dirty/non-repeatable reads and lost updates in many engines, but does not prevent write skew.

## SOA
Start of Authority — the DNS record holding a zone's authoritative metadata (primary nameserver, serial, default TTL).

## Space amplification
The ratio of physical storage used to the logical data size — e.g. an LSM-tree holding obsolete versions and tombstones until compaction, or B-tree fragmentation. The third amplification trade-off alongside read and write.

## SPF
Sender Policy Framework — an email anti-spoofing mechanism that publishes authorized sending hosts in a DNS TXT record.

## SPHINCS+
A stateless hash-based post-quantum signature scheme, standardized by NIST as SLH-DSA (FIPS 205).

## Split-brain
A failure where a network partition leaves two sides each believing it is the sole leader/primary and both accept writes, causing divergent, conflicting state. Prevented by requiring a majority quorum or fencing tokens before acting as leader.

## SPOF
Single Point of Failure — a component whose failure alone brings down the entire system.

## SPV
Simplified Payment Verification — a Bitcoin light-client method that verifies a transaction's inclusion via a Merkle proof against block headers.

## SSE
Server-Sent Events — a unidirectional protocol that streams server updates to a client over one long-lived HTTP connection.

## SSTable
Sorted String Table — an immutable on-disk file of sorted key-value pairs, the persisted layer of LSM-tree engines.

## Sticky session
Load-balancer behavior (session affinity) that routes a given client's requests to the same backend so in-memory session state is found there; simplifies state but harms even load distribution and loses the session if that backend fails.

## TCP
Transmission Control Protocol — a connection-oriented transport that guarantees ordered, reliable, error-checked byte delivery over IP.

## Thundering herd
When a large number of waiters are all released at once (e.g. a cache entry expires, or a lock/connection frees) and stampede the same resource simultaneously, spiking load. Mitigated by request coalescing, staggered expiry, and jittered backoff.

## TLD
Top-Level Domain — the highest level of the DNS hierarchy below the root (e.g. .com, .io).

## TLE
Time Limit Exceeded — a competitive-programming judge verdict that a solution ran too slowly, signaling a wrong complexity class.

## TLS
Transport Layer Security — the cryptographic protocol that encrypts and authenticates network connections (the "S" in HTTPS).

## Token bucket
A rate-limiting algorithm where tokens refill at a fixed rate into a bucket of capacity B and each request consumes one; requests are allowed while tokens remain, permitting short bursts up to B while bounding the long-run average rate. Contrast leaky bucket (no bursts).

## Tombstone
A marker written to record that a key was deleted in an append-only/LSM or replicated store, so the deletion propagates and shadows older values; the space is reclaimed only later during compaction (and tombstones must outlive replica repair windows).

## Topological sort
A linear ordering of a DAG's vertices such that every edge u→v has u before v; used for dependency/build ordering and computable via Kahn's algorithm (repeatedly remove in-degree-0 nodes) or DFS post-order. Exists iff the graph has no cycle.

## TPS
Transactions Per Second — a throughput metric for how many transactions a database or blockchain commits each second.

## TSDB
Time-Series Database — a store specialized for timestamped data such as metrics, IoT readings, and logs.

## TSP
Traveling Salesman Problem — the NP-hard problem of the shortest route visiting each city once, often solved with bitmask DP for small n.

## TTL
Time To Live — a duration after which a cached entry or DNS record is considered expired and must be refreshed.

## Two-phase commit
A blocking atomic-commit protocol across participants: a coordinator asks all to prepare (phase 1); only if all vote yes does it tell all to commit (phase 2), else abort. Guarantees atomicity but stalls if the coordinator fails after prepare (participants hold locks), a key availability weakness.

## TXT
A DNS record holding arbitrary text, commonly used for SPF, DKIM, and domain-ownership verification.

## UDP
User Datagram Protocol — a connectionless, low-overhead transport that sends datagrams without ordering or delivery guarantees.

## UTXO
Unspent Transaction Output — Bitcoin's model where a balance is the set of unspent outputs, and validity forbids double-spending them.

## Vector clock
A per-replica vector of counters attached to each version so replicas can tell whether two updates are causally ordered or genuinely concurrent (needing conflict resolution) — unlike a single timestamp, which can't distinguish concurrency.

## VIP
Virtual IP — an IP address shared among redundant nodes so it can float to a standby on failure.

## Virtual node
In consistent hashing, mapping each physical node to many points ("vnodes") on the ring so load and the keys moved on join/leave are spread evenly, and more powerful nodes can own more vnodes.

## VPC
Virtual Private Cloud — a logically isolated private network within a public cloud provider.

## VRRP
Virtual Router Redundancy Protocol — a standard first-hop redundancy protocol where routers share a virtual IP for automatic gateway failover.

## WA
Wrong Answer — a competitive-programming judge verdict that output is incorrect due to a logic error or missed edge case.

## WAF
Web Application Firewall — a filter that inspects HTTP traffic to block application-layer attacks such as injection and abuse.

## WAL
Write-Ahead Log — a durability technique that records changes to an append-only log before applying them, enabling crash recovery and rollback.

## WAN
Wide Area Network — a network spanning large geographic distances, typically with higher latency than a local network.

## Write amplification
The ratio of bytes physically written to storage versus bytes logically written by the application — e.g. LSM compaction rewriting data repeatedly, or SSD block rewrites. Trading it against read and space amplification is central to storage-engine tuning.

## Write skew
A concurrency anomaly where two transactions each read an overlapping set, each makes a decision that is valid given its snapshot, and both write — but together they violate an invariant neither would alone (e.g. both doctors go off-call because each sees the other on-call). Only serializable isolation prevents it; snapshot isolation does not.

## XOF
Extendable-Output Function — a hash-like primitive (e.g. SHAKE, BLAKE3) that produces a digest of arbitrary requested length.

## XOR
Exclusive OR — the bitwise operation whose self-inverse property lets you find a lone unpaired element in an array.

## ZK
Zero-Knowledge — a proof technique that lets one party prove a statement is true without revealing the underlying data.
