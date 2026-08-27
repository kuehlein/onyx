---
id: 0cb20a55-6dc6-41a8-b104-bd533744bb7e
type: flashcard
tags:
  - ds-a
  - binary-search
  - searching
tiers:
  ds-a: 1
created: 2026-08-19
confidence: high
---

# Binary Search

Binary search eliminates half of the remaining search space at each step by comparing the target against the midpoint of a sorted range — this logarithmic halving is why it finds any element in O(log n) comparisons rather than O(n).

> [!tip] Recognition heuristic
> If the input is **sorted**, or you can phrase the answer as a **monotone predicate** `feasible(x)`, binary search likely applies — even when the problem never says the word "search".

## When to Use

**Problem signals that suggest binary search:**
- The input array or range is **sorted** (ascending or descending), or can be treated as monotone
- The problem asks for the **index, position, or existence** of a specific value in a large collection
- Constraint says n can be up to 10⁵–10⁹ and O(n) would be too slow, but O(log n) suffices
- Problem asks you to **minimize the maximum** or **maximize the minimum** of something (binary search on the answer)
- The word **"search"**, **"find"**, **"position"**, or **"exists"** appears alongside a sorted structure
- A feasibility function `f(x)` is monotone: all values ≤ k satisfy it, all values > k do not (or vice versa)
- Problems involving **rotated sorted arrays**, **mountain arrays**, or any unimodal structure

