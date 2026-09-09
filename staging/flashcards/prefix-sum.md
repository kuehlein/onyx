---
id: prefix-sum
type: flashcard
tags:
  - ds-a
  - prefix-sum
  - array
tiers:
  ds-a: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Prefix Sum

Prefix sum precomputes cumulative totals so any range-sum query becomes a single subtraction. Build an array where `prefix[i]` holds the sum of the first `i` elements (`prefix[0] = 0`); then the sum of the half-open range `[l, r)` is `prefix[r] - prefix[l]`, and the inclusive range `[l, r]` is `prefix[r+1] - prefix[l]`. This trades an O(n) precompute for O(1) per query — a win whenever you answer many range queries against a **static** array. The same idea generalizes to 2D (rectangle sums via inclusion-exclusion) and inverts into the **difference array** for batching many range *updates*.

> [!tip] Recognition
> Reach for prefix sum when you see **many range-sum queries over an array that does not change**, or subarray-sum problems like "count/find subarrays summing to k" (prefix sum + hash map). Signals: "sum between indices i and j", "number of subarrays with sum = k", "range update then query", or a 2D grid asking for rectangle sums.

## When to Use

**Problem signals that suggest Prefix Sum:**
- **Repeated range-sum (or range-average/range-count) queries** on an array whose values do not change between queries — precompute once, answer each in O(1).
- **Subarray-sum problems** where you need the count of, or existence of, a contiguous subarray with a target sum — combine running prefix with a **hash map of prefix values seen** (a subarray `(l, r]` sums to `k` iff `prefix[r] - prefix[l] = k`, i.e. `prefix[l] = prefix[r] - k`).
- **Many range *updates* followed by reads** — use the inverse, a difference array: add `v` at `l` and subtract `v` at `r+1`, then take a prefix sum once at the end.
- **2D rectangle-sum queries** on a static matrix — build a 2D prefix table, answer each rectangle in O(1) via inclusion-exclusion.

**Prefer Prefix Sum over alternatives when:**
- Over recomputing each query with a loop: recompute is O(n) per query → O(nq); prefix sum is O(n + q).
- Over a **Fenwick/segment tree**: if the array is static (no point/range updates interleaved with queries), prefix sum is simpler and has a smaller constant. Reach for Fenwick/segment tree only when updates and queries are **interleaved**.

