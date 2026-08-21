---
id: d628d657-b67f-42df-86d7-d93238d136b4
type: flashcard
tags:
  - ds-a
  - bfs
  - graph
  - tree
tiers:
  ds-a: 2
created: 2026-08-20
confidence: medium
---

# Breadth-First Search (BFS)

BFS explores all nodes at the current distance from the source before advancing to nodes one step farther away — a queue enforces this level-by-level guarantee. Because BFS visits nodes in non-decreasing order of edge count from the source, it finds the **shortest path (fewest edges)** in unweighted graphs and answers any question about the minimum number of "steps" to reach a target.

## When to Use

**Problem signals that suggest BFS:**
- "Minimum number of steps / moves / jumps / transformations" to reach a goal
- "Shortest path" in an unweighted graph or grid (each edge/cell costs 1)
- "Nearest / closest node" satisfying some condition
- Level-order traversal of a tree ("return nodes level by level", "right-side view", "average of each level")
- "Spread" problems where something propagates one unit per time step (rotting oranges, infection, walls falling)
- Graphs where all edge weights are equal (or can be treated as equal)
- Finding the minimum depth of a binary tree

**Keywords that frequently appear:** "minimum", "shortest", "fewest", "nearest", "level by level", "steps", "hops"

**Prefer BFS over alternatives when:**
- Over DFS: you need the **shortest path** in an unweighted graph — DFS finds *a* path, not necessarily the shortest
- Over Dijkstra: all edge weights are equal (BFS is simpler and O(V+E) vs O((V+E) log V))
- Over BFS with one source: when the problem has **multiple simultaneous sources** (e.g., "distance from nearest 0"), seed the queue with all sources at once (multi-source BFS)

**Do not use when:**
- Edge weights differ → use Dijkstra (non-negative weights) or Bellman-Ford (negative weights)
- You need to explore all paths or enumerate combinations → use DFS / backtracking
- The graph is a DAG and you need shortest weighted path → topological sort + DP
- The search space is enormous and the goal is deep → consider bidirectional BFS or A*

## Time & Space Complexity

| Variant | Time | Space |
|---|---|---|
| Tree BFS | O(n) | O(w) — w = max width of tree |
| Graph BFS | O(V + E) | O(V) — visited set + queue |
| Grid BFS (r×c) | O(r·c) | O(r·c) |

**Why O(V + E):** every vertex is enqueued exactly once (visited set prevents re-enqueuing), and every edge is examined exactly once when its source vertex is dequeued. The queue never holds more than one full "frontier level" at a time, hence O(V) space in the worst case (a star graph where all nodes are neighbors of the root).

## Key Properties

- **Completeness:** BFS always finds a path if one exists (for finite graphs).
- **Optimality:** BFS finds the path with the fewest edges in an unweighted graph.
- **FIFO order:** the queue is the structural reason for both properties — nodes dequeued earlier were enqueued earlier (i.e., discovered at a smaller depth).
- **Level invariant:** all nodes at depth d are fully processed before any node at depth d+1 is processed. This makes it natural to track which "level" (step count) you are on by either using a sentinel or noting queue size at the start of each level.

## Common Pitfalls

- **Forgetting the visited set in graphs** — without it, BFS loops on cycles and never terminates. Mark nodes visited *at enqueue time*, not at dequeue time; marking at dequeue allows the same node to be enqueued multiple times, wasting work and potentially causing incorrect distance counts.
- **Forgetting multi-source BFS** — if you run BFS from each source separately and aggregate, you lose O(n) time. Seed all sources into the queue at depth 0 and let BFS spread from all of them simultaneously.
- **Modifying the grid in-place instead of a visited set** — acceptable when the grid can be mutated, but easy to forget to restore if the function is called multiple times.
- **Off-by-one on step count** — the number of levels processed equals the distance. Be precise about whether you increment the step counter before or after processing a level.
- **Using BFS on a weighted graph and expecting shortest paths** — BFS finds the path with the fewest edges, not the minimum total weight.

## Implementation Notes

### Tree BFS — level-order traversal

```js
function levelOrder(root) {
  if (!root) return [];
  const result = [];
  const queue = [root]; // seed with root

  while (queue.length > 0) {
    const levelSize = queue.length; // snapshot: nodes at current depth
    const level = [];

    for (let i = 0; i < levelSize; i++) {
      const node = queue.shift(); // dequeue front
      level.push(node.val);
      if (node.left)  queue.push(node.left);  // enqueue children
      if (node.right) queue.push(node.right);
    }

    result.push(level);
    // after this inner loop, queue holds exactly the next level
  }

  return result;
}
```

