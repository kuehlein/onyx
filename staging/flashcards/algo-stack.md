---
id: algo-stack
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-04
---

# Stack

Reach for a stack when the most recently seen thing is the first you need to
resolve — matching pairs, nested structure, or "nearest previous" relationships.
Solve each on your own machine, then log how it went.

## Valid Parentheses
[Solve on LeetCode](https://leetcode.com/problems/valid-parentheses/) · Easy

**Recognition:** matching nested brackets → push openers, and on each closer pop
and check it matches. Valid iff the stack is empty at the end.

## Min Stack
[Solve on LeetCode](https://leetcode.com/problems/min-stack/) · Medium

**Recognition:** O(1) min alongside push/pop → keep an auxiliary stack of the
running minimum in lockstep with the main stack.

## Daily Temperatures
[Solve on LeetCode](https://leetcode.com/problems/daily-temperatures/) · Medium

**Recognition:** "days until a greater value" → monotonic decreasing stack of
indices; pop while the current value exceeds the top, recording the gap.
