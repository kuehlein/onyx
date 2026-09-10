---
id: sorting
type: flashcard
tags:
  - ds-a
  - sorting
  - algorithms
tiers:
  ds-a: 1
created: 2026-09-10
confidence: high
priority: normal
---

# Sorting

Sorting imposes a total order so that downstream work — binary search, deduplication, grouping, greedy sweeps — becomes cheap; the comparison-based cost is fundamentally bounded at Θ(n log n), and the "right" algorithm is chosen by two orthogonal axes: **[stability](_meta/glossary.md#stable-sort)** and **[in-place](_meta/glossary.md#in-place)** memory, plus **adaptivity** to existing order.

> [!tip] Recognition
> "Sort first, then …" (two-pointer, binary search, sweep line, interval merge), "kth largest / top-k", "sort by multiple keys / preserve prior order on ties" (stability), "n is huge, keys are small bounded integers" ([radix](_meta/glossary.md#radix-sort)/[counting](_meta/glossary.md#counting-sort)), "why is std::sort not stable?" ([introsort](_meta/glossary.md#introsort)), "guaranteed n log n even in the worst case" (merge/heap, not quick).

## When to Use

**Problem signals that suggest sorting:**
- The problem gets trivial once data is ordered: interval merging, meeting rooms, two-pointer pair-sums, sweep lines, deduplication, finding the median.
- You will do many membership/range queries after → sort once (n log n), then binary search (log n) each.
- "Sort by X, break ties by original order / by Y" → you need a **stable** sort (or a composite comparator).
- Keys are integers/strings in a **bounded, keyable domain** and n is large → non-comparison sort (counting/radix) can hit O(n + k) / O(nk), beating n log n.

**Prefer specific sorts over alternatives when:**
- **Merge sort** over quicksort when: you need a **guaranteed** O(n log n) worst case, **stability**, or you're sorting a linked list / external (on-disk) data where sequential access dominates.
- **Quicksort** over merge sort when: you want the **fastest in-practice** in-memory sort with O(log n) stack and great cache locality, and average-case guarantees are acceptable.
- **Heapsort** over quicksort when: you need **guaranteed** O(n log n) AND strict **in-place** O(1) space (e.g. memory-constrained), and stability is irrelevant.
- **A heap / [quickselect](_meta/glossary.md#quickselect)** over sorting when: you only need the top-k or the kth element, not a full order — O(n log k) or O(n) average vs O(n log n).

**Do not use (a full sort) when:**
- You only need the kth-smallest / top-k → use quickselect (O(n) avg) or a size-k heap (O(n log k)).
- Data is already nearly sorted and you need it fast → an **adaptive** sort ([Timsort](_meta/glossary.md#timsort), insertion sort) runs near O(n); a naive quicksort does not exploit this.
- The comparison itself is the bottleneck and keys are bounded → counting/radix sort skips comparisons entirely.

## Key Properties

- **Θ(n log n) is a hard floor for comparison sorts.** Any algorithm that only compares pairs of elements is a binary decision tree: each comparison has 2 outcomes, so a tree of height h distinguishes at most 2^h orderings. To sort n distinct elements it must reach all n! permutations, so 2^h ≥ n!, giving h ≥ log₂(n!) = Θ(n log n) by Stirling. This is why merge/heap/quick can't asymptotically beat n log n — only non-comparison sorts, which exploit key structure, can.
- **Stable** = equal keys keep their original relative order. Critical when sorting by a secondary key after a primary (radix sort *requires* a stable inner sort), or when the payload beyond the key matters.
- **In-place** = O(1) or O(log n) auxiliary space; sorts the array without a second copy. Merge sort is *not* in-place (O(n) aux); heapsort and (well-tuned) quicksort are.
- **Adaptive** = runs faster on partially-ordered input (e.g. Timsort, insertion sort hit O(n) on sorted data). Merge/heap/plain-quick are non-adaptive.
- **Non-comparison sorts beat the floor by not comparing:** counting sort tallies occurrences into buckets by key; radix sort applies a stable counting sort digit-by-digit. They need a bounded, integer-mappable key domain.

## Time & Space Complexity

| Algorithm | Best | Average | Worst | Space (aux) | Stable | In-place |
|---|---|---|---|---|---|---|
| Merge sort | Θ(n log n) | Θ(n log n) | Θ(n log n) | O(n) | Yes | No |
| Quicksort | Θ(n log n) | Θ(n log n) | Θ(n²) | O(log n) stack | No | Yes* |
| Heapsort | Θ(n log n) | Θ(n log n) | Θ(n log n) | O(1) | No | Yes |
| Insertion sort | Θ(n) | Θ(n²) | Θ(n²) | O(1) | Yes | Yes |
| Timsort | Θ(n) | Θ(n log n) | Θ(n log n) | O(n) | Yes | No |
| Introsort | Θ(n log n) | Θ(n log n) | Θ(n log n) | O(log n) | No | Yes |
| Counting sort | Θ(n + k) | Θ(n + k) | Θ(n + k) | O(n + k) | Yes | No |
| Radix sort | Θ(nk) | Θ(nk) | Θ(nk) | O(n + b) | Yes | No |
| Bucket sort | Θ(n + k) | Θ(n + k) | Θ(n²) | O(n + k) | Yes† | No |

\* Quicksort is "in-place" for the array but uses O(log n) recursion stack (O(n) if unbalanced without tail-call/smaller-half recursion).
† Bucket sort stability depends on the per-bucket sort; worst case n² if all keys collide into one bucket.

- **k** = size of the key range (counting/bucket); **b** = radix base and number of digit passes; radix is O(d·(n+b)) for d digits, commonly written O(nk).
- **Comparison-sort disambiguation (the #1 interference source):** all three canonical sorts are O(n log n) *on average* — distinguish them by the axes they differ on:

| | Merge | Quick | Heap |
|---|---|---|---|
| Worst case | n log n (guaranteed) | **n²** | n log n (guaranteed) |
| Stable? | **Yes** | No | No |
| In-place? | No (O(n) aux) | Yes (O(log n) stack) | Yes (O(1)) |
| Cache locality | Moderate | **Excellent** | **Poor** (scattered heap indexing) |
| Speed in practice | Good | **Fastest** | Slower (constant factors) |
| Distinguishing pick | need stability / guarantee | need raw speed | need guarantee + O(1) space |

## Common Pitfalls

- **Assuming the language's sort is stable.** JS `Array.prototype.sort` is stable (ES2019+); Python `sorted`/`list.sort` (Timsort) is stable; **C++ `std::sort` (introsort) is NOT stable** — use `std::stable_sort`. Java `Arrays.sort` is stable for objects (Timsort) but NOT for primitives (dual-pivot quicksort).
- **Quicksort's O(n²) on adversarial input.** A fixed pivot (first/last element) degrades to O(n²) on already-sorted or reverse-sorted arrays — the exact inputs that show up in production. Mitigate with randomized or median-of-three pivots (introsort additionally falls back to heapsort).
- **Radix/counting on unbounded keys.** They only beat n log n when the key domain is bounded and small. On 64-bit keys with tiny n, or on floating/arbitrary keys, they are *worse* — the k or d factor dominates.
- **JS default sort is lexicographic.** `[10, 2, 1].sort()` yields `[1, 10, 2]` — it coerces to strings. Always pass a comparator: `.sort((a, b) => a - b)`.
- **Sorting when you only need top-k.** Full sort is O(n log n); quickselect is O(n) average for the kth element, and a size-k heap is O(n log k). Don't sort the whole array to grab one element.
- **Unstable sort silently breaking a multi-key sort.** If you sort by secondary key then primary key expecting ties preserved, an unstable sort corrupts the order — the secondary ordering is lost on primary ties.

## Trade-offs

| Decision axis | Choose |
|---|---|
| Need guaranteed worst-case n log n | Merge or Heapsort (never plain quicksort) |
| Need stability | Merge, Timsort, counting/radix (not quick/heap) |
| Minimize memory (strict O(1)) | Heapsort |
| Fastest average in-memory sort | Quicksort / introsort |
| Nearly-sorted or real-world mixed data | Timsort (adaptive, stable) |
| Sorting a linked list / external data | Merge sort (sequential access, no random indexing) |
| Bounded small integer keys, huge n | Counting / radix sort (O(n + k)) |
| Only need kth / top-k | Quickselect or a heap, not a sort |

**Why library sorts are hybrids:** no single algorithm wins everywhere, so standard libraries combine them.
- **Timsort** (Python, Java objects): merge-based, **stable**, **adaptive** — detects pre-sorted "runs" and merges them, hitting O(n) on ordered data and O(n log n) worst case. Falls back to insertion sort on small runs.
- **Introsort** (C++ `std::sort`): starts as quicksort for speed, switches to **heapsort** when recursion depth exceeds ~2·log n to dodge the O(n²) worst case, and uses insertion sort for small subarrays. Not stable.

## Resources

- CLRS (*Introduction to Algorithms*, 4th ed.) — Ch. 2 (insertion/merge), Ch. 6 (heapsort), Ch. 7 (quicksort), Ch. 8 (decision-tree lower bound, counting/radix/bucket).
- [Timsort — Wikipedia](https://en.wikipedia.org/wiki/Timsort) and the [CPython listsort.txt](https://github.com/python/cpython/blob/main/Objects/listsort.txt) design notes.
- [Introsort — Musser, 1997](https://en.wikipedia.org/wiki/Introsort)
- [Comparison sort lower bound — Wikipedia](https://en.wikipedia.org/wiki/Comparison_sort#Number_of_comparisons_required_to_sort_a_list)

## Related

- [[heap]]
- [[binary-search]]
- [[big-o-complexity]]
- [[top-k-elements]]
