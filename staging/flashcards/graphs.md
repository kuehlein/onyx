---
id: 7f3a2c1e-84b6-4d09-b2f7-e5c3a1d09f82
type: flashcard
tags:
  - ds-a
  - graph
  - data-structures
tiers:
  ds-a: 2
created: 2026-08-20
confidence: high
priority: normal
---

# Graphs

A graph is a set of **nodes (vertices)** connected by **edges**; it generalizes trees by allowing arbitrary connections, cycles, and multiple components. Every tree is a graph, but not every graph is a tree — the key difference is that graphs permit cycles and disconnected components.

> [!warning] Mark visited *before* enqueuing, and loop over all nodes
> Adding to `visited` only after dequeuing lets duplicates pile up and cycles loop forever. For disconnected graphs, kick off [BFS](_meta/glossary.md#bfs)/[DFS](_meta/glossary.md#dfs) from every unvisited node — starting only at node 0 misses whole components.

## When to Use

**Problem signals that suggest Graphs:**
- The problem describes pairwise **relationships** between entities (friendships, dependencies, roads, pipes, courses)
- You need to find a **path**, **shortest path**, or determine **reachability** between two nodes
- The problem involves **cycles** — detecting them, avoiding them, or counting them
- Entities form a **network** where local connections create global structure (social graph, call graph, city map)
- Keywords: "connected components", "islands", "regions", "prerequisites", "dependency order", "bidirectional", "network flow"
- The input is an **adjacency list**, **edge list**, or **grid where cells are nodes**

**Prefer Graphs over alternatives when:**
- Over trees: the relationship is not strictly hierarchical or cycles are possible
- Over arrays/matrices: you need to traverse based on *connectivity*, not position
- Over disjoint-set: you need the actual path, not just "are they connected?"

**Do not use when:**
- Pure parent-child hierarchy with no cycles → use a tree or recursive structure
- You only need to check set membership or connectivity with no path queries → use Union-Find (faster and simpler)
- The "graph" is small enough that a brute-force nested loop is O(1) space with acceptable time

## Key Properties

| Property | Description |
|---|---|
| **Directed (digraph)** | Edges have direction: A → B does not imply B → A |
| **Undirected** | Edges are symmetric: A — B implies both directions |
| **Weighted** | Each edge carries a numeric cost |
| **Cyclic** | Contains at least one cycle |
| **Acyclic** | No cycles; a directed acyclic graph is a **[DAG](_meta/glossary.md#dag)** |
| **Connected** | Every node is reachable from every other (undirected) |
| **Sparse** | E ≪ V²; adjacency list preferred |
| **Dense** | E ≈ V²; adjacency matrix sometimes preferred |

**Degree:** number of edges incident to a node. In directed graphs: in-degree (arrows in) and out-degree (arrows out).

## Time & Space Complexity

V = number of vertices, E = number of edges.

| Operation | Adjacency List | Adjacency Matrix |
|---|---|---|
| Add edge | O(1) | O(1) |
| Remove edge | O(degree) | O(1) |
| Check edge u→v | O(degree(u)) | O(1) |
| Enumerate neighbors | O(degree) | O(V) |
| Space | O(V + E) | O(V²) |
| BFS / DFS traversal | O(V + E) | O(V²) |

**Why O(V + E) for traversal:** each vertex is enqueued/visited once (O(V)) and each edge is examined once from each endpoint in undirected graphs — O(E) total edge inspections.

Adjacency list dominates for sparse graphs (most real-world and interview graphs). Adjacency matrix is only worth it when E ≈ V² and O(1) edge-existence checks are critical.

## Implementation Notes

### Building the graph — adjacency list

```js
// Undirected graph from edge list
function buildGraph(n, edges) {
  const adj = Array.from({ length: n }, () => []); // n empty lists
  for (const [u, v] of edges) {
    adj[u].push(v);
    adj[v].push(u); // omit this line for a directed graph
  }
  return adj;
}

// Weighted directed graph
function buildWeightedGraph(n, edges) {
  const adj = Array.from({ length: n }, () => []);
  for (const [u, v, w] of edges) {
    adj[u].push({ node: v, weight: w });
  }
  return adj;
}
```

### BFS — shortest path in unweighted graph

BFS explores level by level, so the first time a node is reached its distance is minimal.

```js
function bfs(start, adj) {
  const visited = new Set([start]);
  const queue = [start];           // treat array as queue: shift() from front
  const dist = new Map([[start, 0]]);

  while (queue.length) {
    const node = queue.shift();    // O(n) per call — acceptable for interviews;
                                   // use a proper deque/pointer for large inputs

    for (const neighbor of adj[node]) {
      if (!visited.has(neighbor)) {
        visited.add(neighbor);
        dist.set(neighbor, dist.get(node) + 1);
        queue.push(neighbor);
      }
    }
  }
  return dist;
}
```

**Grid BFS** (cells as nodes — common for "islands", "shortest path in maze"):

```js
function bfsGrid(grid, startR, startC) {
  const rows = grid.length, cols = grid[0].length;
  const dirs = [[1,0],[-1,0],[0,1],[0,-1]];
  const visited = Array.from({ length: rows }, () => new Array(cols).fill(false));
  const queue = [[startR, startC, 0]]; // [row, col, distance]
  visited[startR][startC] = true;

  while (queue.length) {
    const [r, c, d] = queue.shift();
    for (const [dr, dc] of dirs) {
      const nr = r + dr, nc = c + dc;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols
          && !visited[nr][nc] && grid[nr][nc] !== 0) {
        visited[nr][nc] = true;
        queue.push([nr, nc, d + 1]);
      }
    }
  }
}
```

### DFS — iterative and recursive

DFS is better for: cycle detection, topological sort, connected components, and problems where you need to explore an entire path before backtracking.

```js
// Recursive DFS — natural for backtracking; risk: call stack overflow on very deep graphs
function dfsRecursive(node, adj, visited = new Set()) {
  visited.add(node);
  for (const neighbor of adj[node]) {
    if (!visited.has(neighbor)) {
      dfsRecursive(neighbor, adj, visited);
    }
  }
}

// Iterative DFS — avoids stack overflow, mirrors BFS structure
function dfsIterative(start, adj) {
  const visited = new Set();
  const stack = [start];

  while (stack.length) {
    const node = stack.pop();          // pop from end — LIFO
    if (visited.has(node)) continue;   // guard here, not before push, for simplicity
    visited.add(node);

    for (const neighbor of adj[node]) {
      if (!visited.has(neighbor)) {
        stack.push(neighbor);
      }
    }
  }
}
```

### Cycle detection — directed graph (DFS with three-color marking)

```js
// Returns true if a directed graph contains a cycle
function hasCycle(n, adj) {
  // 0 = unvisited, 1 = in current path (gray), 2 = fully processed (black)
  const state = new Array(n).fill(0);

  function dfs(node) {
    state[node] = 1; // mark as in-progress
    for (const neighbor of adj[node]) {
      if (state[neighbor] === 1) return true;   // back edge → cycle
      if (state[neighbor] === 0 && dfs(neighbor)) return true;
    }
    state[node] = 2; // fully processed
    return false;
  }

  for (let i = 0; i < n; i++) {
    if (state[i] === 0 && dfs(i)) return true;
  }
  return false;
}
```

### Connected components — undirected graph

```js
function countComponents(n, edges) {
  const adj = buildGraph(n, edges);
  const visited = new Set();
  let components = 0;

  for (let i = 0; i < n; i++) {
    if (!visited.has(i)) {
      dfsRecursive(i, adj, visited); // marks all reachable nodes
      components++;
    }
  }
  return components;
}
```

## Common Pitfalls

- **Forgetting `visited` tracking** — causes infinite loops on any graph with a cycle; always add to visited *before* pushing to queue/stack, not after popping (BFS) or at minimum guard before recursing (DFS)
- **Off-by-one in grid bounds** — always check `nr >= 0 && nr < rows && nc >= 0 && nc < cols` before accessing `grid[nr][nc]`
- **`queue.shift()` is O(n)** — acceptable in interviews but note the limitation; for large inputs, use a pointer (`let head = 0; queue[head++]`) or a true deque
- **Directed vs undirected confusion** — adding an edge in only one direction when the problem is undirected (or vice versa) is a common bug; re-read the problem
- **Disconnected graphs** — iterating only from node 0 misses unreachable components; always loop over all nodes and kick off BFS/DFS for unvisited ones
- **Modifying the graph during traversal** — avoid pushing duplicate entries into the queue by checking `visited` before enqueuing, not just after dequeuing

## Trade-offs

| Representation | Pros | Cons |
|---|---|---|
| Adjacency list | O(V+E) space; fast neighbor enumeration | O(degree) edge lookup |
| Adjacency matrix | O(1) edge lookup; simple for dense graphs | O(V²) space; slow neighbor enumeration for sparse graphs |
| Edge list | Minimal space; easy to sort by weight | O(E) to find neighbors |

**BFS vs DFS:**
- BFS: shortest path (unweighted), level-order traversal, finding nearest neighbor
- DFS: cycle detection, topological sort, connected components, backtracking, detecting if a path *exists*
- Neither is universally faster — both are O(V+E); the choice is determined by what you need from the traversal

## Variants

- **Weighted shortest path** → Dijkstra's (non-negative weights) or Bellman-Ford (negative weights)
- **Minimum spanning tree** → Prim's or Kruskal's
- **Topological sort** → Kahn's algorithm (BFS-based) or DFS post-order
- **Bipartite check** → BFS/DFS with two-coloring
- **Strongly connected components** → Kosaraju's or Tarjan's algorithm

## Resources

- [NeetCode — Graph Theory Playlist](https://neetcode.io/roadmap)
- [CLRS Chapter 22 — Elementary Graph Algorithms](https://mitpress.mit.edu/9780262046305/)
- [LeetCode Graph Study Plan](https://leetcode.com/study-plan/graph/)

## Related

- [[bfs]]
- [[dfs]]
- [[topological-sort]]
- [[dijkstra]]
- [[union-find]]
- [[minimum-spanning-tree]]
