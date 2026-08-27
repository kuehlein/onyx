---
id: 9c92a57b-21d6-42f8-952f-db2d22c3e720
type: flashcard
created: 2026-08-21
confidence: medium
tiers:
  blockchain: 1
tags:
  - blockchain
  - cryptography
  - digital-signatures
  - public-key-crypto
  - authentication
  - ecdsa
  - eddsa
---

# Digital Signatures

A digital signature is a value produced from a message and a **private key** that anyone holding the corresponding **public key** can verify. It binds a message to the holder of a secret without revealing that secret.

**Core principle:** signing uses the private key; verifying uses the public key. This asymmetry gives three properties at once:
- **Authentication** — only the private-key holder could have produced it.
- **Integrity** — any change to the message invalidates the signature (you actually sign `hash(message)`).
- **Non-repudiation** — the signer cannot plausibly deny signing, since no one else has the key.

Contrast with a **MAC** (e.g. HMAC): a MAC also proves integrity + authenticity, but uses a *shared* secret, so it gives **no non-repudiation** — either party could have produced it. Signatures split the secret from the verifier.

> [!warning] Reusing or predicting the ECDSA nonce `k` leaks the private key
> Two signatures with the same `k` expose the key via simple algebra (the Sony PS3 and Bitcoin thefts). Use RFC 6979 deterministic nonces or EdDSA.

## When to Use

**Problem signals that suggest digital signatures:**
- Verifier and signer do **not** share a secret; the verifier is untrusted or is the whole public (blockchain nodes, software update clients).
- You need **non-repudiation** — a third party must later prove *who* authorized something (transaction authorization, audit trails, legal e-signatures).
- One party authorizes; **many independent parties** must verify the same artifact (signed firmware, TLS certificate chains, JWTs with `RS256`/`ES256`).
- The authorization must be **transferable / publicly checkable** without contacting the signer.

**Prefer digital signatures over alternatives when:**
- Over **MAC / HMAC**: verifiers must not be able to forge, and you need non-repudiation. HMAC verifiers *can* forge because they hold the same key.
- Over **plain hash / checksum**: a hash proves integrity only if the hash itself is trusted; a signature authenticates the hash's origin so an attacker can't recompute it.
- Over **encryption**: signing proves *origin*, not *confidentiality*. Encryption hides content; it does not by itself bind authorship (encrypt-then-MAC or sign-then-encrypt if you need both).

**Do not use when:**
- Both endpoints already **share a symmetric key** and non-repudiation is not needed -> use **HMAC** (far faster, no PKI).
- You need to **hide the message** -> use encryption (signatures usually leave the message in the clear).
- Data never leaves a trusted boundary and integrity is the only concern -> a plain hash or CRC is cheaper.
- You want deniability (e.g. off-the-record messaging) -> non-repudiation is a *bug* here; use a MAC / deniable scheme.

## Key Properties

| Property | Meaning |
|---|---|
| **EUF-CMA** | "Existential Unforgeability under Chosen-Message Attack" — the standard security goal: even after seeing many signatures on chosen messages, an attacker cannot forge a signature on any *new* message. |
| Public verifiability | Anyone with the public key can verify; no interaction with the signer. |
| Sign the digest | You sign `H(m)`, not `m`. Enables signing arbitrary-length messages and fixes signature size. |
| Deterministic vs randomized | ECDSA needs fresh randomness per signature; EdDSA and RFC 6979 ECDSA derive the nonce deterministically from the key + message. |
| Malleability | Some schemes (textbook ECDSA) allow a *different* valid signature for the same message/key — dangerous when the signature is used as an ID. |

## Common Pitfalls

- **Reusing / predictable ECDSA nonce `k`.** Two signatures with the same `k` leak the private key via simple algebra. The 2010 Sony PS3 (ECDSA) break and Bitcoin thefts came from this. Fix: RFC 6979 deterministic nonces or EdDSA.
- **Not hashing, or using a broken hash.** MD5/SHA-1 collisions let an attacker get a signature on a benign document that is also valid for a malicious one (Flame malware forged a Microsoft cert via an MD5 chosen-prefix collision). Sign a collision-resistant digest.
- **Signature malleability.** ECDSA `(r, s)` and `(r, -s mod n)` are both valid. Bitcoin's original txid used the signature, so malleability changed txids (fixed by the low-`s` rule (BIP-146) and SegWit (BIP-141)). Enforce canonical/low-`s` form.
- **Verifying the signature but not *what* it covers.** A valid signature over the wrong scope is worthless: confirm the message, key, chain-of-trust, expiry, and that the public key belongs to the expected identity.
- **Trusting an unauthenticated public key.** A signature is only as trustworthy as your binding of key -> identity (PKI / cert chain / on-chain address). Without that, an attacker just presents their own key.
- **Ignoring domain separation / replay.** The same signed bytes may be valid in another context (different chain, different contract). Include chain ID, nonce, and context tags in the signed payload (cf. EIP-155, EIP-712).

