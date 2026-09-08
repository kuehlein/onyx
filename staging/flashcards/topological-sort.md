---
id: topological-sort
type: flashcard
tags:
  - ds-a
  - graph
tiers:
  ds-a: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Topological Sort

A topological sort is a linear ordering of the vertices of a [DAG](_meta/glossary.md#dag) such that for every directed edge `u → v`, `u` appears before `v`. It exists **iff the graph is acyclic** — a cycle would force some vertex to precede itself. The ordering is generally not unique. The principle behind every implementation: emit a vertex only once all of its dependencies (predecessors) have already been emitted, which is exactly what "every edge points forward" means.

> [!tip] Recognition signal
> Reach for topological sort when the problem is about **ordering under dependencies** — "you must do A before B", prerequisites, build/compile order, task scheduling — over a set of items whose relationships form a directed graph. If you also need to detect an impossible schedule, that is a **cycle check**, which topological sort gives you for free.

## When to Use

**Problem signals that suggest Topological Sort:**
- The problem gives **dependencies / prerequisites**: "course B requires course A", "task X must finish before Y", "package depends on package Z"
- You must produce a **valid order** to process items, or count/verify that one exists — build systems, makefiles, spreadsheet cell recalculation, symbol resolution
- The input is (or can be modeled as) a **directed graph** and you need a linear sequence respecting edge direction
- Keywords: "**order**", "**sequence**", "**schedule**", "**prerequisite**", "**dependency**", "**before/after**", "can this be completed?", "**alien dictionary**" (derive letter order from constraints)
- You need to **detect a cycle** in a directed graph as a byproduct ("is the schedule feasible?" ⇒ acyclic?)

**Prefer Topological Sort over alternatives when:**
- Over plain [DFS](_meta/glossary.md#dfs)/[BFS](_meta/glossary.md#bfs) traversal: when the *order between dependent items* is the answer, not mere reachability or connectivity
- Over sorting by a key: when there is no total order — only **partial** pairwise constraints — so a comparison sort has no comparator to use
- Over [DP](_meta/glossary.md#dp) on a DAG: topological order is often the *setup* for DAG-DP (process vertices in topo order so subproblems are ready); use topo sort first, then relax

**Do not use when:**
- The graph is **undirected** or may contain cycles that are legal → topological order is undefined; use union-find / [SCC](_meta/glossary.md#scc) / cycle handling instead
- You need a specific *optimal* ordering (shortest, min-cost) rather than any valid one → that is DAG shortest/longest path (topo order + relaxation), not bare topo sort
- The relation is a true **total order** already (numbers, timestamps) → just sort, O(n log n) with no graph

## Time & Space Complexity

Both standard algorithms are linear in the size of the graph because each vertex and each edge is touched a constant number of times.

| Method | Time | Space | Notes |
|---|---|---|---|
| Kahn (BFS on in-degree) | O(V + E) | O(V) | queue + in-degree array; result list |
| DFS (reverse post-order) | O(V + E) | O(V) | recursion/explicit stack O(V) depth + visited state |
| Cycle detection (either) | O(V + E) | O(V) | no extra asymptotic cost |

**Why O(V + E):** computing in-degrees scans every edge once (O(E)); each vertex enters and leaves the queue exactly once (O(V)); decrementing neighbors' in-degrees processes each edge exactly once more (O(E)). DFS visits each vertex once and traverses each adjacency-list edge once. Adjacency **list** is assumed — an adjacency matrix makes neighbor scans O(V²).

**Space** is O(V) auxiliary: in-degree array + queue (Kahn), or visited/state array + recursion stack up to depth O(V) (DFS). Output list is O(V).

## Key Properties

- **Existence ⇔ acyclicity.** A topological ordering exists **if and only if** the directed graph has no cycle (is a DAG). This is the invariant both algorithms exploit and test.
- **Not unique.** Any vertex with no unmet dependencies can go next; different tie-break choices yield different valid orders. Kahn with a min-heap instead of a [FIFO](_meta/glossary.md#fifo) queue yields the *lexicographically smallest* order.
- **Kahn invariant:** a vertex is emitted only when its **in-degree reaches 0**, i.e. all predecessors are already placed. Vertices trapped in a cycle never reach in-degree 0.
- **DFS invariant:** for every edge `u → v` in a DAG, `v` **finishes before** `u` (`f[v] < f[u]`), because a DAG has no back edges. So listing vertices in **decreasing finish time** (reverse post-order) is a valid topo order — this is the CLRS result.
- **Cycle detection is free:** Kahn — if fewer than `V` vertices are emitted, the leftover vertices lie on/after a cycle. DFS — encountering a **gray (in-progress) vertex** during recursion is a back edge ⇒ cycle.

## Common Pitfalls

- **Forgetting the cycle check.** On cyclic input, DFS post-order silently returns a *complete-looking but wrong* order — no error thrown. You must track a gray/in-recursion set (or verify Kahn emitted all `V`) to reject cycles. A plain `visited` boolean is not enough to detect a cycle.
- **Reversing (or not) the DFS output.** DFS gives reverse topological order; you must **reverse the post-order list** (or push to a stack and pop). Emitting in finish order without reversing gives the exact opposite ordering.
- **Wrong edge direction.** "A depends on B" must become edge `B → A` (B before A) — or you must reverse the final result. Getting the arrow backwards produces a perfectly valid topo sort of the *wrong* graph.
- **Recursion depth.** DFS recursion can blow the stack on a long chain (`V` deep). Use an explicit stack or Kahn (iterative) for large graphs.
- **Disconnected graph.** Multiple components / multiple in-degree-0 roots are normal — start DFS from *every* unvisited vertex; seed Kahn's queue with *all* in-degree-0 vertices, not just one.
- **Multi-edges / self-loops.** A self-loop `v → v` is a cycle (no valid order). Duplicate edges inflate in-degree counts — decrement consistently.

## Implementation Notes

Kahn is usually preferred in interviews: iterative (no stack-overflow risk) and its cycle check falls out naturally.

```python
from collections import deque

def topo_sort_kahn(n, edges):
    """n vertices [0..n), edges as (u, v) meaning u must come before v.
       Returns a valid order, or None if a cycle exists."""
    adj = [[] for _ in range(n)]
    indeg = [0] * n
    for u, v in edges:
        adj[u].append(v)
        indeg[v] += 1

    q = deque(i for i in range(n) if indeg[i] == 0)  # all roots
    order = []
    while q:
        u = q.popleft()
        order.append(u)
        for w in adj[u]:
            indeg[w] -= 1
            if indeg[w] == 0:
                q.append(w)

    return order if len(order) == n else None  # < n ⇒ cycle
```

```js
// DFS (reverse post-order) with cycle detection via 3-color marking.
function topoSortDFS(n, edges) {
  const adj = Array.from({ length: n }, () => []);
  for (const [u, v] of edges) adj[u].push(v);

  const state = new Array(n).fill(0); // 0=white(unseen) 1=gray(in-stack) 2=black(done)
  const order = [];
  let hasCycle = false;

  const dfs = (u) => {
    state[u] = 1;                       // gray
    for (const w of adj[u]) {
      if (state[w] === 1) { hasCycle = true; return; } // back edge ⇒ cycle
      if (state[w] === 0) dfs(w);
    }
    state[u] = 2;                       // black
    order.push(u);                      // post-order
  };

  for (let i = 0; i < n && !hasCycle; i++) if (state[i] === 0) dfs(i);
  return hasCycle ? null : order.reverse(); // reverse post-order = topo order
}
```

## Variants

- **Kahn with min-heap** — replace the FIFO queue with a priority queue to get the lexicographically smallest valid ordering (common follow-up).
- **All topological orderings** — backtracking over in-degree-0 choices; exponential, used when every valid order is needed.
- **DAG shortest/longest path** — relax edges in topological order for O(V+E) shortest/longest paths (critical-path / project scheduling); longest path underlies critical-path method.
- **Lexicographically-constrained scheduling** — e.g. alien dictionary: build edges from adjacent-word differences, then topo sort the alphabet.
- **Cycle-detection-only** — when you just need "is it schedulable?", either algorithm answers without materializing the full order.

## Resources

- CLRS, *Introduction to Algorithms* 3rd ed., §22.4 "Topological sort" (DFS finish-time proof)
- cp-algorithms — Topological Sort: https://cp-algorithms.com/graph/topological-sort.html
- GeeksforGeeks — Kahn's algorithm (in-degree BFS): https://www.geeksforgeeks.org/dsa/topological-sorting-indegree-based-solution/
- NeetCode — Course Schedule II (canonical topo-sort problem): https://neetcode.io/problems/course-schedule-ii

## Related

- [[dfs]]
- [[bfs]]
- [[graphs]]
- [[cycle-detection]]
- [[dynamic-programming-2d]]
