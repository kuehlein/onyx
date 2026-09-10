---
id: algo-sliding-window
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-10
confidence: high
---

# Sliding Window

Spot when the answer is over a contiguous run and recomputing each window from
scratch is wasteful: grow the window on the right, shrink from the left, and
carry the running state so each element enters and leaves at most once. Solve
each on your own machine, then log how it went.

## Best Time to Buy and Sell Stock
[Solve on LeetCode](https://leetcode.com/problems/best-time-to-buy-and-sell-stock/) · Easy

**Problem.** You're given daily prices for a stock as an array. Pick one day to
buy and a strictly later day to sell to maximize profit. Return the best profit
achievable, or `0` if no profitable trade exists.

**Example.** For prices `[8, 3, 6, 1, 9]` the answer is `8` — buy at `1`, sell
later at `9`; buying at `3` and selling at `6` only nets `3`.

**Recognition.** max profit from a single buy then later sell → sweep once,
tracking the lowest price seen so far and the best profit measured against it.

## Longest Substring Without Repeating Characters
[Solve on LeetCode](https://leetcode.com/problems/longest-substring-without-repeating-characters/) · Medium

**Problem.** Given a string, find the length of the longest contiguous substring
that contains no repeated characters. Only the length is required, not the
substring itself.

**Example.** For `"abcabcbb"` the answer is `3` (`"abc"`); for `"bbbb"` it's
`1`.

**Recognition.** longest run under a "no duplicates" constraint → expand the
right edge, and when a character repeats jump the left edge past that
character's last-seen index; track the max width along the way.

## Longest Repeating Character Replacement
[Solve on LeetCode](https://leetcode.com/problems/longest-repeating-character-replacement/) · Medium

**Problem.** Given an uppercase string and an integer `k`, you may replace up to
`k` characters with any letters. Return the length of the longest substring that
can be made into a single repeated character after those replacements.

**Example.** For `s = "AABABBA"`, `k = 1` the answer is `4` — turn one `B` in
`"AABA"` into `A` to get four `A`s in a row.

**Recognition.** longest window that becomes uniform with ≤k edits → track the
count of the most frequent char in the window; while (window length − maxFreq) >
k, shrink from the left.

## Permutation in String
[Solve on LeetCode](https://leetcode.com/problems/permutation-in-string/) · Medium

**Problem.** Given two strings `s1` and `s2`, decide whether any permutation of
`s1` appears as a contiguous substring of `s2`, and return a boolean.
Equivalently, does some window of `s2` match `s1`'s exact character counts?

**Example.** `s1 = "abc"`, `s2 = "lecabxyz"` returns `true` — the window
`"cab"` is a rearrangement of `"abc"`. `s1 = "abc"`, `s2 = "acdfe"` returns
`false`.

**Recognition.** "does a rearranged copy fit anywhere" → slide a fixed-width
window of length `len(s1)` across `s2` and compare character-count frequencies;
match when the counts line up.

## Minimum Window Substring
[Solve on LeetCode](https://leetcode.com/problems/minimum-window-substring/) · Hard

**Problem.** Given strings `s` and `t`, return the shortest contiguous substring
of `s` that contains every character of `t`, counting duplicates. If no covering
window exists, return the empty string; assume the answer is unique when it
exists.

**Example.** For `s = "ADOBECODEBANC"`, `t = "ABC"` the answer is `"BANC"` — it
holds an `A`, `B`, and `C` and no shorter window does.

**Recognition.** smallest window covering a required multiset → grow right until
all required counts are satisfied, then shrink from the left as far as still
valid, recording the minimum; a "need vs. have" counter tells you when the
window is complete.

## Sliding Window Maximum
[Solve on LeetCode](https://leetcode.com/problems/sliding-window-maximum/) · Hard

**Problem.** Given an array and a window size `k`, slide a window of width `k`
from left to right one step at a time. Return the maximum of each window
position, in order, as an array.

**Example.** For `nums = [1, 3, -1, -3, 5, 3]`, `k = 3` the maxes are
`[3, 3, 5, 5]`.

**Recognition.** running max over a fixed-width window → keep a monotonic
decreasing deque of indices; pop smaller values from the back before pushing,
drop the front when it slides out of range, and the front index is always the
current max.