> Note: `queue.shift()` is O(n) — for performance-sensitive work, use a pointer
> (`let head = 0; queue[head++]`) instead of mutating the array.

### Graph BFS — shortest path (adjacency list)

```js
function bfs(graph, start, target) {
  // graph: Map<node, node[]> — adjacency list (directed or undirected)
  const visited = new Set([start]); // mark visited AT ENQUEUE TIME
  const queue = [[start, 0]];       // [node, distance]

  while (queue.length > 0) {
    const [node, dist] = queue.shift();

    if (node === target) return dist; // found shortest path

    for (const neighbor of (graph.get(node) ?? [])) {
      if (!visited.has(neighbor)) {
        visited.add(neighbor);         // mark before pushing to prevent duplicates
        queue.push([neighbor, dist + 1]);
      }
    }
  }

  return -1; // target unreachable
}

// Build an undirected adjacency list:
function buildGraph(edges) {
  const graph = new Map();
  for (const [u, v] of edges) {
    if (!graph.has(u)) graph.set(u, []);
    if (!graph.has(v)) graph.set(v, []);
    graph.get(u).push(v);
    graph.get(v).push(u); // omit this line for directed graphs
  }
  return graph;
}
```

### Grid BFS — shortest path in a 2-D grid

```js
function shortestPath(grid, start, end) {
  const rows = grid.length, cols = grid[0].length;
  const [sr, sc] = start, [er, ec] = end;
  const dirs = [[0,1],[0,-1],[1,0],[-1,0]]; // 4-directional

  // Use a 2-D visited array instead of a Set for O(1) lookup
  const visited = Array.from({ length: rows }, () => new Array(cols).fill(false));
  visited[sr][sc] = true;

  const queue = [[sr, sc, 0]]; // [row, col, steps]

  while (queue.length > 0) {
    const [r, c, steps] = queue.shift();
    if (r === er && c === ec) return steps;

    for (const [dr, dc] of dirs) {
      const nr = r + dr, nc = c + dc;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols
          && !visited[nr][nc] && grid[nr][nc] !== 1 /* wall */) {
        visited[nr][nc] = true;
        queue.push([nr, nc, steps + 1]);
      }
    }
  }

  return -1; // no path
}
```

### Multi-source BFS

```js
// Example: distance from nearest 0 in a binary grid
function updateMatrix(mat) {
  const rows = mat.length, cols = mat[0].length;
  const dist = Array.from({ length: rows }, () => new Array(cols).fill(Infinity));
  const queue = [];

  // Seed all 0-cells simultaneously — they are all at distance 0
  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (mat[r][c] === 0) {
        dist[r][c] = 0;
        queue.push([r, c]);
      }
    }
  }

  const dirs = [[0,1],[0,-1],[1,0],[-1,0]];
  while (queue.length > 0) {
    const [r, c] = queue.shift();
    for (const [dr, dc] of dirs) {
      const nr = r + dr, nc = c + dc;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols
          && dist[nr][nc] > dist[r][c] + 1) {
        dist[nr][nc] = dist[r][c] + 1;
        queue.push([nr, nc]);
      }
    }
  }

  return dist;
}
```

## Variants

| Variant | When to reach for it |
|---|---|
| **Multi-source BFS** | Multiple simultaneous origins; distance from nearest of a set |
| **0-1 BFS** | Edge weights are only 0 or 1; use a deque — push 0-cost to front, 1-cost to back |
| **Bidirectional BFS** | Search space is huge but answer depth is moderate; alternates BFS from both ends, meeting in the middle — reduces effective branching factor from b^d to ~2·b^(d/2) |
| **BFS on implicit graph** | Nodes are states (e.g., word ladder, sliding puzzle); build neighbors on the fly instead of pre-building an adjacency list |

## Resources

- CLRS 4th ed., Chapter 22.2 — Breadth-First Search
- NeetCode BFS playlist: https://neetcode.io/courses/advanced-algorithms/0
- LeetCode BFS topic: https://leetcode.com/tag/breadth-first-search/

## Related

- [[depth-first-search]]
- [[dijkstra-shortest-path]]
- [[topological-sort]]
- [[graph-adjacency-list]]
