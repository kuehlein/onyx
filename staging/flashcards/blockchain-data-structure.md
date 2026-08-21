---
id: 7f3a2d1e-9b4c-4e8f-a5d6-3c2b1a0e7f9d
type: flashcard
tags:
  - blockchain
  - merkle-tree
  - cryptography
  - distributed-systems
tiers:
  blockchain: 1
created: 2026-08-20
confidence: medium
---

# Blockchain Data Structure

A blockchain is a cryptographically linked list of blocks where each block contains a cryptographic hash of its predecessor, making retroactive tampering computationally infeasible — altering any block invalidates every subsequent block's hash, requiring proof-of-work or stake re-computation the attacker cannot outpace the honest chain.

## When to Use

**Problem signals that suggest blockchain data structure knowledge is required:**
- Interview asks you to design a tamper-evident, append-only ledger
- Question involves distributed consensus with no trusted coordinator ("trustless")
- Problem involves auditable history of state transitions across mutually distrusting parties
- Question mentions "finality", "fork choice", or "chain reorganization"
- System design prompt asks for a decentralized payment or settlement layer
- Question uses keywords: immutability, provenance, double-spend, censorship resistance

**Prefer blockchain over alternatives when:**
- Over a traditional append-only log (e.g., Kafka): you need the history to be verifiable by any participant without trusting the log host
- Over a Merkle DAG alone: you need a canonical total ordering of events enforced by cumulative work or stake
- Over a distributed database with MVCC: you need Byzantine fault tolerance, not just crash fault tolerance — you do not trust all writers

**Do not use when:**
- All writers are trusted and performance matters → use a replicated database (Postgres + WAL, CockroachDB)
- You need mutable records → use a distributed key-value store; blockchains are append-only by design
- Throughput requirements exceed ~thousands of TPS and finality latency is critical → consider L2 rollups or permissioned chains (Hyperledger Fabric), not a public L1

## Key Properties

**Block anatomy (Bitcoin-style):**
- `previousHash`: SHA-256(SHA-256(previous block header)) — the cryptographic link
- `merkleRoot`: root of a Merkle tree over all transactions in this block; lets a light client verify one transaction with O(log n) hashes instead of downloading all transactions
- `nonce`: the value miners iterate to satisfy the proof-of-work target (`hash(header) < target`)
- `timestamp`, `version`, `bits` (difficulty target): consensus metadata

**Chain integrity invariant:**
Every block header commits to its entire ancestry. A hash is a fixed-size digest produced by a one-way function — collision resistance means no attacker can produce two distinct inputs with the same digest. Therefore `previousHash` is an unforgeable pointer; changing any ancestor changes all descendant hashes, breaking the chain.

**Ethereum extensions:**
- Block header additionally contains `stateRoot`, `transactionsRoot`, and `receiptsRoot` — all Merkle Patricia Trie (MPT) roots. This lets a client verify world-state membership proofs (EIP-1186) without syncing the full chain.
- Post-Merge: PoW nonce replaced by a BLS aggregate signature from the validator committee (`randaoReveal`, `parentBeaconBlockRoot`).

## Time & Space Complexity

| Operation | Time | Notes |
|---|---|---|
| Append block | O(n) | n = transactions; must build Merkle tree |
| Verify chain tip integrity | O(1) | One hash comparison against known tip |
| Verify full chain | O(h) | h = chain height; one hash per block |
| Merkle inclusion proof | O(log n) | Sibling hashes from leaf to root |
| Reorg to depth d | O(d · n) | Must re-validate d blocks |

Space: O(h · n) for full node storing all blocks and transactions. Bitcoin's UTXO set is ~10 GB (2025); Ethereum's full state is ~1+ TB with history.

## Common Pitfalls

**Confusing block hash with transaction hash.** A block hash is the digest of the block *header* only, not the transactions. Transactions are committed via the Merkle root in the header — they are not directly hashed into the block hash.

**Assuming longest chain = canonical chain.** Bitcoin uses "heaviest chain" (most cumulative proof-of-work), not strictly the longest by block count. An attacker with 51% hash power can produce a shorter chain with more work if they mine faster.

**Merkle tree second-preimage attack.** In a naive binary Merkle tree, an internal node and a leaf node of the same digest can be confused if the tree is not depth-prefixed. Bitcoin prevents this by different hash functions for leaves vs. internal nodes. Do not implement a Merkle tree without this distinction.

