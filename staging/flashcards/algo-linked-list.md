---
id: algo-linked-list
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-10
confidence: high
---

# Linked List

Reach for these when the input is a chain of nodes you must rewire by pointer rather than by index: reverse, merge, detect a loop, or splice something out in place. The tells are a dummy/sentinel head to erase first-element edge cases and two pointers (fast/slow or a fixed gap) to locate a spot in one pass. Solve each on your own machine and log the outcome.

## Reverse Linked List
[Solve on LeetCode](https://leetcode.com/problems/reverse-linked-list/) · Easy

**Problem.** You are given the head of a singly linked list. Flip the direction of every `next` pointer so the last node becomes the new head, and return that new head. Do it in place, without building a new list.

**Example.** `1 -> 2 -> 3` becomes `3 -> 2 -> 1`; the old tail `3` is now the head and the old head `1` points to nothing.

**Recognition.** Any "reverse the list in place" prompt. Walk once with `prev`, `curr`, and a saved `next`, repointing `curr.next` back to `prev` each step; `prev` is the new head at the end.

## Merge Two Sorted Lists
[Solve on LeetCode](https://leetcode.com/problems/merge-two-sorted-lists/) · Easy

**Problem.** Two already-sorted linked lists are given by their heads. Weave their nodes into one sorted list by splicing the existing nodes (no new node allocation) and return the merged head.

**Example.** `1 -> 4` and `2 -> 3` merge to `1 -> 2 -> 3 -> 4`.

**Recognition.** Two sorted inputs to combine into one. Use a dummy head and a tail pointer; repeatedly attach the smaller of the two current nodes, then link on whatever list remains.

## Linked List Cycle
[Solve on LeetCode](https://leetcode.com/problems/linked-list-cycle/) · Easy

**Problem.** Given a list's head, decide whether following `next` pointers ever loops back onto a node already visited. Return true if a cycle exists, false otherwise, ideally in O(1) extra space.

**Example.** `1 -> 2 -> 3` whose `3.next` points back to `2` returns `true`; a plain `1 -> 2 -> 3 -> null` returns `false`.

**Recognition.** "Does the list loop?" with a space constraint. Floyd's tortoise-and-hare: advance slow by one and fast by two; if they ever meet there is a cycle.

## Reorder List
[Solve on LeetCode](https://leetcode.com/problems/reorder-list/) · Medium

**Problem.** Given the head of a list, rearrange it so it alternates first, last, second, second-to-last, and so on, modifying pointers in place rather than reassigning node values. Return nothing meaningful; the list itself is mutated.

**Example.** `1 -> 2 -> 3 -> 4` becomes `1 -> 4 -> 2 -> 3`.

**Recognition.** An interleaving of front and back halves. Find the middle with fast/slow, reverse the second half, then zip the two halves together node by node.

## Remove Nth Node From End of List
[Solve on LeetCode](https://leetcode.com/problems/remove-nth-node-from-end-of-list/) · Medium

**Problem.** Given a list's head and an integer `n`, delete the node that sits `n` positions from the end and return the head of the resulting list. Aim to do it in a single traversal.

**Example.** With `1 -> 2 -> 3 -> 4 -> 5` and `n = 2`, removing the 2nd-from-last node (`4`) yields `1 -> 2 -> 3 -> 5`.

**Recognition.** "Nth from the end" in one pass. Use a dummy head and two pointers with an `n`-node gap; when the lead hits the end, the trailer sits just before the target so you can unlink it.

## Copy List with Random Pointer
[Solve on LeetCode](https://leetcode.com/problems/copy-list-with-random-pointer/) · Medium

**Problem.** Each node has a normal `next` pointer plus a `random` pointer that may reference any node in the list or null. Build a completely independent deep copy whose nodes mirror both the `next` and `random` wiring of the original.

**Example.** If node `A.random` points to `C`, then in the copy `A'.random` must point to `C'` (the cloned `C`), not the original `C`.

**Recognition.** Cloning a structure with arbitrary cross-links. Map each original node to its clone (hash map, or interleave clones between originals), then wire up `next` and `random` on the clones via that mapping.

## Add Two Numbers
[Solve on LeetCode](https://leetcode.com/problems/add-two-numbers/) · Medium

**Problem.** Two non-negative integers are stored as linked lists with the least-significant digit first, one digit per node. Add them and return the sum as a new linked list in the same digit-reversed order.

**Example.** `9 -> 1 -> 6` (619) plus `4 -> 5 -> 3` (354) gives `3 -> 7 -> 9` (973).

**Recognition.** Digit-by-digit arithmetic on lists. Walk both lists together carrying the overflow, creating a new node for each `(sum % 10)` and remembering `sum / 10` as the carry into the next position.

## Find the Duplicate Number
[Solve on LeetCode](https://leetcode.com/problems/find-the-duplicate-number/) · Medium

**Problem.** An array of `n + 1` integers holds values in the range `1..n`, so by pigeonhole at least one value repeats. Return the single repeated value without modifying the array and using only constant extra space.

**Example.** In `[1, 3, 4, 2, 2]` the repeated value is `2`.

**Recognition.** Read-only array, O(1) space, one duplicate in `1..n`. Treat `value = next index` to form an implicit linked list; the duplicate is the entry of a cycle, found via Floyd's two-pointer method.

## LRU Cache
[Solve on LeetCode](https://leetcode.com/problems/lru-cache/) · Medium

**Problem.** Design a cache with a fixed capacity supporting `get(key)` and `put(key, value)`, both in O(1). When inserting past capacity, evict the entry that was least recently accessed; any get or put counts as a use.

**Example.** With capacity 2, after `put(1,1)`, `put(2,2)`, `get(1)`, then `put(3,3)` evicts key `2` (it was the least recently used), so `get(2)` returns `-1`.

**Recognition.** "O(1) get/put with eviction by recency." Combine a hash map (key -> node) with a doubly linked list ordered by recency; move touched nodes to the front and evict from the back.

## Merge k Sorted Lists
[Solve on LeetCode](https://leetcode.com/problems/merge-k-sorted-lists/) · Hard

**Problem.** Given an array of `k` linked lists, each already sorted ascending, merge them all into one sorted list and return its head. Some of the input lists may be empty.

**Example.** `[1 -> 5]`, `[2 -> 3]`, `[4]` merge into `1 -> 2 -> 3 -> 4 -> 5`.

**Recognition.** Many sorted lists to fold into one. Push each list's head into a min-heap and repeatedly pop the smallest, pushing its successor — O(N log k) — or merge the lists pairwise.

## Reverse Nodes in k-Group
[Solve on LeetCode](https://leetcode.com/problems/reverse-nodes-in-k-group/) · Hard

**Problem.** Given a list's head and an integer `k`, reverse the nodes in consecutive blocks of `k`, in place. If the final block has fewer than `k` nodes, leave it in its original order. Return the new head.

**Example.** With `1 -> 2 -> 3 -> 4 -> 5` and `k = 2`, the result is `2 -> 1 -> 4 -> 3 -> 5` (the leftover `5` stays put).

**Recognition.** "Reverse in fixed-size chunks." For each group, first check that `k` nodes remain; if so, reverse that segment and carefully reconnect the reversed block to the tail of the previous group and the head of the next.
