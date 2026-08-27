---
id: ee26bf24-a1be-40f8-a78b-5969da74e406
type: flashcard
tags:
  - ds-a
  - array
  - data-structures
tiers:
  ds-a: 1
created: 2026-08-19
confidence: medium
---

# Array

A contiguous block of memory storing elements of the same type, indexed by position. Random access is O(1) because any element's address is computable as `base + index * element_size` — arithmetic, not traversal.

> [!tip] Recognition heuristic
> Reach for an array when the input is a fixed/known-length sequence and access is **index-based** or **adjacency-based** — swaps, in-place rearrangement, two-pointer/sliding-window, or prefix sums.

## When to Use

**Problem signals that suggest Array:**
- Problem gives you a fixed-size or known-length input ("given an array of n integers…")
- Problem requires index-based access: "find the element at position k", "swap elements i and j"
- Problem mentions in-place manipulation: "rearrange", "rotate", "reverse", "partition without extra space"
- Problem compares adjacent or nearby elements: "find peak element", "check if sorted", "trap rainwater"
- Constraints include `1 <= n <= 10^5` or similar — implies contiguous iteration is expected
- Two-pointer or sliding-window patterns are applicable: sorted input, subarray/substring, palindrome check
- Problem asks for running prefix computations: prefix sums, prefix products ("product of array except self")
- Coordinate compression or bucket counting is involved ("count frequencies", "find missing number in range 1..n")

**Prefer Array over alternatives when:**
- Over Linked List: you need O(1) random access or cache-friendly sequential iteration; linked lists pay pointer-traversal overhead and cache-miss penalties
- Over Hash Map: you need to preserve insertion order without overhead, or the key space is small and dense (use the index as the key)
- Over Deque: access pattern is index-based, not front/back-heavy; arrays avoid deque's block-allocation overhead

**Do not use when:**
- Frequent insertions/deletions at arbitrary positions → use a Linked List or Deque (shifting costs O(n))
- Key space is large and sparse → use a Hash Map (array would waste memory)
- Size is unknown and grows unboundedly at both ends → use a Deque

## Time & Space Complexity

| Operation | Time | Why |
|---|---|---|
| Access by index | O(1) | Address is `base + i * size` — pure arithmetic |
| Search (unsorted) | O(n) | Must inspect every element in the worst case |
| Search (sorted, binary) | O(log n) | Halve the search space each step |
| Insert/delete at end | O(1) amortized | Dynamic arrays double capacity; amortized over all appends |
| Insert/delete at index i | O(n) | All elements after i must shift one position |
| Slice / copy | O(k) | k is the slice length; copying each element is unavoidable |

Space: O(n) — one contiguous allocation proportional to the number of elements stored.

## Key Properties

- **Contiguous memory layout**: enables cache-line prefetching; sequential reads are significantly faster in practice than the asymptotic analysis suggests
- **Zero-indexed (most languages)**: element at logical position k lives at memory offset k from the base pointer
- **Fixed vs. dynamic**: C arrays are fixed; Python `list`, Java `ArrayList`, and Rust `Vec` are dynamic arrays that reallocate (typically doubling) when capacity is exceeded
- **Two-dimensional arrays**: stored in row-major order in most languages; `matrix[r][c]` in Python is a list-of-lists, not a true 2D array — has pointer indirection at each row

## Common Pitfalls

- **Off-by-one errors on bounds**: writing `for i in range(n+1)` or accessing `arr[n]` is the single most common array bug in interviews; always verify the loop boundary against example inputs
- **Modifying a list while iterating over it**: inserting or deleting during `for x in arr` skips elements or raises `IndexError`; iterate over a copy or collect indices to modify after the loop
- **Shallow copy vs. deep copy for 2D arrays**: `matrix_copy = matrix[:]` copies the outer list but the inner row lists are still shared references; mutations to `matrix_copy[0][0]` affect the original. Use `copy.deepcopy` or a list comprehension `[row[:] for row in matrix]`
- **Assuming sort is free**: interviewers will ask about the pre-sort cost; a solution that sorts then binary-searches is O(n log n) total, not O(log n)
- **Integer overflow in index arithmetic**: mid-point calculation `(lo + hi) // 2` is safe in Python (arbitrary precision), but `(lo + hi) >> 1` and C-style `(lo + hi) / 2` overflow 32-bit signed integers when both are large — use `lo + (hi - lo) // 2`
- **Ignoring the "in-place" constraint**: returning a new array when the problem says O(1) extra space will cost you the optimal solution mark; practice the two-pointer swap pattern

