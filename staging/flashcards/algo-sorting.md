---
id: algo-sorting
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-12
confidence: high
---

# Sorting

Most interviews let you call the library sort — these are the exceptions, where
you implement one yourself. Know two comparison sorts cold and when each wins:
**merge sort** (stable, guaranteed O(n log n), the natural fit for linked lists
and external data) and **quicksort** (fastest in-memory, in-place, but randomize
the pivot to dodge the O(n²) worst case on sorted input). The signal is "sort
without the built-in", "sort in O(n log n)", or "sort a linked list". See the
[[sorting]] concept card for the full landscape (stability, non-comparison sorts,
why libraries are hybrids). Solve each on your own machine, then log how it went.

## Sort an Array
[Solve on LeetCode](https://leetcode.com/problems/sort-an-array/) · Medium

**Problem.** Given an array of integers, return it sorted in ascending order in
O(n log n) time and the smallest space you can — and you may **not** call the
language's built-in sort.

**Example.** `[5, 2, 3, 1]` becomes `[1, 2, 3, 5]`; `[5, 1, 1, 2, 0, 0]` becomes
`[0, 0, 1, 1, 2, 5]`.

**Recognition.** the canonical "write a real sort". Implement **merge sort** —
split in half, recurse, merge two sorted halves (stable, O(n) aux, guaranteed
n log n) — or **quicksort** — partition around a **randomized** pivot and recurse
each side (in-place, O(log n) stack); use three-way partitioning when duplicates
are heavy so equal keys settle in one pass.

## Sort List
[Solve on LeetCode](https://leetcode.com/problems/sort-list/) · Medium

**Problem.** Sort a singly linked list in ascending order, targeting O(n log n)
time and O(1) auxiliary space beyond the recursion stack.

**Example.** `4 → 2 → 1 → 3` becomes `1 → 2 → 3 → 4`.

**Recognition.** merge sort is the fit — a list has no random access, so quicksort
and heapsort are awkward. Find the middle with slow/fast pointers, split, recurse
on each half, then merge two sorted lists. Top-down is simplest (O(log n) stack);
bottom-up (merge runs of size 1, 2, 4, …) reaches true O(1) space.
