---
id: algo-2d-dynamic-programming
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 3
created: 2026-09-10
confidence: high
---

# 2-D Dynamic Programming

Reach for this pattern when the state you need to memoize depends on two moving indices at once — a position in one sequence paired with a position in another, a cell's row and column, or an index paired with a running budget/target. The tell is that a single 1-D array can't capture the subproblem because progress is tracked along two axes, so you fill a grid where each cell reuses smaller already-computed cells. Solve each on your own machine, then log how it went.

## Unique Paths
[Solve on LeetCode](https://leetcode.com/problems/unique-paths/) · Medium

**Problem.** A robot sits at the top-left corner of an `m` by `n` grid and wants to reach the bottom-right corner. It may only step right or down at each move. Return the total number of distinct routes it can take.

**Example.** A `3 x 3` grid -> `6` distinct paths, since each route is some interleaving of two rights and two downs.

**Recognition.** "Count paths through a grid moving only right/down" is the cue. Each cell's path-count is the sum of the cell above and the cell to the left, with the top row and left column all seeded to `1`.

## Longest Common Subsequence
[Solve on LeetCode](https://leetcode.com/problems/longest-common-subsequence/) · Medium

**Problem.** Given two strings, find the length of the longest sequence of characters that appears in both, in the same relative order, though not necessarily contiguously. Return that length, or `0` if they share no common subsequence.

**Example.** `"abcde"` and `"ace"` -> `3`, because `a`, `c`, `e` appear in order in both.

**Recognition.** Two strings plus "longest shared ordered subsequence" points to a 2-D table indexed by prefixes of each string. On a character match, take the diagonal cell plus one; otherwise take the max of dropping one character from either side.

## Best Time to Buy and Sell Stock with Cooldown
[Solve on LeetCode](https://leetcode.com/problems/best-time-to-buy-and-sell-stock-with-cooldown/) · Medium

**Problem.** Given daily stock prices, maximize your total profit from any number of buy/sell transactions, holding at most one share at a time. The twist: after you sell, you must skip one day (a cooldown) before you can buy again. Return the best achievable profit.

**Example.** Prices `[1, 2, 3]` -> `2`: buy at `1` and sell at `3`; the forced cooldown after selling makes a second trade unprofitable here, so one clean trade wins.

**Recognition.** "Stock trading with a state restriction" means track profit per day across a small set of states — holding, sold-today, and free-to-buy. Each day's states transition from the prior day's, with the cooldown enforced by routing "sold" only into a resting state.

## Coin Change II
[Solve on LeetCode](https://leetcode.com/problems/coin-change-ii/) · Medium

**Problem.** Given coin denominations with unlimited supply and a target amount, count how many distinct combinations of coins sum exactly to that amount. Order does not matter — `1+2` and `2+1` are the same combination. Return the number of combinations.

**Example.** Coins `[1, 2, 5]`, amount `5` -> `4`: `5`, `2+2+1`, `2+1+1+1`, `1+1+1+1+1`.

**Recognition.** "Count combinations (not permutations) with unlimited coins" is the trigger — an unbounded-knapsack count. Loop coins on the outer axis and amounts on the inner, adding ways-to-make; iterating coins outermost is what prevents double-counting reorderings.

## Target Sum
[Solve on LeetCode](https://leetcode.com/problems/target-sum/) · Medium

**Problem.** Given an array of non-negative integers, assign a `+` or `-` sign to each one so the signed sum equals a given target. Return how many distinct sign assignments achieve it. Every element must receive exactly one sign.

**Example.** `[1, 1, 1]`, target `1` -> `3`: the three ways to make one `-` cancel out (e.g. `+1+1-1`).

**Recognition.** "Split into +/- groups hitting a target" reduces to a subset-sum count: the positives must total `(sum + target) / 2`. Then it's a 0/1-knapsack DP counting subsets that reach that derived sum.

## Interleaving String
[Solve on LeetCode](https://leetcode.com/problems/interleaving-string/) · Medium

**Problem.** Given three strings, decide whether the third can be formed by interleaving the characters of the first two while preserving each one's internal order. Return a boolean. A necessary first check: the third's length must equal the sum of the other two.

**Example.** `"ab"` and `"cd"` interleaving into `"acbd"` -> `true`; into `"abdc"` -> `false` because `d` would come before `c`.

**Recognition.** "Can string C be woven from A and B keeping order" is a 2-D reachability grid indexed by how many characters of A and of B are consumed. A cell is reachable if the next char of C matches A's next (from the left cell) or B's next (from the cell above).

## Longest Increasing Path in a Matrix
[Solve on LeetCode](https://leetcode.com/problems/longest-increasing-path-in-a-matrix/) · Hard

**Problem.** Given a matrix of integers, find the length of the longest path of strictly increasing values, moving only up, down, left, or right between adjacent cells. You cannot revisit a cell, and diagonal moves are not allowed. Return that maximum length.

**Example.** A matrix whose values form `1 -> 2 -> 6 -> 9` along adjacent increasing steps -> `4`.

**Recognition.** "Longest strictly increasing walk in a grid" — because strict increase forbids cycles, it's a DAG, so DFS from each cell with memoization. Cache the longest path starting at each cell; each cell's answer is `1 + max` over larger neighbors.

## Distinct Subsequences
[Solve on LeetCode](https://leetcode.com/problems/distinct-subsequences/) · Hard

**Problem.** Given two strings `s` and `t`, count how many distinct ways you can delete characters from `s` (without reordering) so that what remains equals `t` exactly. Return that count of subsequences of `s` that spell out `t`.

**Example.** `s = "rabbbit"`, `t = "rabbit"` -> `3`, since there are three ways to choose which `b` to drop.

**Recognition.** "Count subsequences of s that equal t" is a 2-D table over prefixes of both. When the current characters match you sum two options — use it (diagonal) or skip this `s` char (left); when they differ you can only skip in `s`.

## Edit Distance
[Solve on LeetCode](https://leetcode.com/problems/edit-distance/) · Medium

**Problem.** Given two strings, compute the minimum number of single-character edits needed to turn the first into the second. The allowed operations are inserting a character, deleting a character, or replacing one character with another. Return that minimum count.

**Example.** `"cat"` -> `"cut"` needs `1` edit (replace `a` with `u`); `"sunday"` -> `"saturday"` needs `3`.

**Recognition.** "Minimum operations to transform one string into another" is the classic 2-D edit grid. If the characters match, copy the diagonal; otherwise take `1 +` the min of the three neighbors (insert = left, delete = up, replace = diagonal).

## Burst Balloons
[Solve on LeetCode](https://leetcode.com/problems/burst-balloons/) · Hard

**Problem.** Given balloons each painted with a number, you burst them one at a time. Bursting a balloon earns you the product of its value with its two current neighbors (treating out-of-bounds edges as `1`). After a burst, its neighbors become adjacent. Return the maximum coins obtainable by choosing a burst order.

**Example.** `[3, 1, 5]` -> `35`: burst `1` first (`3*1*5 = 15`), then `3` (`1*3*5 = 15`), then `5` (`1*5*1 = 5`), totaling `35`.

**Recognition.** "Optimal order over a range where each choice reshapes neighbors" is interval DP. Flip the framing: decide which balloon is burst *last* in each subinterval, so its neighbors are the fixed interval boundaries, and combine left and right subintervals.

## Regular Expression Matching
[Solve on LeetCode](https://leetcode.com/problems/regular-expression-matching/) · Hard

**Problem.** Given an input string and a pattern, decide whether the pattern matches the entire string. The pattern supports `.` (matches any single character) and `*` (matches zero or more of the immediately preceding element). The match must cover the whole string, not just a prefix. Return a boolean.

**Example.** `"aab"` against pattern `"c*a*b"` -> `true`, since `c*` matches zero `c`s and `a*` matches two `a`s.

**Recognition.** "Full-string match with `.` and `*` wildcards" is a 2-D DP over positions in the string and pattern. The subtle case is `*`: it can mean zero of the preceding token (skip two pattern chars) or one-more (if that token matches the current string char, consume it and stay on the `*`).
