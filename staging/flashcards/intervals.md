---
id: intervals
type: flashcard
tags:
  - ds-a
  - intervals
tiers:
  ds-a: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Intervals

The intervals pattern turns overlap questions into a single ordered scan: **sort by start (or end), then walk the intervals once**, deciding at each step whether the current interval touches the running one. The core insight is that once intervals are sorted, overlap becomes a *local* property — the only thing that can overlap the interval you're building is the very next one in sorted order — so an O(n²) all-pairs comparison collapses to a linear pass after the sort. Room-allocation variants keep a running set of "still-open" end times in a [[heap|min-heap]] (or use a **sweep line** of +1/-1 events) to count concurrency.

> [!tip] Recognition signal
> Reach for the intervals pattern when the input is a **list of `[start, end]` pairs** and the question is about **overlap**: "merge overlapping intervals", "can a person attend all meetings", "minimum meeting rooms", "insert a new interval and merge", "find free time / gaps", or "maximum number of concurrent events". Sorting by start (or end) is almost always the first move.

## When to Use

**Problem signals that suggest the intervals pattern:**
- The input is a collection of **`[start, end]` ranges** (times, segments, appointments, byte ranges) and the question involves **overlap, merging, or gaps**
- Keywords: "**merge overlapping**", "**meeting rooms**", "**can attend all**", "**insert interval**", "**free time**", "**maximum overlap / max concurrent**", "**non-overlapping**", "**interval intersection**"
- You need the **minimum number of resources** (rooms, CPUs, platforms) to service all ranges without conflict → count peak concurrency
- You need to **remove the fewest intervals** so the rest are non-overlapping → greedy by *end* time
- Two *separately sorted* interval lists and you must find their **intersection** → two-pointer over intervals

**Prefer intervals (sort + scan) over alternatives when:**
- Over brute-force all-pairs overlap check: sorting makes overlap local, dropping O(n²) to O(n log n)
- Over a **min-heap** of end times: for pure *merge* / *can-attend-all* you only need a linear scan after sorting — the heap is needed only when you must track *how many* ranges are simultaneously open (room allocation)
- Over an interval tree / segment tree: those are for **many repeated queries** against a mostly-static set; a one-shot batch question is solved faster and more simply by sort + scan

