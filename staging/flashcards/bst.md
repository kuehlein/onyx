---
id: 50d38d09-7e70-4484-b2f4-c192e8b51e53
type: flashcard
tags:
  - ds-a
  - bst
  - binary-tree
  - tree
  - data-structures
tiers:
  ds-a: 2
created: 2026-08-20
confidence: medium
---

# Binary Search Tree (BST)

A BST is a binary tree where every node satisfies the invariant: all keys in the left subtree are strictly less than the node's key, and all keys in the right subtree are strictly greater. This ordering property is what makes BSTs useful — it lets you eliminate half the remaining search space at each node, enabling O(log n) operations on a balanced tree.

> [!tip] Reach for a BST when
> You need **fast search AND ordered queries** (range, rank, successor, k-th smallest) on a *dynamic* set. In-order traversal yields sorted output for free. If you only need O(1) lookup use a hash map; if you only need min/max use a heap.

## When to Use

**Problem signals that suggest BST:**
- You need ordered iteration over a dynamic set (in-order traversal yields sorted output for free)
- The problem requires efficient predecessor/successor queries ("next smaller", "next larger")
- You need a structure that supports fast search AND fast insertion/deletion — not just one of the two
- k-th smallest/largest element in a dynamic set
- Range queries: find all elements between [lo, hi]
- The data arrives unsorted and you need to maintain a sorted collection as it grows

**Prefer BST over alternatives when:**
- Over sorted array: you need O(log n) insertion/deletion — arrays require O(n) shifts
- Over hash map: you need order-based queries (range, rank, successor) — hash maps lose ordering
- Over heap: you need arbitrary lookup or deletion, not just min/max — heaps only efficiently expose one extreme
- Over sorted linked list: you need O(log n) search — linked list search is O(n) even when sorted

**Do not use when:**
- You only need O(1) lookup by key → use a hash map instead
- The input arrives already sorted and the tree won't be self-balancing → degenerates to O(n) linked list; use a balanced BST (AVL, Red-Black) or just a sorted array + binary search
- You only need min or max → use a heap
- The key space is small and dense → use an array indexed by key

## Key Properties

- **BST invariant:** `left.val < node.val < right.val` (strict inequality; duplicates require a convention — typically go right or use a count)
- **In-order traversal** (left → node → right) produces keys in sorted ascending order — this is the single most important property to internalize
- **Height determines performance:** O(h) for search, insert, delete where h = height
  - Best/average case (balanced): h = O(log n)
  - Worst case (degenerate): h = O(n) — occurs when inserted in sorted order
- **Not self-balancing by default** — use AVL or Red-Black trees if balance guarantees are required

## Time & Space Complexity

| Operation | Average (balanced) | Worst (degenerate) | Why |
|-----------|-------------------|-------------------|-----|
| Search | O(log n) | O(n) | Eliminate half the tree per step when balanced |
| Insert | O(log n) | O(n) | Search for insertion point, then attach leaf |
| Delete | O(log n) | O(n) | Search + restructure (in-order successor replacement) |
| In-order traversal | O(n) | O(n) | Must visit every node |
| k-th smallest | O(h + k) | O(n) | In-order traversal halted at k |
| Space (storage) | O(n) | O(n) | One node per element |
| Space (call stack) | O(h) | O(n) | Recursion depth equals height |

**Why O(log n) search:** At each node you make a binary decision — go left or right — discarding the other subtree entirely. With a balanced tree of height h, you make at most h decisions, and h = O(log n). The invariant is the guarantee that lets you safely discard half.

**Deletion complexity:** Deleting a node with two children requires finding the in-order successor (leftmost node of the right subtree), swapping values, then deleting the successor — which has at most one child. The extra constant work doesn't change the O(log n) asymptotic.

## Common Pitfalls

> [!warning] Validation checks the whole subtree, not parent-child
> A node can be greater than its parent yet still violate the BST property against an ancestor. Validate by propagating `[min, max]` bounds down the tree — never compare only adjacent nodes.

- **Forgetting the BST invariant applies to the whole subtree, not just parent-child pairs.** A node can be greater than its parent but still violate the BST property relative to an ancestor. Validation must track valid `[min, max]` bounds propagated down from ancestors.
- **Degenerate trees from sorted input.** Inserting [1, 2, 3, 4, 5] in order gives a right-skewed linked list. Always note this risk in interviews and mention self-balancing variants.
- **In-place deletion gotcha.** When deleting a node with two children, you swap the value with the in-order successor and delete the successor — do NOT restructure pointers wholesale, as this is error-prone.
- **Duplicate handling is undefined by default.** Decide upfront: skip duplicates, go right, or store a count. State your choice in the interview.
- **Null checks.** Every recursive call must handle the null base case (empty subtree) before accessing `.left` / `.right`.

## Implementation Notes

