---
id: password-storage
type: flashcard
tags:
  - security
tiers:
  security: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Password Storage

Never store passwords as plaintext or under a fast general-purpose hash ([SHA-256](_meta/glossary.md#sha-256), MD5). Instead store the output of a **slow, salted password-hashing function** — argon2id (preferred in 2026), scrypt, or bcrypt. Two principles do the work: a **per-user random [salt](_meta/glossary.md#salt)** (stored alongside the hash) makes precomputed rainbow-table attacks useless and ensures two users with the same password get different hashes; a **tunable work factor** (memory + iterations) keeps each guess expensive so the function can be re-tuned upward as hardware improves. The goal is not secrecy of the algorithm but making offline brute-force of a leaked hash economically infeasible. This is the mitigation for OWASP's "Cryptographic Failures" category.

> [!tip] Recognition
> Reach for this whenever you are **storing a credential a user re-enters to [authenticate](_meta/glossary.md#authentication)** (login password, PIN). Signals: "how do we store passwords," a database column named `password`/`password_hash`, a data breach where "the passwords were exposed," or a code review showing `sha256(password)` / plaintext / reversible encryption. If the secret must be *verified* but never *retrieved*, use a password hash — not encryption, not a fast hash.

## When to Use

**Use a slow salted password hash (argon2id/scrypt/bcrypt) when:**
- You store a secret used to authenticate a human — password, passphrase, PIN
- You only ever need to *verify* the secret (compare on login), never recover the original

**Do NOT reach for these when:**
- You need the value back later (session token, API key you must show, encrypting user data) → that is encryption or a random-token scheme, not password hashing
- You need a fast digest for integrity/dedup/[HMAC](_meta/glossary.md#hmac)/content-addressing → use a general cryptographic hash (SHA-256); see contrast below
- You are hashing a high-entropy random secret (e.g. a 256-bit API token) → a single fast hash is acceptable because brute-force is already infeasible; slowness buys nothing

> [!important] Contrast vs. general cryptographic hash functions
> A cryptographic hash (SHA-256) is engineered to be **fast** — that is a feature for integrity checks and signatures, and exactly why it is **wrong for passwords**: an attacker computes billions of guesses/sec against a leaked hash. A password hash is **deliberately slow and memory-hard** and takes a **salt** (and cost parameters) as input. Same word "hash," opposite performance goal. Rule: fast hash = verify *data*; slow salted hash = verify *human secrets*.

## Key Properties

**Per-user random salt (16+ bytes, from a CSPRNG):**
- Defeats rainbow tables (precomputed hash→password lookups) — the attacker cannot precompute against an unknown salt
- Makes identical passwords produce different hashes, so a breach does not reveal which users share a password
- Not secret: stored in the clear alongside the hash (modern PHC-string formats embed salt + params in the output)

**Tunable work factor:**
- The cost (argon2/scrypt memory + iterations, bcrypt cost `c` = 2^c rounds) is a stored parameter, so you can raise it over time and rehash-on-login without breaking old hashes
- Memory-hardness (argon2id, scrypt) specifically resists GPU/ASIC cracking, which cheaply parallelizes CPU-only work

**Pepper (optional, defense in depth):**
- A single site-wide secret mixed in (e.g. HMAC the password before hashing, or configure the [KDF](_meta/glossary.md#kdf)'s secret/"associated data") that is stored **outside the database** — in a secrets manager/HSM/env config
- Protects against a DB-only leak (attacker has hashes+salts but not the pepper); it is *additive* to salting, never a replacement

## Trade-offs

| Algorithm | 2026 status | Resists GPU/ASIC? | Notes |
|---|---|---|---|
| **argon2id** | Preferred for new systems | Yes (memory-hard) | OWASP min: 19 MiB, 2 iterations, parallelism 1. Hybrid variant of Argon2, winner of the Password Hashing Competition (2015) |
| **scrypt** | Good if argon2 unavailable | Yes (memory-hard) | OWASP min: N=2^17, r=8, p=1 |
| **bcrypt** | Legacy / when argon2+scrypt unavailable | Partial (CPU cost only) | OWASP min work factor ≥ 10; **truncates input at 72 bytes** |
| [PBKDF2](_meta/glossary.md#pbkdf2) | Only for FIPS-140 compliance | No (CPU only, GPU-friendly) | Needs very high iteration counts (OWASP: ≥600k with HMAC-SHA-256); weakest of the four |
| SHA-256 / MD5 / plaintext | **Never for passwords** | No | Fast/no salt/no work factor = trivially cracked offline |

- **Higher work factor = stronger but slower logins.** For interactive login, tune so a single verify costs roughly ~50–250 ms of server work (OWASP's 19 MiB argon2id minimum lands near the low end); push higher only where UX and capacity allow, since every verify is CPU/RAM you pay per login and too high enables a DoS on your own auth endpoint.
- **argon2id memory cost** is the point of memory-hardness — cutting it to save RAM erodes the GPU-resistance you chose argon2 for.

## Common Pitfalls

- **Using a fast hash for passwords.** `SHA-256(password)`, even salted, is crackable at billions/sec on a GPU — salt stops rainbow tables but not brute force. Slowness is the missing property.
- **Global/static salt or no salt.** A shared salt re-enables one rainbow table for the whole DB and re-exposes shared passwords. Salt must be per-user and random.
- **Treating pepper as a substitute for salt.** Pepper is site-wide and secret; salt is per-user and public. You need the salt for correctness; pepper is optional hardening. Neither replaces the other.
- **bcrypt 72-byte truncation.** bcrypt silently ignores input past 72 bytes, so long passwords / naive pre-hashing collide. If pre-hashing to bypass this, base64-encode the digest (raw bytes may contain a NUL that bcrypt treats as string end).
- **Encrypting passwords instead of hashing.** Reversible encryption means a stolen key exposes every password; passwords should be verifiable but never recoverable.
- **Non-constant-time comparison.** Compare candidate and stored hash with a constant-time equality check to avoid timing leaks (most verify APIs do this internally — use them, don't hand-roll `==`).
- **Never upgrading the work factor.** Parameters chosen years ago are now weak; rehash transparently on successful login when the stored cost is below current policy.

## Implementation Notes

- Prefer a vetted library that outputs a self-describing **PHC string** (`$argon2id$v=19$m=...,t=...,p=...$<salt>$<hash>`), which stores algorithm + params + salt together so verification and future re-tuning are automatic. Examples: libsodium `crypto_pwhash`, `argon2-cffi` (Python), Go `golang.org/x/crypto/argon2`, Rust `argon2`/`password-hash`, PHP `password_hash(PASSWORD_ARGON2ID)`.
- Do not implement the KDF or the salt/compare logic yourself; use the library's `hash`/`verify` pair.
- Store the pepper in a secrets manager (AWS Secrets Manager / Vault / [KMS](_meta/glossary.md#kms)-encrypted config), rotatable independently of the DB.

## Resources

- OWASP Password Storage Cheat Sheet — https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- OWASP Top 10 A02:2021 Cryptographic Failures — https://owasp.org/Top10/A02_2021-Cryptographic_Failures/
- PHC string format spec — https://github.com/P-H-C/phc-string-format/blob/master/phc-sf-spec.md
- RFC 9106 (Argon2) — https://www.rfc-editor.org/rfc/rfc9106.html

## Related

- [[cryptographic-hash-functions]]
- [[authentication]]
- [[owasp-top-10]]
- [[symmetric-encryption]]
