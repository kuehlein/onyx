---
id: algo-heap-priority-queue
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 2
created: 2026-09-10
confidence: high
---

# Heap / Priority Queue

Reach for a heap whenever you need the smallest or largest element repeatedly, or the "top k" of something, without paying to fully sort — a binary heap gives you O(log n) inserts and O(log n) pops of the extreme while keeping the rest loosely ordered. The tell is any phrase like "kth largest", "k closest", "most frequent", "next most urgent", or "running median from a stream": you care about the ends of an ordering as data flows, not the whole thing. Solve each on your own machine, then log how it went.

## Kth Largest Element in a Stream
[Solve on LeetCode](https://leetcode.com/problems/kth-largest-element-in-a-stream/) · Easy

**Problem.** Build a class that is seeded with a number `k` and an initial list of scores. Every time a new score is added, the class must return the `k`-th largest score seen so far across all additions. It is a stateful, online query rather than a one-shot computation.

**Example.** With `k = 2` and starting scores `[1, 6, 4]`, adding `3` makes the sorted-descending view `[6, 4, 3, 1]`, so the 2nd largest returned is `4`; then adding `9` returns `6`.

**Recognition.** "K-th largest, but updated as items stream in" is the trigger. Keep a min-heap capped at size `k` — its root is always the k-th largest — and on each add, push then pop if the heap grows past `k`.

## Last Stone Weight
[Solve on LeetCode](https://leetcode.com/problems/last-stone-weight/) · Easy

**Problem.** You have a pile of stones, each with a positive weight. Repeatedly take the two heaviest stones and smash them: if equal, both are destroyed; if not, the heavier one is reduced by the lighter one's weight and stays. Return the weight of the final surviving stone, or `0` if none remain.

**Example.** `[2, 7, 4, 1]` -> smash `7` and `4` leaving `3`, giving `[3, 2, 1]`; smash `3` and `2` leaving `1`, giving `[1, 1]`; smash the two `1`s to nothing -> answer `0`.

**Recognition.** "Repeatedly grab the two biggest and combine them" screams a max-heap. Pop the top two each round, push back their difference if nonzero, and continue until one or zero stones remain.

## K Closest Points to Origin
[Solve on LeetCode](https://leetcode.com/problems/k-closest-points-to-origin/) · Medium

**Problem.** Given a set of 2-D points and a number `k`, return the `k` points nearest to the origin by straight-line distance. Any order among the returned `k` is fine, and the answer is unique. You need not compute the actual square root — squared distance preserves the ordering.

**Example.** Points `[[1, 2], [3, 4], [0, 1]]` with `k = 2` -> `[[0, 1], [1, 2]]`, since their squared distances `1` and `5` beat `[3, 4]`'s `25`.

**Recognition.** "The k nearest / smallest by some metric" points to a heap keyed on that metric. Use a max-heap of size `k` on squared distance, evicting the farthest whenever it overflows, so what remains is the closest `k`.

## Kth Largest Element in an Array
[Solve on LeetCode](https://leetcode.com/problems/kth-largest-element-in-an-array/) · Medium

**Problem.** Given an unsorted integer array and a number `k`, return the value that would sit in the `k`-th position from the largest if the array were sorted descending. This is the k-th largest by value (duplicates count), not the k-th distinct value.

**Example.** `[3, 1, 5, 5, 2]` with `k = 2` -> `5`, because the descending order is `5, 5, 3, 2, 1` and the 2nd entry is `5`.

**Recognition.** "K-th largest of a static array" is the cue — a size-`k` min-heap gives O(n log k), while Quickselect gives average O(n). Keep the `k` biggest in a min-heap whose root is the answer, or partition around a pivot until index `n - k` settles.

## Task Scheduler
[Solve on LeetCode](https://leetcode.com/problems/task-scheduler/) · Medium

**Problem.** You are given a list of CPU tasks labeled by letter and a cooldown `n`: two runs of the same task must be separated by at least `n` other time slots (which may be idle). Each task takes one unit of time. Return the minimum number of time units needed to finish every task.

**Example.** Tasks `["A", "A", "A", "B"]` with `n = 2` -> `7`: a valid run is `A B idle A idle idle A`, since the three `A`s each need two gaps between them.

**Recognition.** "Schedule with cooldown, minimize total time" — always run the most-frequent available task next. Drive it with a max-heap on remaining counts plus a queue holding tasks cooling down until their ready-time; or apply the closed-form idle-slot formula from the highest frequency.

## Design Twitter
[Solve on LeetCode](https://leetcode.com/problems/design-twitter/) · Medium

**Problem.** Design a mini social feed supporting: post a tweet, follow a user, unfollow a user, and fetch a user's news feed. The feed must return the 10 most recent tweets drawn from the user themselves plus everyone they follow, newest first.

**Example.** User `1` posts tweet `100`, follows user `2`, then user `2` posts tweet `200`; user `1`'s feed is `[200, 100]` because `200` is more recent.

**Recognition.** "Merge several time-ordered sources and take the newest few" is a k-way merge — a heap's home turf. Timestamp every tweet, then merge the followees' tweet lists with a max-heap on timestamp, popping the 10 most recent.

## Find Median from Data Stream
[Solve on LeetCode](https://leetcode.com/problems/find-median-from-data-stream/) · Hard

**Problem.** Support two operations on a growing stream of numbers: add a number, and query the median of everything added so far. With an even count the median is the average of the two middle values. Both operations should be efficient even as the stream grows large.

**Example.** Add `1`, then `2` -> median is `1.5`; add `3` -> the sorted view is `1, 2, 3` so the median becomes `2`.

**Recognition.** "Running median of a stream" is the classic two-heap balance. Keep a max-heap of the lower half and a min-heap of the upper half, sized within one of each other, so the median is a heap root (or the average of the two roots).
