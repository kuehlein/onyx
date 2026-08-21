---
id: 7f3a2c1e-9b4d-4e8f-a5c0-d2f6b8e3a7c9
type: flashcard
tags:
  - blockchain
  - cryptography
  - wallet
tiers:
  blockchain: 1
created: 2026-08-20
confidence: medium
---

# Public Key Cryptography and Address Derivation

A blockchain address is a collision-resistant hash digest of a public key, derived from a private key via a one-way elliptic curve scalar multiplication — the public key cannot be reversed to recover the private key, and the address cannot be reversed to recover the public key. This asymmetry is what makes self-sovereign ownership possible without a trusted third party.

## When to Use

**Problem signals that suggest this concept is directly relevant:**
- An interview question asks "how does a user prove ownership of funds without revealing a password?"
- A system design prompt asks you to design a wallet, a key management service (KMS), or an HD wallet derivation scheme
- A question asks "what is an Ethereum address?" or "why are addresses 20 bytes?"
- A question involves signature verification, transaction authorization, or on-chain identity
- A question asks about the security properties of blockchain accounts (e.g., "what happens if two users collide on the same address?")
- Any question about private key custody, seed phrases, or hardware wallets

**Prefer this concept (ECDSA + hashing) over alternatives when:**
- Over symmetric cryptography: asymmetric keys allow public verification of a signature without exposing the signing secret — essential when anyone on the network must verify a transaction without a shared secret
- Over simple hash-based identity: a public key lets you also prove knowledge of the preimage (private key) via a signature; a bare hash gives you an identifier but no authentication mechanism

**Do not use when:**
- Signing bulk data for storage integrity alone → use HMAC or plain SHA-256 (no need for asymmetric overhead)
- Anonymity is the primary goal → zero-knowledge proofs or stealth addresses extend this primitive; raw public-key addresses are pseudonymous, not anonymous

## Key Properties

**Elliptic Curve Discrete Logarithm Problem (ECDLP):**
Given `Q = k · G` (scalar multiplication of generator point `G` by private scalar `k`), recovering `k` from `Q` is computationally infeasible. This is the security foundation — not factoring (RSA) and not generic DLP (Diffie-Hellman over integers).

**Bitcoin and Ethereum both use secp256k1:**
- 256-bit private key `k` chosen uniformly at random from `[1, n-1]` where `n` is the curve order (~2²⁵⁶)
- Public key `Q = k · G` is an (x, y) point on the curve — 64 bytes uncompressed (with `04` prefix) or 33 bytes compressed (with `02`/`03` prefix indicating y parity)

**Address derivation is one-way and lossy:**
- **Ethereum:** `address = keccak256(publicKey[1:])[12:]` — drop the `04` prefix byte, hash the 64-byte key, take the last 20 bytes. The address discards 44 bytes of the public key; the public key cannot be recovered from the address alone (only from a transaction signature).
- **Bitcoin P2PKH:** `address = Base58Check(RIPEMD-160(SHA-256(publicKey)))` — double-hashing adds quantum resistance margin and reduces the digest to 20 bytes.

**Signature scheme (ECDSA):**
- Signing: given message hash `z` and private key `k`, produce `(r, s)` pair
- Verifying: given `(r, s)` and public key `Q`, anyone can confirm the signature is valid without knowing `k`
- Ethereum transactions include `(v, r, s)` — `v` is a recovery ID that allows deriving the signer's public key from the signature + message hash (used by `ecrecover`)

## Common Pitfalls