## Trade-offs

| Axis | Notes |
|---|---|
| Speed | Verification is often the hot path (blockchain nodes verify every tx). EdDSA (Ed25519) is fast to sign *and* verify; RSA verify is fast but sign is slow; RSA keys are large. |
| Signature / key size | ECDSA & EdDSA: ~64-byte sigs, ~32-byte keys. RSA-2048: ~256-byte sigs. Size matters on-chain (block space) and in constrained devices. |
| Determinism | Deterministic (EdDSA, RFC 6979) removes the catastrophic RNG-failure mode but can leak via fault attacks; add hedging in hostile hardware. |
| Recovery | ECDSA (secp256k1) supports **public-key recovery** from the signature (+ recovery id `v`) — Ethereum derives the sender address from the signature, so no separate pubkey is stored. EdDSA does not natively support recovery. |
| Quantum | RSA/ECDSA/EdDSA all fall to Shor's algorithm on a large quantum computer. Post-quantum options (ML-DSA/Dilithium, SPHINCS+) exist but have far larger signatures. |
| Aggregation | BLS signatures can be **aggregated** — many signatures over the same or different messages compress to one, and support threshold signing. Used by Ethereum's consensus layer for validator attestations. Trade-off: pairing checks are slower per-signature than Ed25519. |

## Implementation Notes

Sign the digest, never raw bytes; verify identity binding, not just cryptographic validity.

```js
// Node's built-in crypto, EdDSA (Ed25519) — recommended default.
import { generateKeyPairSync, sign, verify } from "node:crypto";

const { publicKey, privateKey } = generateKeyPairSync("ed25519");

const msg = Buffer.from("transfer 5 to alice; nonce=42; chainId=1");

// Ed25519 hashes internally; pass null as the digest algorithm.
const signature = sign(null, msg, privateKey); // 64 bytes

const ok = verify(null, msg, publicKey, signature); // boolean

// SECURITY: a true `ok` only means "this key signed these bytes".
// You MUST additionally check:
//   1. publicKey maps to the expected identity/address (PKI or on-chain).
//   2. the message scope (nonce, chainId, expiry) is what you expect.
//   3. for ECDSA specifically: reject non-canonical / high-s signatures.
```

Why sign a hash (mental model):

```js
// digest is fixed-size and collision-resistant, so:
//   - arbitrary-length messages -> constant-size signing input
//   - flipping any message bit -> different digest -> signature fails
// Requirement: H must be collision-resistant, else two messages share a
// signature. Never sign with MD5/SHA-1.
```

## Variants

| Scheme | Notes |
|---|---|
| **RSA (PKCS#1 v1.5 / PSS)** | Oldest, ubiquitous in TLS/PKI. Prefer **PSS** (randomized, provably secure) over v1.5. Large keys/sigs, slow signing. |
| **ECDSA (secp256r1 / secp256k1)** | Compact. secp256k1 is Bitcoin/Ethereum's curve; supports pubkey recovery. Needs careful nonce handling (RFC 6979). |
| **EdDSA (Ed25519 / Ed448)** | Modern default: deterministic, fast, misuse-resistant, no per-signature RNG. Used by SSH, Signal, Solana. |
| **Schnorr (BIP-340)** | Linear structure enables key/signature aggregation (MuSig) and simpler proofs. Bitcoin Taproot uses Schnorr over secp256k1; non-malleable. |
| **BLS** | Aggregatable + threshold-friendly via pairings. Ethereum consensus, drand. Slower verify. |
| **Threshold / multisig (FROST, GG20)** | Split the private key among *n* parties; *t* must cooperate to sign. No single key ever exists in one place. Used in custody/MPC wallets. |
| **Post-quantum (ML-DSA/Dilithium, SPHINCS+, Falcon)** | Resist quantum attacks; much larger signatures. Being standardized (FIPS 204/205). |

## Resources

- FIPS 186-5 — Digital Signature Standard (DSS): RSA, ECDSA, EdDSA
- RFC 8032 — EdDSA (Ed25519 / Ed448)
- RFC 6979 — Deterministic ECDSA nonce generation
- BIP-340 — Schnorr signatures for Bitcoin
- FIPS 204 (ML-DSA/Dilithium) & FIPS 205 (SLH-DSA/SPHINCS+) — post-quantum
- Boneh & Shoup, *A Graduate Course in Applied Cryptography*, ch. on signatures

## Related

- [[Hash Functions]]
- [[Public Key Cryptography]]
- [[HMAC]]
- [[Merkle Trees]]
- [[Elliptic Curve Cryptography]]
- [[Zero-Knowledge Proofs]]
- [[Public Key Infrastructure]]
- [[BLS Signatures]]
