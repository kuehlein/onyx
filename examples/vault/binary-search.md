---
id: binary-search
type: flashcard
tags:
  - ds-a
  - binary-search
  - searching
tiers:
  ds-a: 1
created: 2026-09-20
confidence: high
---

# Binary Search

Repeatedly halve a **sorted** search space by comparing against the middle — each
step discards half the remaining candidates, so the cost is logarithmic.

> [!tip] Recognition
> Reach for binary search when the data is sorted (or the *answer* is monotonic:
> "smallest X that works") and a linear scan would be too slow.

## When to Use

**Problem signals that suggest binary search:**
- The input is **sorted**, or you can sort it cheaply and queries dominate.
- You're asked for a **boundary** — "first/last element satisfying P", "minimum
  capacity that finishes in time" — and `P` flips false→true exactly once.
- `n` is large and an O(n) scan per query is too slow.

**Prefer binary search over alternatives when:**
- Over a linear scan: the space is sorted/monotonic (turns O(n) into O(log n)).
- Over a hash set: you need **order** (nearest, first-greater), not just membership.

**Do not use when:**
- The data is unsorted and used once → a single linear scan is cheaper than sorting.
- There's no monotonic predicate to bisect on → binary search doesn't apply.

## Key Properties

- **Loop invariant is everything.** Keep the target within `[lo, hi]` and shrink
  the interval every iteration; an off-by-one in how you move `lo`/`hi` is the
  classic bug (infinite loop or a skipped answer).
- **"Binary search on the answer."** When you can *test* a candidate answer with a
  monotonic yes/no, bisect the answer range even if the input isn't a sorted array.

## Time & Space Complexity

O(log n) time because each comparison halves the candidate range, so it takes
`⌈log₂ n⌉` steps to reach one element. Space is O(1) iteratively (two indices);
a recursive version is O(log n) for the call stack.

## Common Pitfalls

- `mid = (lo + hi) / 2` can **overflow** in fixed-width integers — use
  `lo + (hi - lo) / 2`.
- Mixing interval conventions (`[lo, hi]` vs `[lo, hi)`) mid-function — pick one
  and keep the update/termination consistent with it.

## Resources

- Sedgewick & Wayne, *Algorithms* — binary search chapter.

## Related

- [[sorting]]
- [[two-pointers]]
