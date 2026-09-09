---
id: symmetric-vs-asymmetric-encryption
type: flashcard
tags:
  - security
tiers:
  security: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Symmetric vs Asymmetric Encryption

Encryption transforms plaintext into ciphertext so only an authorized party can reverse it. **Symmetric** encryption uses *one shared secret key* for both encrypt and decrypt ([AES](_meta/glossary.md#aes)) — fast and used for bulk data, but it has a key-distribution problem: both parties must already share the secret over a secure channel. **Asymmetric** (public-key) encryption uses a *mathematically linked key pair* ([RSA](_meta/glossary.md#rsa), ECC): the public key encrypts and only the private key decrypts, which solves key distribution (publish the public key freely) and enables digital signatures — but it is orders of magnitude slower and can only encrypt small payloads. Real systems ([TLS](_meta/glossary.md#tls)) are **hybrid**: use asymmetric crypto once to agree on a fresh symmetric session key, then use symmetric crypto for all the actual traffic. The core principle: asymmetric solves *trust/distribution*, symmetric solves *bulk speed* — combine them.

> [!tip] Recognition
> Reach for this when the design mentions: "two parties who have never met need to communicate securely" (asymmetric to bootstrap), "encrypt gigabytes / a video stream fast" (symmetric), "how does HTTPS/TLS actually work" (hybrid), "prove *who* sent this" (asymmetric signatures), or "we shipped a hardcoded shared password to every client" (a symmetric key-distribution smell).

## When to Use

- **Symmetric (AES-256-[GCM](_meta/glossary.md#gcm)):** any time you need to encrypt a non-trivial amount of data and the two sides already share (or can derive) a key — session traffic after a handshake, disk/file encryption, database field encryption. Default choice for confidentiality of bulk data.
- **Asymmetric (RSA, ECC/ECDH, [Ed25519](_meta/glossary.md#eddsa)):** when parties *cannot* pre-share a secret — key exchange/agreement over an open network, encrypting a small secret (like a session key or an email) to a recipient's public key, and digital signatures / certificate chains.
- **Hybrid (the real-world default):** essentially all secure transport. Use asymmetric to authenticate and agree on a symmetric session key, then switch to symmetric. Applies to TLS, SSH, PGP/email, Signal.
- **Contrast vs. hashing:** if the goal is to *detect tampering* or *store passwords* — where you never need to recover the original — you want a **one-way hash**, not encryption. Encryption is reversible by design; hashing is not.
- **Contrast vs. "public-key cryptography":** this card is the *symmetric ↔ asymmetric* decision (which family to pick, and why hybrid wins). The `public-key-cryptography` card zooms into *how the asymmetric half works* (key-pair math, encryption vs. signing vs. key agreement). If the question is "shared key or key pair?" you're here; if it's "how does one key pair do encrypt/sign/exchange?" that's public-key crypto.

## Key Properties

| Dimension | Symmetric (AES) | Asymmetric (RSA/ECC) |
|---|---|---|
| Keys | one shared secret | public + private pair |
| Speed | very fast (HW-accelerated) | ~100–1000× slower |
| Payload size | any size | tiny (≤ key size; RSA-2048 ≈ 245 bytes) |
| Key distribution | hard — needs secure channel | easy — publish public key |
| Enables signatures | no | yes |
| Typical use | bulk data / sessions | key exchange, signatures, certs |

- **Symmetric:** confidentiality only (use an [AEAD](_meta/glossary.md#aead) mode like AES-GCM to also get integrity). Key length: AES-128/256. `n` parties needing pairwise secrets require `O(n²)` keys — the scaling reason key distribution is painful.
- **Asymmetric:** private key stays secret and never transmitted; public key is shared openly. Security rests on hard math problems (integer factorization for RSA, elliptic-curve discrete log for ECC). ECC gives equivalent security at much smaller keys than RSA (256-bit ECC ≈ 3072-bit RSA).

## Trade-offs

- **Symmetric buys speed, pays with distribution.** Great throughput, but "how do both sides get the same key without an eavesdropper seeing it?" is the whole problem — you either need a prior secure channel or an asymmetric handshake.
- **Asymmetric buys distribution + signatures, pays with speed and size.** You can hand out the public key on a billboard, but you can't stream data through it. So it's used only to protect small things (a session key) or to sign.
- **Hybrid resolves the tension:** asymmetric once (expensive, but only a few operations), symmetric thereafter (cheap, unlimited data). This is why nobody encrypts a whole HTTP response with RSA.
- **Trust anchor still required:** asymmetric fixes *distribution* but not *authenticity of the public key* — you still need certificates / a [PKI](_meta/glossary.md#pki) (or manual verification) to know a public key really belongs to who you think, otherwise you're exposed to a man-in-the-middle.

## Common Pitfalls

- **Confusing the three primitives (highest-value distinction):**
  - **Encryption** = confidentiality, **reversible** (symmetric *or* asymmetric).
  - **Hashing** = integrity/fingerprint, **one-way**, no key ([SHA-256](_meta/glossary.md#sha-256)). You can't "decrypt" a hash.
  - **Digital signature** = authenticity + integrity + non-repudiation. Made by encrypting/signing a *hash* with the **sender's private key**; verified with the sender's **public key**.
  - Note the direction flip: for *confidentiality* you encrypt with the **recipient's public** key; for a *signature* you sign with the **sender's private** key. Different keys, opposite parties.
- **Encrypting bulk data with RSA directly** — wrong and often impossible (payload exceeds the modulus). Always encrypt data symmetrically and only wrap the symmetric key asymmetrically.
- **Reusing a symmetric key/nonce** — reusing a [nonce](_meta/glossary.md#nonce) in AES-GCM catastrophically breaks confidentiality *and* integrity. Session keys should be fresh per session.
- **Assuming asymmetric = "more secure, always use it"** — it's slower, size-limited, and no more secure for confidentiality once you have a shared key; it's a bootstrap tool, not a bulk tool.
- **Thinking key exchange = encrypting the key.** Modern TLS 1.3 does not send an RSA-encrypted key; it uses ephemeral Diffie-Hellman (ECDHE) so both sides *derive* a shared secret. This gives forward secrecy — capturing traffic + later stealing the private key still can't decrypt past sessions.

## Implementation Notes

Reference, not for verbatim recall:
- **How TLS works (hybrid, TLS 1.3):** client and server run **ephemeral (EC)DH** to agree on a shared secret; the server proves identity by **signing** handshake data with its certificate's private key (which the client validates against a CA chain). From the DH secret both derive symmetric keys and switch to an **AEAD symmetric cipher** (e.g. AES-GCM or ChaCha20-Poly1305) for all application data. TLS 1.3 removed legacy RSA *key transport* precisely because it lacked forward secrecy.
- **Practical guidance:** never roll your own crypto; use vetted libraries (libsodium/`crypto_box`, Google Tink, or platform TLS). Prefer AEAD modes; prefer Ed25519/X25519 over raw RSA for new systems.

## Resources

- Cloudflare — What happens in a TLS handshake: https://www.cloudflare.com/learning/ssl/what-happens-in-a-tls-handshake/
- RFC 8446 — TLS 1.3 (key exchange & handshake): https://datatracker.ietf.org/doc/html/rfc8446
- NIST FIPS 197 — AES specification: https://csrc.nist.gov/pubs/fips/197/final
- Cloudflare — What is asymmetric / public-key encryption: https://www.cloudflare.com/learning/ssl/how-does-public-key-encryption-work/

## Related

- [[public-key-cryptography]]
- [[cryptographic-hash-functions]]
- [[digital-signatures]]
- [[tls-ssl]]
