---
id: 725b647d-8ca7-4c1c-abbb-511045bbd1e0
type: flashcard
created: 2026-08-21
confidence: high
tiers:
  blockchain: 1
tags:
  - blockchain
  - cryptography
  - hash-functions
  - data-integrity
  - sha-256
---

# Cryptographic Hash Functions

A **cryptographic hash function** `H` maps an arbitrary-length input to a fixed-length output (the *digest*) such that the mapping is deterministic, fast to compute forward, and computationally infeasible to invert or to force collisions. It is the workhorse primitive of blockchain: block linking, addresses, commitments, Merkle trees, and proof-of-work all reduce to "hash this and check a property."

The security rests on three properties. Let `n` be the digest bit-length.

| Property | Informal statement | Best generic attack |
|---|---|---|
| **Preimage resistance** (one-wayness) | Given `h`, hard to find any `m` with `H(m)=h` | `O(2^n)` |
| **Second-preimage resistance** | Given `m1`, hard to find `m2 != m1` with `H(m2)=H(m1)` | `O(2^n)` |
| **Collision resistance** | Hard to find *any* pair `m1 != m2` with `H(m1)=H(m2)` | `O(2^{n/2})` (birthday) |

These properties are formally independent — no strict implication holds in general (in particular, collision resistance does **not** imply preimage resistance). But collision resistance has the weakest generic bound (`2^{n/2}` vs `2^n`), so it is the easiest to break and therefore dictates output size: SHA-256 gives ~128-bit collision security and is chosen where 128-bit *symmetric* security is the target.

## When to Use

**Problem signals that suggest a cryptographic hash:**
- You need a compact, fixed-size, tamper-evident *fingerprint* of variable-size data (file, transaction, block header).
- You need to **commit** to a value now and reveal it later, proving you did not change it (commit-reveal, sealed bids, RANDAO).
- You need **content addressing**: the identifier *is* the hash of the content (Git objects, IPFS CIDs, Merkle-tree nodes).
- You need to link records into a tamper-evident chain — each entry stores the hash of the previous (blockchains, Certificate Transparency logs, append-only ledgers).
- You need a puzzle that is cheap to verify but tunably expensive to solve (proof-of-work: find nonce so `H(header) < target`).
- You need to reduce a public key to a short, checksummed **address**.

**Prefer a plain cryptographic hash over alternatives when:**
- Over a **MAC / HMAC**: you need a *public*, keyless fingerprint anyone can verify. Use HMAC instead the moment authenticity depends on a *secret* (see Pitfalls — length extension).
- Over a **digital signature**: you only need integrity/identity of *content*, not proof of *who* produced it. Signatures are ~100–1000x more expensive and require key management; hashes do not prove authorship.
- Over a **non-cryptographic hash** (CRC32, MurmurHash, FNV): an adversary can influence the input. Non-crypto hashes optimize speed/distribution and are trivially collidable on purpose.
- Over a **password KDF** (bcrypt, scrypt, Argon2): the input has high entropy (a key, a random nonce, a 256-bit tx). A raw hash is *deliberately fast* and therefore wrong for low-entropy secrets.

**Do not use when:**
- Hashing passwords or other low-entropy secrets -> use **Argon2id / scrypt / bcrypt** (slow, salted, memory-hard). A single SHA-256 is brute-forceable at billions/sec on GPUs.
- You need authenticated integrity with a shared key -> use **HMAC** (or an AEAD like AES-GCM), never `H(secret ‖ message)`.
- You need short output *and* collision resistance from a legacy 128-bit digest -> **MD5 and SHA-1 are broken** for collision resistance; use SHA-256 or BLAKE2/BLAKE3.
- You need a fast in-memory hash table or checksum with no adversary -> a non-cryptographic hash is faster and sufficient.
- You need constant-time equality of digests in a security context -> compare with a constant-time comparator, not `==` (timing side channel), though this is a comparison issue, not the hash itself.

