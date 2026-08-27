---
id: 9d787059-c973-4685-954b-71ab8f5105f9
type: flashcard
tags:
  - ds-a
  - dfs
  - graph
  - tree
  - backtracking
tiers:
  ds-a: 2
created: 2026-08-20
confidence: low
---

# Depth-First Search (DFS)

DFS explores as far as possible along each branch before backtracking — the call stack (implicit or explicit) enforces this depth-first guarantee, which makes it the natural fit for problems that require exhaustive exploration, path tracking, or decisions at each node that depend on the full path taken so far.

> [!tip] Reach for DFS for exhaustive search, paths, and backtracking
> "Find all paths/combinations/subsets", cycle detection, topological sort, connected components, tree traversals. If you need the *shortest* path in an unweighted graph, use BFS instead — DFS does not guarantee it.

## When to Use

**Problem signals that suggest DFS:**
- "Find all paths", "enumerate all combinations/subsets/permutations" — exhaustive search over a decision tree
- "Does a path exist from X to Y?" or "is the graph connected?" — reachability without needing shortest path
- Detecting cycles in a directed or undirected graph
- Topological sort / dependency ordering
- Connected components, strongly connected components
- Tree problems: lowest common ancestor, path sum, subtree matching, serialization
- "Backtracking" problems — n-queens, sudoku solver, word search on a grid — where you build a candidate incrementally and abandon it when a constraint is violated
- Problems on trees where preorder, inorder, or postorder processing is meaningful

**Prefer DFS over alternatives when:**
- Over BFS: you need to track the full current path, not just distance; or stack space is acceptable and you want simpler recursive code
- Over BFS: the solution is likely deep in the search tree (BFS expands wide first, which wastes work)
- Over iterative approaches: the problem has a natural recursive decomposition (divide and conquer, tree traversal)
- Over Dijkstra/BFS: edges are unweighted and you only need existence of a path, not shortest path

**Do not use when:**
- You need shortest path in an unweighted graph → use BFS instead (DFS does not guarantee shortest path)
- You need shortest path in a weighted graph → use Dijkstra or Bellman-Ford
- The graph is very deep / unbounded and stack overflow is a risk in a recursive implementation → use iterative DFS with an explicit stack, or BFS
- You need level-order (breadth-first) output → use BFS

## Key Properties

- **Order:** visits nodes in preorder by default (process node, then recurse into children); postorder is achieved by processing after the recursive calls return
- **Stack usage:** recursive DFS uses the implicit call stack; iterative DFS uses an explicit stack
- **Visited set:** required for graphs (to prevent infinite loops on cycles); not needed for trees (no back edges by definition)
- **Path tracking:** the current recursion frame represents the current path — backtracking happens automatically when a recursive call returns
- **Time complexity:** O(V + E) for graphs; O(N) for trees where N is the number of nodes
- **Space complexity:** O(V) for the visited set + O(H) for the call stack, where H is the maximum depth (H = N in the worst case for a skewed tree or a path graph)

## Time & Space Complexity

| Context | Time | Space | Notes |
|---|---|---|---|
| Graph (adjacency list) | O(V + E) | O(V) visited + O(V) stack | Visited set O(V); recursion depth up to V in worst case |
| Tree traversal | O(N) | O(H) | H = height; O(log N) balanced, O(N) skewed |
| Backtracking (general) | O(b^d) | O(d) | b = branching factor, d = max depth |

**Why O(V + E)?** Each vertex is visited once (the visited set prevents revisits). For each vertex, we iterate over its adjacency list once — summing all adjacency list sizes gives E total. So the total work is V (visit overhead) + E (edge traversal).

**Why O(H) stack space for trees?** At any point in the recursion, only the nodes on the current root-to-leaf path are on the call stack — at most H frames deep.

## Implementation Notes

### Tree DFS (recursive) — three traversal orders

```js
// Preorder: root → left → right (useful for serialization, copying a tree)
function preorder(node, result = []) {
  if (!node) return result;
  result.push(node.val);       // process BEFORE recursing
  preorder(node.left, result);
  preorder(node.right, result);
  return result;
}

// Inorder: left → root → right (produces sorted order for a BST)
function inorder(node, result = []) {
  if (!node) return result;
  inorder(node.left, result);
  result.push(node.val);       // process BETWEEN left and right
  inorder(node.right, result);
  return result;
}

// Postorder: left → right → root (useful for deletion, bottom-up aggregation)
function postorder(node, result = []) {
  if (!node) return result;
  postorder(node.left, result);
  postorder(node.right, result);
  result.push(node.val);       // process AFTER both children
  return result;
}
```

### Graph DFS (recursive) — adjacency list, directed or undirected