- **Confusing the key with the address.** The private key signs; the public key verifies; the address is a commitment to the public key used for routing funds. These are three distinct values with different exposure risk levels.
- **k-value reuse in ECDSA is catastrophic.** If the same nonce `k` is used to sign two different messages, the private key can be algebraically recovered. Sony's PS3 signing key was extracted this way. Ethereum uses deterministic nonce generation (RFC 6979) to prevent this.
- **Ethereum addresses are not checksummed by default.** EIP-55 defines a checksum via mixed-case hex encoding (`keccak256` of the lowercase address determines which letters are uppercased). Ignoring this leads to silent fund loss from typos.
- **Compressed vs. uncompressed keys produce different addresses.** Early Bitcoin clients used uncompressed keys; modern wallets use compressed. The same private key yields two different public keys (and thus two different Bitcoin addresses) depending on compression.
- **The address does not commit to the signing algorithm.** On Ethereum, a contract and an EOA (externally owned account) share the same 20-byte address space — distinguishing them requires a node call (`eth_getCode`).

## Trade-offs

| Property | secp256k1 (ECDSA) | Ed25519 (EdDSA) |
|---|---|---|
| Key size | 32-byte private, 33/65-byte public | 32-byte private, 32-byte public |
| Signature size | 64 bytes (+ 1 recovery byte on ETH) | 64 bytes |
| Deterministic signing | Via RFC 6979 (bolt-on) | Native |
| Batch verification | No | Yes — significant throughput gain |
| Quantum resistance | No (ECDLP broken by Shor's algorithm) | No (same class) |
| Ecosystem adoption | Bitcoin, Ethereum, most EVM chains | Solana, Cardano, Polkadot, Zcash (Sapling) |

Ethereum's choice of secp256k1 over the NIST curves (P-256) was deliberate: secp256k1's constants are visibly structured, reducing suspicion of a NIST backdoor.

## Implementation Notes

```js
// Conceptual derivation — use a audited library (noble-secp256k1, ethers.js) in production
import { keccak256 } from 'ethereum-cryptography/keccak';
import { secp256k1 } from '@noble/secp256k1';

function deriveEthereumAddress(privateKeyHex) {
  const privateKey = hexToBytes(privateKeyHex); // 32 bytes

  // Scalar multiplication: Q = k · G
  // Returns 65-byte uncompressed public key: [0x04, x (32 bytes), y (32 bytes)]
  const publicKeyUncompressed = secp256k1.getPublicKey(privateKey, false);

  // Drop the 0x04 prefix byte — hash the raw 64-byte (x, y) point
  const publicKeyBytes = publicKeyUncompressed.slice(1); // 64 bytes

  // keccak256 produces a 32-byte digest; take the last 20 bytes
  const digest = keccak256(publicKeyBytes);
  const address = digest.slice(12); // 20 bytes

  return '0x' + bytesToHex(address);
}

// ecrecover: derive public key FROM a signature (used in Solidity for on-chain auth)
// Given (msgHash, v, r, s) → recovers the signing address
// This is why Ethereum can skip storing public keys — they're recovered on demand
```

**HD Wallet derivation (BIP-32 / BIP-44):** A single 128–256-bit entropy seed (encoded as a 12/24-word BIP-39 mnemonic) is stretched via PBKDF2 into a 512-bit master seed, then a tree of child keys is derived via HMAC-SHA512 at each node. Path `m/44'/60'/0'/0/0` is the first Ethereum address. Child key derivation is one-way — a child key cannot be used to recover the parent.

## Resources

- [SEC 2: Recommended Elliptic Curve Domain Parameters](https://www.secg.org/sec2-v2.pdf) — defines secp256k1
- [Ethereum Yellow Paper, Appendix F — Signing Transactions](https://ethereum.github.io/yellowpaper/paper.pdf)
- [BIP-32: Hierarchical Deterministic Wallets](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)
- [BIP-39: Mnemonic code for generating deterministic keys](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
- [EIP-55: Mixed-case checksum address encoding](https://eips.ethereum.org/EIPS/eip-55)
- [noble-secp256k1 — audited JS implementation](https://github.com/paulmillr/noble-secp256k1)

## Related

- [[elliptic-curve-digital-signature-algorithm]]
- [[keccak256-and-hash-functions]]
- [[hd-wallet-bip32-bip44]]
- [[merkle-tree]]
- [[zero-knowledge-proofs]]
