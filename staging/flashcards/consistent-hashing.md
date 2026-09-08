---
id: consistent-hashing
type: flashcard
tags:
  - distributed-systems
  - hashing
  - partitioning
tiers:
  distributed-systems: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Consistent Hashing

Consistent hashing maps both keys and nodes onto the same fixed hash space — conceptually a ring — and assigns each key to the first node found walking clockwise from the key's position. The principle: because a node owns only the arc between it and its predecessor, adding or removing a node re-homes only the keys in *that one arc* — on average K/N keys for K keys and N nodes — instead of the near-total reshuffle that `hash(key) mod N` forces when N changes. Virtual nodes (multiple ring positions per physical node) then smooth the otherwise lumpy arc sizes and let heterogeneous nodes carry proportional load.

> [!tip] Recognition
> Reach for consistent hashing when the trigger is **"minimize the keys that move when the cluster resizes"** — elastic scaling of a distributed cache or shard set, a [DHT](_meta/glossary.md#dht), or partition/ownership assignment where nodes join and leave continuously. The tell is that plain `hash(key) mod N` would remap almost everything on every membership change.

## When to Use

**Problem signals that suggest consistent hashing:**
- "When we add or remove a cache/shard node, we cause a thundering herd of cache misses / a full data reshuffle" — the classic `mod N` rehash-storm symptom
- "We autoscale nodes up and down constantly and need key→node ownership to stay stable"
- "Design a distributed cache (memcached/Ketama), a DHT, or a Dynamo/Cassandra-style ring"
- "Route each user/session to a consistent backend so warm local state survives a fleet change" (sticky routing at the [LB](_meta/glossary.md#lb))
- "Partition data across N shards where N changes over the system's lifetime"

**Prefer consistent hashing over alternatives when:**
- Over `hash(key) mod N`: whenever N is *not fixed* — mod-N remaps ~(N-1)/N of all keys on any resize; consistent hashing remaps ~K/N
- Over a central lookup table / directory service: when you want each client to compute ownership locally with no coordination and no [SPOF](_meta/glossary.md#spof) directory
- Over range partitioning: when you want uniform load spreading and have no need for range scans across adjacent keys

**Do not use when:**
- N is fixed and known → plain `hash(key) mod N` is simpler and gives perfectly uniform buckets
- You need range queries (scan keys between X and Y) → hashing destroys key locality; use range/order-preserving partitioning instead
- Buckets are densely numbered 0..N-1 and you never remove arbitrary ones → jump consistent hash is faster and needs zero memory (see Variants)
- You must reason about per-node load caps → plain consistent hashing gives no load bound (see Common Pitfalls / bounded-load variant)

## Key Properties

- **Monotonicity / minimal remapping.** When a node is added or removed, only keys mapped to (or now mapped from) that node move. No other key→node assignment changes. This is the defining property from Karger et al. 1997.
- **Expected K/N movement.** Adding the (N+1)-th node moves ~1/(N+1) of keys; removing a node moves that node's ~K/N keys to its clockwise successor.
- **Balance (with vnodes).** A single ring position per node gives high variance in arc sizes (a node can own far more or less than its fair share). Assigning many virtual positions per node makes arc sizes concentrate around the mean by averaging.
- **Local computability.** Any client can compute a key's owner from just the node set and a shared hash function — no central coordinator needed.
- **Heterogeneity.** Give a node more virtual positions to make it own proportionally more of the ring — the mechanism for weighting by capacity.

## Time & Space Complexity

Let N = number of (physical) nodes, V = virtual nodes per physical node, K = number of keys.

| Operation | Cost | Why |
|---|---|---|
| Key lookup (find owner) | O(log(N·V)) | binary search for the successor position in the sorted ring |
| Add / remove a node | O(V·log(N·V)) | insert/delete V ring positions |
| Keys remapped on 1 node change | **~K/N expected** | only the affected node's arc(s) move |
| Ring storage | O(N·V) | one sorted entry per virtual node |

Vnode count V trades memory and lookup constant-factor for smoother load: more vnodes → tighter balance but larger ring. Common production values are 100–256 vnodes per node (Ketama, Cassandra default 256).

## Common Pitfalls

- **`hash(key) mod N` is the anti-pattern.** Changing N changes the divisor, so ~(N-1)/N of keys land on a different node — a cache-miss storm or full data migration on every scale event. This is the specific failure consistent hashing exists to fix.
- **Load imbalance WITHOUT virtual nodes.** With one point per node, ring arcs are highly uneven; a few nodes can own a large fraction of the space. Naive consistent hashing's load is no better than random assignment, so the most-loaded node is expected to carry Θ(log N / log log N) times the average — vnodes are not optional in practice.
- **Hot keys / hot partitions.** Consistent hashing balances *key ranges*, not *access frequency*. A single viral key (celebrity user, trending item) overloads its one owner no matter how many vnodes you add. Mitigate with per-key replication, request-level caching, or splitting the hot key.
- **Correlated node loss.** Vnodes for one physical node are scattered around the ring; when it dies, each vnode's load falls on a *different* successor. Good for spreading load, but it means one failure touches many neighbors — size headroom accordingly.
- **Reusing the same hash seed for keys and node IDs badly.** Poor/low-entropy node-ID hashing clusters vnodes and reintroduces imbalance; use a good hash and enough vnodes.

## Trade-offs

- **Vnode count: balance vs. overhead.** More vnodes → smoother load and gentler failure redistribution, but larger ring metadata, slower membership updates, and more gossip/state to propagate.
- **Minimal movement vs. perfect balance.** Consistent hashing optimizes for *few keys moving* on resize; it does not guarantee even load. Bounded-load variants add a per-node cap but then move slightly more keys and need coordination on load.
- **No range queries.** You gain uniform spread and cheap resizing but lose the ability to scan adjacent keys — the reason range-partitioned stores (HBase, Bigtable) choose the opposite tradeoff.
- **Nuance (DDIA Ch. 6).** Kleppmann notes many systems that advertise "consistent hashing" use it loosely: Cassandra/Dynamo-style rings often pin a *fixed number of partitions per node* (e.g. 256) and split/reassign whole partitions, which matches Karger's original definition more closely than the textbook clockwise-ring picture. He even suggests just calling it "hash partitioning." Know the term but state the specific mechanism in interviews.

## Implementation Notes

**Ring as a sorted structure + binary search:**
1. Hash each node's V virtual IDs (e.g. `hash("node-A#0")`, `hash("node-A#1")`, …) to points in `[0, 2^m)`; store them in a sorted map keyed by hash value → physical node.
2. To find a key's owner: `h = hash(key)`; binary-search for the *first* ring entry with value ≥ h; if none, wrap to the smallest entry (the ring closes). That entry's physical node owns the key.
3. Add node: insert its V entries. Remove node: delete its V entries. Only keys whose successor changed are affected.

```python
import bisect
class Ring:
    def __init__(self, vnodes=200):
        self.vnodes = vnodes
        self.keys = []          # sorted ring positions
        self.owner = {}         # position -> physical node

    def add(self, node):
        for i in range(self.vnodes):
            pos = hash_fn(f"{node}#{i}")
            bisect.insort(self.keys, pos)
            self.owner[pos] = node

    def get(self, key):
        pos = hash_fn(key)
        idx = bisect.bisect_right(self.keys, pos) % len(self.keys)  # wrap-around
        return self.owner[self.keys[idx]]
```

**Vnode assignment:** for weighted/heterogeneous nodes, give a node `vnodes ∝ capacity`. For replication (Dynamo), the key is stored on the next R *distinct physical* nodes clockwise (skip additional vnodes of a node already chosen).

## Variants

- **Rendezvous hashing (Highest Random Weight, HRW).** For each key, compute `hash(key, node)` for every node and pick the node with the max score. Gives minimal disruption (removing a node only remaps *its* keys) and clean weighting, with no ring to maintain — but naive lookup is O(N) per key (vs. O(log N) for the ring). Predates and inspired much ring practice.
- **Jump consistent hash (Lamping & Veach, 2014).** A ~5-line, stateless function mapping a key to a bucket in `[0, N)` with zero storage, faster than the ring, and near-perfect balance. Limitation: buckets must be numbered sequentially `0..N-1` and you can only add/remove the *highest* bucket — great for elastic shard counts, poor for arbitrary node removal (so less suited to web caching).
- **Consistent hashing with bounded loads (Mirrokni, Thorup, Zadimoghaddam, 2016).** Adds a per-node capacity cap: a key overflowing its owner spills to the next node with room. Guarantees a max load of (1+ε)·average while moving only an expected constant number of keys per update. Shipped in Google Cloud Pub/Sub and HAProxy.
- **Maglev hashing (Google).** Builds a fixed-size lookup table for O(1) lookups with good balance and minimal disruption, tuned for software load balancers.

## Resources

- Karger et al., *Consistent Hashing and Random Trees* (STOC 1997): https://www.cs.princeton.edu/courses/archive/fall09/cos518/papers/chash.pdf
- DeCandia et al., *Dynamo: Amazon's Highly Available Key-value Store* (SOSP 2007): https://www.allthingsdistributed.com/files/amazon-dynamo-sosp2007.pdf
- Lamping & Veach, *A Fast, Minimal Memory, Consistent Hash Algorithm* (jump hash, 2014): https://arxiv.org/abs/1406.2294
- Mirrokni, Thorup, Zadimoghaddam, *Consistent Hashing with Bounded Loads* (2016) + Google blog: https://arxiv.org/abs/1608.01350

## Related

- [[partitioning-sharding]]
- [[load-balancing]]
- [[caching]]
- [[hash-map]]
- [[cap-theorem]]
