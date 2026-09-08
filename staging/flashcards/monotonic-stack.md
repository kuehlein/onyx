---
id: monotonic-stack
type: flashcard
tags:
  - ds-a
  - stack
tiers:
  ds-a: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Monotonic Stack

A monotonic stack is a stack whose contents are kept in sorted order (strictly increasing or decreasing) by popping every element that would violate that order *before* pushing the new one. The principle: each popped element has just met its "next" boundary — the incoming value is the answer to a next-greater/next-smaller query for everything it evicts, and the element left below it after popping is the previous-greater/previous-smaller. Because every index is pushed once and popped at most once, an inner loop that "looks like" O(n²) collapses to O(n) [amortized](_meta/glossary.md#amortized-analysis) over the whole scan.

> [!tip] Recognition trigger
> Reach for a monotonic stack when the problem asks, for each element, for the **nearest greater/smaller element to its left or right** — phrasings like "next greater element", "daily temperatures / days until warmer", "stock span", "largest rectangle in histogram", or "trapping rain water". The tell: a per-element "nearest bigger/smaller neighbor" relationship you'd naively find with a nested loop.

## When to Use

**Problem signals that suggest a monotonic stack:**
- For **each element**, you must find the **next (or previous) strictly greater / smaller** element — "next greater element", "next warmer day", "previous less element"
- The phrases "**daily temperatures**", "**stock span**", "**largest rectangle in histogram**", "**maximal rectangle**", or "**trapping rain water**" appear — these are canonical monotonic-stack shapes
- A brute force is an obvious O(n²) nested loop scanning left/right from each index for the first element that beats it by some comparison
- The answer for an element becomes determinable the moment you scan past a value that "resolves" it (a taller bar, a warmer day) — i.e. results are produced lazily as boundaries are discovered

**Prefer a monotonic stack over alternatives when:**
- Over the nested-loop brute force: the stack turns O(n²) into O(n) by never re-examining an index whose answer is already fixed
- Over sorting: the query is about **positional adjacency** ("nearest to the left/right"), which sorting destroys — you need original index order preserved
- Over a [[heap]]: a heap gives the global min/max, but a monotonic stack gives the *nearest-by-position* boundary and keeps candidates in index order, which a heap cannot

**Do not use when:**
- You need the nearest element by **value distance**, not by "first one greater/smaller" → use sorting or a balanced [BST](_meta/glossary.md#bst)
- The comparison isn't a simple monotone order (no consistent "greater/smaller wins" rule) → the stack invariant can't be maintained
- You need a **sliding-window min/max over a fixed window** → use a monotonic **deque** (double-ended), not a plain stack, so you can also evict from the front by index

## Time & Space Complexity

The linear bound is an **amortized** result from a counting (aggregate) argument: across the entire outer scan, there are exactly n pushes and at most n pops, so the total work of the inner while-loop is O(n) over the whole run — not O(n) per element.

| Operation | Time | Space |
|---|---|---|
| Next greater / next smaller (per element) | O(n) total | O(n) worst case |
| Daily temperatures | O(n) | O(n) |
| Largest rectangle in histogram | O(n) | O(n) |
| Trapping rain water (stack variant) | O(n) | O(n) |
| Stock span | O(n) | O(n) |
| Amortized cost **per element** | O(1) | — |

**Why O(n) time (aggregate/amortized argument):** each index is pushed exactly once. Once popped, it never returns to the stack, so it is popped at most once. Total pushes + total pops ≤ 2n; add the n outer-loop steps → O(n). The inner while-loop can run many times on one iteration and zero times on many others, but its *total* iterations across the scan are bounded by the pop count (≤ n). This is amortized O(1) per element, not worst-case O(1) per step.

**Why O(n) space:** in the worst case (a strictly monotonic input where nothing ever gets popped, e.g. `[5,4,3,2,1]` for a next-greater scan) the stack holds all n indices simultaneously. The output array is also O(n).

## Key Properties

- **Invariant:** at every step the stack is monotonic (strictly increasing or strictly decreasing from bottom to top). You choose the direction by what you're querying — a **decreasing** stack surfaces *next greater* (a new larger value pops the smaller ones it beats); an **increasing** stack surfaces *next smaller*.
- **Store indices, not values.** Push indices so you can recover both the *distance* (`i - stack.top`) and the value (`arr[stack.top]`). Storing raw values throws away the positional information most of these problems need.
- **Two answers per pop.** When element `x` pops element `y`: `x` is the *next* greater/smaller of `y` (scanning left→right), and the element now exposed *below* `y` is the *previous* greater/smaller of `y`. One pass can yield both directions.
- **Direction of scan sets which "next" you get.** Left→right with a decreasing stack answers *next greater to the right*. Right→left answers *next greater to the left*. Pick the scan direction to match the question.
- **Amortized, not per-step, guarantee.** Any single push may trigger a long run of pops; the O(1) is only true averaged across the whole scan.

## Common Pitfalls

- **Strict vs. non-strict comparison (`>` vs `>=`).** This decides how *equal* values are handled — whether a later equal element counts as the "next greater". Getting it wrong silently produces off-by-ties errors (e.g. duplicate bar heights in largest-rectangle). Nail down the exact wording ("next greater" vs "next greater-or-equal") first.
- **Storing values instead of indices.** You then can't compute widths/distances (daily temperatures needs `i - j`; histogram needs the span between boundaries).
- **Leftover stack elements.** After the scan, indices still on the stack have **no** next-greater/next-smaller element — initialize their answer to the sentinel (`-1`, `0`, or `n`) *before* the loop, don't forget them.
- **Wrong stack direction for the query.** A decreasing stack does not answer "next smaller". Re-derive: "the incoming element pops things it *beats*, so pops fix *those* elements' answers" — that tells you the direction.
- **Histogram width off-by-one.** After popping a bar in largest-rectangle, the width is `i - stack.top - 1` (the exclusive gap between the new left and right boundaries), not `i - poppedIndex`. Also append a sentinel `0` height (or iterate to `n` inclusive) to flush the stack at the end.

## Implementation Notes

Push indices; pop while the incoming element violates the desired order; the value that does the popping is the answer for everything it pops.

```javascript
// ── NEXT GREATER TO THE RIGHT ─ decreasing stack of indices ──────────────
// res[i] = value of the first element to the right of i that is > arr[i], else -1
const nextGreater = (arr) => {
    const n = arr.length;
    const res = new Array(n).fill(-1);   // sentinel: nothing greater to the right
    const stack = [];                    // holds indices; arr[stack] strictly decreasing
    for (let i = 0; i < n; i++) {
        // arr[i] resolves every smaller-or-equal index still waiting on the stack
        while (stack.length && arr[stack[stack.length - 1]] < arr[i]) {
            res[stack.pop()] = arr[i];   // arr[i] is the next-greater for the popped index
        }
        stack.push(i);                   // i now waits for its own next-greater
    }
    return res;
};

// ── DAILY TEMPERATURES ─ answer is a DISTANCE, hence store indices ───────
const dailyTemperatures = (t) => {
    const res = new Array(t.length).fill(0); // 0 = no warmer day ahead
    const stack = [];                        // indices of days awaiting a warmer day
    for (let i = 0; i < t.length; i++) {
        while (stack.length && t[stack[stack.length - 1]] < t[i]) {
            const j = stack.pop();
            res[j] = i - j;                  // days waited = index distance
        }
        stack.push(i);
    }
    return res;
};

// ── LARGEST RECTANGLE IN HISTOGRAM ─ increasing stack; width is exclusive gap ──
const largestRectangle = (heights) => {
    const stack = [];        // indices with strictly increasing heights
    let best = 0;
    // iterate to length INCLUSIVE with a virtual 0-height bar to flush the stack
    for (let i = 0; i <= heights.length; i++) {
        const h = i === heights.length ? 0 : heights[i];
        while (stack.length && heights[stack[stack.length - 1]] >= h) {
            const height = heights[stack.pop()];
            // left boundary is the new stack top; width excludes both boundaries
            const width = stack.length ? i - stack[stack.length - 1] - 1 : i;
            best = Math.max(best, height * width);
        }
        stack.push(i);
    }
    return best;
};
```

```python
# Next greater to the right (decreasing stack of indices)
def next_greater(arr):
    n = len(arr)
    res = [-1] * n
    stack = []                       # indices; arr[stack] strictly decreasing
    for i, x in enumerate(arr):
        while stack and arr[stack[-1]] < x:
            res[stack.pop()] = x     # x is the next-greater for the popped index
        stack.append(i)
    return res
```

## Variants

- **Monotonic deque (sliding-window min/max):** a double-ended queue kept monotonic so the window extreme sits at the front; unlike a stack it also evicts stale indices from the front as the window slides. This is the structure behind the O(n) *minimum for all fixed-length subarrays* result. See [[sliding-window]].
- **Previous less / previous greater:** same machinery, but the element left below after popping is the answer, or scan in the opposite direction.
- **Two-sided (histogram / maximal rectangle):** combine next-smaller-to-left and next-smaller-to-right to get, for each bar, the widest span in which it is the minimum.
- **Trapping rain water (stack form):** a decreasing stack where each pop computes trapped water bounded by the popped bar and the new left/right walls (a two-pointer solution also exists).

## Resources

- cp-algorithms — Minimum stack / minimum queue (the monotone-structure counting argument): https://cp-algorithms.com/data_structures/stack_queue_modification.html
- NeetCode roadmap — Stack section (Daily Temperatures, Largest Rectangle, Car Fleet): https://neetcode.io/roadmap
- LeetCode tag — Monotonic Stack problem set: https://leetcode.com/tag/monotonic-stack/
- NeetCode — Daily Temperatures walkthrough: https://neetcode.io/problems/daily-temperatures

## Related

- [[stack]]
- [[sliding-window]]
- [[two-pointers]]
- [[queue-deque]]
- [[heap]]
- [[intervals]]
