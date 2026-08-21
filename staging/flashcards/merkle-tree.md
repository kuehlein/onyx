---
id: 596f0cea-b598-46c6-bbfd-9e0de0ce0008
type: flashcard
created: 2026-08-21
confidence: medium
tiers:
  blockchain: 1
tags:
  - blockchain
  - merkle-tree
  - cryptography
  - hashing
  - data-structures
  - authenticated-data-structures
  - inclusion-proof
---

# Merkle Tree

A **Merkle tree** (hash tree) is a binary tree in which every leaf is the cryptographic hash of a data block and every internal node is the hash of the concatenation of its two children. The single root hash commits to the entire dataset: any change to any leaf changes the root. It lets a verifier confirm that a specific element belongs to a large set using only a small **inclusion proof** (an *authentication path*), without downloading the whole set.

## When to Use

**Problem signals that suggest a Merkle tree:**
- You must prove a single item is part of a large, immutable dataset while transferring only `O(log n)` data (e.g., "is this transaction in this block?").
- A lightweight client trusts one small commitment (the root) that was signed / consensus-agreed, and wants to verify server-provided data against it.
- You need to detect *which* block changed between two large datasets, not just *whether* something changed (diffing / anti-entropy).
- You want tamper-evidence: any mutation anywhere must be detectable from a fixed-size digest.
- Content-addressed storage where large objects are split into chunks and addressed by a root hash (integrity of streamed/partial downloads).

**Prefer a Merkle tree over alternatives when:**
- Over a **flat hash of the whole dataset** (`hash(concat(all blocks))`): a flat hash proves *the whole set* is intact but forces you to have all data to verify any part; Merkle proves *individual membership* with `O(log n)` proof and supports partial verification.
- Over a **hash list / hash chain**: a list gives `O(n)` proof size and `O(n)` re-verification; Merkle gives `O(log n)` proofs and only `O(log n)` recomputation on an update.
- Over a **HMAC / MAC over the set**: a MAC needs a shared secret and does not localize *where* corruption occurred; Merkle needs no secret and pinpoints the differing subtree.
- Over a **plain balanced BST / hash table**: those give fast lookup but no compact cryptographic membership proof against an untrusted server.

**Do not use when:**
- The dataset is tiny or you always have all of it -> a single `hash(all bytes)` is simpler and cheaper.
- You need to prove **non-membership** or ordered-range queries efficiently -> use a **sparse Merkle tree** or **Merkle–Patricia / Merkle B-tree**, not a plain Merkle tree.
- You need frequent random inserts/deletes with cheap rebalancing -> plain Merkle trees are order-sensitive and rebuild-heavy; use a Patricia/AVL-Merkle hybrid.
- Confidentiality (not integrity) is the goal -> Merkle trees provide integrity/authentication, not encryption.
- A single writer holds all data and there is no untrusted intermediary -> the proof machinery is unnecessary overhead.

## Key Properties

| Property | Description |
|---|---|
| Root binds everything | The root hash is a succinct commitment to every leaf and their order. |
| Inclusion proof size | `O(log n)` sibling hashes (the authentication path). |
| Collision resistance | Security reduces to the collision resistance of the underlying hash (e.g., SHA-256). |
| Order-sensitive | Leaf order is part of the commitment; permuting leaves changes the root. |
| Verifier is stateless | Given root + leaf + path, verification needs no other state and no secret. |
| Update locality | Changing one leaf recomputes only the `O(log n)` nodes on its path to the root. |

## Common Pitfalls

- **Second-preimage / node-type confusion.** If leaf hashes and internal hashes use the same domain, an attacker can present an internal node as if it were a leaf. **Fix:** domain-separate — prefix leaves with `0x00` and internal nodes with `0x01` before hashing (as Certificate Transparency, RFC 6962, does).
- **Odd-node duplication attack (CVE-2012-2459).** Bitcoin duplicates the last hash when a level has an odd count. Duplicating an existing subtree can yield the *same root* for two different transaction lists, letting an attacker mutate a block into an invalid form with an identical Merkle root (a malleability/DoS vector). Mitigate by rejecting any block whose transaction list contains duplicate txids (equivalently, whose Merkle computation had to duplicate a node) — this is Bitcoin Core's fix.
- **Forgetting to bind element order** when order matters (transactions) — or *not* sorting when a canonical order is required for reproducible roots across nodes.
- **Assuming inclusion proofs prove uniqueness.** A plain inclusion proof shows a leaf exists; it does not prove the leaf is *unique* or that the set excludes something (no non-membership).
- **Using a weak/truncated hash.** Truncating the digest lowers collision resistance and can make forged siblings feasible.
- **Trusting the root implicitly.** A Merkle proof is only as trustworthy as the root's provenance (signature, blockchain consensus). Verifying a proof against an attacker-supplied root proves nothing.

