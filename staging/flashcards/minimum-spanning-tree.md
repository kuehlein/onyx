---
id: minimum-spanning-tree
type: flashcard
tags:
  - ds-a
  - graph
  - greedy
tiers:
  ds-a: 3
created: 2026-09-08
confidence: high
priority: normal
---

# Minimum Spanning Tree (MST)

A minimum spanning tree ([MST](_meta/glossary.md#mst)) of a connected, undirected, weighted graph is the cheapest subset of edges that connects **all** vertices with **no cycle** — exactly V-1 edges spanning V nodes at minimum total weight. Both standard algorithms are greedy and justified by the **cut property**: for any partition of the vertices into two sets, the minimum-weight edge crossing that cut is always safe to include in some MST. Kruskal grows a forest by repeatedly taking the globally cheapest edge that does not form a cycle; Prim grows a single tree by repeatedly taking the cheapest edge leaving it.

> [!tip] Recognition
> Reach for MST when the problem says "**connect all** X at **minimum total cost**" over an **undirected weighted** graph — laying cable/roads/pipes between every site, clustering points by cheapest links, or any "minimize the sum of chosen connection weights so everything is reachable." The objective is the *total weight of the whole tree*, not the distance between any specific pair.

## When to Use

**Problem signals that suggest MST:**
- "Connect every node/city/computer" while "**minimizing total wiring/cost/weight**" — the answer is a set of edges, not a path
- The graph is **undirected** and **weighted**, and you need a **cycle-free** connecting subgraph
- Clustering: removing the k-1 most expensive MST edges yields k clusters (single-linkage clustering)
- "Minimum cost to make all points connected" / "min cost to supply water/electricity to all houses"

**Prefer Kruskal when:**
- The graph is **sparse** (E close to V) or edges are already sorted / cheap to sort
- Edges come as a flat list rather than an adjacency structure — Kruskal just needs the edge list plus union-find

**Prefer Prim when:**
- The graph is **dense** (E close to V²) — growing from a heap of frontier edges avoids sorting all edges
- You already have an adjacency list and a natural start vertex

**Do not use when:**
- You need the shortest path **from a source** to other nodes → use Dijkstra/[BFS](_meta/glossary.md#bfs), NOT MST (different objective — see contrast below)
- The graph is **directed** — MST is undefined; the directed analogue is a minimum spanning arborescence (Edmonds' algorithm)
- The graph is **disconnected** — no spanning tree exists; you get a minimum spanning *forest* instead

> [!warning] Contrast — MST vs. Dijkstra vs. Union-Find
> **MST vs. Dijkstra:** MST minimizes the **TOTAL weight of the whole tree** (a global connect-everything objective, no source); Dijkstra minimizes the **path cost FROM a fixed source** to each node. The MST path between two nodes is often NOT their shortest path — different objectives, do not substitute one for the other.
> **MST vs. Union-Find:** MST is the *problem/answer* (a set of edges); union-find is a *tool* Kruskal uses to test whether an edge would close a cycle. If the task is only "are these two nodes connected / merge groups" with no edge-weight minimization, you want union-find alone, not an MST.

## Key Properties

- **Cut property (why greedy works):** for any cut of the vertices into two nonempty sets, the minimum-weight edge crossing the cut belongs to some MST. This single fact justifies both Kruskal and Prim — each step adds a safe minimum crossing edge.
- **Cycle property:** if an edge is the *unique* maximum-weight edge on some cycle, it is in no MST (it can always be dropped and the cycle reconnected by a cheaper edge). With tied maxima the edge may still appear in some MST.
- **Structure:** an MST has exactly **V-1 edges** and contains **no cycle**; it spans all V vertices.
- **Uniqueness:** if all edge weights are **distinct**, the MST is unique. Ties can produce multiple MSTs (all with equal total weight).
- **Not a shortest-path tree:** minimizing total tree weight does not minimize source-to-node distances.

## Trade-offs

| Aspect | Kruskal | Prim (binary heap) |
|---|---|---|
| Core mechanism | Sort edges; add cheapest non-cycle edge | Grow one tree; pull cheapest frontier edge |
| Cycle check | **Union-find** (disjoint set) | Implicit — heap tracks in/out of tree |
| Time | O(E log E) = O(E log V) | O(E log V) |
| Best fit | Sparse graphs / edge list given | Dense graphs / adjacency list given |
| Data structure | Union-find + sorted edge list | Min-heap keyed by frontier edge weight |

> Note: log E and log V are within a constant factor since E ≤ V², so both are O(E log V). Prim with a Fibonacci heap is O(E + V log V) — better asymptotically for dense graphs but rarely used in interviews.

## Common Pitfalls

- **Confusing MST with shortest path.** Building an MST and reading off a "path" between two nodes gives the wrong answer for shortest distance — that is Dijkstra's job. (Highest-value distinction.)
- **Kruskal without a union-find cycle check.** The whole point of Kruskal is that adding an edge is safe *iff* its two endpoints are in different components. Detecting cycles by other means (e.g., [DFS](_meta/glossary.md#dfs) per edge) blows up the complexity.
- **Applying MST to a directed graph.** MST assumes undirected edges; on directed graphs you need a minimum arborescence (Edmonds/Chu–Liu), which is a different algorithm.
- **Assuming the graph is connected.** If it is not, there is no spanning tree — check connectivity (or expect a spanning forest) rather than returning a wrong "tree."
- **Prim: not using a lazy/decrease-key discipline.** With a lazy heap you may push stale (outdated) edges; skip any popped edge whose endpoint is already in the tree, or you will add cycles.

## Time & Space Complexity

| Algorithm | Time | Space |
|---|---|---|
| Kruskal (sort + union-find) | O(E log E) = O(E log V) | O(V) for union-find (+ edge list) |
| Prim (binary heap) | O(E log V) | O(V + E) for heap + adjacency |
| Prim (Fibonacci heap) | O(E + V log V) | O(V + E) |

**Why Kruskal is O(E log E):** sorting the E edges dominates; each of the E union/find operations is near-constant (inverse-Ackermann α) with union by rank + [path compression](_meta/glossary.md#path-compression). Since E ≤ V², log E ≤ 2 log V, so O(E log E) = O(E log V).

**Why Prim is O(E log V):** each edge can trigger a heap push, and each of the up-to-E heap operations costs O(log V) (the heap holds at most O(V) or O(E) entries depending on lazy vs. eager).

## Implementation Notes

```python
# ── KRUSKAL: sort edges, add cheapest that doesn't create a cycle ──────────
# edges: list of (weight, u, v); n vertices labeled 0..n-1
def kruskal(n, edges):
    parent = list(range(n))
    rank = [0] * n

    def find(x):                       # path compression
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):                   # union by rank; False if already joined (cycle)
        ra, rb = find(a), find(b)
        if ra == rb:
            return False               # same component → edge would form a cycle
        if rank[ra] < rank[rb]:
            ra, rb = rb, ra
        parent[rb] = ra
        if rank[ra] == rank[rb]:
            rank[ra] += 1
        return True

    total, used = 0, 0
    for w, u, v in sorted(edges):      # cheapest edges first
        if union(u, v):                # only add if it joins two components
            total += w
            used += 1
    return total if used == n - 1 else None   # None → graph disconnected


# ── PRIM: grow one tree, pull cheapest edge leaving it via a min-heap ──────
import heapq

def prim(n, adj):                      # adj[u] = list of (weight, v)
    visited = [False] * n
    heap = [(0, 0)]                    # (weight, vertex); start from vertex 0
    total, count = 0, 0
    while heap and count < n:
        w, u = heapq.heappop(heap)
        if visited[u]:                 # skip stale entries (lazy deletion)
            continue
        visited[u] = True
        total += w
        count += 1
        for wt, v in adj[u]:
            if not visited[v]:
                heapq.heappush(heap, (wt, v))
    return total if count == n else None   # None → graph disconnected
```

## Variants

- **Minimum spanning forest** — run either algorithm to completion on a disconnected graph; you get one MST per connected component.
- **Maximum spanning tree** — negate weights (or sort descending) to maximize total weight.
- **Minimum spanning arborescence** — the directed-graph analogue (Edmonds' / Chu–Liu algorithm); MST algorithms do not apply.
- **Borůvka's algorithm** — a third classic MST algorithm that adds the cheapest edge out of every component in parallel rounds; basis for fast parallel MST.

## Resources

- CLRS, *Introduction to Algorithms*, ch. 21 (Minimum Spanning Trees) — cut property, Kruskal, Prim
- Kruskal reference: https://en.wikipedia.org/wiki/Kruskal%27s_algorithm
- Prim reference: https://en.wikipedia.org/wiki/Prim%27s_algorithm
- CP-Algorithms MST: https://cp-algorithms.com/graph/mst_kruskal.html

## Related

- [[union-find]]
- [[dijkstra-shortest-path]]
- [[graph-traversal-bfs-dfs]]
- [[heap]]
