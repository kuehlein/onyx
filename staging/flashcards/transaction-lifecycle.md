---
id: 7f3a2c1e-9b84-4d56-a031-e8c5f702d193
type: flashcard
tags:
  - blockchain
  - cryptography
  - distributed-systems
  - consensus-mechanism
tiers:
  blockchain: 1
created: 2026-08-20
confidence: low
---

# Transaction Lifecycle

A blockchain transaction is a cryptographically signed state-transition instruction that moves through distinct phases — construction, signing, broadcast, mempool queuing, block inclusion, and finalization — before it becomes irreversible. Each phase enforces invariants (signature validity, nonce ordering, fee sufficiency, state rules) that together prevent double-spends without a trusted third party.

> [!warning] Broadcast ≠ Confirmed ≠ Finalized
> A tx in the mempool can be evicted, replaced ([RBF](_meta/glossary.md#rbf)), or never mined. Crediting on broadcast (before mining) is a double-spend vector. Confirmed (1 block) is still not final — probabilistic finality (Bitcoin) needs N confirmations; Ethereum has explicit finality only after ~2 epochs.

## When to Use

**Interview/design scenarios where this concept is directly relevant:**
- "Walk me through what happens when a user sends ETH from one address to another."
- "How does a blockchain prevent double-spending without a central authority?"
- "Why can a transaction be pending for hours, and how would you design a fee-estimation service?"
- "How would you build a transaction monitoring or block explorer service?"
- "Explain mempool dynamics and how [MEV](_meta/glossary.md#mev) (Maximal Extractable Value) arises."
- "What is transaction finality and why does it differ between Bitcoin and Ethereum?"
- "How do hardware wallets sign transactions without exposing the private key?"

**Prefer explaining the full lifecycle over partial answers when:**
- The question involves debugging stuck/dropped transactions — root cause almost always lives in one specific phase.
- Designing infrastructure (indexers, relayers, bridges) that must distinguish "submitted" from "confirmed" from "finalized."
- Questions about gas, fee markets, or priority — these are mempool and block-inclusion concerns, not signing concerns.

**Do not conflate phases:**
- Broadcast ≠ Confirmed — a transaction in the mempool can be evicted, replaced (RBF), or never mined.
- Confirmed (1 block) ≠ Finalized — probabilistic finality (Bitcoin [PoW](_meta/glossary.md#pow)) requires N confirmations; Ethereum post-Merge has explicit finality after ~2 epochs (~12.8 min).

## Key Properties

### 1. Construction

The sender assembles the transaction fields:

| Field | Bitcoin ([UTXO](_meta/glossary.md#utxo)) | Ethereum (account) |
|---|---|---|
| From / Inputs | One or more UTXOs | `from` address (implicit via signature) |
| To / Outputs | Recipient scriptPubKey | `to` address |
| Amount | Output values (change explicit) | `value` (wei) |
| Fee | Input sum − Output sum | `gasLimit × maxFeePerGas` ([EIP-1559](_meta/glossary.md#eip-1559)) |
| Nonce | N/A (UTXO uniqueness is structural) | Monotonically increasing per account |
| Data | `OP_RETURN` or script | Arbitrary calldata (for contract calls) |

The **nonce** in Ethereum is critical: it enforces ordering and prevents replay. A gap in nonces (e.g., nonce 5 submitted before nonce 4 is mined) stalls all subsequent transactions from that sender.

### 2. Signing

The sender produces a digital signature over the transaction digest (preimage hash), using their private key:

```
digest = keccak256(RLP_encode(tx_fields))   // Ethereum
sig = ECDSA.sign(digest, privateKey)        // secp256k1 curve
// sig = { r, s, v }  where v encodes chain ID (EIP-155 replay protection)
```

The **private key never leaves the signer** — only the signature `(r, s, v)` is attached to the transaction. The public key (and thus the `from` address) is *recovered* from the signature and digest by validators:

```
recoveredPubKey = ECDSA.recover(digest, r, s, v)
from = keccak256(recoveredPubKey)[12:]   // last 20 bytes
```

The security of [ECDSA](_meta/glossary.md#ecdsa) against forgery rests on the hardness of the elliptic-curve discrete logarithm problem ([ECDLP](_meta/glossary.md#ecdlp)) on secp256k1 — an attacker cannot derive the private key from the public key or forge a valid signature without it. Collision resistance of keccak256 is an additional, separate protection: it prevents existential forgery attacks where two distinct messages share the same digest.

### 3. Broadcast & Mempool

The signed transaction is serialized ([RLP](_meta/glossary.md#rlp)-encoded in Ethereum) and broadcast to the [P2P](_meta/glossary.md#p2p) network. Each node that receives it performs **local validation** before accepting it into its mempool:

- Signature recovers to a valid `from` address.
- Nonce equals `currentNonce` for that account (where `currentNonce` = `eth_getTransactionCount(addr, "latest")`, the count of confirmed transactions and thus the next expected nonce) — or is a replacement with higher fee.
- Sender balance ≥ `value + gasLimit × maxFeePerGas`.
- Gas limit ≤ block gas limit.
- No conflicting nonce already in mempool (if so, replacement rules apply — EIP-1559 requires ≥10% fee bump to replace).

The mempool is a **local, non-consensus data structure** — different nodes may have different views. This is the source of MEV: block producers can see pending transactions and reorder, insert, or censor them.

### 4. Block Inclusion

Miners (PoW) or validators ([PoS](_meta/glossary.md#pos)) select transactions from their mempool, typically by fee priority, subject to block gas/size limits. In Ethereum EIP-1559:

- `baseFee` is burned (protocol-determined, adjusts per block).
- `priorityFee` (tip) goes to the validator.
- Effective fee = `min(maxFeePerGas, baseFee + maxPriorityFeePerGas)`.

The block producer executes transactions sequentially against the state. If a transaction reverts (e.g., contract call fails), the state changes are rolled back but **gas is still consumed** — the nonce still increments, preventing replay.

### 5. Confirmation & Finality

| Chain | Confirmation | Finality |
|---|---|---|
| Bitcoin | 1 block (~10 min) | Probabilistic: 6 blocks (~1 hr) conventional |
| Ethereum (post-Merge) | 1 block (~12 sec) | Explicit: 2 epochs (~12.8 min) via Casper [FFG](_meta/glossary.md#ffg) |
| Solana | ~400 ms slot | Optimistic: 32 slots; max lockout after ~13 s |

**Probabilistic finality** (Bitcoin): the probability of a block being reorged out decreases exponentially with each subsequent block. After 6 confirmations, reorg cost exceeds any rational attacker's incentive for typical transaction values.

**Explicit finality** (Ethereum): Casper FFG checkpoints are voted on by the validator set. Once a checkpoint is "finalized," reverting it requires ≥⅓ of staked ETH to be slashed — an economic guarantee, not just probabilistic.

## Common Pitfalls

- **Nonce gaps:** Submitting nonce 5 before nonce 4 is mined causes nonce 5 to queue indefinitely. Fix: resubmit nonce 4 (or cancel by sending a zero-value self-transfer with nonce 4 and a higher fee).
- **Treating mempool inclusion as confirmation:** Exchanges and bridges that credit deposits on broadcast (before mining) are vulnerable to double-spend via fee replacement (RBF) or transaction eviction.
- **Ignoring [EIP-155](_meta/glossary.md#eip-155) replay protection:** A transaction signed without chain ID can be replayed on any chain sharing the same genesis — critical for multi-chain deployments.
- **Gas estimation on dynamic state:** `eth_estimateGas` snapshots current state; if state changes between estimation and mining, the transaction may revert with out-of-gas.
- **Assuming transaction hash immutability:** In Bitcoin (pre-[SegWit](_meta/glossary.md#segwit)), txid malleability allowed a third party to alter the scriptSig (unlocking script) without changing the economic content, producing a different hash — for example by using alternative [DER](_meta/glossary.md#der) encodings of the signature or inserting extra push operations. SegWit fixes this by moving signature data to a separate witness field that is excluded from the txid hash.

## Trade-offs

| Concern | Higher Throughput | Higher Security/Decentralization |
|---|---|---|
| Block time | Shorter (more txs/s) | Longer (more propagation time) |
| Block size | Larger | Smaller (easier to run full nodes) |
| Finality | Faster (optimistic) | Slower (more confirmations / epochs) |
| Mempool | Smaller (evicts faster) | Larger (absorbs demand spikes) |

## Implementation Notes

Minimal JS sketch of transaction construction and signing (using ethers.js patterns):

```js
// 1. Construct
const tx = {
  to:       "0xRecipient...",
  value:    ethers.parseEther("1.0"),
  nonce:    await provider.getTransactionCount(wallet.address, "pending"),
  gasLimit: 21_000n,                     // simple ETH transfer
  maxFeePerGas:         ethers.parseUnits("20", "gwei"),
  maxPriorityFeePerGas: ethers.parseUnits("1",  "gwei"),
  chainId:  1n,                          // mainnet — EIP-155
};

// 2. Sign (private key stays inside wallet)
const signedTx = await wallet.signTransaction(tx);
// signedTx is RLP-encoded hex; includes r, s, v

// 3. Broadcast
const response = await provider.broadcastTransaction(signedTx);
// response.hash is known now, but tx is only in mempool

// 4. Wait for confirmation
const receipt = await response.wait(1);   // 1 block confirmation
// receipt.status === 1  → success; 0 → reverted (gas still charged)

// 5. Wait for finality (Ethereum)
const receipt6 = await response.wait(64); // ~2 epochs, post-Merge convention
```

**Key non-obvious points:**
- `provider.getTransactionCount(addr, "pending")` returns mined nonce + pending mempool nonces — use this to avoid gaps when submitting multiple transactions in rapid succession.
- `receipt.status === 0` with gas consumed means the [EVM](_meta/glossary.md#evm) executed but the call reverted — this is not a failed broadcast, it is a successful (but reverting) on-chain execution.

## Resources

- [Ethereum Yellow Paper — Transaction Execution (Section 6)](https://ethereum.github.io/yellowpaper/paper.pdf)
- [EIP-1559: Fee Market Change](https://eips.ethereum.org/EIPS/eip-1559)
- [EIP-155: Simple Replay Attack Protection](https://eips.ethereum.org/EIPS/eip-155)
- [Bitcoin Developer Guide — Transactions](https://developer.bitcoin.org/devguide/transactions.html)
- [ethereum.org — Transactions](https://ethereum.org/en/developers/docs/transactions/)
- [Mastering Ethereum, Ch. 6 — Transactions (Antonopoulos & Wood)](https://github.com/ethereumbook/ethereumbook/blob/develop/06transactions.asciidoc)

## Related

- [[merkle-tree]]
- [[consensus-mechanism]]
- [[cryptography]]
- [[evm]]
- [[p2p]]
- [[wallet]]