## Key Properties

- **Deterministic**: same input always yields the same digest; no randomness, no salt (unlike a KDF).
- **Fixed output size** independent of input length (SHA-256 -> 32 bytes, Keccak-256 -> 32 bytes).
- **Avalanche effect**: flipping one input bit flips ~50% of output bits; outputs of related inputs look statistically independent. This is a design goal, not a formal security property.
- **One-way**: forward is O(input size); inverting requires generic search.
- **Efficient**: hundreds of MB/s to GB/s in software; hardware-accelerated (SHA-NI).
- **Not a random oracle**: real hashes are only *modeled* as random oracles in proofs; concrete constructions have structure (e.g., Merkle–Damgård length extension) that can break that assumption.

## Common Pitfalls

> [!warning] Never build a MAC as `H(key ‖ msg)`
> Merkle–Damgård hashes (MD5, SHA-1, SHA-256/512) are length-extendable: given `H(secret ‖ msg)` and `len(secret)`, an attacker forges `H(secret ‖ msg ‖ pad ‖ ext)` without the secret. Use **HMAC**, or a length-extension-immune hash (SHA-3/Keccak, BLAKE2/3, SHA-512/256).

- **Length-extension attack (Merkle–Damgård):** SHA-256, SHA-512, SHA-1, MD5 leak enough state that, given `H(secret ‖ msg)` and `len(secret)`, an attacker computes `H(secret ‖ msg ‖ pad ‖ ext)` without knowing the secret. => Never build a MAC as `H(key ‖ data)`. Use **HMAC**, or a hash immune by design (SHA-3/Keccak, BLAKE2/3, or SHA-512/256).
- **Confusing collision vs preimage resistance:** SHA-1 and MD5 are shattered for *collisions* but preimages remain hard. A protocol only relying on second-preimage resistance may survive; one relying on collision resistance (e.g., certificate signing over attacker-chosen content) does not.
- **Birthday bound underestimation:** an `n`-bit digest gives only `n/2` bits of collision security. A 128-bit hash => ~2^64 work to collide — feasible for a funded adversary. Size the digest to the collision threat, not the preimage threat.
- **Non-canonical / ambiguous encoding:** hashing structured data without a canonical serialization lets two different logical messages hash equal or lets fields "slide." Always hash a fixed, unambiguous byte encoding; add domain separation / length-prefixing between concatenated fields.
- **Using a fast hash for passwords:** even salted SHA-256 is far too fast; salting stops rainbow tables but not GPU brute force.
- **Truncating carelessly:** truncating a digest is acceptable (SHA-512/256 is a standard) but halving output halves collision security; do it deliberately.

## Trade-offs

| Axis | Consideration |
|---|---|
| Digest size vs cost | Larger `n` -> stronger collision resistance but larger storage/bandwidth (matters at billions of hashes in a Merkle forest). |
| Speed vs abuse resistance | Fast is good for throughput (PoW verification, integrity) but *bad* for password/secret hashing where you want slowness. |
| Construction | Merkle–Damgård (SHA-2): mature, ubiquitous, but length-extendable. Sponge (SHA-3/Keccak): length-extension immune, arbitrary output (XOF), slower in software. BLAKE3: very fast, parallel/tree-based, SIMD-friendly. |
| Standardization vs performance | SHA-256 is the FIPS/interoperability default; BLAKE3 is faster but less universally deployed. |
| Ecosystem lock-in | Bitcoin uses double-SHA-256; Ethereum uses Keccak-256 (pre-standard SHA-3 padding). Mixing them up produces silently wrong addresses/hashes. |

## Time & Space Complexity