## Implementation Notes

```javascript
// --- Core patterns every senior SWE must reproduce without hesitation ---

// 1. In-place reversal (two pointers, O(n) time, O(1) space)
const reverseInPlace = (arr) => {
    let lo = 0, hi = arr.length - 1;
    while (lo < hi) {
        [arr[lo], arr[hi]] = [arr[hi], arr[lo]];  // destructuring swap; no temp needed
        lo++;
        hi--;
    }
};

// 2. Prefix sum array (build once, answer range-sum queries in O(1))
const buildPrefix = (arr) => {
    // prefix[i] = sum of arr[0..i-1], so prefix[0] = 0 (sentinel avoids i-1 check)
    const prefix = new Array(arr.length + 1).fill(0);
    for (let i = 0; i < arr.length; i++) {
        prefix[i + 1] = prefix[i] + arr[i];
    }
    return prefix;
};

const rangeSum = (prefix, l, r) => {
    // Sum of arr[l..r] inclusive
    return prefix[r + 1] - prefix[l];
};

// 3. Sliding window maximum (fixed-size window k)
const slidingWindowMax = (arr, k) => {
    const dq = [];   // stores indices; front is always the max of current window
    const result = [];
    for (let i = 0; i < arr.length; i++) {
        const val = arr[i];
        // Remove indices outside the window
        while (dq.length && dq[0] < i - k + 1) {
            dq.shift();
        }
        // Maintain decreasing order — smaller values behind current are useless
        while (dq.length && arr[dq[dq.length - 1]] < val) {
            dq.pop();
        }
        dq.push(i);
        if (i >= k - 1) {
            result.push(arr[dq[0]]);  // front of deque is max
        }
    }
    return result;
};

// 4. Correct deep copy of 2D array
const matrix = [[1, 2], [3, 4]];
const copy = matrix.map(row => [...row]);  // NOT [...matrix]; that is a shallow copy

// 5. Safe binary search midpoint (avoids overflow in languages with fixed-width ints)
const binarySearch = (arr, target) => {
    let lo = 0, hi = arr.length - 1;
    while (lo <= hi) {
        const mid = lo + Math.floor((hi - lo) / 2);  // safe even if lo+hi would overflow 32-bit
        if (arr[mid] === target) {
            return mid;
        } else if (arr[mid] < target) {
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return -1;
};
```

## Trade-offs

| Concern | Array wins | Array loses |
|---|---|---|
| Access speed | O(1) random access | — |
| Cache performance | Row-sequential reads are hardware-prefetched | Random access to sparse keys thrashes cache |
| Insert/delete mid | — | O(n) shift; prefer linked structures |
| Memory overhead | No per-element pointer overhead | Wasted capacity when load factor is low after deletes |
| API simplicity | Language-native; no imports | 2D layouts require discipline to avoid shallow-copy bugs |

## Variants

- **Circular array**: index arithmetic uses `i % n` to wrap around; common in round-robin schedulers and the sliding-window-maximum problem
- **Bit array / bitset**: each element is a single bit; used for membership sets at extreme scale (Bloom filters)
- **Sorted array**: enables binary search and two-pointer techniques; pay O(n log n) once, gain O(log n) per query
- **NumPy ndarray**: typed, contiguous, supports vectorized SIMD operations — not the same as a Python list

## Resources

- CLRS 4th ed., Chapter 2 — Insertion Sort and loop invariants use arrays as the running example
- Python docs — [list](https://docs.python.org/3/library/stdtypes.html#lists)
- NeetCode Arrays & Hashing playlist: https://neetcode.io/roadmap

## Related

- [[hash-map]]
- [[two-pointers]]
- [[sliding-window]]
- [[binary-search]]
- [[prefix-sum]]
- [[dynamic-programming]]
