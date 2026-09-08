---
id: backtracking
type: flashcard
tags:
  - ds-a
  - backtracking
tiers:
  ds-a: 2
created: 2026-09-08
confidence: high
priority: normal
---

# Backtracking

Backtracking is a [DFS](_meta/glossary.md#dfs) over an *implicit* decision tree: at each node you **choose** one option, **explore** the consequences recursively, then **un-choose** (undo the choice) before trying the next. It works because every candidate solution corresponds to a root-to-leaf path, and the choose/explore/un-choose invariant means the shared mutable state (the partial solution) is always restored to exactly what it was on entry — so sibling branches never see each other's mutations. The payoff over brute force is **pruning**: the moment a partial solution provably cannot extend to a valid full solution, you abandon the whole subtree, cutting off `branching^remaining_depth` dead-end leaves at once.

> [!tip] Recognition signal
> Reach for backtracking when the problem says "**find/generate ALL** ..." (subsets, permutations, combinations, valid arrangements) or is a **constraint-satisfaction** puzzle (N-queens, Sudoku, word search, graph coloring). The tell: the answer is built **one incremental choice at a time**, and a partial choice can be **checked for validity before completing it**.

## When to Use

**Problem signals that suggest backtracking:**
- The problem asks to **enumerate all** valid configurations: "return all subsets", "list every permutation", "all combinations of k from n", "all ways to..."
- **Constraint satisfaction**: place items subject to rules (N-queens, Sudoku, graph coloring, "partition into k equal-sum subsets")
- **Grid path / search** where a path is built cell-by-cell and can be pruned mid-way (word search, rat-in-a-maze, "does this path spell the target")
- The candidate answer is a **sequence of decisions** and each partial decision can be **validated early** (a prefix can be judged invalid before it's complete)
- Small `n` with **exponential/factorial** solution space — constraints (e.g. `n <= 20` for subsets, `n <= 10` for permutations) hint the intended answer explores the full tree

**Prefer backtracking over alternatives when:**
- Over plain [recursion](recursion.md) / naive DFS: when you can **prune** — validity is checkable on partial states, so you skip whole subtrees instead of generating every leaf and filtering
- Over [dynamic programming](dynamic-programming-1d.md) ([DP](_meta/glossary.md#dp)): when you must **produce the actual configurations**, not just count them or find one optimum. DP collapses overlapping subproblems into a value; backtracking materializes each distinct arrangement
- Over iterative bitmask enumeration (for subsets): when there are **constraints that prune**, or the choice set is not a simple include/exclude bit (e.g. permutations, k-way partitions)

**Do not use when:**
- You only need the **count** of solutions or a **single optimal** value with overlapping subproblems → use [[dynamic-programming-1d]] (partial states repeat and can be memoized)
- The choices are **independent with no ordering/constraint** and you just want every subset → a bitmask loop over `0..2^n-1` is simpler and allocation-light
- `n` is large (say > ~20–25): the tree is `branching^depth` and no pruning saves you from exponential blowup → the problem almost certainly wants DP, greedy, or a polynomial insight instead

## Time & Space Complexity

Backtracking's cost is the **number of tree nodes visited x work per node**. Without pruning that is `branching^depth` leaves; pruning lowers the *effective* branching factor but the worst case stays exponential/factorial. The "x n" factors below come from **copying** each completed solution into the output list.

| Problem | Time (worst case) | Extra space (excl. output) | Why |
|---|---|---|---|
| All subsets (power set) | O(n · 2^n) | O(n) recursion depth | 2^n subsets, O(n) to copy each |
| All permutations | O(n · n!) | O(n) depth + O(n) used-set | n! leaves, O(n) to copy each |
| Combinations (k of n) | O(k · C(n,k)) | O(k) depth | C(n,k) results, O(k) to copy each |
| N-Queens (all solutions) | O(N!) | O(N) for column/diagonal sets | ≤ N choices row 1, ≤ N−1 row 2, ... pruned by attack checks |
| Word search (grid m×n, word len L) | O(m · n · 4^L) | O(L) recursion stack | start DFS from each cell; ≤4 directions × L depth |

- **General upper bound:** O(b^d) nodes where `b` = branching factor, `d` = depth, times O(work-per-node) for the validity check and any copy. This `branching^depth` shape is the single most important thing to state in an interview.
- **Space** is dominated by the **recursion stack = O(depth)**, plus any auxiliary bookkeeping (a `visited`/`used` set, column/diagonal occupancy). The **output itself** can be exponentially large and is usually excluded from "extra space" by convention — state that assumption explicitly.
- Pruning changes the **constant/effective branching**, not the asymptotic worst case. N-Queens is O(N!) worst case even though real runs explore far fewer nodes.

## Key Properties

- **The choose → explore → un-choose invariant is the whole trick.** After a recursive call returns, you must restore mutable state (pop the last element, unmark the cell, clear the row) so the next sibling branch starts from the same state the current one did. Skipping the undo leaks state across branches — the classic source of wrong output.
- **The decision tree is implicit.** You never build the tree in memory; the call stack *is* the current root-to-node path. Depth = length of a full solution; branching = number of choices at each step.
- **Pruning (a.k.a. bounding) is what separates backtracking from exhaustive DFS.** A *feasibility* check kills invalid partials early (N-queens: is this square attacked?); a *bound* check kills partials that can't beat the best-so-far (optimization variants → branch and bound).
- **Ordering choices well amplifies pruning.** Trying the most-constrained variable first (e.g. the empty Sudoku cell with fewest candidates — the MRV heuristic) prunes far more of the tree.
- **Deduplication vs. distinct results:** when the input has duplicates, **sort first** and skip a choice equal to its previous sibling at the same tree level (`if i>start and a[i]==a[i-1]: continue`) to avoid emitting duplicate subsets/permutations.

## Common Pitfalls

- **Forgetting to un-choose.** Adding to the path but not removing it after the recursive call corrupts every subsequent branch. Every `path.push(x)` needs a matching `path.pop()` on the way out.
- **Appending a reference instead of a copy.** In the "found a full solution" base case, pushing the *same* mutable `path` array/list into results means later mutations rewrite already-saved answers. Push a **copy** (`[...path]` / `path[:]`).
- **Duplicate results from duplicate inputs.** Without sort-then-skip-equal-siblings, `[1,2,2]` yields the same subset/permutation multiple times. Interviewers check this explicitly.
- **Wrong pruning that discards valid solutions.** An over-aggressive bound or an off-by-one in the "is this partial still feasible?" check silently drops correct answers — fails on specific inputs, not all.
- **Using `start` index vs. a `used` set incorrectly.** Combinations/subsets advance a `start` index so each element is considered once and order doesn't matter; permutations need a `used[]` marker because every position can draw from all unused elements. Mixing them up produces permutations when you wanted combinations (or vice-versa).
- **Not restoring auxiliary state, only the path.** For N-queens/Sudoku you must also un-mark the column/diagonal/box occupancy sets, not just pop the coordinate.

## Implementation Notes

The universal skeleton — memorize the shape, not the specific problem:

```python
def backtrack(state, choices):
    if is_complete(state):
        results.append(state.copy())      # COPY, not reference
        return
    for choice in choices:                # branching
        if not is_valid(state, choice):   # PRUNE dead branches early
            continue
        state.apply(choice)               # CHOOSE
        backtrack(state, next_choices)    # EXPLORE (depth += 1)
        state.undo(choice)                # UN-CHOOSE (restore invariant)
```

Subsets and permutations in JS — note how `start` (subsets) vs. `used` (permutations) encodes the difference:

```js
// ── ALL SUBSETS (power set): O(n · 2^n) ──────────────────────────────
const subsets = (nums) => {
  const res = [], path = [];
  const dfs = (start) => {
    res.push([...path]);                  // every node is a valid subset — copy it
    for (let i = start; i < nums.length; i++) {
      path.push(nums[i]);                 // choose
      dfs(i + 1);                         // explore: i+1 => each element used once, order-free
      path.pop();                         // un-choose
    }
  };
  dfs(0);
  return res;
};

// ── ALL PERMUTATIONS: O(n · n!) ──────────────────────────────────────
const permutations = (nums) => {
  const res = [], path = [], used = new Array(nums.length).fill(false);
  const dfs = () => {
    if (path.length === nums.length) { res.push([...path]); return; } // leaf only
    for (let i = 0; i < nums.length; i++) {
      if (used[i]) continue;             // prune: can't reuse an element
      used[i] = true; path.push(nums[i]); // choose
      dfs();                              // explore
      path.pop(); used[i] = false;        // un-choose (restore BOTH)
    }
  };
  dfs();
  return res;
};
```

N-Queens shows constraint pruning via [LIFO](_meta/glossary.md#lifo)-restored occupancy sets:

```python
def solve_n_queens(n):
    res, board = [], []
    cols, diag, anti = set(), set(), set()   # occupancy: col, r-c, r+c
    def place(r):
        if r == n:
            res.append(board.copy()); return
        for c in range(n):
            if c in cols or (r - c) in diag or (r + c) in anti:
                continue                     # PRUNE: this square is attacked
            cols.add(c); diag.add(r - c); anti.add(r + c); board.append(c)   # choose
            place(r + 1)                     # explore next row
            cols.remove(c); diag.remove(r - c); anti.remove(r + c); board.pop()  # un-choose
    place(0)
    return res
```

## Variants

- **Branch and bound** — backtracking for *optimization*: maintain a bound (best-so-far) and prune any partial whose best possible completion can't beat it. Used for TSP, knapsack, job assignment.
- **Constraint propagation (forward checking / AC-3)** — after each choice, eliminate now-impossible options from other variables' domains before recursing; drastically shrinks the tree in Sudoku/CSP solvers.
- **Iterative deepening DFS (IDDFS)** — repeated depth-limited backtracking; combines DFS's O(depth) space with BFS-like shallowest-solution-first behavior for huge/infinite trees.
- **Bitmask backtracking** — encode the chosen/used set as an integer for O(1) choose/undo and cache-friendly state (fast N-queens, subset problems, TSP DP).

## Resources

- cp-algorithms — Generating all K-combinations: https://cp-algorithms.com/combinatorics/generating_combinations.html
- NeetCode — Backtracking roadmap (subsets / permutations / combinations): https://neetcode.io/roadmap
- Sedgewick & Wayne, *Algorithms* 4th ed. — §6 backtracking / N-Queens; and CLRS *Introduction to Algorithms* Ch. 34 (NP-completeness) for why these search spaces are exponential

## Related

- [[dfs]]
- [[recursion]]
- [[dynamic-programming-1d]]
- [[graphs]]
- [[bit-manipulation]]
