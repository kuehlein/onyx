---
id: algo-arrays-and-hashing
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-10
confidence: high
---

# Arrays & Hashing

Reach for this pattern when the work is really about fast lookups, counting, or grouping: a hash map or set trades space for O(1) membership, complement, and frequency checks, collapsing a naive nested scan into a single pass. The tell is any question that asks "have I seen this before?", "how many of each?", or "which items share a key?". Solve each on your own machine, then log how it went.

## Contains Duplicate
[Solve on LeetCode](https://leetcode.com/problems/contains-duplicate/) · Easy

**Problem.** You are handed an integer array and must report whether any value shows up more than once. Return `true` if at least one number repeats anywhere in the array, otherwise `false`. The whole array is fair game — duplicates need not be adjacent.

**Example.** `[4, 1, 7, 1]` -> `true` because `1` appears twice; `[3, 5, 9]` -> `false` since every value is distinct.

**Recognition.** "Are there any repeats?" is the trigger. Stream the values into a hash set and return `true` the moment you try to add one that is already present.

## Valid Anagram
[Solve on LeetCode](https://leetcode.com/problems/valid-anagram/) · Easy

**Problem.** Given two strings, decide if the second is an anagram of the first — that is, whether they contain exactly the same letters with the same multiplicities, just reordered. Return a boolean. Length mismatch is an immediate no.

**Example.** `"listen"` and `"silent"` -> `true` (same letter counts); `"rat"` and `"car"` -> `false` because the letter multisets differ.

**Recognition.** Two strings, "same characters rearranged" — compare character frequencies. Tally counts with a 26-slot array or a map, then check both sides match.

## Two Sum
[Solve on LeetCode](https://leetcode.com/problems/two-sum/) · Easy

**Problem.** Given an array of integers and a target value, find the two positions whose values add up to the target and return those two indices. Exactly one valid pair is guaranteed, and you may not reuse the same element twice.

**Example.** `nums = [2, 8, 5, 3]`, `target = 8` -> `[0, 3]` because `2 + 3 == 8`.

**Recognition.** An array plus "find a pair summing to a target" returning indices. As you scan, store each value's index and check whether the complement `target - x` was already seen before inserting.

## Group Anagrams
[Solve on LeetCode](https://leetcode.com/problems/group-anagrams/) · Medium

**Problem.** Given a list of strings, cluster them so that words which are anagrams of one another land in the same group. Return the collection of groups in any order. Every input word belongs to exactly one group.

**Example.** `["bat", "tab", "cat"]` -> `[["bat", "tab"], ["cat"]]` since `bat` and `tab` share the same letters.

**Recognition.** "Bucket items that share some canonical form." Map each word to a key that is identical for anagrams — the sorted string or a 26-length count signature — and append it into that key's list.

## Top K Frequent Elements
[Solve on LeetCode](https://leetcode.com/problems/top-k-frequent-elements/) · Medium

**Problem.** Given an integer array and a number `k`, return the `k` values that occur most often. The answer is guaranteed unique, and the returned order does not matter.

**Example.** `nums = [5, 5, 5, 2, 2, 9]`, `k = 2` -> `[5, 2]` because `5` appears three times and `2` twice, the two highest counts.

**Recognition.** "The most frequent items" means count first, then rank. Build a frequency map, then either use bucket sort indexed by count (O(n)) or a size-`k` heap to pull off the top `k`.

## Product of Array Except Self
[Solve on LeetCode](https://leetcode.com/problems/product-of-array-except-self/) · Medium

**Problem.** Given an integer array, return a new array where each position holds the product of every other element — everything except the value at that index. You must do it without using division and in linear time.

**Example.** `[2, 3, 4]` -> `[12, 8, 6]`: position 0 is `3 * 4`, position 1 is `2 * 4`, position 2 is `2 * 3`.

**Recognition.** "Aggregate of everything but i" with division banned is the cue. Sweep left-to-right accumulating prefix products, then right-to-left multiplying in suffix products.

## Valid Sudoku
[Solve on LeetCode](https://leetcode.com/problems/valid-sudoku/) · Medium

**Problem.** Given a partially filled 9x9 Sudoku board, decide whether the current placement breaks any rule. No digit may repeat within a row, within a column, or within any of the nine 3x3 sub-boxes. Empty cells are ignored, and you only validate what is filled — you do not solve it.

**Example.** A board where row 0 already contains two `7`s -> `false`; a board with no repeats in any row, column, or box -> `true`.

**Recognition.** "Check no duplicates across three overlapping groupings" points to sets. Keep a seen-set per row, per column, and per 3x3 box (box index `(r/3, c/3)`), and fail on the first collision.

## Encode and Decode Strings
[Solve on LeetCode](https://leetcode.com/problems/encode-and-decode-strings/) · Medium

**Problem.** Design two functions: one that serializes a list of strings into a single string, and one that reconstructs the original list from that string. The catch is the strings may contain any characters, including whatever delimiter you might be tempted to use, so the scheme must be unambiguous.

**Example.** Encoding `["hi", "a#b"]` as `"2#hi3#a#b"` (each chunk is length + `#` + payload) decodes back to `["hi", "a#b"]` even though a payload contains `#`.

**Recognition.** "Round-trip a list through one string with arbitrary contents" means a length-prefix framing. Write each string as its length, a separator, then the raw bytes; on decode, read the number, skip the separator, then slice exactly that many characters.

## Longest Consecutive Sequence
[Solve on LeetCode](https://leetcode.com/problems/longest-consecutive-sequence/) · Medium

**Problem.** Given an unsorted integer array, find the length of the longest run of consecutive integers that can be formed from its values. The elements need not be adjacent in the array, and the solution must run in linear time (so no sorting).

**Example.** `[8, 3, 100, 4, 2, 5]` -> `4` because `2, 3, 4, 5` form the longest consecutive stretch.

**Recognition.** "Longest consecutive run in O(n)" rules out sorting, so use a set. Dump all values into a hash set, and only start counting upward (`x, x+1, x+2, ...`) from numbers that have no `x-1` — those are sequence starts.
