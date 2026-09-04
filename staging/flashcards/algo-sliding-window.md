---
id: algo-sliding-window
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-04
---

# Sliding Window

Spot when the answer is over a contiguous run and recomputing each window from
scratch is wasteful: grow the window on the right, shrink from the left, and
carry the running state. Solve each on your own machine, then log how it went.

## Best Time to Buy and Sell Stock
[Solve on LeetCode](https://leetcode.com/problems/best-time-to-buy-and-sell-stock/) · Easy

**Recognition:** max profit from one buy/sell → track the minimum price seen so
far and the best profit against it in a single pass.

## Longest Substring Without Repeating Characters
[Solve on LeetCode](https://leetcode.com/problems/longest-substring-without-repeating-characters/) · Medium

**Recognition:** longest run under a "no repeats" constraint → expand right, and
when a repeat appears jump the left edge past its last-seen index.

## Longest Repeating Character Replacement
[Solve on LeetCode](https://leetcode.com/problems/longest-repeating-character-replacement/) · Medium

**Recognition:** longest window valid after ≤k changes → track the count of the
most frequent char; shrink when (window length − maxFreq) exceeds k.
