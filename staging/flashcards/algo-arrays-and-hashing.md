---
id: algo-arrays-and-hashing
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-04
---

# Arrays & Hashing

Spot when a problem is really about fast lookups: a hash map/set trades space for
O(1) membership or complement checks. Solve each on your own machine, then log
how it went.

## Two Sum
[Solve on LeetCode](https://leetcode.com/problems/two-sum/) · Easy

**Recognition:** an array + "find a pair that sums to a target", returning
indices. Store value → index as you go and check for the complement `target - x`
before inserting.

## Contains Duplicate
[Solve on LeetCode](https://leetcode.com/problems/contains-duplicate/) · Easy

**Recognition:** "are there any repeats?" — a hash set gives O(1) membership;
return true the first time an element is already present.

## Valid Anagram
[Solve on LeetCode](https://leetcode.com/problems/valid-anagram/) · Easy

**Recognition:** two strings, same multiset of characters — compare character
counts (a 26-int array or a map).

## Product of Array Except Self
[Solve on LeetCode](https://leetcode.com/problems/product-of-array-except-self/) · Medium

**Recognition:** "product/aggregate of everything but i", no division allowed →
prefix products left-to-right, then multiply by suffix products right-to-left.

## Group Anagrams
[Solve on LeetCode](https://leetcode.com/problems/group-anagrams/) · Medium

**Recognition:** bucket items by a canonical key — here the sorted string (or the
char-count signature) maps anagrams to the same group.