**Do not use when:**
- The array changes between queries (interleaved point updates) → a single prefix rebuild is O(n) per update; use a **Fenwick tree** instead.
- The query is not a decomposable aggregate — sum, count, and [XOR](_meta/glossary.md#xor) work (each has an inverse); **min/max do not** (no inverse to subtract) → use a sparse table or segment tree.

## Key Properties

- **Half-open convention avoids off-by-one.** Define `prefix[0] = 0` and `prefix[i] = a[0] + ... + a[i-1]`, so `prefix` has length `n+1` and `sum[l, r) = prefix[r] - prefix[l]`. The extra leading zero removes the special case for ranges starting at index 0.
- **Requires an invertible operation.** The O(1) query works because you *subtract* two cumulative values. This holds for sum, count, and XOR (self-inverse), but not for min/max.
- **Static-array assumption.** Query is O(1) only while the underlying array is unchanged; any element update forces an O(n) rebuild of the suffix of `prefix`.
- **Difference array is the inverse.** A prefix sum turns an array of *deltas* back into absolute values, which is why range-update batching (increment a whole range in O(1), reconstruct in O(n) once) is the mirror image of range-sum querying.

## Trade-offs

- **O(n) space overhead** for the auxiliary array (or O(nm) for 2D). Acceptable for query-heavy workloads; wasteful if you only query once.
- **Rebuild cost on mutation.** Cheap queries come at the price of expensive updates — the opposite balance from a Fenwick tree (O(log n) for both).
- **Only worth it above a query threshold.** For a single range query, a direct O(n) loop is simpler and uses O(1) space; the precompute pays off only when queries are numerous.

## Common Pitfalls

- **Off-by-one from mixing conventions.** Inclusive `[l, r]` is `prefix[r+1] - prefix[l]`; half-open `[l, r)` is `prefix[r] - prefix[l]`. Pick one convention (half-open with a leading zero is safest) and never mix them.
- **Integer overflow.** Cumulative sums grow with n and can exceed 32-bit range even when individual elements are small — use 64-bit (`long`/`BigInt`) for the prefix array.
- **Forgetting to seed the hash map with `{0: 1}`** in the count-subarrays-summing-to-k pattern. Without the empty-prefix entry, subarrays that start at index 0 (whose whole prefix equals `k`) are miscounted.
- **Using prefix sum for min/max range queries.** There is no inverse operation, so subtraction is meaningless — a common wrong reach; use a sparse table or segment tree.

## Time & Space Complexity

| Operation | Time | Space |
|---|---|---|
| Build 1D prefix | O(n) | O(n) |
| 1D range-sum query | O(1) | — |
| Build 2D prefix | O(nm) | O(nm) |
| 2D rectangle query | O(1) | — |
| Count subarrays sum = k (prefix + hash map) | O(n) | O(n) |
| Difference array: q range updates + 1 read | O(q + n) | O(n) |

**Contrast vs. Sliding Window:** sliding window handles **contiguous** subarrays where the constraint is **monotone** — growing the window only increases the aggregate — so it requires **non-negative** values to shrink safely. Prefix sum handles **arbitrary** ranges (any `l`, `r`) and works with **negative numbers**, which is exactly when sliding window breaks. Rule of thumb: negatives present, or you need random-access range queries → prefix sum; all non-negative and you slide one contiguous window → sliding window.

**Contrast vs. Two Pointers:** two pointers converge/advance indices using a sorted or monotone ordering to find *a* pair/subarray; prefix sum precomputes a lookup so *any* range aggregate is O(1) and does not require sorted or non-negative input.

## Implementation Notes

```python
# ── 1D prefix sum: half-open convention, prefix[0] = 0 ─────────────────
def build_prefix(a):
    prefix = [0] * (len(a) + 1)
    for i, x in enumerate(a):
        prefix[i + 1] = prefix[i] + x
    return prefix

def range_sum(prefix, l, r):        # inclusive [l, r]
    return prefix[r + 1] - prefix[l]


# ── Count subarrays summing to k (prefix + hash map) ──────────────────
from collections import defaultdict
def subarray_sum_k(a, k):
    seen = defaultdict(int)
    seen[0] = 1                     # empty prefix — critical seed
    running = count = 0
    for x in a:
        running += x
        count += seen[running - k]  # prefix[l] = running - k
        seen[running] += 1
    return count


# ── Difference array: batch range updates, reconstruct once ───────────
def apply_range_updates(n, updates):     # updates: (l, r, v) inclusive
    diff = [0] * (n + 1)
    for l, r, v in updates:
        diff[l] += v
        diff[r + 1] -= v                 # r+1 may be index n; sized n+1
    out = [0] * n
    running = 0
    for i in range(n):
        running += diff[i]
        out[i] = running
    return out


# ── 2D prefix sum: rectangle sum via inclusion-exclusion ──────────────
def build_prefix_2d(g):
    R, C = len(g), len(g[0])
    p = [[0] * (C + 1) for _ in range(R + 1)]
    for i in range(R):
        for j in range(C):
            p[i + 1][j + 1] = g[i][j] + p[i][j + 1] + p[i + 1][j] - p[i][j]
    return p

def rect_sum(p, r1, c1, r2, c2):         # inclusive corners
    return p[r2 + 1][c2 + 1] - p[r1][c2 + 1] - p[r2 + 1][c1] + p[r1][c1]
```

## Variants

- **Difference array** — the inverse operation; batch O(1) range updates, then one O(n) prefix pass to materialize results. Also generalizes to 2D (imos method).
- **2D / N-D prefix sums** — rectangle/box sums in O(1) via inclusion-exclusion after an O(product of dims) build.
- **Prefix XOR / prefix product** — same subtraction trick with any invertible operation (XOR is self-inverse; product needs care with zeros).
- **Fenwick (Binary Indexed) tree** — the mutable cousin: O(log n) point update *and* prefix query, for interleaved updates and reads.

## Resources

- LeetCode tag: https://leetcode.com/tag/prefix-sum/
- LeetCode 303 Range Sum Query - Immutable: https://leetcode.com/problems/range-sum-query-immutable/
- LeetCode 560 Subarray Sum Equals K: https://leetcode.com/problems/subarray-sum-equals-k/
- CP-Algorithms, Fenwick tree (contrast for mutable case): https://cp-algorithms.com/data_structures/fenwick.html

## Related

- [[sliding-window]]
- [[two-pointers]]
- [[fenwick-tree]]
- [[difference-array]]
