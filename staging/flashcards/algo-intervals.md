---
id: algo-intervals
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 2
created: 2026-09-10
confidence: high
---

# Intervals

Reach for this pattern whenever the input is a set of ranges with start/end pairs and the question is about how they overlap, merge, or pack together. The near-universal first move is to sort by start (sometimes by end), after which overlaps become a simple local comparison between neighbors instead of an all-pairs check; harder variants swap in a heap or sweep line to track what is currently "open". The tell is any prompt mentioning meetings, bookings, time slots, or `[start, end]` pairs. Solve each on your own machine, then log how it went.

## Insert Interval
[Solve on LeetCode](https://leetcode.com/problems/insert-interval/) · Medium

**Problem.** You are given a list of non-overlapping intervals already sorted by their start values, plus one new interval to add. Insert the new interval and merge anything it overlaps so the result stays sorted and non-overlapping. Return the updated list.

**Example.** Intervals `[[1,3],[6,9]]` with new interval `[2,5]` -> `[[1,5],[6,9]]`, because `[2,5]` overlaps `[1,3]` and fuses into `[1,5]`.

**Recognition.** A pre-sorted interval list plus one insertion is the trigger. Walk left-to-right: copy intervals that end before the new one starts, absorb every interval that overlaps by widening the new interval's bounds, then copy the rest.

## Merge Intervals
[Solve on LeetCode](https://leetcode.com/problems/merge-intervals/) · Medium

**Problem.** Given an unsorted collection of intervals, combine every pair that overlaps into a single continuous interval and return the resulting non-overlapping set. Two intervals overlap when one starts at or before the other ends.

**Example.** `[[1,4],[2,5],[8,10]]` -> `[[1,5],[8,10]]`, since `[1,4]` and `[2,5]` merge but `[8,10]` stands alone.

**Recognition.** "Collapse overlapping ranges" means sort by start first. Sweep through, and whenever the current interval's start is not past the last kept interval's end, extend that end; otherwise start a fresh interval.

## Non-overlapping Intervals
[Solve on LeetCode](https://leetcode.com/problems/non-overlapping-intervals/) · Medium

**Problem.** Given a set of intervals, determine the fewest you must delete so that none of the remaining ones overlap. Return that minimum count. Touching endpoints (one ends exactly where another begins) do not count as overlapping.

**Example.** `[[1,3],[2,4],[3,5]]` -> `1`: removing `[2,4]` leaves `[1,3]` and `[3,5]`, which only touch.

**Recognition.** "Minimum removals to eliminate overlaps" is the greedy interval-scheduling classic. Sort by end time, keep each interval whose start is at least the previous kept end, and count the ones you skip.

## Meeting Rooms
[Solve on LeetCode](https://leetcode.com/problems/meeting-rooms/) · Easy

**Problem.** Given a list of meeting time intervals, decide whether a single person could attend all of them — that is, whether any two meetings overlap in time. Return `true` if there are no conflicts, otherwise `false`.

**Example.** `[[0,30],[35,40]]` -> `true` (no clash); `[[0,30],[15,25]]` -> `false` because the second starts before the first ends.

**Recognition.** "Can one person attend everything?" is a pure overlap check. Sort by start, then confirm each meeting begins at or after the previous one ends; a single violation returns `false`.

## Meeting Rooms II
[Solve on LeetCode](https://leetcode.com/problems/meeting-rooms-ii/) · Medium

**Problem.** Given a list of meeting time intervals, compute the minimum number of rooms needed so that no two overlapping meetings share a room. Return that count, which equals the maximum number of meetings happening simultaneously.

**Example.** `[[0,30],[5,10],[15,20]]` -> `2`, since `[5,10]` overlaps `[0,30]` (two rooms at once) but `[15,20]` reuses the freed room.

**Recognition.** "Maximum concurrent intervals" calls for a min-heap of end times (or a start/end sweep line). Sort by start, push each meeting's end onto the heap, pop when the earliest end is free, and track the heap's peak size.

## Minimum Interval to Include Each Query
[Solve on LeetCode](https://leetcode.com/problems/minimum-interval-to-include-each-query/) · Hard

**Problem.** You are given a set of intervals and a list of query points. For each query, find the length of the smallest interval that contains that point, where length is end minus start plus one. Return an answer per query, using `-1` when no interval covers the point.

**Example.** Intervals `[[1,4],[2,4],[3,6]]` with queries `[2,7]` -> `[3,-1]`: point `2` sits in `[2,4]` (length `3`, the smallest covering it) and point `7` lies in none.

**Recognition.** "Smallest covering interval per query" combines offline sorting with a min-heap keyed by size. Sort queries and intervals ascending, and as each query point advances, add intervals whose start has been reached, discard those that already ended, and read the smallest remaining size off the heap.
