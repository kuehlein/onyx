---
id: big-o-complexity
type: flashcard
tags:
  - ds-a
  - complexity
tiers:
  ds-a: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Big-O Complexity

Asymptotic analysis measures how an algorithm's running time or space grows as input size `n → ∞`, discarding hardware- and constant-dependent detail so two algorithms can be compared by their *growth rate* alone. The core principle: constants and lower-order terms vanish in the limit, so a term's rate of growth — not its coefficient — is what determines scalability. Big-O bounds growth from above (≤), Ω from below (≥), and Θ pins it from both sides (tight). You reason about complexity by counting how the dominant operation's count scales with `n`, then collapsing to the fastest-growing term.

> [!tip] Recognition
> The interviewer asks "what's the time/space complexity?", or a constraint like `n ≤ 10^5` (needs ~O(n log n)) vs `n ≤ 20` (O(2^n)/O(n!) is fine) hints at the target class. A "Time Limit Exceeded" ([TLE](_meta/glossary.md#tle)) verdict means your complexity class is too slow — re-derive it. Any time you compare two approaches, you are implicitly doing asymptotic analysis.

## When to Use

**Problem signals that call for asymptotic analysis:**
- The interviewer explicitly asks "what is the time and space complexity?" — expect this on every coding problem
- Input-size constraints hint at the required class: `n ≤ 20` → exponential/factorial is acceptable; `n ≤ 5000` → O(n²) passes; `n ≤ 10^5–10^6` → you need O(n log n) or better; `n ≤ 10^9` → O(log n) or O(√n)
- You must choose between two data structures/algorithms and justify the pick by growth rate
- A solution passes small tests but hits [TLE](_meta/glossary.md#tle) / [MLE](_meta/glossary.md#mle) at scale — the fix is almost always a better complexity class, not micro-optimization

**Use the right bound for the claim:**
- Over a loose Big-O: use **Θ** when the upper and lower bounds match and you want a *tight* claim ("this is exactly n log n", not merely "at most")
- Over worst-case: quote **amortized** when a rare expensive operation is paid for by many cheap ones (dynamic-array push, [[union-find]])
- Over worst-case: quote **average/expected** when randomization or typical input makes the worst case pathological and unlikely (quicksort, hash tables, quickselect)

**Do not conflate:**
- Big-O is an *upper bound*, not "the exact cost" — saying an O(n²) algorithm is "also O(n³)" is technically true but useless; quote the tightest bound you can justify
- Best-case complexity is almost never the answer an interviewer wants → default to worst-case (or average, if you state the assumption)

## Time & Space Complexity

Complexity classes, ordered slowest-growing to fastest. For large `n`, a lower class always wins regardless of constants:

| Class | Name | Canonical example |
|---|---|---|
| O(1) | constant | hash lookup, array index, stack push |
| O(log n) | logarithmic | binary search, balanced-[BST](_meta/glossary.md#bst) / heap op |
| O(n) | linear | single scan, [BFS](_meta/glossary.md#bfs)/[DFS](_meta/glossary.md#dfs) over adjacency list |
| O(n log n) | linearithmic | mergesort, heapsort, any comparison sort's lower bound |
| O(n²) | quadratic | nested loop over pairs, naive 3Sum's inner scan |
| O(n³) | cubic | Floyd-Warshall, naive matrix multiply |
| O(2^n) | exponential | subset enumeration, naive recursive Fibonacci |
| O(n!) | factorial | permutations, brute-force [TSP](_meta/glossary.md#tsp) |

Ordering: `O(1) < O(log n) < O(n) < O(n log n) < O(n²) < O(2^n) < O(n!)`.

**Space complexity** counts auxiliary memory as a function of `n`, and — critically — **includes the recursion call stack**:

| Source | Space |
|---|---|
| Output array of size n | O(n) |
| In-place scan (few scalars) | O(1) |
| Recursion depth `d` (each frame O(1)) | O(d) |
| Balanced recursion (mergesort, balanced tree) | O(log n) stack |
| Skewed recursion (sorted-input [BST](_meta/glossary.md#bst), bad quicksort pivot) | O(n) stack |
| Hash set/map holding n keys | O(n) |

A "constant-space" claim is wrong if the algorithm recurses `n` deep — that stack is O(n) space even with no explicit allocation.

## Key Properties

- **Formal definitions (CLRS ch. 3).** `f = O(g)`: ∃ c, n₀ such that `0 ≤ f(n) ≤ c·g(n)` for all `n ≥ n₀` (asymptotic upper bound). `f = Ω(g)`: `f(n) ≥ c·g(n)` (lower bound). `f = Θ(g)`: bounded both above and below, i.e. `f = O(g)` **and** `f = Ω(g)` (tight bound). Little-o/ω are the strict (non-tight) versions.
- **Drop constants and lower-order terms.** `3n² + 100n + 5 = Θ(n²)`. The `n²` term dominates as `n → ∞`; coefficients reflect hardware, not the algorithm's scaling. `O(2n) = O(n)`; `O(log₂ n) = O(log n)` (log bases differ by a constant factor).
- **Best / average / worst are different functions.** Quicksort is O(n log n) average but O(n²) worst (already-sorted input, naive pivot). Hash lookup is O(1) average, O(n) worst (all keys collide). State *which* case you mean.
- **Amortized ≠ average.** Amortized is a *worst-case* guarantee over a *sequence* of operations (no probability): every sequence of m operations costs at most O(m·f) total. Average-case is a *probabilistic* expectation over inputs. A dynamic array's push is O(1) amortized — guaranteed — not "O(1) on average if you're lucky."
- **Amortized analysis methods (CLRS ch. 16/17).** *Aggregate:* bound total cost of any sequence, divide by count. *Accounting:* prepay cheap operations extra "credit" that later expensive ones spend (e.g. charge 3 per push; the +2 credits stored fund the eventual O(n) copy on resize, so each push is O(1) amortized). *Potential:* define a potential function Φ; amortized cost = actual + ΔΦ.
- **Θ is transitive and symmetric-in-spirit;** it defines an equivalence-like partition of functions into growth classes. O and Ω are transitive and reflexive (a partial order on growth rates).

## Common Pitfalls

- **Adding when you should multiply (and vice versa).** Sequential blocks add: O(n) then O(n log n) → O(n log n) (dominant term wins). Nested blocks multiply: an O(n) loop containing an O(log n) op → O(n log n).
- **Ignoring the recursion stack in space.** Depth-`n` recursion is O(n) space even if it allocates nothing else. "O(1) space" DFS on a skewed tree is wrong.
- **Assuming average = worst.** Reporting quicksort or hash-map as "O(1)/O(n log n)" without noting the O(n)/O(n²) worst case. Interviewers probe exactly this.
- **Hidden costs of built-ins.** `list.insert(0, x)` in Python and `array.unshift` in JS are O(n) (shift everything). String concatenation in a loop is O(n²) (immutable strings copy each time). `x in list` is O(n); `x in set` is O(1). Slicing `a[i:j]` copies → O(j−i).
- **Big-O hides the constant that matters at small n.** An O(n log n) algorithm can lose to O(n²) for tiny n (why Timsort/introsort fall back to insertion sort on small runs). Asymptotics describe the limit, not every input.
- **Forgetting the input encoding.** "Pseudo-polynomial" DP (knapsack O(n·W)) is polynomial in the *value* W but exponential in the *bit-length* of W — not truly polynomial.
- **Loose bounds stated as tight.** Saying an algorithm "is O(n²)" when it is actually Θ(n) — technically valid (O is an upper bound) but misleading. Quote the tightest bound you can prove.

## Implementation Notes

Deriving complexity is mechanical: identify the dominant repeated operation, count how its count scales with `n`, collapse to the fastest-growing term.

```python
# O(n): one pass. Work is proportional to n.
def total(nums):
    s = 0
    for x in nums:        # runs n times
        s += x            # O(1) body
    return s              # → O(n) time, O(1) space

# O(n^2): nested loops over the same input.
def has_dup_pair(nums, target):
    for i in range(len(nums)):        # n
        for j in range(i + 1, len(nums)):  # ~n
            if nums[i] + nums[j] == target:
                return True           # n * n → O(n^2)
    return False

# O(log n): the search space halves each step.
def binary_search(a, target):
    lo, hi = 0, len(a) - 1
    while lo <= hi:                   # ~log2(n) iterations
        mid = (lo + hi) // 2
        if a[mid] == target: return mid
        elif a[mid] < target: lo = mid + 1
        else: hi = mid - 1
    return -1                          # → O(log n) time, O(1) space

# Recurrence → complexity (Master Theorem, CLRS ch. 4).
# T(n) = 2*T(n/2) + O(n)  → O(n log n)   (mergesort: split in 2, linear merge)
# T(n) = 2*T(n/2) + O(1)  → O(n)         (tree traversal)
# T(n) =   T(n/2) + O(1)  → O(log n)     (binary search)

# Space includes the call stack: this recursion is O(n) space at depth n,
# even though it allocates nothing but the frames themselves.
def rec_sum(nums, i=0):
    if i == len(nums): return 0
    return nums[i] + rec_sum(nums, i + 1)   # depth n → O(n) stack
```

```javascript
// Amortized O(1) push: array doubles when full.
// Most pushes are O(1); the occasional resize copies all n elements (O(n)),
// but resizes are geometrically spaced, so total cost of n pushes is O(n)
// → O(1) amortized per push (aggregate method).
class DynamicArray {
  constructor() { this.data = new Array(1); this.len = 0; this.cap = 1; }
  push(x) {
    if (this.len === this.cap) {        // rare: triggers O(n) copy
      this.cap *= 2;
      const bigger = new Array(this.cap);
      for (let i = 0; i < this.len; i++) bigger[i] = this.data[i];
      this.data = bigger;
    }
    this.data[this.len++] = x;          // common case: O(1)
  }
}
```

## Variants

- **Amortized worst-case** — a per-operation guarantee derived from sequence cost (dynamic array, [[union-find]] with path compression + union by rank: O(α(n)) per op, where α is the inverse Ackermann function and < 5 for any practical n).
- **Expected (randomized)** — bound holds in expectation over the algorithm's random choices, independent of input (randomized quickselect: expected O(n); randomized quicksort: expected O(n log n)).
- **Output-sensitive** — complexity expressed in output size, not just input (e.g. reporting all k results in O((n + k) log n)).
- **Pseudo-polynomial** — polynomial in the numeric *value* of an input but exponential in its bit-length (knapsack O(nW)).

## Resources

- CLRS, *Introduction to Algorithms* (4th ed.), ch. 3 (asymptotic notation), ch. 4 (recurrences/Master Theorem), ch. 16–17 (amortized analysis)
- MIT 6.046J Lecture 11 — Amortized Analysis: https://ocw.mit.edu/courses/6-046j-design-and-analysis-of-algorithms-spring-2012/
- Big-O cheat sheet (data structures + sorting): https://www.bigocheatsheet.com/
- cp-algorithms, Disjoint Set Union (amortized O(α(n))): https://cp-algorithms.com/data_structures/disjoint_set_union.html

## Related

- [[master-theorem]]
- [[binary-search]]
- [[sorting]]
- [[union-find]]
- [[heap]]
- [[hash-map]]
