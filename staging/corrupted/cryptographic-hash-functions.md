## Key Properties

Four security properties define whether a hash function is *cryptographic*:

| Property | Definition | Why it matters in blockchain |
|---|---|---|
| **Preimage resistance** | Given digest `h`, it is infeasible to find any `m` such that `H(m) = h` | Prevents reversing a commitment or a wallet address back to the preimage |
| **Second-preimage resistance** | Given `m₁`, it is infeasible to find `m₂ ≠ m₁` such that `H(m₁) = H(m₂)` | Prevents substituting a different transaction that hashes to the same ID |
| **Collision resistance** | It is infeasible to find *any* pair `(m₁, m₂)` where `m₁ ≠ m₂` and `H(m₁) = H(m₂)` | Strongest practical requirement; a collision in block hashing would allow history rewriting |
| **Avalanche effect** | Flipping one input bit changes ~50% of output bits unpredictably | Design criterion (not a formal security property); makes the digest appear random and prevents partial-preimage attacks |

These three security properties — preimage resistance, second-preimage resistance, and collision resistance — are formally independent of one another; no strict implication holds between them in general. In practice, collision attacks against deployed functions have historically appeared before second-preimage or preimage attacks (e.g., SHA-1's collision was demonstrated in 2017 long before any preimage threat emerged), but this is a historical pattern, not a cryptographic theorem.