## Trade-offs

- **Proof size vs. tree fanout.** Binary trees give simple `log₂ n` proofs; higher-arity trees reduce depth (fewer hash rounds) but each proof step carries `(k−1)` sibling hashes, so total proof bytes can grow.
- **Recompute on update vs. store internal nodes.** Storing all internal nodes speeds proofs/updates but costs `~2n` storage; recomputing from leaves saves space but costs CPU per query.
- **Immutability vs. mutability.** Excellent for append-mostly / immutable data; poor for high-churn mutable data unless you adopt a Patricia/sparse variant.
- **Integrity only.** Provides tamper-evidence and membership, but no confidentiality and (plain form) no non-membership.

## Time & Space Complexity

| Operation | Cost |
|---|---|
| Build tree | `O(n)` hashes, `O(n)` space |
| Inclusion proof size | `O(log n)` |
| Verify inclusion proof | `O(log n)` hashes |
| Update one leaf → new root | `O(log n)` |
| Storing full tree | `O(n)` (leaves + internal ≈ `2n`) |

## Implementation Notes

```javascript
// Domain-separated hashing (guards against leaf/internal confusion).
// Prefix bytes must be actual bytes, so concatBytes receives Uint8Arrays.
const LEAF = Uint8Array.of(0x00);
const NODE = Uint8Array.of(0x01);
const hashLeaf = (data) => sha256(concatBytes(LEAF, data));
const hashNode = (l, r) => sha256(concatBytes(NODE, l, r));

// Compare two digests by value (Uint8Array === is reference equality, so it
// would always be false for distinct arrays). Use a constant-time compare in
// production to avoid timing side channels.
const bytesEqual = (a, b) => {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
};

// Build root from ordered leaf-data blocks.
const merkleRoot = (blocks) => {
  // RFC 6962 empty-tree convention: MTH({}) = SHA-256() over the empty string
  // (NOT hashLeaf("") — that would be SHA-256(0x00 || "")).
  if (blocks.length === 0) return sha256(new Uint8Array());
  let level = blocks.map(hashLeaf);
  while (level.length > 1) {
    const next = [];
    for (let i = 0; i < level.length; i += 2) {
      const left = level[i];
      const right = i + 1 < level.length ? level[i + 1] : left; // odd: duplicate (see pitfall)
      next.push(hashNode(left, right));
    }
    level = next;
  }
  return level[0];
};

// Verify an inclusion proof: proof = [{ hash, isRight }, ...] bottom-up.
const verifyProof = (leafData, proof, expectedRoot) => {
  let acc = hashLeaf(leafData);
  for (const { hash, isRight } of proof) {
    acc = isRight ? hashNode(acc, hash) : hashNode(hash, acc);
  }
  return bytesEqual(acc, expectedRoot);
};
```

Key detail: the proof must carry each sibling's **side** (left/right) so concatenation order matches how the root was built; getting the order wrong silently produces a wrong root.

## Variants

| Variant | Purpose |
|---|---|
| **Binary Merkle tree** | Classic membership proofs (Bitcoin block tx commitment). |
| **Merkle–Patricia trie** | Key→value with efficient inclusion *and* non-membership proofs (Ethereum state/storage/tx tries). |
| **Sparse Merkle tree** | Fixed key space; proves presence and absence via default (empty) subtree hashes. |
| **Merkle Mountain Range (MMR)** | Append-only logs with cheap appends and consistency proofs (e.g., Grin, Utreexo). |
| **Verkle tree** | Replaces sibling hashes with vector commitments → much smaller proofs (Ethereum roadmap). |
| **RFC 6962 (CT) tree** | Append-only log with inclusion *and* consistency proofs; domain-separated leaves/nodes. |

## Resources

- RFC 6962 — Certificate Transparency (defines leaf/node domain separation, inclusion + consistency proofs)
- Ralph Merkle, "A Digital Signature Based on a Conventional Encryption Function" (CRYPTO '87) — original construction
- Bitcoin developer reference — Merkle trees & block headers; CVE-2012-2459 (duplicate-tx malleability)
- Ethereum Yellow Paper — Merkle–Patricia trie specification
- NeetCode / algorithm references — hashing and tree fundamentals

## Related

- [[Cryptographic Hash Function]]
- [[SHA-256]]
- [[Merkle-Patricia Trie]]
- [[Bloom Filter]]
- [[Blockchain]]
- [[Simplified Payment Verification (SPV)]]
- [[Certificate Transparency]]
- [[Verkle Tree]]