**Do not use when:**
- Queries arrive online and you must answer "does X overlap anything?" repeatedly against a mutating set → use an **interval tree** or **balanced [BST](_meta/glossary.md#bst) keyed by start**, not a re-sort each time
- The ranges are over a small, bounded integer domain and you just need per-point coverage counts → a **difference array** (prefix-sum of +1/-1) is O(domain), often simpler
- There is no ordering/overlap structure to exploit (the pairs aren't ranges) → the pattern doesn't apply

## Time & Space Complexity

Nearly every interval algorithm is **dominated by the initial sort at O(n log n)**; the scan/merge itself is O(n). The exception is *insert interval*, where the input is already sorted, so no sort is needed.

| Task | Time | Space | Note |
|---|---|---|---|
| Merge overlapping intervals | O(n log n) | O(n) output, O(1)–O(n) sort aux | sort by start, then one linear merge pass |
| Can attend all meetings (any overlap?) | O(n log n) | O(1) extra | sort by start, check adjacent pairs |
| Meeting Rooms II — min-heap | O(n log n) | O(n) heap | sort by start; heap holds active end times |
| Meeting Rooms II — sweep line | O(n log n) | O(n) events | 2n signed events, sort, running counter |
| Insert interval (into sorted list) | **O(n)** | O(n) output | input already sorted → no sort, single pass |
| Non-overlapping intervals (min removals) | O(n log n) | O(1) extra | greedy sort by **end**, keep earliest finishers |
| Interval list intersections (two sorted lists) | O(n + m) | O(1) extra | two-pointer; both inputs already sorted |

**Why the sort dominates:** the merge pass touches each interval a constant number of times (compare to the running interval, extend or emit), so it is O(n). Comparison sorting is O(n log n), which strictly dominates O(n) — hence the whole algorithm is O(n log n). If the input is *already* sorted (insert interval, interval intersection), you skip the sort and the algorithm is linear.

**Why the heap is O(n log n):** you push and pop each of the n intervals at most once, and each heap operation is O(log n), giving O(n log n) for the heap work — matched by the O(n log n) start-time sort. Sweep line reaches the same bound by sorting 2n events.

## Key Properties

- **Two intervals `a` and `b` overlap iff `a.start <= b.end && b.start <= a.end`.** For the "touching counts as overlap" convention use `<=`; for "touching is allowed" (e.g. `[1,2]` and `[2,3]` don't conflict) use strict `<`. Pin this convention down before coding — it is the single most common source of bugs.
- **After sorting by start, overlap is local.** The interval currently being built can only be extended by the *next* interval in sorted order; you never need to look backward. This is the invariant that makes the linear merge correct.
- **Merge extends the end monotonically:** when the next start is `<= current end`, the merged end becomes `max(current end, next end)` — never blindly the next end, because the next interval may be fully contained.
- **Peak concurrency = minimum rooms.** The maximum number of intervals open at any single instant is exactly the minimum number of resources needed (this is interval-graph coloring, and interval graphs are perfect, so greedy peak-count is optimal).
- **Greedy by end time is optimal for max non-overlapping selection** (activity selection): always keep the interval that finishes earliest, because it leaves the most room for the rest. Sorting by *start* here would be wrong.

## Common Pitfalls

- **Sorting by the wrong key.** Merge and room-allocation sort by **start**; "max non-overlapping / min removals" (activity selection) sorts by **end**. Using start-sort for the greedy selection gives wrong answers.
- **`<` vs `<=` in the overlap test.** Off-by-one on whether adjacent, touching intervals (`[1,2]`, `[2,3]`) count as overlapping. Decide per problem statement; getting it backwards fails edge tests silently.
- **Extending with `next.end` instead of `max(cur.end, next.end).`** If the next interval is nested inside the current one, taking `next.end` shrinks the merged interval incorrectly.
- **Comparator returning a truncated/boolean value.** In JS, `arr.sort((a,b) => a[0] - b[0])` is correct; `arr.sort()` sorts lexicographically as strings and `(a,b) => a[0] > b[0]` returns a boolean that V8 coerces unreliably. Always return a signed number.
- **Forgetting to flush the last interval.** In a merge loop that emits only when a gap is found, the final in-progress interval must be pushed after the loop ends.
- **Empty input / single interval.** Guard for `intervals.length <= 1` (already merged, zero rooms for empty).
- **Sweep-line tie-breaking.** When a start and an end share the same coordinate, order depends on the touching convention: process the **end before the start** if touching is *allowed* (frees the room first); process **start before end** if touching *counts as overlap*.

## Implementation Notes

```javascript
// ── 1. MERGE OVERLAPPING INTERVALS ───────────────────────────────────────────
// Sort by start, then extend a running interval. O(n log n) time.
const merge = (intervals) => {
    if (intervals.length <= 1) return intervals;
    intervals.sort((a, b) => a[0] - b[0]);            // numeric sort by start
    const out = [intervals[0].slice()];
    for (let i = 1; i < intervals.length; i++) {
        const cur = intervals[i];
        const last = out[out.length - 1];
        if (cur[0] <= last[1]) {                       // overlap (touching counts)
            last[1] = Math.max(last[1], cur[1]);       // extend — NOT just cur[1]
        } else {
            out.push(cur.slice());                     // disjoint → start a new run
        }
    }
    return out;
};


// ── 2. MEETING ROOMS II — minimum rooms via min-heap of end times ─────────────
// Sort by start; heap top = the earliest end among active meetings.
const minMeetingRooms = (intervals) => {
    if (!intervals.length) return 0;
    intervals.sort((a, b) => a[0] - b[0]);
    const heap = new MinHeap();                        // holds end times, min on top
    for (const [start, end] of intervals) {
        if (heap.size() && heap.peek() <= start) {     // a room freed up → reuse it
            heap.pop();
        }
        heap.push(end);                                // occupy a room (new or reused)
    }
    return heap.size();                                // peak concurrency = rooms
};


// ── 3. INSERT INTERVAL (input already sorted, non-overlapping) — O(n) ─────────
const insert = (intervals, newInterval) => {
    const out = [];
    let [ns, ne] = newInterval;
    let i = 0, n = intervals.length;
    while (i < n && intervals[i][1] < ns) out.push(intervals[i++]);   // ends before new
    while (i < n && intervals[i][0] <= ne) {                          // overlaps new
        ns = Math.min(ns, intervals[i][0]);
        ne = Math.max(ne, intervals[i][1]);
        i++;
    }
    out.push([ns, ne]);
    while (i < n) out.push(intervals[i++]);                           // starts after new
    return out;
};
```

```python
# ── SWEEP LINE: max concurrent intervals (= minimum rooms) ───────────────────
# Split each interval into a +1 start event and a -1 end event, sort, sweep.
def min_rooms(intervals):
    events = []
    for start, end in intervals:
        events.append((start, 1))     # a meeting begins
        events.append((end, -1))      # a meeting ends
    # end (-1) sorts before start (+1) at equal time: touching frees the room first
    events.sort(key=lambda e: (e[0], e[1]))
    active = peak = 0
    for _, delta in events:
        active += delta
        peak = max(peak, active)
    return peak
```

## Variants

- **Merge / union** — combine all overlapping ranges into their union (LeetCode 56).
- **Insert interval** — splice one interval into an already-sorted list, merging as needed, in O(n) (LeetCode 57).
- **Room allocation (Meeting Rooms II)** — minimum resources = peak concurrency, via a **min-heap** of end times or a **sweep line** of signed events (LeetCode 253).
- **Activity selection / non-overlapping intervals** — greedy by **end** time to keep the most non-conflicting ranges (LeetCode 435). See [[greedy]].
- **Interval list intersections** — two-pointer over two sorted lists, emit `[max(starts), min(ends)]` when it's valid (LeetCode 986).
- **Interval tree** — augmented balanced BST for repeated online "what overlaps X?" queries in O(log n + k); use when the set is queried many times, not merged once.
- **Difference array** — prefix-sum of +1/-1 over a bounded integer domain for coverage/booking counts (a discrete sweep line).

## Resources

- CLRS, *Introduction to Algorithms* (4th ed.), §14.3 "Interval trees" and §15.1 "Activity-selection problem" (greedy by finish time)
- cp-algorithms — Sweep line / segment intersection: https://cp-algorithms.com/geometry/intersecting_segments.html
- NeetCode — Merge Intervals (56): https://neetcode.io/problems/merge-intervals
- NeetCode — Meeting Rooms II (253): https://neetcode.io/solutions/meeting-rooms-ii

## Related

- [[heap]]
- [[greedy]]
- [[sorting]]
- [[two-pointers]]
- [[sliding-window]]
