---
id: algo-stack
type: algorithm
tags:
  - ds-a
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-10
confidence: high
---

# Stack

Reach for a stack when the most recently seen thing is the first you need to
resolve — matching nested pairs, deferred operations, or "nearest previous/next"
relationships where a monotonic stack keeps only the useful candidates. Solve
each on your own machine, then log how it went.

## Valid Parentheses
[Solve on LeetCode](https://leetcode.com/problems/valid-parentheses/) · Easy

**Problem.** You're given a string made only of the six bracket characters
`()[]{}`. Decide whether every opener has a matching closer of the same type and
whether the brackets are properly nested (no interleaving). Return a boolean.

**Example.** `"([]{})"` -> `true` because each closer matches the most recent
unclosed opener, while `"([)]"` -> `false` because the `)` tries to close a `[`.

**Recognition.** Nested matching pairs scream stack: push each opener, and on a
closer pop the top and confirm it's the matching opener. The string is valid iff
nothing mismatched and the stack ends empty.

## Min Stack
[Solve on LeetCode](https://leetcode.com/problems/min-stack/) · Medium

**Problem.** Design a stack supporting `push`, `pop`, `top`, and a `getMin` that
returns the smallest element currently in the stack. Every operation, including
`getMin`, must run in O(1) time.

**Example.** After pushing `5`, `2`, `7`, `getMin` returns `2`; pop the `7` and
`getMin` still returns `2`; pop the `2` and now `getMin` returns `5`.

**Recognition.** The trigger is "O(1) minimum alongside normal stack ops." Keep a
second stack (or store pairs) tracking the running minimum in lockstep, so the
current min is always readable at the top.

## Evaluate Reverse Polish Notation
[Solve on LeetCode](https://leetcode.com/problems/evaluate-reverse-polish-notation/) · Medium

**Problem.** You get a list of tokens forming an arithmetic expression in postfix
(Reverse Polish) form, where operators `+ - * /` follow their operands. Evaluate
it and return the integer result; division truncates toward zero.

**Example.** `["4","1","+","2","*"]` -> `10` because it means `(4 + 1) * 2`, with
each operator consuming the two most recent numbers.

**Recognition.** Postfix evaluation is a stack classic: push numbers, and on an
operator pop the top two, apply it (minding operand order), and push the result
back. The final remaining value is the answer.

## Daily Temperatures
[Solve on LeetCode](https://leetcode.com/problems/daily-temperatures/) · Medium

**Problem.** Given an array of daily temperatures, for each day compute how many
days you must wait until a warmer day appears. If no warmer day ever comes, that
day's answer is `0`. Return the array of waits.

**Example.** `[70, 73, 71, 75]` -> `[1, 2, 1, 0]` because day 0 warms up the next
day, day 1 waits two days for `75`, and the last day never gets warmer.

**Recognition.** "Days until a greater value" means next-greater-element, so use a
monotonic decreasing stack of indices; when the current temp exceeds the top,
pop and record the index gap.

## Car Fleet
[Solve on LeetCode](https://leetcode.com/problems/car-fleet/) · Medium

**Problem.** Cars start at distinct positions on a one-lane road heading to a
common target, each with its own constant speed. A faster car catching a slower
one cannot pass, so it slows to travel as a fleet. Given positions and speeds,
return how many distinct fleets arrive at the target.

**Example.** With target `12`, positions `[10, 8, 0]` and speeds `[2, 4, 1]`, the
cars at `10` and `8` both reach the target in `1` unit and merge, while the car
at `0` arrives later alone, giving `2` fleets.

**Recognition.** Sort cars by position descending and compute each car's arrival
time; walk toward the target keeping a stack of fleet lead-times. A car that
arrives no later than the fleet ahead merges into it, so a new stack entry means
a new fleet.

## Largest Rectangle in Histogram
[Solve on LeetCode](https://leetcode.com/problems/largest-rectangle-in-histogram/) · Hard

**Problem.** You're given bar heights of a histogram, all of width one. Find the
area of the largest axis-aligned rectangle that fits entirely under the bars,
where the rectangle may span several consecutive bars but is capped by the
shortest bar in that span. Return that maximum area.

**Example.** `[2, 1, 4, 5, 3]` -> `9` because the bars of heights `4, 5, 3` span
three columns capped at height `3`, giving `3 * 3 = 9`.

**Recognition.** Each bar's widest rectangle is bounded by the nearest shorter bar
on each side, so use a monotonic increasing stack of indices. When a shorter bar
appears, pop taller bars and settle their area using the popped index as the
left boundary.