```js
class BSTNode {
  constructor(val) {
    this.val = val;
    this.left = null;
    this.right = null;
  }
}

class BST {
  constructor() {
    this.root = null;
  }

  // Insert: walk down using the invariant; attach a new leaf
  insert(val) {
    this.root = this._insert(this.root, val);
  }

  _insert(node, val) {
    if (node === null) return new BSTNode(val); // base: found the correct empty slot
    if (val < node.val) node.left = this._insert(node.left, val);
    else if (val > node.val) node.right = this._insert(node.right, val);
    // val === node.val: skip duplicate (policy choice — state this in an interview)
    return node;
  }

  // Search: O(h) — eliminate half the tree at each step
  search(val) {
    return this._search(this.root, val);
  }

  _search(node, val) {
    if (node === null) return false;          // not found
    if (val === node.val) return true;        // found
    if (val < node.val) return this._search(node.left, val);
    return this._search(node.right, val);
  }

  // Delete: three cases — no child, one child, two children
  delete(val) {
    this.root = this._delete(this.root, val);
  }

  _delete(node, val) {
    if (node === null) return null;           // val not in tree
    if (val < node.val) {
      node.left = this._delete(node.left, val);
    } else if (val > node.val) {
      node.right = this._delete(node.right, val);
    } else {
      // Found the node to delete
      if (node.left === null) return node.right;  // case 1 & 2: 0 or 1 child
      if (node.right === null) return node.left;
      // Case 3: two children — replace value with in-order successor
      // In-order successor = leftmost node of right subtree (smallest value > node.val)
      let successor = node.right;
      while (successor.left !== null) successor = successor.left;
      node.val = successor.val;             // overwrite value
      node.right = this._delete(node.right, successor.val); // delete successor
    }
    return node;
  }

  // In-order traversal: yields keys in sorted ascending order
  inOrder() {
    const result = [];
    this._inOrder(this.root, result);
    return result;
  }

  _inOrder(node, result) {
    if (node === null) return;
    this._inOrder(node.left, result);       // left subtree first (smaller values)
    result.push(node.val);                  // visit node
    this._inOrder(node.right, result);      // right subtree last (larger values)
  }

  // k-th smallest: in-order traversal, stop at k
  // O(h + k) — traverse down to the minimum, then step right k times
  kthSmallest(k) {
    let count = 0;
    let result = null;
    const inOrder = (node) => {
      if (node === null || result !== null) return;
      inOrder(node.left);
      count++;
      if (count === k) { result = node.val; return; }
      inOrder(node.right);
    };
    inOrder(this.root);
    return result;
  }

  // Validate BST: propagate [min, max] bounds — catches cross-ancestor violations
  isValid() {
    return this._isValid(this.root, -Infinity, Infinity);
  }

  _isValid(node, min, max) {
    if (node === null) return true;
    if (node.val <= min || node.val >= max) return false; // violates ancestor constraint
    return (
      this._isValid(node.left, min, node.val) &&   // left subtree must be < node.val
      this._isValid(node.right, node.val, max)      // right subtree must be > node.val
    );
  }
}

// --- Common interview patterns ---

// Lowest Common Ancestor (LCA) of a BST: O(h)
// Key insight: the first node where lo <= node <= hi IS the LCA
function lcaBST(root, p, q) {
  if (root === null) return null;
  if (p < root.val && q < root.val) return lcaBST(root.left, p, q);   // both left
  if (p > root.val && q > root.val) return lcaBST(root.right, p, q);  // both right
  return root; // split point — this node is the LCA
}

// Range sum [lo, hi]: only recurse into subtrees that can contain values in range
function rangeSumBST(root, lo, hi) {
  if (root === null) return 0;
  let sum = 0;
  if (root.val >= lo && root.val <= hi) sum += root.val;  // node is in range
  if (root.val > lo) sum += rangeSumBST(root.left, lo, hi);  // left may have values >= lo
  if (root.val < hi) sum += rangeSumBST(root.right, lo, hi); // right may have values <= hi
  return sum;
}
```

## Variants

- **Self-Balancing BSTs (AVL, Red-Black Tree):** Maintain O(log n) height guarantee through rotations after insert/delete. AVL is stricter (height differs by at most 1 at every node); Red-Black allows slightly more imbalance but is cheaper to rebalance. Used internally in most language standard libraries (`TreeMap` in Java, `std::map` in C++).
- **Augmented BST:** Store additional metadata at each node (e.g., subtree size for rank/select queries, subtree sum for range queries). Enables O(log n) rank, select, and range aggregate operations.
- **Order Statistics Tree:** An augmented BST where each node stores the size of its subtree. Enables O(log n) k-th smallest and rank queries.
- **Treap:** A randomized BST that maintains BST property by key and heap property by random priority. Expected O(log n) height without explicit rebalancing logic — simpler to implement than AVL/RB.
- **Splay Tree:** Self-adjusting BST that moves recently accessed nodes to the root. Gives O(log n) amortized for all operations with good cache locality for repeated accesses.

## Trade-offs

| Structure | Insert | Search | Delete | Ordered iteration | Notes |
|-----------|--------|--------|--------|------------------|-------|
| BST (unbalanced) | O(log n) avg | O(log n) avg | O(log n) avg | O(n) | Degenerates on sorted input |
| AVL / Red-Black | O(log n) | O(log n) | O(log n) | O(n) | Guaranteed balance; more complex |
| Hash Map | O(1) avg | O(1) avg | O(1) avg | O(n log n) | No ordering; best for pure lookup |
| Sorted Array | O(n) | O(log n) | O(n) | O(n) | Best when static; terrible for writes |
| Min/Max Heap | O(log n) | O(n) | O(log n) | O(n log n) | Only efficient for one extreme |

## Resources

- CLRS Chapter 12 (Binary Search Trees) and Chapter 13 (Red-Black Trees)
- NeetCode BST playlist: https://neetcode.io/roadmap (Data Structures & Algorithms → Trees)
- LeetCode BST tag: https://leetcode.com/tag/binary-search-tree/

## Related

- [[binary-tree]]
- [[avl-tree]]
- [[red-black-tree]]
- [[heap]]
- [[binary-search]]
- [[dfs]]
- [[segment-tree]]
