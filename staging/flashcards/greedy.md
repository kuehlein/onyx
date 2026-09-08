---
id: 0b944f23-5f7a-4650-84c4-ee970441cee8
type: flashcard
tags:
  - ds-a
  - greedy
tiers:
  ds-a: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Greedy

A greedy algorithm builds a solution one step at a time, at each step taking the choice that looks best *right now* — never reconsidering. It works only when local optimality is provably safe: the problem must have the **greedy-choice property** (some locally optimal choice is contained in *a* globally optimal solution) and **optimal substructure** (an optimal solution contains optimal solutions to subproblems). When the greedy choice is not safe, greedy gives a wrong answer and you must fall back to [DP](_meta/glossary.md#dp) or search. The standard way to *prove* a greedy is correct is an **exchange argument**: take any optimal solution, swap its first choice for the greedy one, and show the result is no worse.

> [!tip] Recognition signal
> Reach for greedy when the problem asks to **maximize/minimize a count or cost** and there is a **natural ordering** (by finish time, weight, ratio, deadline) such that committing to the "best-looking" item first *never blocks* a better overall solution. If a choice can force a worse future — you'd have to undo it — greedy is unsafe; think DP instead.

## When to Use

**Problem signals that suggest Greedy:**
- "Select the **maximum number** of non-overlapping intervals / meetings / activities" → sort by **earliest finish time** (activity selection / interval scheduling)
- "Minimize total waiting time / cost / lateness" with an obvious sort key (shortest job first, earliest deadline first)
- "Build an **optimal prefix code** / minimize weighted path length" → Huffman (merge two smallest frequencies)
- "**Fractional** knapsack — you may take fractions of items" → take highest value/weight ratio first
- "Cover all points / reach the end with **fewest** jumps/coins/stops" and each choice locally extends reach as far as possible (jump game, gas station, coin change with canonical denominations)
- The problem has a clear **greedy invariant** you can state in one sentence ("the greedy choice stays ahead")

**Prefer Greedy over alternatives when:**
- Over DP: when a *single* locally optimal choice is provably safe — greedy is O(n log n) or better and O(1)–O(n) space, vs DP's larger table and time. Only use DP when you must weigh choices against each other.
- Over brute force / [backtracking](_meta/glossary.md#backtracking): when the greedy-choice property holds you never explore alternatives, collapsing an exponential search to one pass.

**Do not use when:**
- Choices **interact** so that the best local pick can block a better global solution (**0-1 knapsack** — you cannot take fractions, so ratio-greedy fails) → use DP
- **Coin change with arbitrary denominations** (e.g. coins {1, 3, 4}, amount 6: greedy picks 4+1+1=3 coins, optimal is 3+3=2 coins) → use DP
- **Longest path**, general shortest path **with negative edges**, or any objective where a myopic choice can't be shown safe → DP / Bellman-Ford / search
- You cannot state and prove a greedy-choice property → assume greedy is wrong until proven

## Time & Space Complexity

Greedy itself is usually a single pass; the cost is dominated by the **sort** or the **priority-queue** operations that order the choices.

| Algorithm | Time | Space | Dominant cost |
|---|---|---|---|
| Activity selection / interval scheduling | O(n log n) | O(1) extra | sort by finish time |
| Interval scheduling (already sorted) | O(n) | O(1) | single scan |
| Huffman coding | O(n log n) | O(n) | n-1 heap extract-mins |
| Fractional knapsack | O(n log n) | O(1) extra | sort by value/weight ratio |
| Dijkstra (greedy + [heap](heap.md)) | O((V+E) log V) | O(V) | extract-min per vertex |
| Generic "sort then one pass" | O(n log n) | O(1)–O(n) | the sort |

**Why O(n log n) is the common floor:** the greedy scan is O(n), but establishing the ordering the greedy choice relies on requires a comparison sort (O(n log n)) or a priority queue (O(log n) per op × n ops). If the input arrives pre-sorted, greedy drops to **O(n)**.

**Why Huffman is O(n log n):** build a min-heap of n frequencies, then do n-1 merges; each merge is two extract-mins and one insert, each O(log n), giving O(n log n) total.

## Key Properties

- **Greedy-choice property:** there exists a globally optimal solution that *contains* the greedy (locally optimal) first choice. This is the crux — it lets you commit without lookahead. It must be proven per problem, typically by an exchange argument.
- **Optimal substructure:** after making the greedy choice, what remains is a smaller instance of the same problem, and stitching the greedy choice onto that subproblem's optimum yields the whole optimum. Shared with DP; greedy differs by needing *only one* subproblem, not a choice among many.
- **Exchange argument (the proof template):** assume an optimal solution O that differs from the greedy solution G at the first choice. Swap O's choice for greedy's and show the result is still feasible and no worse. Repeat to transform O into G without loss ⇒ G is optimal.
- **"Stays ahead" argument (alternative proof):** show that after each step, the greedy partial solution is at least as good as any other partial solution by some measured quantity (e.g. finish time so far), so it can never be overtaken.
- **No backtracking:** a greedy never revisits a committed choice. This is exactly why it's fast and exactly why it fails when choices interact.
- **Matroids (theory):** greedy is provably optimal for any problem whose feasible sets form a **matroid** (CLRS 16.4) — a sufficient (not necessary) condition that explains why MST greedies (Kruskal/Prim) work.

## Common Pitfalls

- **Assuming greedy works because it *looks* right.** The most common interview mistake. A passing example proves nothing — you must argue the greedy-choice property or produce a counterexample. Coin change with {1,3,4} is the classic trap.
- **Wrong sort key.** Interval scheduling is optimal sorting by **finish time**, *not* start time or shortest duration. A plausible-but-wrong key silently gives suboptimal answers.
- **0-1 vs fractional knapsack.** Ratio-greedy is optimal only when items are divisible. For 0-1 knapsack it can be arbitrarily bad; that problem is DP (pseudo-polynomial).
- **Not proving optimality.** In interviews, stating "this is greedy" without a one-line justification (exchange or stays-ahead) is a red flag. Have the argument ready.
- **Ties and stability.** When multiple items share the sort key, the tie-break can matter for correctness or for producing a specific required output — decide it deliberately.
- **Confusing greedy with DP-with-a-greedy-flavor.** Dijkstra and Prim are greedy *and* need a priority queue; the greedy choice (nearest unvisited vertex) is what makes them correct on non-negative weights — and negative weights break exactly that safety.

## Implementation Notes

Two canonical greedies. The pattern is always: **impose an order, then take items that stay feasible.**

```javascript
// ── Interval scheduling: max non-overlapping intervals ──────────────
// Greedy: always keep the interval that finishes earliest, because it
// leaves the most room for the rest. Proof: exchange argument on finish time.
function maxNonOverlapping(intervals) {
  intervals.sort((a, b) => a[1] - b[1]);   // sort by FINISH time (a[1])
  let count = 0;
  let lastEnd = -Infinity;
  for (const [start, end] of intervals) {
    if (start >= lastEnd) {                 // no overlap with last kept
      count++;
      lastEnd = end;                        // commit; never reconsider
    }
  }
  return count;
}
```

```python
import heapq

# ── Huffman coding: minimal-weight prefix code ──────────────────────
# Greedy: repeatedly merge the two lowest-frequency nodes. Proof: the two
# rarest symbols are siblings at the deepest level of some optimal tree.
def huffman(freqs):                          # freqs: dict symbol -> count
    heap = [[w, sym] for sym, w in freqs.items()]
    heapq.heapify(heap)                      # O(n) build
    while len(heap) > 1:                     # n - 1 merges
        lo = heapq.heappop(heap)             # two smallest
        hi = heapq.heappop(heap)
        # merged node's weight is the sum; children keep the two subtrees
        heapq.heappush(heap, [lo[0] + hi[0], [lo, hi]])
    return heap[0]                           # root of the Huffman tree
```

## Variants

- **Interval scheduling** (max count) vs **interval partitioning** (min rooms/resources to cover all) — the latter sorts by start time and uses a min-heap of end times.
- **Activity selection** — CLRS's canonical greedy; identical to interval scheduling.
- **Huffman coding** — greedy over a min-priority queue; optimal prefix code.
- **Fractional knapsack** — sort by value/weight ratio, take greedily (contrast 0-1 knapsack = DP).
- **Dijkstra / Prim** — greedy graph algorithms; safe only under their invariants (non-negative weights; cut property).
- **Kruskal** — greedy [MST](_meta/glossary.md#mst) by increasing edge weight, feasibility checked with union-find (a matroid instance).

## Resources

- CLRS, *Introduction to Algorithms* — Chapter 16 "Greedy Algorithms" (activity selection 16.1, greedy-vs-DP 16.2, Huffman 16.3, matroids 16.4)
- cp-algorithms — Scheduling / greedy topics: https://cp-algorithms.com/schedules/schedule_one_machine.html
- Stanford CS161 Lecture 14 (greedy, exchange arguments): https://web.stanford.edu/class/archive/cs/cs161/cs161.1172/CS161Lecture14.pdf
- NeetCode roadmap (Greedy section): https://neetcode.io/roadmap

## Related

- [[dynamic-programming-1d]]
- [[dynamic-programming-2d]]
- [[intervals]]
- [[heap]]
- [[union-find]]
- [[graphs]]
- [[binary-search]]
