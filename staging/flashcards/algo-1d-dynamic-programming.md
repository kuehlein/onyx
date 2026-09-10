---
id: algo-1d-dynamic-programming
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 2
created: 2026-09-10
confidence: high
---

# 1-D Dynamic Programming

Reach for 1-D DP when the answer for a position depends on the answers for a few earlier positions, and the same subproblem keeps recurring — you are counting ways, minimizing cost, or asking whether some target is reachable along a single axis (an index, a length, an amount). The tell is a natural recurrence `f(i)` built from `f(i-1)`, `f(i-2)`, or `f(i - k)`, letting you fill a table left-to-right (often collapsing to a couple of rolling variables) instead of re-exploring an exponential tree. Solve each on your own machine, then log how it went.

## Climbing Stairs
[Solve on LeetCode](https://leetcode.com/problems/climbing-stairs/) · Easy

**Problem.** You climb a staircase of `n` steps, taking either 1 or 2 steps at a time. Count how many distinct sequences of moves reach the top exactly. Return that count.

**Example.** `n = 4` -> `5`: the move sequences are `1+1+1+1`, `1+1+2`, `1+2+1`, `2+1+1`, and `2+2`.

**Recognition.** "Count paths where each move is +1 or +2" is Fibonacci in disguise. The ways to reach step `i` equal the ways to reach `i-1` plus the ways to reach `i-2`, so carry two rolling values.

## Min Cost Climbing Stairs
[Solve on LeetCode](https://leetcode.com/problems/min-cost-climbing-stairs/) · Easy

**Problem.** Each stair has a cost you pay to step on it, given as an array. From a stair you may advance one or two positions, and you may start on either the first or second stair. Return the cheapest total cost to step past the top.

**Example.** `cost = [10, 5, 1, 20]` -> `6`: start on index 1 (pay `5`), hop to index 2 (pay `1`), then step off the end — total `5 + 1 = 6`.

**Recognition.** "Minimize accumulated cost with +1/+2 hops" means a min-recurrence. The cost to reach a position is its own cost plus the cheaper of the two preceding reachable positions; roll two values up the array.

## House Robber
[Solve on LeetCode](https://leetcode.com/problems/house-robber/) · Medium

**Problem.** Houses along a street each hold some cash, given in an array. You want the most money, but robbing two directly adjacent houses trips an alarm, so no two chosen houses may be neighbors. Return the maximum loot.

**Example.** `[4, 1, 1, 4]` -> `8`: take the first and last house (`4 + 4`); grabbing the middle ones would force skipping the larger ends.

**Recognition.** "Max sum with no two adjacent picks" is the classic take-or-skip DP. At each house choose the better of skipping it (best through `i-1`) or taking it (its value plus best through `i-2`).

## House Robber II
[Solve on LeetCode](https://leetcode.com/problems/house-robber-ii/) · Medium

**Problem.** Same non-adjacent robbery rule as before, but now the houses are arranged in a circle, so the first and last houses are also neighbors. Given the array of amounts, return the maximum you can steal without hitting two adjacent houses.

**Example.** `[3, 7, 3, 7]` -> `14`: rob indices 1 and 3 (`7 + 7`); you cannot take both ends since they are now adjacent.

**Recognition.** The circular constraint links the two ends, so split into two linear House Robber runs — one excluding the first house, one excluding the last — and take the better result.

## Longest Palindromic Substring
[Solve on LeetCode](https://leetcode.com/problems/longest-palindromic-substring/) · Medium

**Problem.** Given a string, find the longest contiguous slice that reads the same forwards and backwards. Return that substring itself. If several tie, any one of them is acceptable.

**Example.** `"xabbaz"` -> `"abba"`: the widest slice that mirrors around its center, longer than single letters like `"x"`.

**Recognition.** "Longest mirror-symmetric contiguous run" cues expand-around-center: treat every index (and every gap) as a possible palindrome center and grow outward while the ends match, tracking the widest span.

## Palindromic Substrings
[Solve on LeetCode](https://leetcode.com/problems/palindromic-substrings/) · Medium

**Problem.** Given a string, count how many of its contiguous substrings are palindromes. Every single character counts as one, and substrings at different positions are counted separately even if identical. Return the total count.

**Example.** `"aaa"` -> `6`: three single letters, two `"aa"` pairs, and the whole `"aaa"`.

**Recognition.** "Count all palindromic substrings" is the same expand-around-center machinery as the longest-palindrome problem, but instead of tracking the max span you increment a counter for every valid expansion from each center.

## Decode Ways
[Solve on LeetCode](https://leetcode.com/problems/decode-ways/) · Medium

**Problem.** A digit string encodes letters where `1`->`A` through `26`->`Z`. Count how many distinct letter strings could have produced the given digit string. Return that count; a leading `0` in any group makes it invalid.

**Example.** `"226"` -> `3`: it decodes as `"BZ"` (2, 26), `"VF"` (22, 6), or `"BBF"` (2, 2, 6).

**Recognition.** "Count decodings" is a 1-D DP over string position. Ways to decode up to `i` add the ways up to `i-1` if the single digit is valid (1–9) plus the ways up to `i-2` if the two-digit pair is 10–26.

## Coin Change
[Solve on LeetCode](https://leetcode.com/problems/coin-change/) · Medium

**Problem.** Given coin denominations (unlimited supply of each) and a target amount, return the fewest coins that sum exactly to the amount. If no combination reaches the amount, return `-1`.

**Example.** `coins = [1, 3, 4]`, `amount = 6` -> `2`: use `3 + 3` rather than three coins like `4 + 1 + 1`.

**Recognition.** "Fewest items to hit an exact total, unlimited reuse" is unbounded-knapsack DP over amount. Build `best[a] = 1 + min over coins c of best[a - c]`, filling amounts 0..target.

## Maximum Product Subarray
[Solve on LeetCode](https://leetcode.com/problems/maximum-product-subarray/) · Medium

**Problem.** Given an integer array, find the contiguous subarray whose elements multiply to the largest product, and return that product. The array may contain negatives and zeros, which can flip or reset the running product.

**Example.** `[2, -3, -4]` -> `24`: the whole array, since two negatives multiply back to a positive `24`.

**Recognition.** Negatives make a large product swing to smallest, so track both a running max and a running min at each index; a negative element swaps their roles. The answer is the best max seen across the sweep.

## Word Break
[Solve on LeetCode](https://leetcode.com/problems/word-break/) · Medium

**Problem.** Given a string and a dictionary of words, decide whether the string can be segmented into a sequence of one or more dictionary words, reusing words freely. Return a boolean. The segmentation must consume the whole string.

**Example.** `s = "applepen"`, dict `["apple", "pen"]` -> `true`, split as `"apple" + "pen"`.

**Recognition.** "Can this string be sliced into dictionary pieces" is a reachability DP over prefixes. `reach[i]` is true if some `reach[j]` is true and the slice `s[j..i]` is a dictionary word; build up to the full length.

## Longest Increasing Subsequence
[Solve on LeetCode](https://leetcode.com/problems/longest-increasing-subsequence/) · Medium

**Problem.** Given an integer array, find the length of the longest subsequence whose values strictly increase. The chosen elements keep their original order but need not be contiguous. Return just the length.

**Example.** `[3, 1, 4, 2, 5]` -> `3`: for instance `1, 4, 5` or `1, 2, 5`.

**Recognition.** "Longest strictly increasing pick keeping order" is LIS. The O(n^2) DP sets `len[i]` to 1 plus the best `len[j]` for any earlier smaller value; the patience-sorting variant with binary search gets it to O(n log n).

## Partition Equal Subset Sum
[Solve on LeetCode](https://leetcode.com/problems/partition-equal-subset-sum/) · Medium

**Problem.** Given an array of positive integers, decide whether it can be split into two groups with equal sums. Return a boolean. Every element must go into exactly one of the two groups.

**Example.** `[1, 5, 4, 2]` -> `true`: split into `{1, 5}` and `{4, 2}`, each summing to `6`.

**Recognition.** Equal halves means finding a subset that sums to half the total (bail early if the total is odd). That is a 0/1 subset-sum DP: a boolean set of reachable sums, adding each number's contribution over a rolling array from high to low.
