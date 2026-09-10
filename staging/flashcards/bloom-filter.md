---
id: bloom-filter
type: flashcard
tags:
  - databases
  - ds-a
  - probabilistic-data-structures
  - lsm-tree
  - caching
tiers:
  databases: 3
created: 2026-09-10
confidence: high
priority: normal
---

# Bloom Filter

A Bloom filter is a compact probabilistic structure that answers "is this element in the set?" with **"definitely not"** or **"probably yes."** It is a bit array of `m` bits plus `k` independent hash functions; `add(x)` sets the `k` bits that `x` hashes to, and `contains(x)` returns true only if *all* `k` of those bits are set. Because bits are shared across elements, a query can return true when the element was never added (a **false positive**), but it can *never* return false for an element that was added (**no false negatives**). That asymmetry is the whole point: it lets you use a tiny, fixed amount of memory to cheaply rule out the common "not present" case before paying for an expensive exact lookup (a disk seek, a network call, a full [set](_meta/glossary.md#hash-set) probe).

> [!tip] Recognition
> Reach for a Bloom filter when you see: **"skip the expensive lookup if the key is definitely absent,"** "have we seen this before?" at massive scale, membership check where a **tunable, small false-positive rate is acceptable** but false negatives are not, or "we can't fit the whole set in memory but need a fast negative check." Concrete tells: LSM-tree read path avoiding SSTable reads, CDN/cache "one-hit-wonder" filtering, URL/dedup "already crawled?" checks, and any "space vs. accuracy" trade where you never need to *retrieve* the element, only test membership.
>
> **vs. hash set:** a [hash set](_meta/glossary.md#hash-set) stores the actual keys → exact answers but O(n·keysize) memory. A Bloom filter stores only bits → ~10 bits/element regardless of key size, but answers are approximate and you cannot enumerate or delete. **vs. counting Bloom filter / cuckoo filter:** those add deletion support the plain filter lacks.

## When to Use

**Problem signals that suggest a Bloom filter:**
- "Before doing an expensive operation, cheaply check if it *might* be needed" — the negative answer lets you skip a disk read, RPC, or cache miss entirely
- "Have we already seen / processed / crawled this?" at a scale where storing all keys is too expensive (dedup, crawler frontier, event de-duplication)
- Membership test where **memory is the binding constraint** and a small, controllable error rate is fine (e.g. 1%)
- "Filter out the majority of definitely-absent keys, then fall back to an exact structure for the survivors"

**Prefer a Bloom filter over alternatives when:**
- Over a [hash set](_meta/glossary.md#hash-set) / hash map: when you only need membership (never retrieval), keys are large, and the set is huge — the filter is far smaller and its size is independent of key length
- Over hitting the source of truth directly: when the source is slow (disk, network) and most queries are for absent keys — the filter absorbs the negative case in memory
- Over a counting/cuckoo filter: when you never need to delete elements — the plain filter is the simplest and most space-efficient

**Do not use when:**
- **False positives are unacceptable** (e.g. "is this password revoked?" where a false positive blocks a valid user) → use an exact structure, or use the filter only as a pre-check backed by an authoritative lookup
- **You need to retrieve or enumerate elements**, not just test membership → a Bloom filter stores no keys and cannot list its contents → use a hash map/set
- **You need deletions** → plain Bloom filters cannot delete → use a [[counting-bloom-filter]] or cuckoo filter
- The set is small enough to fit exactly in memory → a plain hash set is simpler and gives exact answers

## Key Properties

- **No false negatives, tunable false positives.** If `contains(x)` returns false, `x` is guaranteed absent. If it returns true, `x` is *probably* present with a known probability. This is the defining invariant — and it holds because `add` only ever *sets* bits, never clears them.
- **Fixed size, set at construction.** You must estimate the expected element count `n` and target false-positive rate up front to size `m` and `k`. The filter does not grow; exceeding `n` degrades the FP rate (see Trade-offs / scalable variant).
- **The FP rate is governed by `m/n` and `k`.** With `m` bits, `n` inserted elements, and `k` hashes, the false-positive probability is approximately `(1 − e^(−kn/m))^k`. It rises as the array fills (as `n` grows toward and past `m`).
- **Optimal `k = (m/n)·ln 2 ≈ 0.693·(m/n)`.** This is the `k` that minimizes the FP rate; at that `k` roughly **half the bits are set**, which maximizes information density. Too few hashes underuses the array; too many saturate it.
- **Space rule of thumb: ~9.6 bits per element for a 1% FP rate.** More generally the optimal filter needs about `1.44·log2(1/ε)` bits per element for target rate `ε` — so each additional factor-of-10 reduction in `ε` costs only about **4.8 more bits per element**. Crucially this is independent of how large the keys themselves are.
- **No deletions in the plain filter.** Clearing an element's bits could clear a bit shared with another element, creating a false negative and breaking the core invariant. Deletion requires the counting variant.
- **Union is cheap; intersection is lossy.** Two filters of identical `m` and `k` (and hash functions) can be merged into the filter of the union of their sets via bitwise **OR**. Bitwise AND does *not* give a correct intersection filter.

## Common Pitfalls

- **Treating "probably yes" as "yes."** A positive result must still be confirmed against the source of truth if correctness matters. The filter is a fast negative check, not an authority.
- **Under-sizing for the real `n`.** The advertised FP rate assumes you insert no more than the `n` you sized for. Insert 2× as many and the array saturates — the FP rate climbs sharply (eventually toward 100% as all bits become 1). Size for peak, not average.
- **Trying to delete by clearing bits.** This silently introduces **false negatives** and destroys the one guarantee the structure offers. Use a counting Bloom filter (per-slot counters) or a cuckoo filter if deletion is required.
- **Using slow or correlated hashes.** `k` truly independent hashes are assumed. In practice use double hashing — `h_i(x) = h1(x) + i·h2(x)` from two good hashes (e.g. a single 128-bit hash split in two) — which is cheap and, per Kirsch–Mitzenmacher, does not meaningfully worsen the FP rate.
- **Assuming you can enumerate or count.** A Bloom filter cannot list its members or give an exact cardinality; it only answers membership queries.
- **Ignoring saturation over time in a long-lived filter.** A filter that accumulates entries forever (e.g. "seen URLs") monotonically fills up. Use a scalable/rotating design or periodic rebuild.

## Trade-offs

**vs. exact and alternative membership structures:**

| Structure | Memory | False positives | False negatives | Delete? | Retrieve keys? |
|---|---|---|---|---|---|
| Hash set / map | O(n · keysize) | none | none | yes | yes |
| **Bloom filter** | ~9.6 bits/elem @ 1% | tunable | **never** | **no** | no |
| Counting Bloom filter | ~3–4× a Bloom filter (counters, not bits) | tunable | never* | **yes** | no |
| Cuckoo filter | comparable / better at low ε | tunable | never | **yes** | no |

\*Counting filters can suffer false negatives only if a counter overflows and is clamped — size counters (typically 4 bits) to avoid it.

- **Space vs. accuracy.** Fewer bits/element → higher FP rate; the relationship is fixed by `1.44·log2(1/ε)`. You buy an order of magnitude fewer false positives for ~4.8 extra bits/element.
- **Speed vs. `k`.** Every query and insert touches `k` bit positions, so larger `k` costs more hashing/memory accesses. `k = 0.693·(m/n)` optimizes accuracy, but a slightly smaller `k` can be a reasonable speed trade.
- **Simplicity vs. deletability/scalability.** Plain Bloom filters are the smallest and simplest but are fixed-size and delete-free. Counting/cuckoo filters add deletion at a memory cost; scalable Bloom filters add growth at added complexity.
- **In the [[lsm-tree]] read path** this trade is a clear win: a per-SSTable Bloom filter (a few bits per key, kept in memory) lets a point lookup **skip reading an SSTable from disk** whenever the key is definitely absent, turning most negative lookups into a memory-only check and avoiding random disk I/O — the single most important read optimization for LSM stores.

## Implementation Notes

Core operations over a bit array `bits[0..m)` and `k` hash functions:

```text
add(x):
  for i in 0..k-1:
    bits[ hash_i(x) mod m ] = 1

contains(x):                 # "probably yes" / "definitely no"
  for i in 0..k-1:
    if bits[ hash_i(x) mod m ] == 0:
      return false           # a clear bit ⇒ definitely absent
  return true                # all set ⇒ probably present
```

Sizing from a target `n` and false-positive rate `ε`:

```text
m = ceil( -(n · ln ε) / (ln 2)^2 )      # bits
k = round( (m / n) · ln 2 )             # optimal hash count
```

- Derive the `k` indices from **two** hashes via double hashing (Kirsch–Mitzenmacher) rather than computing `k` independent hashes.
- Real deployments: RocksDB/LevelDB per-SSTable filters (RocksDB defaults to ~10 bits/key), Cassandra SSTable filters, Google BigTable (the original LSM Bloom use case), and CDN/proxy caches filtering one-hit-wonders before admitting to cache.

## Variants

- **Counting Bloom filter** — replaces each bit with a small counter (typically 4 bits) so elements can be *deleted* by decrementing; costs several× the space. See [[counting-bloom-filter]].
- **Cuckoo filter** — stores small fingerprints in a cuckoo hash table; supports deletion and often beats Bloom filters on space at low target FP rates.
- **Scalable Bloom filter** — a chain of filters with geometrically shrinking FP rates that grows as elements are added, removing the fixed-`n` limitation.
- **Blocked / register-blocked Bloom filter** — confines each element's `k` bits to one cache line/block for better CPU cache locality at a slight FP-rate cost.
- **Quotient filter** — a cache-friendly, mergeable, resizable filter used in some storage engines.

## Resources

- Bloom, *Space/Time Trade-offs in Hash Coding with Allowable Errors* (1970) — the original paper: https://dl.acm.org/doi/10.1145/362686.362692
- Broder & Mitzenmacher, *Network Applications of Bloom Filters: A Survey* — https://www.eecs.harvard.edu/~michaelm/postscripts/im2005b.pdf
- Kirsch & Mitzenmacher, *Less Hashing, Same Performance: Building a Better Bloom Filter* (double hashing) — https://www.eecs.harvard.edu/~michaelm/postscripts/rsa2008.pdf
- RocksDB Wiki, *Bloom Filter* (LSM read-path use) — https://github.com/facebook/rocksdb/wiki/RocksDB-Bloom-Filter

## Related

- [[lsm-tree]]
- [[hash-set]]
- [[counting-bloom-filter]]
- [[caching]]
- [[consistent-hashing]]
- [[hash-map]]
