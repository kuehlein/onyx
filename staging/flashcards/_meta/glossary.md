# Glossary

Definitions for the specialist acronyms used across cards. Edit freely in
Obsidian — this note is the single source of truth. Cards link here, e.g.
`[TCP](_meta/glossary.md#tcp)`.

Specialist terms (crypto, blockchain, distributed systems, networking) were
verified against primary standards — IETF RFCs, NIST FIPS, Ethereum EIPs,
Bitcoin BIPs, and vendor docs. Confidence is high; if you spot a slip, just fix
it here.

## AAAA
A DNS record that maps a hostname to an IPv6 address.

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

## BASE
Basically Available, Soft state, Eventual consistency — the availability-favoring counterpart to ACID common in NoSQL systems.

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

## CDN
Content Delivery Network — geographically distributed edge servers that cache content near users to cut latency and origin load.

## CID
Content Identifier — a self-describing, hash-based address (as in IPFS) derived from the content itself.

## CNAME
Canonical Name — a DNS record that aliases one hostname to another; not allowed at a zone apex.

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

## DER
Distinguished Encoding Rules — a canonical binary format used to encode ECDSA signatures; historically lax parsing enabled malleability.

## DFS
Depth-First Search — a traversal that follows each branch as far as possible (via recursion or a stack) before backtracking.

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

## EVM
Ethereum Virtual Machine — the stack-based runtime that executes smart-contract bytecode and applies state transitions.

## FFG
Casper Friendly Finality Gadget — Ethereum's proof-of-stake finality mechanism where validators vote on checkpoints.

## FIFO
First-In, First-Out — an ordering where the earliest-inserted element is removed first (a queue).

## FNV
Fowler-Noll-Vo — a simple, fast non-cryptographic hash for hash tables where adversarial resistance isn't required.

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

## GTM
Global Traffic Management — DNS-based routing of clients to the nearest or healthiest regional endpoint.

## HATEOAS
Hypermedia as the Engine of Application State — the REST constraint where responses embed links to the valid next actions.

## HD
Hierarchical Deterministic (wallet) — a wallet that derives a tree of keys from a single seed per BIP-32.

## HLC
Hybrid Logical Clock — timestamps combining physical time with a logical counter for causal, monotonic ordering in distributed databases.

## HMAC
Hash-based Message Authentication Code — a keyed hash construction (RFC 2104) that authenticates integrity and is immune to length-extension.

## HSRP
Hot Standby Router Protocol — a Cisco first-hop redundancy protocol where a group of routers share a virtual IP for gateway failover.

## IP
Internet Protocol — the network-layer protocol that addresses and routes packets between hosts (IPv4/IPv6).

## JWT
JSON Web Token — a compact, signed token carrying claims that can be verified statelessly without a database lookup.

## KDF
Key Derivation Function — derives cryptographic keys from a secret input; password KDFs (bcrypt, scrypt, Argon2) are deliberately slow, and scrypt/Argon2 are also memory-hard, to resist GPU/ASIC cracking.

## KMP
Knuth-Morris-Pratt — an O(n+m) string-matching algorithm using a precomputed prefix table to skip redundant comparisons.

## KMS
Key Management Service — a system for securely generating, storing, and controlling access to cryptographic keys.

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

## LRU
Least Recently Used — a cache eviction policy that discards the entry unused for the longest time.

## LSM
Log-Structured Merge-tree — a write-optimized store (RocksDB, Cassandra) that turns random writes into sequential I/O.

## LWW
Last-Write-Wins — a conflict-resolution strategy that keeps the write with the latest timestamp, potentially dropping concurrent updates.

## MAC
Message Authentication Code — a keyed tag proving a message's integrity and authenticity to holders of the shared secret.

## MD5
Message-Digest 5 — a 128-bit legacy cryptographic hash, broken for collision resistance and unsafe for security use.

## MEV
Maximal Extractable Value — profit a block producer can capture by reordering, inserting, or censoring pending transactions.

## MLE
Memory Limit Exceeded — a competitive-programming judge verdict that a solution used more memory than allowed.

## ML-DSA
Module-Lattice Digital Signature Algorithm — the NIST post-quantum signature standard (FIPS 204) derived from CRYSTALS-Dilithium.

## MMR
Merkle Mountain Range — an append-only Merkle structure supporting cheap appends and consistency proofs.

## MPC
Multi-Party Computation — a technique letting parties jointly compute over secret inputs, used for distributed key custody and threshold signing.

## MPT
Merkle Patricia Trie — Ethereum's content-addressed trie that lets a block header commit to the entire world state via a single root hash.

## MST
Minimum Spanning Tree — the minimum-total-weight subset of edges connecting all vertices of a weighted graph.

## mTLS
Mutual TLS — a TLS mode in which both client and server present and verify certificates.

## MuSig
A Schnorr multi-signature protocol that aggregates signers' keys and signatures into a single key and signature.

## MX
Mail Exchange — a DNS record naming the mail servers that accept email for a domain.