**Prefer binary search over alternatives when:**
- Over linear scan: the array is sorted and n > ~20; binary search is O(log n) vs O(n)
- Over hash map: you need the floor/ceil/predecessor/successor, not just exact membership; hash maps cannot answer range queries efficiently
- Over ternary search: the function is strictly monotone (not unimodal) — binary search is simpler and equivalent
- Over sorted set / [BST](_meta/glossary.md#bst): you need a single lookup on static data; a BST has higher constant factors

**Do not use when:**
- Data is unsorted and sorting first would dominate cost → use a hash map for O(1) lookup
- You need to find all occurrences of a value in a mutable collection → use a sorted multiset
- The search space is not monotone (e.g., a 2-D matrix without a monotone property) → use row-wise binary search or a different traversal
- n is tiny (< 20) → linear scan is simpler and equally fast in practice

## Time & Space Complexity

| Operation | Time | Space |
|-----------|------|-------|
| Search (iterative) | O(log n) | O(1) |
| Search (recursive) | O(log n) | O(log n) call stack |
| Build (sort first) | O(n log n) | O(1) or O(n) |

**Why O(log n):** each iteration cuts the search space in half. Starting from n elements, after k iterations the remaining range is n / 2ᵏ. Solving n / 2ᵏ = 1 gives k = log₂ n.

**Why O(1) space (iterative):** only three integer variables (`lo`, `hi`, `mid`) are maintained regardless of input size.

## Key Properties

- **Precondition:** the search space must be sorted (or satisfy a monotone predicate). Violating this silently produces wrong answers.
- **Invariant:** the target, if it exists, always lies within `[lo, hi]` at the start of every iteration.
- **Two canonical variants:**
  - *Exact match* — return index if `arr[mid] == target`, else -1
  - *Left boundary* — find the first index where `arr[i] >= target` (lower_bound); useful for counting, insertion point, and "minimize X" problems
- **Binary search on the answer:** when you cannot binary search the array directly, define a predicate `feasible(x)` and binary search over the answer domain. Common in optimization problems ("find the minimum speed such that…").

## Common Pitfalls

1. **Integer overflow in `mid` calculation.** Using `mid = (lo + hi) // 2` is safe in Python (arbitrary precision), but in C++/Java, `(lo + hi)` can overflow a 32-bit int. The safe form is `mid = lo + (hi - lo) // 2`.

2. **Off-by-one errors in loop termination and boundary updates.** The three most common loop templates are `lo < hi`, `lo <= hi`, and `lo + 1 < hi` — mixing them with inconsistent boundary updates (`hi = mid` vs `hi = mid - 1`) is the #1 source of infinite loops and wrong answers. Commit to one template and apply it consistently.

3. **Returning `mid` when searching for a boundary.** When finding the first position satisfying a condition, do not `return mid` early — you must continue narrowing: `hi = mid` (not `hi = mid - 1`).

4. **Assuming the array is sorted without verifying.** In rotated or modified arrays, applying vanilla binary search produces silently incorrect results; you must adapt the comparison logic.

5. **Confusing `lo` and `hi` post-loop.** After a lower_bound search, check whether `lo` is within bounds and whether `arr[lo] == target` before returning — the loop ends with `lo == hi` pointing to the first candidate, which may not equal the target.

6. **Applying binary search to a non-monotone predicate.** If `feasible(mid)` is true but `feasible(mid+1)` is false and then true again, binary search will miss the global answer. Verify monotonicity before applying.

## Implementation Notes

```javascript
// ── Variant 1: Exact match ──────────────────────────────────────────────────
// Return index of target in sorted arr, or -1 if not found.
const binarySearch = (arr, target) => {
    let lo = 0, hi = arr.length - 1;  // both inclusive

    while (lo <= hi) {                 // '<=' because hi is an inclusive bound
        const mid = lo + Math.floor((hi - lo) / 2);  // avoids overflow
        if (arr[mid] === target) {
            return mid;
        } else if (arr[mid] < target) {
            lo = mid + 1;              // target is in the right half
        } else {
            hi = mid - 1;              // target is in the left half
        }
    }

    return -1;                         // target not found
};


// ── Variant 2: Left boundary (lower_bound) ───────────────────────────────────
// Return the first index i such that arr[i] >= target.
// Returns arr.length if all elements are < target.
const lowerBound = (arr, target) => {
    let lo = 0, hi = arr.length;      // hi is EXCLUSIVE; range is [lo, hi)

    while (lo < hi) {                  // '<' not '<=' because hi is exclusive
        const mid = lo + Math.floor((hi - lo) / 2);
        if (arr[mid] < target) {
            lo = mid + 1;
        } else {
            hi = mid;                  // NOT mid-1; we keep mid as a candidate
        }
    }

    return lo;                         // lo == hi; first position >= target
};


// ── Variant 3: Binary search on the answer ──────────────────────────────────
// Find the minimum integer x in [lo, hi] for which feasible(x) is true.
// Assumes feasible is monotone: false...false, true...true.
const minFeasible = (lo, hi, feasible) => {
    while (lo < hi) {
        const mid = lo + Math.floor((hi - lo) / 2);
        if (feasible(mid)) {
            hi = mid;                  // mid could be the answer; don't exclude it
        } else {
            lo = mid + 1;              // mid is definitely not the answer
        }
    }
    return lo;                         // lo == hi is the minimum feasible value
};
```

**Template decision guide:**
- Need exact index → Variant 1 (`lo <= hi`, return `mid`)
- Need insertion point / count of elements < target / first occurrence → Variant 2 (`lo < hi`, `hi = mid`)
- Minimizing/maximizing over a continuous domain → Variant 3 (same shape as Variant 2)

## Variants

- **Right boundary (upper_bound):** find the last index where `arr[i] <= target`; flip the comparison in lower_bound.
- **Rotated sorted array:** determine which half is sorted by comparing `arr[mid]` to `arr[lo]`, then decide which half the target lies in.
- **2-D binary search:** apply row-wise binary search on a matrix where each row is sorted and first element of row i+1 > last of row i.
- **Floating-point binary search:** iterate a fixed number of times (e.g., 100) instead of until `lo < hi`; used for continuous domains like square roots.
- **Exponential (galloping) search:** double the index until you overshoot, then binary search the identified range; useful when the array is unbounded or very large with a nearby target.

## Resources

- https://en.wikipedia.org/wiki/Binary_search_algorithm
- https://neetcode.io/roadmap (Binary Search section)
- https://leetcode.com/explore/learn/card/binary-search/

## Related

- [[two-pointers]]
- [[sliding-window]]
- [[divide-and-conquer]]
- [[sorting]]
