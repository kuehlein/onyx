---
id: union-find
type: flashcard
tags:
  - ds-a
  - union-find
  - graph
tiers:
  ds-a: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Union-Find

Union-Find (disjoint-set union, DSU) maintains a partition of `n` elements into disjoint sets under two operations: `find(x)` (which set is `x` in?) and `union(x, y)` (merge two sets). Sets are stored as a forest of trees where each element points to a parent and each set is identified by its root. The near-constant speed comes from two invariants working together: **union by rank/size** keeps trees shallow by always attaching the smaller tree under the larger, and [**path compression**](_meta/glossary.md#path-compression) flattens a tree on every `find` by repointing visited nodes straight at the root. Together they make future queries cheaper than the ones that paid for the flattening — the [amortization](_meta/glossary.md#amortized-analysis) argument that yields the α(n) bound.

> [!tip] Recognition signal
> Reach for Union-Find when a problem is about **connectivity of an undirected structure** and merges are irreversible: "are these two in the same group?", "how many groups remain after these connections?", "does adding this edge create a cycle?", or "process edges cheapest-first without forming a cycle" ([MST](_meta/glossary.md#mst) / Kruskal). If you only ever *add* connections (never remove), Union-Find beats re-running [BFS](_meta/glossary.md#bfs)/[DFS](_meta/glossary.md#dfs).

## When to Use

**Problem signals that suggest Union-Find:**
- The problem asks whether two elements are **connected / in the same group**, and you answer many such queries as connections accumulate ("dynamic connectivity")
- You must count **connected components** in an undirected graph, or count them as edges are added incrementally
- **Cycle detection in an *undirected* graph**: an edge `(u, v)` closes a cycle iff `find(u) == find(v)` before you union them
- **Kruskal's MST**: sort edges ascending, add an edge only if its endpoints are in different sets (adding it wouldn't create a cycle)
- Grouping / equivalence problems: "accounts merge", "friend circles", "number of islands" (grid cells as nodes), "redundant connection", "graph valid tree"
- Keywords: "merge", "same group", "provinces", "connected components", "union", "disjoint"

**Prefer Union-Find over alternatives when:**
- Over BFS/DFS: when connectivity is **queried repeatedly and interleaved with edge additions**. Re-running a traversal per query is O(V+E) each; Union-Find answers each in ~O(α(n)) after near-linear preprocessing
- Over a graph coloring/component-labeling pass: when the edge set is **not known up front** (streams in) — Union-Find is incremental, a DFS labeling is a one-shot batch
- Over adjacency structures for cycle detection (undirected): Union-Find needs no explicit graph, just the parent array

**Do not use when:**
- The graph is **directed** and you need directed cycle detection or [SCC](_meta/glossary.md#scc)s → use DFS (white/gray/black coloring) or Tarjan/Kosaraju. Union-Find only models *undirected* connectivity
- You must **remove** edges / split sets (disconnection). Plain DSU has no efficient un-union → use link-cut trees, Euler-tour trees, or offline techniques
- You need the **actual path** or **shortest distance** between two nodes, not just "are they connected?" → BFS/DFS
- The structure is static and you need one component labeling → a single DFS/BFS pass is simpler

## Time & Space Complexity

Let `n` = number of elements, `m` = number of operations. The headline `α(n)` requires **both** heuristics; either one alone gives only `O(log n)`.

| Configuration | Amortized per op | Notes |
|---|---|---|
| Naive (no heuristics) | O(n) worst | trees can degenerate to a chain |
| Union by rank/size only | O(log n) | balanced height, no flattening |
| Path compression only | O(log n) amortized | flattening, but unbalanced unions |
| **Rank/size + path compression** | **O(α(n))** | inverse Ackermann; α(n) < 5 for all practical n |
| `make_set` | O(1) | initialize one singleton |
| Space | O(n) | one parent + one rank/size entry per element |

**Why α(n), not O(1):** α(n) is the inverse Ackermann function — it grows so slowly it is ≤ 4 for any `n` writable in this universe (roughly n < 2^2^2^2^…). It is *not* literally constant (Tarjan proved a matching lower bound: no DSU can be strictly O(1) amortized under this model), but it is constant for every real input. Treat set operations as effectively O(1) in interviews, but say "amortized inverse-Ackermann" to be precise.

**Kruskal's MST end-to-end:** O(E log E) dominated by sorting edges; the E Union-Find operations add only O(E · α(V)), which is lower-order. So MST via Union-Find is O(E log E) = O(E log V).

## Key Properties

- **Core invariant:** every element points toward its set's root; two elements are in the same set iff `find` returns the same root. `union` only ever changes a *root's* parent pointer.
- **Union by rank:** `rank` is an *upper bound on tree height* (not exact height, because compression shrinks trees without decrementing rank). Attach the lower-rank root under the higher-rank root; on a tie, pick either and increment its rank. Keeps height O(log n) before compression.
- **Union by size** is an equivalent alternative: attach the smaller tree (by element count) under the larger. Same O(log n) height guarantee; size is also directly useful (component sizes) so many prefer it.
- **Path compression** repoints every node on the find path directly to the root. It never breaks correctness because a node's set identity = its root, and the root is unchanged.
- **Amortization is essential:** a single `find` can still be O(log n), but that expensive call flattens the path so subsequent finds are O(1) — averaged over m operations the cost is O(α(n)) each.
- **Rank is never decremented** even after compression flattens the tree; it stays an upper bound, which is all the proof needs.

## Common Pitfalls

- **Using it on a directed graph.** Union-Find models *undirected* connectivity only. `find(u) == find(v)` says nothing about a directed path; it cannot detect directed cycles or SCCs.
- **Detecting the cycle *after* unioning.** For undirected cycle detection you must check `find(u) == find(v)` **before** the `union`. If you union first, they're always in the same set and every edge looks like a cycle.
- **Forgetting to union by rank/size — or forgetting compression.** With only one heuristic you silently drop to O(log n) per op; with neither, adversarial input degrades to O(n). Both are needed for α(n).
- **Comparing raw elements instead of roots.** `union(x, y)` and same-set checks must operate on `find(x)`/`find(y)` (the roots), not on `x`/`y` directly, or you corrupt the forest.
- **Incrementing rank on every union.** Rank only increases on a **tie**. Incrementing unconditionally inflates ranks and breaks the height bound.
- **Recursive `find` stack overflow.** On a large near-degenerate forest built before the first compression, deep recursion can overflow. Prefer iterative find with a second pass, or two-pass path compression.
- **Off-by-one on component count.** Track a `count` initialized to `n` and decrement it only when a `union` actually merges two *distinct* sets (roots differ) — not on every `union` call.

## Implementation Notes

Reference implementation with **union by rank + path compression** (iterative find), plus the two canonical applications.

```javascript
class UnionFind {
  constructor(n) {
    this.parent = Array.from({ length: n }, (_, i) => i); // each node its own root
    this.rank = new Array(n).fill(0);                     // upper bound on height
    this.count = n;                                       // number of disjoint sets
  }

  find(x) {
    let root = x;
    while (this.parent[root] !== root) root = this.parent[root]; // walk to root
    while (this.parent[x] !== root) {                    // second pass: compress
      const next = this.parent[x];
      this.parent[x] = root;                             // repoint straight to root
      x = next;
    }
    return root;
  }

  union(x, y) {
    const rx = this.find(x), ry = this.find(y);
    if (rx === ry) return false;                         // already connected (cycle if undirected edge)
    if (this.rank[rx] < this.rank[ry]) {                 // attach smaller rank under larger
      this.parent[rx] = ry;
    } else if (this.rank[rx] > this.rank[ry]) {
      this.parent[ry] = rx;
    } else {
      this.parent[ry] = rx;                              // tie: pick one, bump its rank
      this.rank[rx]++;
    }
    this.count--;                                        // two sets became one
    return true;
  }

  connected(x, y) {
    return this.find(x) === this.find(y);
  }
}

// ── Undirected cycle detection ──────────────────────────────────────────────
// A cycle exists iff some edge connects two already-connected vertices.
function hasCycle(n, edges) {
  const uf = new UnionFind(n);
  for (const [u, v] of edges) {
    if (!uf.union(u, v)) return true; // union returned false => same set => cycle
  }
  return false;
}

// ── Kruskal's Minimum Spanning Tree ─────────────────────────────────────────
function kruskal(n, edges) { // edges: [weight, u, v]
  edges.sort((a, b) => a[0] - b[0]);   // ascending by weight  → O(E log E)
  const uf = new UnionFind(n);
  let totalWeight = 0, used = 0;
  for (const [w, u, v] of edges) {
    if (uf.union(u, v)) {              // only add if it joins two components
      totalWeight += w;
      if (++used === n - 1) break;     // MST has exactly n-1 edges
    }
  }
  return totalWeight;
}
```

```python
class UnionFind:
    def __init__(self, n):
        self.parent = list(range(n))   # each node its own root
        self.rank = [0] * n            # upper bound on height
        self.count = n                 # number of disjoint sets

    def find(self, x):
        root = x
        while self.parent[root] != root:
            root = self.parent[root]
        while self.parent[x] != root:  # path compression (second pass)
            self.parent[x], x = root, self.parent[x]
        return root

    def union(self, x, y):
        rx, ry = self.find(x), self.find(y)
        if rx == ry:
            return False               # already connected
        if self.rank[rx] < self.rank[ry]:
            rx, ry = ry, rx            # ensure rx is the taller root
        self.parent[ry] = rx
        if self.rank[rx] == self.rank[ry]:
            self.rank[rx] += 1         # only bump on a tie
        self.count -= 1
        return True
```

## Variants

- **Union by size** — attach the tree with fewer elements under the larger; store `size[root]` instead of `rank`. Same O(α(n)) with compression, and gives component sizes for free.
- **Weighted / relational DSU (union with parity or offset)** — store each node's relation to its parent (e.g. a bit for bipartite parity, or a numeric potential). `find` accumulates the offset while compressing. Solves "bipartite check via odd-cycle detection", "equations with variable ratios", and "detect contradictions in relative constraints".
- **Rollback / persistent DSU** — union by rank/size *without* path compression so unions can be undone via a stack; used in offline dynamic-connectivity and segment-tree-on-time techniques (path compression is incompatible with rollback).
- **Small-to-large merging** — the same "attach smaller under larger" idea applied to merging auxiliary structures (sets, maps) on tree/graph problems, bounding total work at O(n log n).

## Resources

- CLRS, *Introduction to Algorithms* — "Data Structures for Disjoint Sets" (Ch. 19 in 4th ed., Ch. 21 in 3rd ed.): forest representation, union by rank, path compression, and the O(m·α(n)) analysis
- cp-algorithms — Disjoint Set Union: https://cp-algorithms.com/data_structures/disjoint_set_union.html
- NeetCode roadmap (Advanced Graphs / Union-Find section): https://neetcode.io/roadmap
- Tarjan (1975), "Efficiency of a Good But Not Linear Set Union Algorithm" — original α(n) upper and lower bound

## Related

- [[graphs]]
- [[minimum-spanning-tree]]
- [[dfs]]
- [[bfs]]
- [[topological-sort]]
