---
id: algo-greedy
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 2
created: 2026-09-10
confidence: high
---

# Greedy

Reach for greedy when a locally-optimal choice at each step provably leads to a globally-optimal answer, so you can sweep the input once and commit to the best move so far without backtracking or exploring every combination. The tell is an optimization ("max/min", "fewest", "can you reach") where you can keep a single running quantity — a best-so-far, a reachable frontier, a running balance — and never need to reconsider past decisions. Solve each on your own machine, then log how it went.

## Maximum Subarray
[Solve on LeetCode](https://leetcode.com/problems/maximum-subarray/) · Medium

**Problem.** Given an integer array that may contain negatives, find the contiguous slice with the largest sum and return that sum. The slice must be non-empty and unbroken — you cannot skip elements in the middle.

**Example.** `[-2, 4, -1, 3, -5]` -> `6` because the run `4, -1, 3` sums to `6`, beating every other contiguous window.

**Recognition.** "Largest contiguous sum" is the Kadane cue. Walk the array keeping a running sum, and reset it to the current element whenever it drops below zero (a negative prefix can only hurt what follows); track the best seen.

## Jump Game
[Solve on LeetCode](https://leetcode.com/problems/jump-game/) · Medium

**Problem.** You are given an array where each value is the maximum number of steps you can jump forward from that position. Starting at index 0, return whether it is possible to reach the last index.

**Example.** `[2, 3, 0, 1, 4]` -> `true` (jump 0->1->4 or similar reaches the end); `[3, 2, 1, 0, 4]` -> `false` because you get stuck at the `0` before the last index.

**Recognition.** "Can I reach the end from here?" Sweep left to right tracking the farthest index reachable so far; if your current index ever exceeds that frontier you're stuck, otherwise extend the frontier and succeed if it covers the last index.

## Jump Game II
[Solve on LeetCode](https://leetcode.com/problems/jump-game-ii/) · Medium

**Problem.** Same setup as Jump Game — each value is the max forward jump length — but now reaching the last index is guaranteed. Return the minimum number of jumps needed to get there.

**Example.** `[2, 3, 1, 1, 4]` -> `2` because you jump from index 0 to index 1, then from index 1 straight to the last index.

**Recognition.** "Fewest jumps" is a BFS-by-levels greedy. Treat the current jump's reachable range as a window; scan it computing the farthest you could reach next, and when you hit the window's end, spend a jump and advance to that new frontier.

## Gas Station
[Solve on LeetCode](https://leetcode.com/problems/gas-station/) · Medium

**Problem.** You have two arrays over a circular route of stations: gas available at each station and the cost to drive from it to the next. Starting with an empty tank, return the index of the station you must begin at to make a full loop, or `-1` if no start works. A valid start is unique when it exists.

**Example.** gas `[1, 3, 2]`, cost `[2, 1, 2]` -> `1` because starting at station `1` you accumulate enough to complete the circuit; starting elsewhere runs the tank negative.

**Recognition.** "Circular route, one feasible start." If total gas is less than total cost, it's impossible (`-1`). Otherwise sweep once tracking a running tank; whenever it goes negative, the answer can't be any station up to here, so reset the tank and set the candidate start to the next station.

## Hand of Straights
[Solve on LeetCode](https://leetcode.com/problems/hand-of-straights/) · Medium

**Problem.** Given a multiset of card values and a group size, decide whether all cards can be partitioned into groups of exactly that size, where each group is a run of consecutive values. Return `true` only if every card fits into some such consecutive run.

**Example.** cards `[1, 2, 3, 6, 5, 4]`, size `3` -> `true` (groups `[1,2,3]` and `[4,5,6]`); cards `[1, 2, 3, 5]`, size `2` -> `false` because `5` cannot pair with `4`.

**Recognition.** "Partition into consecutive runs" — always start a run from the smallest remaining value. Count frequencies, and repeatedly take the current minimum as a run's start, decrementing counts for the next `size-1` consecutive values; if any is missing, it's impossible.

## Merge Triplets to Form Target Triplet
[Solve on LeetCode](https://leetcode.com/problems/merge-triplets-to-form-target-triplet/) · Medium

**Problem.** You have a list of triplets and a target triplet. A merge of two triplets replaces each position with the larger of the two values. Return whether, by merging some subset of the given triplets, you can produce exactly the target.

**Example.** triplets `[[1,3,1],[2,1,4],[1,2,5]]`, target `[2,3,5]` -> `true` because merging the last three positions from usable triplets hits `2`, `3`, and `5`; a triplet like `[3,1,1]` would be unusable since `3` overshoots the target's first slot.

**Recognition.** "Merge takes the max per position." Ignore any triplet that exceeds the target in any coordinate (it would overshoot). Among the rest, check you can find one that matches the target in each individual position — collect which positions are achievable and require all three.

## Partition Labels
[Solve on LeetCode](https://leetcode.com/problems/partition-labels/) · Medium

**Problem.** Given a string, split it into as many contiguous pieces as possible so that each distinct letter appears in only one piece. Return the list of piece lengths, in order.

**Example.** `"abacdc"` -> `[3, 3]` because both `a`s force the first piece to extend to `aba`, then `cdc` forms the second piece — lengths `3` and `3`.

**Recognition.** "Each letter confined to one segment" — precompute each character's last occurrence. Sweep extending the current segment's end to the max last-index of every character seen; when your position reaches that end, close the segment and record its length.

## Valid Parenthesis String
[Solve on LeetCode](https://leetcode.com/problems/valid-parenthesis-string/) · Medium

**Problem.** Given a string of `(`, `)`, and `*`, where each `*` can act as `(`, `)`, or an empty string, decide whether the string can be made into a valid parenthesization. Return a boolean.

**Example.** `"(*))"` -> `true` because the `*` can act as `(`, giving `(())`; `")("` -> `false` since no substitution fixes a closer that appears before its opener.

**Recognition.** Wildcards make this a range problem — track the min and max possible number of open parens as you scan. `*` widens the range (min down, max up), `(` bumps both up, `)` both down; clamp min at 0, fail if max ever goes negative, and succeed if min can reach 0 at the end.