- **Compute:** `O(L)` in input length `L` (block-by-block compression).
- **Digest storage:** `O(1)` — fixed `n` bits regardless of input.
- **Attack (generic, no structural weakness):**
  - Preimage / second-preimage: `~2^n` hash evaluations.
  - Collision: `~2^{n/2}` via the birthday paradox; memory can be made `O(1)` with cycle-finding (Pollard's rho / van Oorschot–Wiener), so a collision is a work problem, not a storage problem.

## Implementation Notes

Rules of thumb, not algorithm internals:

```js
// 1) Content addressing: identifier = hash(bytes)
const id = sha256(canonicalBytes(obj));   // stable, unambiguous encoding first

// 2) Commit-reveal: hide a value, prove later.
//    Include a random nonce so low-entropy values aren't brute-forced.
const commitment = sha256(concat(valueBytes, nonce32));
// later: reveal (value, nonce); verifier recomputes and compares.

// 3) Chaining / tamper-evidence
block.prevHash = sha256(serialize(previousBlockHeader));

// 4) Proof-of-work: cheap to verify, tunably hard to find.
const ok = toBigInt(sha256(concat(header, nonce))) < target;

// 5) Authentication with a shared secret -> HMAC, NOT H(key ‖ msg)
const tag = hmacSha256(key, msg);          // avoids length extension

// 6) Domain separation when hashing multiple fields
const leaf     = sha256(concat([0x00], data));   // tag leaves and
const internal = sha256(concat([0x01], left, right)); // internal nodes differently
```

- **Canonicalize before hashing.** Fix field order, integer endianness, and length-prefix variable fields so the byte string is unique per logical message.
- **Domain-separate** independent uses of the same hash (leaf vs node, signature contexts) with distinct prefixes/tags to prevent cross-protocol collisions.
- **Constant-time compare** digests/tags in adversarial settings (`crypto.timingSafeEqual`), not `===`.
- **Never roll your own** compression function; call a vetted library (WebCrypto `crypto.subtle.digest`, Node `crypto`, `noble-hashes`).

## Variants

| Family | Examples | Notes |
|---|---|---|
| **SHA-2** (Merkle–Damgård) | SHA-256, SHA-512, SHA-512/256 | Default in Bitcoin, TLS, Git (migrating). Length-extendable except the truncated 512/256. |
| **SHA-3 / Keccak** (sponge) | SHA3-256, Keccak-256, SHAKE128/256 (XOF) | Length-extension immune. Ethereum uses **Keccak-256** (original padding), *not* NIST SHA3-256 — a common gotcha. |
| **BLAKE** | BLAKE2b/2s, BLAKE3 | Fast, secure, length-extension immune; BLAKE3 is tree-structured, parallel, and a XOF. |
| **Broken (do not use)** | MD5, SHA-1 | Collisions demonstrated (chosen-prefix). Fine only for non-adversarial checksums. |
| **Password KDFs (not general hashes)** | Argon2id, scrypt, bcrypt | Deliberately slow/memory-hard; for low-entropy secrets only. |
| **XOF (extendable output)** | SHAKE128/256, BLAKE3 | Arbitrary-length output; useful for deriving multiple keys / streams from one seed. |

## Resources

- FIPS 180-4 (Secure Hash Standard: SHA-1, SHA-2 family)
- FIPS 202 (SHA-3 / Keccak sponge, SHAKE XOFs)
- RFC 2104 (HMAC) and RFC 6234 (SHA + HMAC test vectors)
- RFC 6962 (Certificate Transparency: Merkle leaf/node domain separation, 0x00/0x01)
- Stevens et al., "The first collision for full SHA-1" (SHAttered, 2017); "Chosen-prefix collisions for SHA-1" (2020)
- BLAKE3 specification (O'Connor, Aumasson, Neves, Wilcox-O'Hearn)
- Katz & Lindell, *Introduction to Modern Cryptography*, ch. on hash functions and the random oracle model

## Related

- [[Merkle Trees]]
- [[Proof of Work]]
- [[HMAC]]
- [[Digital Signatures]]
- [[Birthday Paradox]]
- [[Blockchain Data Structure]]
- [[Key Derivation Functions]]
- [[Commitment Schemes]]
