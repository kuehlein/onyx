---
id: algo-trees
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 2
created: 2026-09-10
confidence: high
---

# Trees

Reach for this pattern whenever the input is a binary tree (or BST) and the answer for a node depends on answers from its children or its ancestors — the tell is recursion that returns a value up the tree, or a level-by-level sweep. Most tree problems collapse into a small DFS that combines left and right subtree results, a BFS queue for level work, or an inorder walk that exploits BST ordering. Solve each on your own machine, then log how it went.

## Invert Binary Tree
[Solve on LeetCode](https://leetcode.com/problems/invert-binary-tree/) · Easy

**Problem.** You are given the root of a binary tree and must produce its mirror image, where every node's left and right children are swapped, all the way down. Return the root of the flipped tree. The transformation applies recursively to every subtree.

**Example.** A tree with root `1`, left child `2`, right child `3` becomes root `1`, left child `3`, right child `2`; swaps propagate to deeper levels too.

**Recognition.** "Mirror the tree" is the trigger. Recurse to the bottom, then swap each node's two child pointers on the way back up (or during a BFS pass).

## Maximum Depth of Binary Tree
[Solve on LeetCode](https://leetcode.com/problems/maximum-depth-of-binary-tree/) · Easy

**Problem.** Given the root of a binary tree, return how many nodes lie on the longest path from the root down to any leaf. An empty tree has depth `0`, and a single node has depth `1`.

**Example.** A root with one child that itself has one child -> `3`; a root with two leaf children -> `2`.

**Recognition.** "How tall is the tree?" cues a simple DFS. Depth of a node is `1 + max(depth(left), depth(right))`, with an empty subtree contributing `0`.

## Diameter of Binary Tree
[Solve on LeetCode](https://leetcode.com/problems/diameter-of-binary-tree/) · Easy

**Problem.** Given the root of a binary tree, return the length of the longest path between any two nodes, measured in edges. This path may or may not pass through the root, and the two endpoints can be anywhere in the tree.

**Example.** A tree where the longest node-to-node path visits `4` edges -> `4`, even if that path never touches the root.

**Recognition.** "Longest path between two nodes" means combine the two deepest downward reaches at some node. Run a height DFS, and at each node update a global max with `leftHeight + rightHeight` (edges through that node).

## Balanced Binary Tree
[Solve on LeetCode](https://leetcode.com/problems/balanced-binary-tree/) · Easy

**Problem.** Given the root of a binary tree, decide whether it is height-balanced, meaning that for every node the heights of its two subtrees differ by at most one. Return a boolean. A single failing node anywhere makes the whole tree unbalanced.

**Example.** A tree where one node's left subtree has height `3` and its right subtree has height `1` -> `false` (difference of `2`); a perfectly filled tree -> `true`.

**Recognition.** "Balanced everywhere?" — fold the height computation and the balance check into one bottom-up DFS. Return the subtree height, but short-circuit with a sentinel (like `-1`) the moment any node's children differ by more than one.

## Same Tree
[Solve on LeetCode](https://leetcode.com/problems/same-tree/) · Easy

**Problem.** Given the roots of two binary trees, determine whether they are identical in both structure and node values. Return `true` only if every corresponding position matches, including where nodes are absent. Return `false` otherwise.

**Example.** Two trees each shaped root `1` with left `2`, right `3` -> `true`; if one tree's right child is missing -> `false`.

**Recognition.** "Are these two trees equal?" cues a parallel DFS. Compare the two current nodes, then recurse on `(left, left)` and `(right, right)`; both null is a match, one null is a mismatch.

## Subtree of Another Tree
[Solve on LeetCode](https://leetcode.com/problems/subtree-of-another-tree/) · Easy

**Problem.** Given the roots of a larger tree and a smaller tree, decide whether the smaller tree appears as a subtree somewhere inside the larger one. A subtree must match a node of the big tree plus all of its descendants exactly. Return a boolean.

**Example.** Big tree `3 -> (4 -> (1, 2), 5)` and small tree `4 -> (1, 2)` -> `true`; a small tree `4 -> (1, 3)` -> `false` because the descendants differ.

**Recognition.** "Does one tree contain another as a subtree?" combines two ideas: walk every node of the big tree, and at each node run a same-tree equality check against the candidate root.

## Lowest Common Ancestor of a Binary Search Tree
[Solve on LeetCode](https://leetcode.com/problems/lowest-common-ancestor-of-a-binary-search-tree/) · Medium

**Problem.** Given the root of a binary search tree and two nodes present in it, return their lowest common ancestor — the deepest node that has both as descendants (a node can be its own ancestor). The BST ordering property is the key lever here. Return that ancestor node.

**Example.** In a BST with root `6`, targets `2` and `8` -> `6`, since one lies in the left subtree and one in the right; targets `2` and `4` -> `2`.

**Recognition.** "LCA in a BST" — exploit ordering instead of general search. From the root, go left if both targets are smaller, right if both are larger; the first node where they split (or equals a target) is the answer.

## Binary Tree Level Order Traversal
[Solve on LeetCode](https://leetcode.com/problems/binary-tree-level-order-traversal/) · Medium

**Problem.** Given the root of a binary tree, return its values grouped level by level, from the top row down to the bottom. Each inner list holds one level's node values in left-to-right order. An empty tree yields an empty result.

**Example.** Tree `1 -> (2, 3)` where `3` has child `4` -> `[[1], [2, 3], [4]]`.

**Recognition.** "Group nodes by depth / left-to-right rows" is the classic BFS signal. Use a queue and process it one full level at a time by snapshotting the queue size before draining that level.

## Binary Tree Right Side View
[Solve on LeetCode](https://leetcode.com/problems/binary-tree-right-side-view/) · Medium

**Problem.** Given the root of a binary tree, imagine standing to its right and return the values you would see, top to bottom. That is exactly the rightmost node on each level. Return them as a single list ordered by depth.

**Example.** Tree `1 -> (2, 3)` where `2` has a right child `5` -> `[1, 3, 5]`; you see `3` at level 2 and `5` at level 3.

**Recognition.** "Rightmost node per level" is a BFS variant. Do a level-order sweep and, for each level, keep only the last node visited (or DFS right-first, recording the first node seen at each new depth).

## Count Good Nodes in Binary Tree
[Solve on LeetCode](https://leetcode.com/problems/count-good-nodes-in-binary-tree/) · Medium

**Problem.** Given the root of a binary tree, count the "good" nodes — a node is good if no node on the path from the root down to it has a strictly greater value. Return that count. The root always counts as good.

**Example.** Tree `3 -> (1, 4 -> (1, 5))`: good nodes are `3`, `4`, and `5` (each at least as large as everything above it) -> `3`.

**Recognition.** "Node is valid relative to the max seen along its root path" means carry state downward. DFS while threading the maximum value seen so far; increment when the current value meets or beats it, then pass the updated max to children.

## Validate Binary Search Tree
[Solve on LeetCode](https://leetcode.com/problems/validate-binary-search-tree/) · Medium

**Problem.** Given the root of a binary tree, decide whether it is a valid binary search tree: every node's value must be strictly greater than all values in its left subtree and strictly less than all values in its right subtree. Return a boolean. The constraint is global, not just parent-child.

**Example.** Root `5` with left `3` and right `8` -> `true`; but root `5`, right `8`, where `8` has a left child `4` -> `false`, since `4` sits in the root's right subtree yet is below `5`.

**Recognition.** The trap is only checking immediate children. Recurse carrying an allowed `(low, high)` range, tightening the upper bound going left and the lower bound going right — a node must fall strictly inside its window.

## Kth Smallest Element in a BST
[Solve on LeetCode](https://leetcode.com/problems/kth-smallest-element-in-a-bst/) · Medium

**Problem.** Given the root of a binary search tree and an integer `k`, return the `k`-th smallest value among all nodes (1-indexed). The BST property guarantees a sorted order via inorder traversal. Return that single value.

**Example.** BST with values `{1, 2, 3, 4}` and `k = 2` -> `2`, the second smallest.

**Recognition.** "k-th smallest in a BST" — an inorder traversal visits values in ascending order. Walk inorder (recursively or with a stack) and stop at the `k`-th node you pop.

## Construct Binary Tree from Preorder and Inorder Traversal
[Solve on LeetCode](https://leetcode.com/problems/construct-binary-tree-from-preorder-and-inorder-traversal/) · Medium

**Problem.** Given the preorder and inorder traversal sequences of a binary tree with distinct values, rebuild and return the original tree. Preorder gives you roots first; inorder tells you what falls left versus right of a root. Return the reconstructed root.

**Example.** Preorder `[1, 2, 3]`, inorder `[2, 1, 3]` -> tree with root `1`, left child `2`, right child `3`.

**Recognition.** "Reconstruct a tree from two traversals" hinges on: the first preorder element is the root, and its position in inorder splits the remaining nodes into left and right subtrees. Recurse on those slices, using a value-to-index map on the inorder array for O(1) splits.

## Binary Tree Maximum Path Sum
[Solve on LeetCode](https://leetcode.com/problems/binary-tree-maximum-path-sum/) · Hard

**Problem.** Given the root of a binary tree with possibly negative values, find the maximum sum achievable by any path, where a path is a sequence of connected nodes and each node appears at most once. The path need not touch the root and need not go through it. Return that maximum sum.

**Example.** Tree `-10 -> (9, 20 -> (15, 7))`: the best path is `15 -> 20 -> 7` -> `42`, skipping the negative root.

**Recognition.** Like diameter but summing values and allowing negatives. DFS returning the best single downward chain from a node (clamped at `0` to drop negative branches), while updating a global max with `node + leftGain + rightGain`.

## Serialize and Deserialize Binary Tree
[Solve on LeetCode](https://leetcode.com/problems/serialize-and-deserialize-binary-tree/) · Hard

**Problem.** Design two functions: one that encodes an arbitrary binary tree into a single string, and one that rebuilds the exact tree from that string. Values and structure, including nulls, must survive the round trip. The encoding format is your choice as long as it is reversible.

**Example.** Tree `1 -> (2, 3)` where `3` has children `4, 5` might serialize to `"1,2,#,#,3,4,#,#,5,#,#"` (preorder with `#` for nulls) and decode back to the same tree.

**Recognition.** "Round-trip a whole tree through one string" needs an unambiguous format that records null slots. Serialize with a preorder DFS emitting a sentinel for empty children; deserialize by consuming tokens in the same order, building nodes recursively.
