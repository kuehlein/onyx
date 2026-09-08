---
id: top-k-elements
type: flashcard
tags:
  - ds-a
  - heap
tiers:
  ds-a: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Top-K Elements

Top-K is a selection pattern: you need the `k` largest / smallest / most-frequent items but **not** a full ordering of the input. The principle is that finding a boundary is strictly easier than sorting — a size-`k` heap tracks only the current top-`k` (O(n log k)), and [quickselect](_meta/glossary.md#quickselect) partitions the array around the rank-`k` boundary and recurses on one side only (O(n) average). Paying for a full sort (O(n log n)) does more work than the question asks for.

> [!tip] Recognition signal
> The phrases **"top K"**, **"K largest / K smallest"**, **"Kth largest"**, **"K closest"**, or **"K most frequent"** — where you need only the extreme `k`, not the whole sorted order. Size-`k` heap for streaming / small-`k`; quickselect for a single-rank query on a static in-memory array.

## When to Use

**Problem signals that suggest Top-K:**
- The problem asks for the **"K largest / K smallest / Kth largest / Kth smallest"** element(s)
- **"K most frequent"** elements — combine a frequency hash map with top-K over the counts
- **"K closest points to the origin"** / "K closest to a target" — top-K by a distance key
- The data arrives as a **stream** or is too large to fit in memory, and `k` is small relative to `n` (`k << n`)
- Constraints show large `n` (10^5–10^6) but small `k` — a full O(n log n) sort is more work than needed

**Prefer each approach when:**
- **Size-`k` heap (O(n log k))** — over quickselect when the input is a **stream** (can't random-access or re-partition), when you must **not mutate** the input, or when you want the full top-`k` *set* (not just the single Kth element). Space is only O(k).
- **Quickselect (O(n) average)** — over a heap for a **single-rank query on a static array you can mutate in place**: find the Kth element (or partition so the top-`k` sit on one side) in O(n) average, beating O(n log k).
- **Full sort (O(n log n))** — when you need the top-`k` in **sorted order** *and* `k` is close to `n`, or the language's sort is so optimized that the simplicity outweighs the asymptotic loss. Also when you need the whole ordering anyway.

**Do not use when:**
- `k == n` (you need everything sorted) → just sort; top-K gives no advantage
- You need the top-`k` to **change dynamically** with inserts/deletes over time → maintain a running heap or an order-statistics tree, not a one-shot quickselect
- You need arbitrary rank queries repeatedly on a mutating set → order-statistics tree, not repeated quickselect

## Time & Space Complexity

For an input of size `n`, selecting the top `k`:

| Approach | Time (avg) | Time (worst) | Space | Result order |
|---|---|---|---|---|
| Full sort | O(n log n) | O(n log n) | O(n) or O(log n) | fully sorted |
| Size-`k` heap | O(n log k) | O(n log k) | O(k) | heap order (not sorted) |
| Quickselect | O(n) | O(n²) | O(1) in-place | unsorted, partitioned around Kth |
| Quickselect + median-of-medians | O(n) | O(n) | O(1)/O(log n) | partitioned around Kth |

- **Size-`k` heap = O(n log k):** iterate all `n` elements; each does an O(log k) push/pop against a heap capped at size `k`. For **k-largest, keep a MIN-heap of size k** (its root is the smallest of the current top-`k`, so it's the cheapest to evict); for **k-smallest, keep a MAX-heap of size k**.
- **Quickselect = O(n) average:** each partition is O(n) and recurses on only **one** side. Expected work is n + n/2 + n/4 + ... = O(2n) = O(n). Worst case O(n²) when pivots are consistently the min/max (e.g. already-sorted input with naive pivot) so partitions shrink by one element.
- **Median-of-medians** guarantees an O(n) *worst case* by choosing a provably good pivot (groups of 5, median of the group-medians, discarding ≥30% each step), but its large constant factor makes randomized quickselect faster in practice.
- **Space:** heap is O(k) auxiliary — the key win for streams. Quickselect is O(1) auxiliary (in-place partition), but it mutates and must hold the whole array.

## Key Properties

- **Selection is easier than sorting.** You only need the `k`-boundary, not a total order — that's why O(n) (quickselect) and O(n log k) (heap) beat O(n log n).
- **The min-heap-for-k-largest inversion.** To keep the `k` *largest*, use a **min-heap**: the root is the weakest survivor, so a new element only enters if it beats the root, which is then evicted. (Symmetric: max-heap for k-smallest.) Getting this backwards is the classic bug.
- **Heap output is not sorted.** A size-`k` heap yields the top-`k` as a *set* in heap order. If you need them ranked, pop them all out (adds O(k log k)) or sort the final `k`.
- **Quickselect is destructive and single-shot.** It reorders the array and answers one rank query; it needs the full array in memory (no streaming) and does not preserve original indices.
- **k-most-frequent is two stages:** first a frequency hash map (O(n)), then top-K over the *distinct counts* (heap over the map, or **bucket sort** by frequency for a clean O(n) since counts are bounded by `n`).

## Common Pitfalls

- **Wrong heap polarity.** Using a max-heap for k-largest (or min-heap for k-smallest) forces you to hold all `n` and defeats the O(k) space / O(n log k) time win. k-largest → min-heap; k-smallest → max-heap.
- **Reaching for O(n log n) sort by reflex.** If `k << n`, sorting is asymptotically wasteful; state the heap/quickselect option even if you code the sort for simplicity.
- **Quickselect worst case on sorted input.** A first/last-element pivot degrades to O(n²) on already-sorted data. Use a **random pivot** (or median-of-medians) — mention this in interviews; it's a common follow-up.
- **Off-by-one in the rank.** "Kth largest" in a 0-indexed array is index `n - k` after sorting ascending (or `k - 1` after sorting descending). Quickselect must target the correct index for the chosen order.
- **Expecting sorted output from the heap.** The final heap array is not sorted; sort it if the problem wants ranked output.
- **Distinct vs. total for k-most-frequent.** "K most frequent" ranks by count over *distinct* values — don't confuse it with the Kth element by value.
- **Ties.** Decide tie-breaking up front (by value, by first occurrence) when equal keys/frequencies could straddle the k-boundary.

## Implementation Notes

```js
// ── K largest via a size-k MIN-heap — O(n log k) time, O(k) space ──────────
// Min-heap root is the smallest of the current top-k, so it's cheapest to evict.
// (Assumes a MinHeap with push/pop/peek/size — JS has no built-in heap.)
function kLargest(nums, k) {
  const minH = new MinHeap();
  for (const x of nums) {
    if (minH.size() < k) {
      minH.push(x);
    } else if (x > minH.peek()) {   // only enters if it beats the weakest survivor
      minH.pop();
      minH.push(x);
    }
  }
  return minH.toArray();            // the k largest, in heap (unsorted) order
}

// ── Kth largest via quickselect — O(n) average, O(1) space, in-place ───────
// Kth largest == index (n - k) in ascending order. Random pivot avoids O(n^2).
function findKthLargest(nums, k) {
  const target = nums.length - k;   // 0-indexed position in ascending sort
  let lo = 0, hi = nums.length - 1;
  while (lo < hi) {
    const p = partition(nums, lo, hi);
    if (p === target) break;
    else if (p < target) lo = p + 1; // recurse on ONE side only
    else hi = p - 1;
  }
  return nums[target];
}

function partition(nums, lo, hi) {
  const r = lo + Math.floor(Math.random() * (hi - lo + 1)); // random pivot
  [nums[r], nums[hi]] = [nums[hi], nums[r]];
  const pivot = nums[hi];
  let i = lo;
  for (let j = lo; j < hi; j++) {
    if (nums[j] <= pivot) { [nums[i], nums[j]] = [nums[j], nums[i]]; i++; }
  }
  [nums[i], nums[hi]] = [nums[hi], nums[i]];
  return i;                          // pivot's final sorted position
}
```

```python
# ── K most frequent elements — freq map + heap (O(n log k)) ────────────────
import heapq
from collections import Counter

def top_k_frequent(nums, k):
    counts = Counter(nums)                       # O(n)
    # heapq.nlargest keeps a size-k heap internally → O(n log k)
    return heapq.nlargest(k, counts.keys(), key=counts.get)

# ── Same, but O(n) via bucket sort (counts are bounded by n) ───────────────
def top_k_frequent_buckets(nums, k):
    counts = Counter(nums)
    buckets = [[] for _ in range(len(nums) + 1)]  # index = frequency
    for val, c in counts.items():
        buckets[c].append(val)
    out = []
    for freq in range(len(buckets) - 1, 0, -1):   # high freq → low
        for val in buckets[freq]:
            out.append(val)
            if len(out) == k:
                return out
    return out
```

## Variants

- **Kth largest in a stream** — maintain a running size-`k` min-heap; each `add` is O(log k) and `peek` gives the current Kth largest. (LeetCode 703.)
- **K closest points to origin** — top-K by Euclidean distance key; size-`k` max-heap keyed on distance, or quickselect on the distance array.
- **K most frequent elements / words** — frequency map then top-K over counts (heap or bucket sort). Bucket sort gives O(n) since frequencies are bounded by `n`.
- **Merge K sorted lists** — a *different* "K" pattern: a size-`k` min-heap over the current heads gives O(N log k) total; not selection but often confused with it.
- **Median of a stream** — the two-heap split; related priority-queue technique, not top-K selection.

## Resources

- *Introduction to Algorithms* (CLRS), 4th ed., Chapter 9: Medians and Order Statistics (RANDOMIZED-SELECT; deterministic SELECT / median-of-medians for O(n) worst case)
- [Median of medians — Wikipedia](https://en.wikipedia.org/wiki/Median_of_medians)
- [NeetCode — Kth Largest Element in an Array (quickselect)](https://neetcode.io/problems/kth-largest-element-in-an-array)

## Related

- [[heap]]
- [[quickselect]]
- [[sorting]]
- [[hash-map]]
- [[merge-k-sorted-lists]]
- [[sliding-window-median]]