**Finality is probabilistic on PoW chains.** Six confirmations on Bitcoin gives ~99.9% practical finality, but it is never absolute. Ethereum PoS has economic finality after two justified checkpoints (~12.8 min) — a materially different guarantee; know which you are discussing.

**Hash pointer ≠ content-addressed storage.** A `previousHash` is a commitment to the exact bytes of the prior block header, not a fetch key (unlike IPFS CIDs). The chain does not self-host retrieval; peers gossip blocks separately.

## Trade-offs

| Property | Public PoW (Bitcoin) | Public PoS (Ethereum) | Permissioned (Fabric) |
|---|---|---|---|
| Throughput | ~7 TPS | ~15–100 TPS (L1) | 1 000s TPS |
| Finality latency | ~60 min (6 conf) | ~13 min | ~1 s |
| Trust model | Trustless (51% assumption) | Trustless (1/3 Byzantine) | Trusted consortium |
| Storage growth | Linear, prunable (UTXO) | Linear + state growth | Linear |
| Censorship resistance | High | High | Low |

## Implementation Notes

Minimal block chain in JS illustrating the cryptographic linking principle:

```js
const crypto = require('crypto');

function sha256(data) {
  return crypto.createHash('sha256').update(data).digest('hex');
}

class Block {
  constructor(index, transactions, previousHash) {
    this.index = index;
    this.timestamp = Date.now();
    this.transactions = transactions;
    this.previousHash = previousHash;       // cryptographic link to parent
    this.nonce = 0;
    this.hash = this.mine(4);              // difficulty: 4 leading zeros
  }

  headerBytes() {
    // Commit to all consensus-relevant fields; tx list is committed via a
    // real implementation's Merkle root — simplified here as JSON digest
    return JSON.stringify({
      index: this.index,
      timestamp: this.timestamp,
      txHash: sha256(JSON.stringify(this.transactions)),
      previousHash: this.previousHash,
      nonce: this.nonce,
    });
  }

  mine(difficulty) {
    const target = '0'.repeat(difficulty);
    while (true) {
      const h = sha256(this.headerBytes());
      if (h.startsWith(target)) return h;
      this.nonce++;                        // iterate nonce until target met
    }
  }
}

function isChainValid(chain) {
  for (let i = 1; i < chain.length; i++) {
    const cur = chain[i];
    const prev = chain[i - 1];
    // Re-derive hash from raw fields — any tampering changes the digest
    if (cur.hash !== sha256(cur.headerBytes())) return false;
    if (cur.previousHash !== prev.hash) return false;   // link broken
  }
  return true;
}
```

Key observations:
- `previousHash` is computed from the *prior block's content*, not stored separately — this is the tamper-evidence mechanism
- `nonce` iteration is the proof-of-work; in production Bitcoin the nonce field saturates and miners also vary `extraNonce` in the coinbase transaction
- A real implementation replaces `sha256(JSON.stringify(transactions))` with a Merkle root, enabling O(log n) inclusion proofs

## Variants

**Merkle DAG (IPLD / IPFS):** Replaces the linear chain with a directed acyclic graph of content-addressed blocks. Used in Filecoin and IPFS. Allows branching history; no total order without an additional consensus layer.

**Ethereum's Merkle Patricia Trie:** A radix trie where every node is content-addressed. The state root in each block header is the root of this trie over all account balances and contract storage. Enables stateless client proofs (Verkle tries replace this in Ethereum's roadmap).

**UTXO vs Account model:**
- Bitcoin: unspent transaction outputs; validity requires no double-spend, checked against the UTXO set
- Ethereum: account balances and nonces; validity requires nonce monotonicity and sufficient balance

**Rollup blocks (L2):** L2 sequencers post compressed transaction data or ZK-validity proofs to L1 blocks. The L1 block's data availability guarantees the L2 chain's integrity even if the L2 operator disappears.

## Resources

- Bitcoin Whitepaper: https://bitcoin.org/bitcoin.pdf (sections 2–4 cover the chain structure and Merkle tree)
- Ethereum Yellow Paper: https://ethereum.github.io/yellowpaper/paper.pdf (block header spec, MPT)
- *Mastering Bitcoin* (Antonopoulos) — Chapter 9: The Blockchain
- *Mastering Ethereum* (Antonopoulos & Wood) — Chapter 9: Smart Contracts and the EVM
- Ethereum EIP-1186 (eth_getProof / state proofs): https://eips.ethereum.org/EIPS/eip-1186

## Related

- [[merkle-tree]]
- [[proof-of-work]]
- [[consensus-mechanism]]
- [[cryptography]]
- [[distributed-systems]]
