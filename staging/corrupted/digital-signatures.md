**EdDSA nonce derivation (in Common Pitfalls section):**

Replace:
> EdDSA/ed25519 is deterministic (k derived via HMAC-DRBG from d and m) and eliminates this class of bug entirely.

With:
> EdDSA/ed25519 is deterministic (the nonce r is derived as H(nonce\_key ‖ m), where nonce\_key is the upper half of H(private\_key\_seed), per RFC 8032) and eliminates this class of bug entirely. (RFC 6979 provides a separate HMAC-DRBG-based mechanism for deterministic nonce generation in ECDSA.)

---

**v parameter description (in Implementation Notes section):**

Replace:
> `v` is the recovery parameter (27 or 28, or 0/1 in EIP-155 replay-protected form) that disambiguates which of the two possible curve points corresponds to `r`.

With:
> `v` is the recovery parameter that disambiguates which of the two possible curve points corresponds to `r`. Without replay protection: v = 27 or 28. With EIP-155 replay protection: v = CHAIN_ID * 2 + 35 or CHAIN_ID * 2 + 36 (e.g., 37 or 38 on mainnet).

---

**Signature aggregation table cell for ed25519:**

Replace "Native batch verify" with "Batch verify (not aggregation)" to make clear this is batch verification of separate signatures, not aggregation into a single signature.
