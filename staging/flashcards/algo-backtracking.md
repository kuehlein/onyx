---
id: algo-backtracking
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 2
created: 2026-09-10
confidence: high
---

# Backtracking

Reach for backtracking when a problem asks you to enumerate or search over combinatorial choices — every subset, permutation, arrangement, or valid configuration — and a greedy or single-pass approach cannot capture the branching. The tell is "return all the ways", "find any valid arrangement", or a decision tree where each step picks an option, recurses, then undoes that choice to try the next. You build a partial candidate incrementally, prune branches that can't lead to a solution, and restore state on the way back up. Solve each on your own machine, then log how it went.

## Subsets
[Solve on LeetCode](https://leetcode.com/problems/subsets/) · Medium

**Problem.** Given an array of distinct integers, produce every possible subset — the power set — including the empty set and the full array itself. Order of the subsets and order within each subset do not matter, and no two subsets may be identical (guaranteed since inputs are distinct).

**Example.** `[1, 2]` -> `[[], [1], [2], [1, 2]]`: for each element you either include it or skip it, giving `2^n` subsets.

**Recognition.** "All subsets / power set" is the trigger. At each index make a binary choice — include this element or not — recursing on the rest, and record the running subset at the base case.

## Combination Sum
[Solve on LeetCode](https://leetcode.com/problems/combination-sum/) · Medium

**Problem.** Given a list of distinct positive integers and a target, return every unique combination of the numbers that sums exactly to the target. Each number may be reused an unlimited number of times, and two combinations differing only in ordering count as the same.

**Example.** `candidates = [2, 3]`, `target = 7` -> `[[2, 2, 3]]` since `2 + 2 + 3 == 7`; `[3, 2, 2]` is the same combination and not listed separately.

**Recognition.** "Unlimited reuse, combinations summing to target" cues backtracking with a start index that does NOT advance on reuse. Recurse allowing the same index again, subtract from the remaining target, and prune when it goes negative.

## Combination Sum II
[Solve on LeetCode](https://leetcode.com/problems/combination-sum-ii/) · Medium

**Problem.** Given a list of positive integers that may contain duplicates and a target, return every unique combination summing to the target, where each array element may be used at most once. The tricky part is avoiding duplicate combinations that arise from repeated values in the input.

**Example.** `candidates = [1, 1, 2]`, `target = 3` -> `[[1, 2]]`: even though there are two `1`s, the combination `[1, 2]` must appear only once.

**Recognition.** "Each element used once + duplicates in input + no duplicate combos" means sort first, advance the start index each pick, and skip a value equal to its predecessor at the same recursion depth.

## Permutations
[Solve on LeetCode](https://leetcode.com/problems/permutations/) · Medium

**Problem.** Given an array of distinct integers, return all possible orderings of the entire array. Every permutation uses all elements exactly once, and since the inputs are distinct all `n!` orderings are unique.

**Example.** `[1, 2, 3]` -> `[[1,2,3], [1,3,2], [2,1,3], [2,3,1], [3,1,2], [3,2,1]]`, all `3! = 6` arrangements.

**Recognition.** "All orderings using every element" is a permutation search. At each depth pick any not-yet-used element (track a used set or swap in place), recurse, then unmark to explore the next choice.

## Subsets II
[Solve on LeetCode](https://leetcode.com/problems/subsets-ii/) · Medium

**Problem.** Given an array of integers that may include duplicates, return all possible subsets without any duplicate subsets in the output. The empty set and full set count, and `[1, 2]` must not appear twice even if the input has repeated values.

**Example.** `[1, 2, 2]` -> `[[], [1], [2], [1,2], [2,2], [1,2,2]]`: note `[2]` and `[1,2]` each appear once despite two `2`s.

**Recognition.** "Subsets with duplicate input, no duplicate subsets" = Subsets plus dedup. Sort the array, and when iterating choices at a level skip any element equal to the previous one already tried at that level.

## Word Search
[Solve on LeetCode](https://leetcode.com/problems/word-search/) · Medium

**Problem.** Given a 2D grid of letters and a target word, determine whether the word can be spelled by moving through adjacent cells (up, down, left, right). Each cell may be used at most once per path, and you return `true` or `false`.

**Example.** In grid `[[A, B], [C, D]]` searching `"ABD"` -> `true` (A->B->D are adjacent), but `"AC"` from a path that revisits a cell is disallowed.

**Recognition.** "Find a path spelling a word on a grid, no cell reuse" is DFS backtracking. From each starting cell recurse into the four neighbors matching the next letter, mark the cell as visited during recursion, and unmark it when you backtrack.

## Palindrome Partitioning
[Solve on LeetCode](https://leetcode.com/problems/palindrome-partitioning/) · Medium

**Problem.** Given a string, split it into contiguous pieces such that every piece is a palindrome, and return all such partitionings. Every character must belong to exactly one piece, and you want every valid way to cut the string.

**Example.** `"aab"` -> `[["a", "a", "b"], ["aa", "b"]]`: both cuttings leave only palindromic substrings.

**Recognition.** "All ways to cut a string so each part satisfies a property" cues backtracking over cut positions. Try every prefix, and only recurse on the remainder when that prefix is itself a palindrome.

## Letter Combinations of a Phone Number
[Solve on LeetCode](https://leetcode.com/problems/letter-combinations-of-a-phone-number/) · Medium

**Problem.** Given a string of digits from 2 to 9, return every letter combination the number could represent, using the classic phone keypad mapping (2->abc, 3->def, and so on). The digit order is fixed; you pick one letter per digit. An empty input yields no combinations.

**Example.** `"23"` -> `["ad", "ae", "af", "bd", "be", "bf", "cd", "ce", "cf"]`: one letter chosen from `2`'s set, one from `3`'s set.

**Recognition.** "Cartesian product of per-digit letter sets" is a fixed-depth backtrack. Recurse digit by digit, appending each candidate letter for the current digit before descending to the next.

## Generate Parentheses
[Solve on LeetCode](https://leetcode.com/problems/generate-parentheses/) · Medium

**Problem.** Given a number `n`, generate every string of `n` pairs of parentheses that is well-formed (every open bracket properly closed and correctly nested). Return all such valid strings.

**Example.** `n = 2` -> `["(())", "()()"]`, the only two balanced arrangements of two pairs.

**Recognition.** "Generate all valid bracket sequences" cues backtracking with counting constraints. Add `(` while opens remain, add `)` only while closes-used is below opens-used, and record a string once it reaches length `2n`.

## N-Queens
[Solve on LeetCode](https://leetcode.com/problems/n-queens/) · Hard

**Problem.** Given an `n x n` chessboard, place `n` queens so that no two attack each other — no two share a row, column, or diagonal — and return every distinct valid board configuration. Each solution is typically rendered as the board with queen positions marked.

**Example.** `n = 4` -> two solutions; one places queens at columns `[1, 3, 0, 2]` reading rows top to bottom, so no pair collides on any line.

**Recognition.** "Place N non-attacking pieces / return all boards" is classic constraint backtracking. Go row by row, and before placing a queen check sets of used columns and both diagonals (`row+col`, `row-col`); recurse, then release those markers.
