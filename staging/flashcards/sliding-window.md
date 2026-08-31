---
id: 51deef2d-9084-4330-8455-a239a44127e9
type: flashcard
tags:
  - ds-a
  - sliding-window
  - two-pointers
tiers:
  ds-a: 1
created: 2026-08-19
confidence: low
priority: high
---

# Sliding Window

A technique that maintains a contiguous subarray (or substring) between two pointers, expanding or shrinking the window to satisfy a constraint — avoiding the O(n²) cost of recomputing the subarray from scratch on every step by updating an incremental state as the window moves.

> [!tip] Recognition trigger
> Optimal **contiguous** subarray/substring under a **monotonic** constraint (longest/shortest with "at most k distinct", "no repeats", "window of size k"). Monotonicity is what lets you avoid backtracking.

## When to Use

**Problem signals that suggest sliding window:**
- The problem asks for a **subarray or substring** that is optimal (longest, shortest, maximum sum, minimum length) under some constraint
- Keywords: "contiguous subarray", "substring", "window of size k", "at most k distinct", "no repeating characters"
- The constraint on the window is **monotonic**: making the window larger can only make the constraint harder (or easier) to satisfy in one direction — this is what lets you avoid backtracking
- Input is an **array or string**; order matters (ruling out hash map / sort approaches)
- Constraints hint at O(n) expected: n up to 10⁵–10⁶

**Prefer sliding window over alternatives when:**
- Over brute force (nested loops): the window state can be updated in O(1) per step, giving O(n) vs O(n²) or O(n³)
- Over prefix sums: you need a dynamic constraint (e.g., "at most k distinct elements") rather than a static range query — prefix sums give you fixed-range sums cheaply but cannot shrink a window on a character-count constraint
- Over two-pointer on a sorted array: the input is unsorted and positional order must be preserved

