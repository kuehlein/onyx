---
id: dijkstra-shortest-path
type: flashcard
tags:
  - ds-a
  - graph
  - shortest-path
  - greedy
tiers:
  ds-a: 3
created: 2026-09-08
confidence: high
priority: normal
---

# Dijkstra Shortest Path

Dijkstra computes single-source shortest paths on a graph with **non-negative** edge weights. It is a greedy algorithm: it repeatedly pops the unfinished node with the smallest tentative distance from a min-priority-queue, "finalizes" it, and **relaxes** its outgoing edges (updates a neighbor's distance if going through the popped node is cheaper). The greedy choice is only correct because non-negative weights guarantee that once a node is popped with the minimum distance, no later path can improve it — a negative edge would break that invariant.

> [!tip] Recognition
> Reach for Dijkstra when the graph is **weighted with non-negative edges** and you need the **shortest / cheapest / minimum-cost path** from one source (to one target or all nodes). Signals: "minimum cost to reach", "cheapest route", weighted grid/network, edge costs that are distances, times, or prices.

## When to Use

- Single-source shortest path on a graph where **every edge weight ≥ 0** (distances, latencies, tolls, positive costs).
- You need shortest distance from one source to one target, or to all reachable nodes.
- Works on directed or undirected, dense or sparse graphs.

**vs. BFS:** [BFS](_meta/glossary.md#bfs) gives shortest path only on **unweighted** graphs (every edge = cost 1), running in O(V+E). If edges have differing non-negative weights, BFS is wrong — use Dijkstra. (Dijkstra with all-equal weights degenerates to BFS but with heap overhead.)

**vs. Bellman-Ford:** if any edge weight is **negative**, Dijkstra is incorrect (its finalized-node invariant fails). Use Bellman-Ford, which handles negative edges and detects negative cycles, at O(V·E).

**vs. A\*:** when you have a single target and an admissible **heuristic** estimating remaining distance (e.g., straight-line distance on a map), A\* explores far fewer nodes. Dijkstra is A\* with a zero heuristic.

**vs. graphs (the general card):** "graphs" is the representation and traversal toolkit (adjacency list/matrix, connectivity, BFS/DFS order). Dijkstra is one specific *weighted-shortest-path* algorithm built on top of it. Distinguishing signal: reach for Dijkstra only when the ask is a **minimum-cost path over non-negative edge weights** — not mere reachability, ordering, or component structure.

## Key Properties

- **Greedy + non-negative weights.** Once a node is popped from the min-heap, its shortest distance is final; this only holds because no edge can later reduce it (all weights ≥ 0).
- **Relaxation.** For edge u→v with weight w: if `dist[u] + w < dist[v]`, update `dist[v]` and push v with the new key. Track predecessors to reconstruct the actual path.
- **Lazy deletion.** Standard heap-based Dijkstra pushes duplicate stale entries rather than doing a decrease-key; when a node is popped, skip it if its popped distance exceeds the recorded `dist`.

## Trade-offs

- **Correctness is conditional:** it is only valid for non-negative weights. It silently returns wrong answers (not an error) on negative edges.
- **Heap choice affects complexity:** binary heap gives O((V+E) log V); a Fibonacci heap gives O(E + V log V) in theory but is rarely worth the constants in practice.
- **Single-source only.** For all-pairs shortest paths use Floyd-Warshall (O(V³)) or run Dijkstra from every source.

## Common Pitfalls

- **Using it with negative edges.** The finalized-node invariant breaks; you get wrong distances silently. This is the single most-tested trap — reach for Bellman-Ford instead.
- **Not skipping stale heap entries.** With lazy deletion, you must discard a popped entry whose distance is greater than the current best `dist[node]`, or you re-process nodes and can corrupt results/blow up runtime.
- **Confusing "visited when pushed" with "visited when popped."** A node is only finalized when **popped**, not when first discovered. Marking finalized on push can prevent a later, cheaper relaxation from being applied.
- **Assuming BFS suffices on a weighted graph.** BFS counts edges, not weights; it finds the fewest-hops path, not the cheapest.
- **Forgetting to store predecessors** when the problem asks for the path itself, not just the distance.

## Time & Space Complexity

| Implementation | Time | Space |
|---|---|---|
| Binary min-heap (typical) | O((V + E) log V) | O(V + E) |
| Fibonacci heap | O(E + V log V) | O(V + E) |
| Array/linear scan (dense graphs) | O(V²) | O(V + E) |

**Why O((V+E) log V):** each of V nodes is popped once and each of E edges may trigger a heap push, and every heap operation costs O(log V) (heap holds up to O(E) entries with lazy deletion, but log E = O(log V) since E ≤ V²). For **dense** graphs (E ≈ V²), the O(V²) array version can beat the heap version.

## Implementation Notes

```python
import heapq

def dijkstra(graph, source):          # graph: {u: [(v, weight), ...]}, weights >= 0
    dist = {source: 0}
    prev = {}
    pq = [(0, source)]                 # (tentative_distance, node)
    while pq:
        d, u = heapq.heappop(pq)
        if d > dist.get(u, float("inf")):
            continue                    # stale entry — u already finalized
        for v, w in graph.get(u, ()):
            nd = d + w
            if nd < dist.get(v, float("inf")):
                dist[v] = nd            # relax edge u -> v
                prev[v] = u
                heapq.heappush(pq, (nd, v))
    return dist, prev                   # reconstruct path by walking prev backward
```

## Resources

- CLRS, *Introduction to Algorithms* (4th ed.), ch. 22 "Single-Source Shortest Paths" (Dijkstra + Bellman-Ford)
- Python `heapq` docs: https://docs.python.org/3/library/heapq.html
- NeetCode graph roadmap: https://neetcode.io/roadmap

## Related

- [[bfs]]
- [[graphs]]
- [[heap]]
- [[greedy]]
