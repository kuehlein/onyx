---
id: algo-bit-manipulation
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 3
created: 2026-09-10
confidence: high
---

# Bit Manipulation

Reach for this pattern when a problem is secretly about the binary representation of numbers rather than their arithmetic value: XOR that cancels pairs, masking and shifting to inspect individual bits, or building a result one bit at a time. The tell is anything that talks about "the one non-repeating number", counting or reversing bits, or doing arithmetic "without the operators you'd expect". Solve each on your own machine, then log how it went.

## Single Number
[Solve on LeetCode](https://leetcode.com/problems/single-number/) · Easy

**Problem.** You are given an integer array in which every value appears exactly twice except for one value, which appears just once. Return that lone value. Aim for linear time and constant extra space, so no hash map.

**Example.** `[7, 3, 7, 9, 3]` -> `9` because `7` and `3` each cancel out, leaving `9`.

**Recognition.** "Everything is paired except one" screams XOR. XOR all the numbers together: equal values annihilate to `0`, so the survivor is the unique element.

## Number of 1 Bits
[Solve on LeetCode](https://leetcode.com/problems/number-of-1-bits/) · Easy

**Problem.** Given an unsigned integer, count how many of its bits are set to `1` (its Hamming weight) and return that count. The work is entirely on the binary form of the number, not its decimal magnitude.

**Example.** `11` is `1011` in binary -> `3` set bits.

**Recognition.** "Count the set bits" is the cue. Repeatedly clear the lowest set bit with `n & (n - 1)` and tally each removal, or mask-and-shift through all bit positions.

## Counting Bits
[Solve on LeetCode](https://leetcode.com/problems/counting-bits/) · Easy

**Problem.** Given a non-negative integer `n`, return an array of length `n + 1` where entry `i` holds the number of set bits in `i`. The goal is to compute all of them together far faster than popcounting each number independently.

**Example.** `n = 4` -> `[0, 1, 1, 2, 1]` for the set-bit counts of `0` through `4`.

**Recognition.** "Set-bit count for every number up to n" invites reuse via DP. Build the table using `bits[i] = bits[i >> 1] + (i & 1)` — shifting off the last bit reduces to an already-computed subproblem.

## Reverse Bits
[Solve on LeetCode](https://leetcode.com/problems/reverse-bits/) · Easy

**Problem.** Given a 32-bit unsigned integer, produce the integer formed by reversing the order of its 32 bits (bit 0 swaps with bit 31, and so on). Return the reversed value.

**Example.** Treating `0...0101` (the value `5`) as a 32-bit word and reversing yields a number whose top three bits are `101` -> a large value ending in zeros.

**Recognition.** "Mirror the bit order" means shift-and-accumulate. Walk 32 times: pull the low bit of the input, push it onto the low end of a result that you left-shift each step, then right-shift the input.

## Missing Number
[Solve on LeetCode](https://leetcode.com/problems/missing-number/) · Easy

**Problem.** You are given an array holding `n` distinct numbers drawn from the range `0` through `n`, meaning exactly one value in that range is absent. Return the missing value, ideally in linear time and constant space.

**Example.** `[0, 2, 3]` with `n = 3` -> `1`, the value missing from `0..3`.

**Recognition.** "One value missing from a full range" can be solved by XOR or by a sum. XOR every index `0..n` with every array element so present values cancel, leaving only the gap; or subtract the array sum from `n(n+1)/2`.

## Sum of Two Integers
[Solve on LeetCode](https://leetcode.com/problems/sum-of-two-integers/) · Medium

**Problem.** Add two signed integers and return their sum, but you are forbidden from using the `+` or `-` operators. You must reconstruct addition purely from bitwise operations.

**Example.** `5 + 3` -> `8`, computed as bitwise-XOR for the partial sum plus a shifted AND for the carry, repeated until no carry remains.

**Recognition.** "Add without `+`" is a bit-simulation of a full adder. XOR gives the sum ignoring carries, `(a & b) << 1` gives the carry; loop, feeding the carry back in, until the carry is `0`.

## Reverse Integer
[Solve on LeetCode](https://leetcode.com/problems/reverse-integer/) · Medium

**Problem.** Given a signed 32-bit integer, return the integer obtained by reversing its decimal digits, preserving the sign. If the reversed number would fall outside the signed 32-bit range, return `0` instead.

**Example.** `-321` -> `-123`; `1000000003` reverses to a value beyond the 32-bit limit -> `0`.

**Recognition.** Despite the track name, this is digit math with an overflow guard. Peel digits with `% 10` and `/ 10`, building the result as `result * 10 + digit`, and check against the 32-bit bounds before each push to bail out to `0`.