```js
// Build adjacency list (undirected graph)
function buildGraph(n, edges) {
  const adj = Array.from({ length: n }, () => []);
  for (const [u, v] of edges) {
    adj[u].push(v);
    adj[v].push(u); // omit this line for directed graph
  }
  return adj;
}

// DFS with a visited set to handle cycles
function dfs(node, adj, visited, result = []) {
  visited.add(node);
  result.push(node);          // preorder — process on first visit

  for (const neighbor of adj[node]) {
    if (!visited.has(neighbor)) {
      dfs(neighbor, adj, visited, result);
    }
  }
  return result;
}

// Entry point — call for each component to handle disconnected graphs
function traverseAll(n, edges) {
  const adj = buildGraph(n, edges);
  const visited = new Set();
  const result = [];
  for (let i = 0; i < n; i++) {
    if (!visited.has(i)) {
      dfs(i, adj, visited, result);
    }
  }
  return result;
}
```

### Iterative DFS — explicit stack (avoids call stack overflow)

```js
function dfsIterative(start, adj) {
  const visited = new Set();
  const stack = [start];       // push start; process by popping
  const result = [];

  while (stack.length > 0) {
    const node = stack.pop();  // LIFO — this is what makes it DFS (not BFS)
    if (visited.has(node)) continue;
    visited.add(node);
    result.push(node);

    // Push neighbors in reverse order if consistent ordering matters
    for (const neighbor of adj[node]) {
      if (!visited.has(neighbor)) {
        stack.push(neighbor);
      }
    }
  }
  return result;
}
```

### Cycle detection in a directed graph — three-color marking

```js
// WHITE = 0 (unvisited), GRAY = 1 (in current path), BLACK = 2 (fully done)
function hasCycle(n, adj) {
  const color = new Array(n).fill(0);

  function dfs(node) {
    color[node] = 1;           // GRAY: currently on the recursion stack
    for (const neighbor of adj[node]) {
      if (color[neighbor] === 1) return true;   // back edge → cycle
      if (color[neighbor] === 0 && dfs(neighbor)) return true;
    }
    color[node] = 2;           // BLACK: all descendants done, no cycle via this node
    return false;
  }

  for (let i = 0; i < n; i++) {
    if (color[i] === 0 && dfs(i)) return true;
  }
  return false;
}
```

### Backtracking template — path-based DFS

```js
// Generic backtracking: build candidates, recurse, undo (backtrack)
function backtrack(start, current, result, candidates /* problem-specific params */) {
  if (/* base case: valid complete solution */) {
    result.push([...current]); // snapshot — spread because current is mutated
    return;
  }

  for (let i = start; i < candidates.length; i++) {
    if (/* pruning condition */) continue;   // prune early — key for performance

    current.push(candidates[i]);                         // choose
    backtrack(i + 1, current, result, candidates);       // explore (i+1 to avoid reuse; i to allow reuse)
    current.pop();                                        // unchoose (backtrack)
  }
}
```

## Common Pitfalls

- **Forgetting the visited set on graphs:** causes infinite loops on any cycle; trees don't need it because they have no back edges
- **Mutating shared state without backtracking:** when tracking the current path in a list, always spread/copy before pushing to results, and pop after recursion returns
- **Using iterative DFS and expecting BFS-like level order:** iterative DFS with a stack gives DFS order, not BFS — use a queue for BFS
- **Stack overflow on very deep graphs:** recursive DFS on a path graph of 10⁵ nodes will blow the JS call stack — switch to iterative with an explicit stack
- **Off-by-one on the visited mark timing:** mark a node visited *before* pushing its neighbors (not after), or you may push the same node onto the stack multiple times in iterative DFS
- **Three-color vs. two-color cycle detection:** for undirected graphs, a simple visited boolean suffices; for directed graphs, you need three colors (unvisited / in-stack / done) to distinguish back edges from cross edges

## Variants

- **Topological Sort (DFS-based):** run postorder DFS; nodes finish in reverse topological order — push to a stack on completion, then reverse
- **Tarjan's SCC:** DFS with discovery timestamps and a low-link value to find strongly connected components in O(V + E)
- **Kosaraju's SCC:** two-pass DFS (once on original graph, once on transposed graph)
- **Path sum / root-to-leaf problems:** carry a running sum down the recursion; check at leaf nodes
- **DFS on implicit graphs:** many backtracking problems (combinations, permutations, word search) are DFS on an implicit state graph — no adjacency list, just a recursive expansion of choices

## Resources

- [CLRS Chapter 22 — Elementary Graph Algorithms](https://mitpress.mit.edu/9780262046305/introduction-to-algorithms/)
- [NeetCode — Graph DFS patterns](https://neetcode.io/roadmap)
- [MDN — call stack and recursion](https://developer.mozilla.org/en-US/docs/Glossary/Call_stack)

## Related

- [[breadth-first-search]]
- [[topological-sort]]
- [[backtracking]]
- [[union-find]]
- [[dynamic-programming]]
