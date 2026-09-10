---
id: algo-math-and-geometry
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 3
created: 2026-09-10
confidence: high
---

# Math & Geometry

Reach for this pattern when the problem is really about manipulating numbers, coordinates, or grids by hand: simulating an arithmetic rule digit by digit, walking a matrix in a fixed geometric path, or transforming a grid in place. The tell is that there is no clever data structure to lean on — success comes from nailing the index bookkeeping, the layer boundaries, or the numeric edge cases. Solve each on your own machine, then log how it went.

## Rotate Image
[Solve on LeetCode](https://leetcode.com/problems/rotate-image/) · Medium

**Problem.** You are given a square `n x n` grid of numbers representing an image, and you must turn it 90 degrees clockwise. The rotation has to happen in place — you may not allocate a second grid and copy into it. Return nothing; mutate the input directly.

**Example.** `[[1,2],[3,4]]` becomes `[[3,1],[4,2]]`, because the bottom-left value rises to the top-left after a clockwise quarter turn.

**Recognition.** "Rotate a square matrix in place" is the cue. Transpose the matrix (swap across the main diagonal), then reverse each row — or rotate four cells at a time layer by layer.

## Spiral Matrix
[Solve on LeetCode](https://leetcode.com/problems/spiral-matrix/) · Medium

**Problem.** Given an `m x n` grid, read out every element in spiral order: start at the top-left, go right across the top, down the right side, left along the bottom, up the left side, and inward. Return the values as a single flat list in the order visited.

**Example.** `[[1,2,3],[4,5,6],[7,8,9]]` -> `[1,2,3,6,9,8,7,4,5]`, tracing the outer ring clockwise then landing on the center.

**Recognition.** "Traverse a grid in a spiral" means maintain four shrinking boundaries. Peel off the top row, right column, bottom row, and left column in turn, tightening each bound after use and stopping when they cross.

## Set Matrix Zeroes
[Solve on LeetCode](https://leetcode.com/problems/set-matrix-zeroes/) · Medium

**Problem.** Given an `m x n` grid, wherever a cell holds a `0`, blank out that cell's entire row and column to zeros. The tricky part is doing it in place without letting the newly written zeros trigger further clearing. Aim for constant extra space.

**Example.** `[[1,2,3],[4,0,6]]` -> `[[1,0,3],[0,0,0]]`, since the single `0` zeros out its whole row and its column.

**Recognition.** "Clear rows/columns from marked cells in place" is the trigger. Use the first row and first column themselves as marker flags for which rows/columns to zero, handling those two lines separately to avoid clobbering markers early.

## Happy Number
[Solve on LeetCode](https://leetcode.com/problems/happy-number/) · Easy

**Problem.** Starting from a positive integer, repeatedly replace it with the sum of the squares of its digits. If this process eventually reaches `1`, the number is "happy"; if it loops forever without hitting `1`, it is not. Return whether the given number is happy.

**Example.** `19` -> `1^2 + 9^2 = 82` -> `8^2 + 2^2 = 68` -> `6^2 + 8^2 = 100` -> `1`, so `19` returns `true`.

**Recognition.** "Iterate a transform until it terminates or cycles" is the cue. Detect the cycle with a seen-set, or use Floyd's slow/fast pointers on the digit-square-sum function — non-happy numbers loop, happy ones reach `1`.

## Plus One
[Solve on LeetCode](https://leetcode.com/problems/plus-one/) · Easy

**Problem.** A non-negative integer is given as an array of its decimal digits, most significant digit first, with no leading zeros. Add one to the number and return the resulting digit array. The only subtlety is a carry that ripples all the way up (e.g. all nines).

**Example.** `[1,2,9]` -> `[1,3,0]`; and `[9,9]` -> `[1,0,0]` because the carry propagates past the front and grows the array.

**Recognition.** "Increment a number stored as digits" means simulate grade-school addition from the right. Add the carry back to front; if a digit was `9` set it to `0` and continue, otherwise increment and stop — prepend `1` if you fall off the front.

## Pow(x, n)
[Solve on LeetCode](https://leetcode.com/problems/powx-n/) · Medium

**Problem.** Compute `x` raised to the integer power `n`, where `x` is a floating-point base and `n` may be negative, zero, or positive. Return the result as a double. The expected approach is faster than multiplying `x` by itself `n` times.

**Example.** `x = 2.0`, `n = -3` -> `0.125`, since `2^-3 = 1 / 2^3 = 1/8`.

**Recognition.** "Exponentiation faster than linear" points to fast (binary) exponentiation. Square the base and halve the exponent each step, multiplying in the base on odd exponents; for negative `n`, invert the base and negate the power.

## Multiply Strings
[Solve on LeetCode](https://leetcode.com/problems/multiply-strings/) · Medium

**Problem.** Two non-negative integers are given as strings, possibly far too large to fit in a built-in numeric type. Return their product, also as a string. You may not convert the inputs directly to a big-integer type or use library big-number arithmetic — do the multiplication by hand.

**Example.** `"12"` times `"12"` -> `"144"`, built up digit-by-digit rather than by parsing the strings into numbers.

**Recognition.** "Multiply arbitrarily large numbers as strings" is the cue for schoolbook multiplication. The product of digit `i` and digit `j` lands at result positions `i+j` and `i+j+1`; accumulate into an integer array of length `m+n`, propagate carries, then strip leading zeros.

## Detect Squares
[Solve on LeetCode](https://leetcode.com/problems/detect-squares/) · Medium

**Problem.** Design a data structure that supports adding points (repeats allowed) and querying how many axis-aligned squares can be formed using a given query point as one corner together with three previously added points. A valid square must have positive area and sides parallel to the axes. Return the total count of such squares.

**Example.** After adding `(0,0)`, `(0,2)`, `(2,0)`, `(2,2)`, querying corner `(2,2)` returns `1`, the one square those four points form.

**Recognition.** "Count axis-aligned squares from a stream of points sharing a corner" is the trigger. Store point frequencies in a map keyed by coordinate; for each other point on the same row as the query (a diagonal candidate), the side length is fixed, so multiply the counts of the two remaining corners.