**Do not use when:**
- The subarray does not need to be contiguous → use [DP](_meta/glossary.md#dp) or greedy on subsequences instead
- The optimal answer can skip elements (subsequence problems) → dynamic programming
- The window constraint is not monotonic (e.g., "exactly k occurrences" with both add and remove invalidating the window non-directionally) → reformulate as "at most k" minus "at most k−1", then apply sliding window twice
- Input size is tiny (n ≤ 20) → brute force is clearer and fast enough

## Time & Space Complexity

| Variant | Time | Space |
|---|---|---|
| Fixed-size window | O(n) | O(1) or O(k) for the window state |
| Variable-size window (shrink on violation) | O(n) | O(k) where k = alphabet / distinct elements tracked |

**Why O(n):** Each element enters the window exactly once (right pointer advances) and leaves the window at most once (left pointer advances). The total work across all expand and shrink operations is therefore bounded by 2n pointer moves, regardless of how many times the window changes size.

**Why not O(n·k):** The inner `while` shrink loop looks nested, but because left never moves backward, the total number of left-pointer increments across the entire outer loop is at most n — amortized O(1) per outer iteration.

## Key Properties

- **Two-pointer invariant:** `left <= right`; the window is `arr[left:right+1]` (inclusive on both ends in most implementations)
- **Window state:** Maintain an auxiliary structure (counter, running sum, hash map of frequencies) that can be updated in O(1) when an element enters or exits the window
- **Fixed vs. variable window:**
  - *Fixed (size k):* slide right by one, drop leftmost — always same size
  - *Variable:* expand right greedily; shrink from left when the constraint is violated
- **Monotonicity requirement:** The validity of the window must be decidable from the current state alone, and the shrink operation must always move toward a valid state

## Common Pitfalls

1. **Off-by-one on window bounds.** Using `arr[left:right]` (exclusive right) vs `arr[left:right+1]` (inclusive right) inconsistently. Fix: pick one convention and use it everywhere; prefer inclusive-right in the loop, slice with `arr[left:right+1]`.

2. **Forgetting to update the answer after shrinking.** In "longest window" problems, the answer must be recorded **after** the `while` shrink loop runs — not before. The shrink loop only executes when the window is invalid; recording before it would count an invalid (too-large) window. Record once the window is restored to a valid state. Interviewers probe this with edge cases where the entire array is valid (shrink loop never runs, answer recorded correctly on every iteration).

3. **Shrinking too aggressively.** Using `if` instead of `while` for the shrink condition leaves the window in an invalid state when multiple characters violate the constraint simultaneously. Always `while not valid: shrink`.

4. **Not resetting / correctly updating state on shrink.** Decrementing a frequency counter but forgetting to check if the count hits zero before removing the key — then the key remains in the map with count 0, inflating the distinct-element count.

5. **Applying sliding window to non-monotonic constraints directly.** "Exactly k distinct" is not monotonic — adding an element can both fix and break the constraint. The correct formulation is `atMost(k) - atMost(k-1)`.

6. **Integer overflow on running sum.** In JavaScript all numbers are 64-bit floats — integers are exact up to 2^53, so overflow is rarely a problem in interview contexts. In C++/Java with very large values, use `long`.

## Implementation Notes

```javascript
// --- Variable-size window: longest substring with at most k distinct characters ---
const lengthOfLongestSubstringKDistinct = (s, k) => {
    const freq = new Map();  // tracks character frequencies in the current window
    let left = 0;
    let best = 0;

    for (let right = 0; right < s.length; right++) {
        const ch = s[right];
        freq.set(ch, (freq.get(ch) ?? 0) + 1);  // expand: add rightmost character

        // shrink until the window is valid again
        while (freq.size > k) {
            const leftCh = s[left];
            freq.set(leftCh, freq.get(leftCh) - 1);
            if (freq.get(leftCh) === 0) {
                freq.delete(leftCh);  // remove key so freq.size reflects distinct count
            }
            left++;
        }

        // window [left, right] is now valid — record after shrinking restores validity
        best = Math.max(best, right - left + 1);
    }

    return best;
};


// --- Fixed-size window: maximum sum subarray of size k ---
const maxSumSubarray = (arr, k) => {
    let windowSum = arr.slice(0, k).reduce((a, b) => a + b, 0);  // seed the first window
    let best = windowSum;

    for (let i = k; i < arr.length; i++) {
        windowSum += arr[i] - arr[i - k];  // slide: add incoming, drop outgoing
        best = Math.max(best, windowSum);
    }

    return best;
};


// --- Two-pass trick for "exactly k" (non-monotonic) ---
const subarraysWithKDistinct = (nums, k) => {
    const atMost = (k) => {
        const freq = new Map();  // tracks value frequencies in the current window
        let left = 0;
        let count = 0;
        for (let right = 0; right < nums.length; right++) {
            const val = nums[right];
            freq.set(val, (freq.get(val) ?? 0) + 1);
            while (freq.size > k) {
                const leftVal = nums[left];
                freq.set(leftVal, freq.get(leftVal) - 1);
                if (freq.get(leftVal) === 0) {
                    freq.delete(leftVal);
                }
                left++;
            }
            count += right - left + 1;  // every right endpoint adds (window size) valid subarrays
        }
        return count;
    };

    return atMost(k) - atMost(k - 1);
};
```

## Variants

- **Minimum window substring** (shrink to smallest valid window after each successful match) — `left` advances aggressively once the window contains all required characters
- **Sliding window maximum** (fixed window, track max without recomputing) — combine with a monotonic deque to get O(n)
- **At-most-k / exactly-k** — reformulate with two `atMost` calls when the constraint is not monotonic
- **Circular array window** — extend the array by appending a copy of itself, then apply standard sliding window with length cap at n

## Resources

- Neetcode — Sliding Window playlist: https://neetcode.io/roadmap (Sliding Window section)
- LeetCode — Sliding Window tag: https://leetcode.com/tag/sliding-window/
- "Grokking Algorithms" ch. 1 (array traversal intuition)

## Related

- [[two-pointers]]
- [[monotonic-deque]]
- [[prefix-sums]]
- [[dynamic-programming]]