## NLB
Network Load Balancer — AWS's Layer 4 load balancer for high-throughput, low-overhead TCP/UDP routing.

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

## P2P
Peer-to-Peer — a decentralized topology where nodes relay data directly without a central server.

## P2PKH
Pay-to-Public-Key-Hash — a standard Bitcoin output type that locks funds to the hash of a public key.

## P99
99th-percentile latency — the response time below which 99% of requests complete, used to characterize tail latency.

## PACELC
An extension of CAP: under a Partition, trade Availability vs Consistency; Else (normal operation), trade Latency vs Consistency.

## PBKDF2
Password-Based Key Derivation Function 2 — stretches a password or seed into a key by iterating a pseudorandom function many times.

## PII
Personally Identifiable Information — data that can identify a specific person, requiring protection in transit and at rest.

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

## RBF
Replace-By-Fee — a Bitcoin policy allowing an unconfirmed transaction to be replaced by a higher-fee version spending the same inputs.

## RDBMS
Relational Database Management System — a schema-enforced, SQL, ACID table store.

## RE
Runtime Error — a competitive-programming judge verdict that a program crashed during execution.

## RFC
Request for Comments — the IETF's numbered document series defining internet standards and protocols.

## RIPEMD-160
A 160-bit cryptographic hash used with SHA-256 to derive Bitcoin P2PKH addresses.

## RLP
Recursive Length Prefix — Ethereum's canonical serialization for arbitrarily nested binary data (transactions, blocks, and state), and the basis of a transaction's signed digest.

## RPS
Requests Per Second — a throughput metric for how many requests a system handles each second.

## RSA
Rivest-Shamir-Adleman — a public-key cryptosystem whose security rests on the difficulty of factoring large integers.

## RTT
Round-Trip Time — the time for a packet to reach a destination and its reply to return.

## SCC
Strongly Connected Component — a maximal set of a directed graph in which every vertex reaches every other.

## SegWit
Segregated Witness — a Bitcoin upgrade that moves signature data outside the txid-hashed portion of a transaction, eliminating malleability.

## SHA
Secure Hash Algorithm — a NIST-standardized family of collision-resistant cryptographic hashes (SHA-2, SHA-3).

## SHA-256
A SHA-2 member producing a 256-bit digest, widely used in Bitcoin and Merkle trees.

## SLA
Service Level Agreement — a commitment to measurable service levels such as 99.99% uptime.

## SOA
Start of Authority — the DNS record holding a zone's authoritative metadata (primary nameserver, serial, default TTL).

## SPF
Sender Policy Framework — an email anti-spoofing mechanism that publishes authorized sending hosts in a DNS TXT record.

## SPHINCS+
A stateless hash-based post-quantum signature scheme, standardized by NIST as SLH-DSA (FIPS 205).

## SPOF
Single Point of Failure — a component whose failure alone brings down the entire system.

## SPV
Simplified Payment Verification — a Bitcoin light-client method that verifies a transaction's inclusion via a Merkle proof against block headers.

## SSE
Server-Sent Events — a unidirectional protocol that streams server updates to a client over one long-lived HTTP connection.

## SSTable
Sorted String Table — an immutable on-disk file of sorted key-value pairs, the persisted layer of LSM-tree engines.

## TCP
Transmission Control Protocol — a connection-oriented transport that guarantees ordered, reliable, error-checked byte delivery over IP.

## TLD
Top-Level Domain — the highest level of the DNS hierarchy below the root (e.g. .com, .io).

## TLE
Time Limit Exceeded — a competitive-programming judge verdict that a solution ran too slowly, signaling a wrong complexity class.

## TLS
Transport Layer Security — the cryptographic protocol that encrypts and authenticates network connections (the "S" in HTTPS).

## TPS
Transactions Per Second — a throughput metric for how many transactions a database or blockchain commits each second.

## TSDB
Time-Series Database — a store specialized for timestamped data such as metrics, IoT readings, and logs.

## TSP
Traveling Salesman Problem — the NP-hard problem of the shortest route visiting each city once, often solved with bitmask DP for small n.

## TTL
Time To Live — a duration after which a cached entry or DNS record is considered expired and must be refreshed.

## TXT
A DNS record holding arbitrary text, commonly used for SPF, DKIM, and domain-ownership verification.

## UDP
User Datagram Protocol — a connectionless, low-overhead transport that sends datagrams without ordering or delivery guarantees.

## UTXO
Unspent Transaction Output — Bitcoin's model where a balance is the set of unspent outputs, and validity forbids double-spending them.

## VIP
Virtual IP — an IP address shared among redundant nodes so it can float to a standby on failure.

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

## XOF
Extendable-Output Function — a hash-like primitive (e.g. SHAKE, BLAKE3) that produces a digest of arbitrary requested length.

## XOR
Exclusive OR — the bitwise operation whose self-inverse property lets you find a lone unpaired element in an array.

## ZK
Zero-Knowledge — a proof technique that lets one party prove a statement is true without revealing the underlying data.
