---
id: 711f3a9a-76d7-49b3-ad76-e11367287af4
type: flashcard
tags:
  - ds-a
  - binary-tree
  - tree
  - data-structures
tiers:
  ds-a: 2
created: 2026-08-20
confidence: medium
---

# Binary Tree

A binary tree is a hierarchical data structure where each node holds a value and has at most two children (left and right). Its recursive shape — every subtree is itself a valid binary tree — is what makes divide-and-conquer and recursive decomposition the natural computational model for nearly every tree problem.

## When to Use

**Problem signals that suggest binary tree:**
- Input is explicitly a tree, or data has a clear parent-child / hierarchical relationship
- Problem asks for paths from root to leaf, or paths through any node
- Problem asks you to validate, serialize, deserialize, or reconstruct a tree
- Problem asks for the "level" of nodes, level-order output, or a zigzag traversal
- Problem asks about lowest common ancestor ([LCA](_meta/glossary.md#lca)) of two nodes
- Constraints mention balanced vs. unbalanced behavior (height matters)
- Problem involves expression trees, decision trees, or recursive nested structure

**Prefer binary tree traversal over alternatives when:**
- Over iterating a flat array: the data has inherent parent-child structure that an array index scheme would obscure
- Over graph traversal: the acyclic, rooted structure eliminates the need for a `visited` set, simplifying code

**Do not use when:**
- Nodes can have more than two children → use a general N-ary tree or trie
- You need O(log n) ordered lookups/insertions → use [BST](_meta/glossary.md#bst) (a binary tree with the ordering invariant), [AVL](_meta/glossary.md#avl), or red-black tree
- The relationship is many-to-many → use a graph

## Key Properties

| Property | Detail |
|---|---|
| Height h | O(log n) balanced; O(n) degenerate (linked-list shape) |
| Max nodes at depth d | 2^d |
| Max nodes in tree of height h | 2^(h+1) − 1 |
| Full binary tree | Every node has 0 or 2 children |
| Complete binary tree | All levels full except last; last level filled left-to-right |
| Perfect binary tree | Full + complete; all leaves at same depth |

A tree's height controls nearly every complexity bound. Always ask: is this tree guaranteed to be balanced? If not, worst-case recursion depth is O(n), risking stack overflow on large inputs.

## Time & Space Complexity

Most binary tree operations reduce to traversal — visit every node once.

| Operation | Time | Space (call stack / queue) |
|---|---|---|
| [DFS](_meta/glossary.md#dfs) traversal (recursive) | O(n) | O(h) — h is height |
| [BFS](_meta/glossary.md#bfs) / level-order | O(n) | O(w) — w is max width (up to n/2 at last level) |
| Search (unordered) | O(n) | O(h) |
| Insert at specific position | O(n) | O(h) |

**Why O(h) space for DFS:** the recursion stack holds one frame per level of the tree — depth equals height.
**Why O(w) space for BFS:** the queue holds all nodes at the current level before advancing; the widest level in a complete tree is the last, with ⌈n/2⌉ nodes.

## Traversal Patterns

> [!tip] Choosing a traversal
> Ask "do I need parent info **before** or **after** recursing into children?" Before → preorder. After (need subtree results) → postorder. Sorted BST output → inorder. Layer-by-layer → BFS.

The four canonical traversals and what they reveal:

- **Inorder (left → root → right):** produces sorted output for a BST; reconstructs BST from scratch
- **Preorder (root → left → right):** encodes tree structure (root first = useful for serialization, cloning)
- **Postorder (left → right → root):** processes children before parent (useful for deletion, computing subtree values bottom-up)
- **Level-order (BFS):** processes nodes by depth; required for shortest path in unweighted trees, zigzag, right-side view

**The key insight for choosing a traversal:** ask "do I need parent information before or after I recurse into children?" Before → preorder. After (subtree result needed) → postorder. Both → inorder (for BST). Layer-by-layer → BFS.

## Implementation Notes

```js
// ─── Node definition ──────────────────────────────────────────────────────────
class TreeNode {
  constructor(val, left = null, right = null) {
    this.val = val;
    this.left = left;
    this.right = right;
  }
}

// ─── DFS traversals (recursive) ───────────────────────────────────────────────

function inorder(root, result = []) {
  if (!root) return result;        // base case: null node → no-op
  inorder(root.left, result);
  result.push(root.val);
  inorder(root.right, result);
  return result;
}

function preorder(root, result = []) {
  if (!root) return result;
  result.push(root.val);           // visit before recursing
  preorder(root.left, result);
  preorder(root.right, result);
  return result;
}

function postorder(root, result = []) {
  if (!root) return result;
  postorder(root.left, result);
  postorder(root.right, result);
  result.push(root.val);           // visit after both children
  return result;
}

// ─── Iterative inorder (avoids stack overflow on deep trees) ──────────────────
function inorderIterative(root) {
  const result = [], stack = [];
  let cur = root;
  while (cur || stack.length) {
    while (cur) {                  // go as far left as possible
      stack.push(cur);
      cur = cur.left;
    }
    cur = stack.pop();             // leftmost unvisited node
    result.push(cur.val);
    cur = cur.right;               // now explore right subtree
  }
  return result;
}

// ─── BFS / level-order ────────────────────────────────────────────────────────
function levelOrder(root) {
  if (!root) return [];
  const result = [], queue = [root];
  while (queue.length) {
    const levelSize = queue.length; // snapshot: only process nodes at this level
    const level = [];
    for (let i = 0; i < levelSize; i++) {
      const node = queue.shift();  // dequeue front — O(1) amortized with array in JS
      level.push(node.val);
      if (node.left)  queue.push(node.left);
      if (node.right) queue.push(node.right);
    }
    result.push(level);
  }
  return result;                   // [[root], [l2...], [l3...], ...]
}

// ─── Height / depth ───────────────────────────────────────────────────────────
// Postorder: height of a node = 1 + max(height(left), height(right))
function height(root) {
  if (!root) return 0;
  return 1 + Math.max(height(root.left), height(root.right));
}

// ─── Lowest Common Ancestor (unordered binary tree) ──────────────────────────
// Key insight: if root equals p or q, root IS the LCA (the other is in subtree).
// Otherwise LCA is wherever both sides return non-null.
function lowestCommonAncestor(root, p, q) {
  if (!root || root === p || root === q) return root;
  const left  = lowestCommonAncestor(root.left,  p, q);
  const right = lowestCommonAncestor(root.right, p, q);
  if (left && right) return root;  // p found on one side, q on the other
  return left || right;            // both on same side; propagate the non-null
}

// ─── Max path sum (path through any node) ────────────────────────────────────
// Classic postorder aggregation: compute best gain through each child, update
// global max, return the best single-branch gain to parent.
function maxPathSum(root) {
  let globalMax = -Infinity;
  function dfs(node) {
    if (!node) return 0;
    const leftGain  = Math.max(dfs(node.left),  0); // ignore negative branches
    const rightGain = Math.max(dfs(node.right), 0);
    globalMax = Math.max(globalMax, node.val + leftGain + rightGain);
    return node.val + Math.max(leftGain, rightGain); // return best single path up
  }
  dfs(root);
  return globalMax;
}
```

## Common Pitfalls

- **Forgetting the null base case:** every recursive tree function must handle `!root` first; omitting it causes a runtime error when the tree has an empty child.
- **Confusing height and depth:** height is measured from a node *down* to the deepest leaf; depth is measured from the root *down* to a node. Off-by-one errors are common when mixing the two.
- **Modifying `queue` length mid-loop in BFS:** capturing `levelSize = queue.length` before the inner loop is essential; checking `queue.length` in the loop condition picks up newly enqueued nodes from the *next* level.
- **`Array.shift()` performance:** in JS, `queue.shift()` is O(n) because it re-indexes the array. For large trees, use a pointer index (`let head = 0; queue[head++]`) or a proper deque to avoid O(n²) total cost.
- **Assuming balanced height:** if the problem does not guarantee a balanced tree, worst-case recursion depth is O(n). For very deep trees, prefer the iterative traversal to avoid call-stack overflow.
- **Path vs. subtree distinction:** a "path" through an arbitrary node can use both children but cannot extend further up (it terminates at the node). A "subtree rooted at node" includes all descendants. Mixing these up leads to wrong aggregation logic.

## Variants

- **Binary Search Tree (BST):** adds the ordering invariant (left < node < right), enabling O(log n) search/insert on balanced trees. All BST algorithms exploit this invariant — if a problem does not mention ordering, do not assume BST.
- **Complete Binary Tree:** used to implement binary heaps via arrays (node i has children 2i+1 and 2i+2); the array representation eliminates pointer overhead entirely.
- **Segment Tree:** a binary tree where each node stores an aggregate (sum, min, max) over a range of an underlying array; supports O(log n) range queries and point updates.
- **Trie:** an N-ary tree (not binary) specialized for string prefixes; shares the recursive decomposition model but branches on character rather than comparison.

## Resources

- Sedgewick & Wayne, *Algorithms* (4th ed.) — Chapter 3 (BSTs), Chapter 5 (Tries)
- NeetCode Trees playlist: https://neetcode.io/roadmap (Trees section)
- LeetCode Explore — Tree: https://leetcode.com/explore/learn/card/data-structure-tree/

## Related

- [[binary-search-tree]]
- [[bfs]]
- [[dfs]]
- [[heap]]
- [[trie]]
- [[segment-tree]]
- [[divide-and-conquer]]
