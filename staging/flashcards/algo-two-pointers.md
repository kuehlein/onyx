---
id: algo-two-pointers
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-10
confidence: high
---

# Two Pointers

Reach for two pointers when a linear structure lets you move indices toward each other (or in tandem) and prune the search from both ends instead of checking every pair. The telltale signal is a sorted array, a palindrome-style symmetry, or a width-vs-height trade-off where advancing the weaker side is provably safe. Solve each on your own machine and log the outcome.

## Valid Palindrome
[Solve on LeetCode](https://leetcode.com/problems/valid-palindrome/) · Easy

**Problem.** You are given a string that may mix letters, digits, spaces, and punctuation. After dropping every non-alphanumeric character and treating uppercase and lowercase as equal, decide whether the result reads the same forward and backward. Return a boolean.

**Example.** `"Race, car!"` -> `true`, because the cleaned form `racecar` mirrors itself; `"hello"` -> `false`.

**Recognition.** "Same forward and backward" with characters to skip -> one pointer from each end, stepping past non-alphanumerics and comparing case-folded characters until they meet.

## Two Sum II - Input Array Is Sorted
[Solve on LeetCode](https://leetcode.com/problems/two-sum-ii-input-array-is-sorted/) · Medium

**Problem.** Given an array already sorted in non-decreasing order and a target value, find the two entries that add up exactly to the target. Return their 1-based positions, and you may assume exactly one valid pair exists. Do it using constant extra space.

**Example.** For `[1, 3, 4, 6]` and target `9`, the answer is `[2, 4]` since `3 + 6 = 9`.

**Recognition.** A *sorted* array plus a pair-sum target and an O(1)-space demand -> pointers at both ends; if the sum is too small move the left pointer up, if too big move the right pointer down.

## 3Sum
[Solve on LeetCode](https://leetcode.com/problems/3sum/) · Medium

**Problem.** Given an integer array, return every unique triple of elements that sums to zero. Triples that are reorderings of the same values count as one, so the output must contain no duplicates. Order within the answer does not matter.

**Example.** `[-2, -1, 0, 1, 3]` -> `[[-2, -1, 3], [-1, 0, 1]]`; each triple adds to `0` and appears only once.

**Recognition.** "Triples summing to zero, no duplicates" -> sort first, then fix each element and run the sorted two-pointer sweep on the remainder; skip equal neighbors to dodge duplicate triples.

## Container With Most Water
[Solve on LeetCode](https://leetcode.com/problems/container-with-most-water/) · Medium

**Problem.** Each array entry is the height of a vertical line at that index. Picking two lines forms a container whose water area is the shorter line's height times the horizontal distance between them. Return the maximum area achievable.

**Example.** `[1, 8, 5, 4, 7, 8]` -> `32`: the two height-`8` lines are `4` apart, so `min(8, 8) * 4 = 32`.

**Recognition.** Maximizing area = width times the shorter side -> start pointers at the far ends and always move the shorter line inward, since keeping it could never beat the current width.

## Trapping Rain Water
[Solve on LeetCode](https://leetcode.com/problems/trapping-rain-water/) · Hard

**Problem.** An array gives an elevation map where each bar has width one. After rain, water pools on top of any bar up to the level of the lower of the tallest bars to its left and right. Return the total units of trapped water.

**Example.** `[0, 2, 0, 3, 0, 1, 0, 2]` -> `7` units, water settling in the dips between the taller bars.

**Recognition.** Water above a bar depends on the min of the tallest walls on either side -> two pointers tracking running left-max and right-max, advancing from whichever side has the smaller max since that side bounds the water there.
