---
id: algo-binary-search
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-10
confidence: high
---

# Binary Search

Spot when a search space is sorted or monotonic — where a single check tells you
which half to discard — and you can halve the candidates each step for O(log n).
The signal is "sorted array", "find the boundary/threshold", or "minimize a value
that gets easier/harder as it grows". Solve each on your own machine, then log how
it went.

## Binary Search
[Solve on LeetCode](https://leetcode.com/problems/binary-search/) · Easy

**Problem.** You get an array of numbers sorted in increasing order and a target
value. Return the index where the target lives, or `-1` if it isn't present. The
solution must run in logarithmic time, so a linear scan won't do.

**Example.** In `[-4, 1, 3, 8, 12]` searching for `8` returns `3`; searching for
`5` returns `-1` because it never appears.

**Recognition.** the textbook case — sorted array, find one value. Keep `lo`/`hi`
bounds, compare the midpoint to the target, and discard the half that can't
contain it.

## Search a 2D Matrix
[Solve on LeetCode](https://leetcode.com/problems/search-a-2d-matrix/) · Medium

**Problem.** A matrix has each row sorted left-to-right, and every row's first
value is greater than the previous row's last value. Given a target, report
whether it exists anywhere in the matrix. Aim for logarithmic time in the total
number of cells.

**Example.** For rows `[[1, 3, 5], [7, 9, 11], [13, 15, 17]]` the target `9`
returns `true`; the target `10` returns `false`.

**Recognition.** the ordering means the whole grid behaves like one sorted list →
binary search over `rows*cols` and map a flat index `m` back to `(m / cols, m %
cols)`.

## Koko Eating Bananas
[Solve on LeetCode](https://leetcode.com/problems/koko-eating-bananas/) · Medium

**Problem.** Given piles of bananas and a limit of `h` hours, Koko picks an
eating speed `k` bananas/hour; each hour she eats from one pile, finishing early
if it has fewer than `k` left. Return the smallest speed `k` that lets her clear
every pile within `h` hours.

**Example.** With piles `[4, 11, 8]` and `h = 6`, speed `k = 4` needs
`1 + 3 + 2 = 6` hours, so the answer is `4`; a slower `3` would take too long.

**Recognition.** you're minimizing a value where "is speed k fast enough?" is
monotonic → binary search on the answer `k` between `1` and `max(pile)`, checking
feasibility (summed ceil-divisions ≤ h) at each guess.

## Find Minimum in Rotated Sorted Array
[Solve on LeetCode](https://leetcode.com/problems/find-minimum-in-rotated-sorted-array/) · Medium

**Problem.** A sorted array of distinct values has been rotated at some unknown
pivot. Return the smallest element. It must be done in logarithmic time, so you
can't just scan.

**Example.** `[4, 5, 6, 1, 2, 3]` (a rotation of `1..6`) returns `1`, the rotation
point where the order "wraps".

**Recognition.** the minimum sits at the rotation seam → binary search comparing
`mid` to `hi`: if `nums[mid] > nums[hi]` the dip is to the right, otherwise it's
at `mid` or left.

## Search in Rotated Sorted Array
[Solve on LeetCode](https://leetcode.com/problems/search-in-rotated-sorted-array/) · Medium

**Problem.** Given a rotated sorted array of distinct values and a target, return
the target's index or `-1`. As with the plain case, aim for logarithmic time
despite the rotation.

**Example.** In `[6, 7, 8, 1, 2, 3]`, searching `2` returns `4`; searching `5`
returns `-1`.

**Recognition.** at each step one half of `[lo..mid..hi]` is still properly
sorted → detect which half is sorted, test whether the target falls inside its
range, and recurse into the right side.

## Time Based Key-Value Store
[Solve on LeetCode](https://leetcode.com/problems/time-based-key-value-store/) · Medium

**Problem.** Build a store supporting `set(key, value, timestamp)` and
`get(key, timestamp)`. A get returns the value written at the largest stored
timestamp that is at most the queried one, or empty if none exists. Sets for a
key arrive with strictly increasing timestamps.

**Example.** After `set("a", "x", 1)` and `set("a", "y", 4)`, a `get("a", 3)`
returns `"x"` (the newest write not after time `3`), and `get("a", 5)` returns
`"y"`.

**Recognition.** because timestamps per key arrive sorted, get is a
"largest value ≤ target" lookup → keep a list per key and binary search
(upper-bound then step back one) for the floor timestamp.

## Median of Two Sorted Arrays
[Solve on LeetCode](https://leetcode.com/problems/median-of-two-sorted-arrays/) · Hard

**Problem.** Given two individually sorted arrays, return the median of the two
combined as if merged into one sorted sequence. The required runtime is
logarithmic in the total size, ruling out an actual merge.

**Example.** For `[1, 3]` and `[2, 4]` the merged view is `[1, 2, 3, 4]`, so the
median is `(2 + 3) / 2 = 2.5`.

**Recognition.** find a partition splitting both arrays so every left-side value
is ≤ every right-side value → binary search the cut position in the shorter array,
adjusting until the left/right boundary values interleave correctly.
