---
id: 76f8c3da-efe4-473d-9545-68cb623ccd32
type: flashcard
tags:
  - ds-a
  - recursion
tiers:
  ds-a: 1
created: 2026-08-19
confidence: medium
---

# Recursion and the Call Stack

A recursive function solves a problem by reducing it to a smaller instance of itself, delegating that smaller problem to a recursive call, and combining the result — continuing until a base case is reached. The call stack enforces this by pushing a new frame for every active call and popping it when that call returns, meaning execution at each level is *suspended* until all deeper levels complete.

## When to Use

**Problem signals that suggest recursion:**
- The problem says "tree", "nested", "hierarchical", or "directory structure" — the data has a self-similar shape
- The problem says "all permutations / combinations / subsets" — the search space can be constructed by repeatedly making a choice and recursing on the remainder
- The problem says "merge/split and combine results" — divide-and-conquer structure (merge sort, quicksort, binary search)
- A natural inductive definition exists: "the answer for n depends only on the answer for n-1 (or n-k)" — e.g., Fibonacci, factorials, Catalan numbers
- Graph/tree traversal is required and the path needs to be reconstructed (DFS on trees is naturally recursive)
- The problem says "decode", "parse", or "evaluate expression" — grammar/token structures are inherently recursive
- The constraint n ≤ 20 or depth ≤ 30 appears alongside combinatorial enumeration — the recursion tree is small enough

**Prefer recursion over alternatives when:**
- Over iteration: the data structure is a tree or graph and maintaining an explicit stack iteratively would require more bookkeeping than the recursive frame provides naturally
- Over dynamic programming bottom-up: you need to identify the recurrence first; a working recursive solution (even exponential) is the required first step before memoization
- Over BFS: you need path information, backtracking, or are exploring all solutions rather than shortest path

**Do not use when:**
- The recursion depth can reach O(n) with n up to 10^5–10^6 → Python's default stack limit (~1000 frames) will raise `RecursionError`; convert to iterative with an explicit stack or increase limit cautiously
- The same subproblems are recomputed exponentially (e.g., naive Fibonacci) → add memoization or switch to tabulation
- Tail-call optimization is required for correctness and the language does not support it (Python does not)

## Time & Space Complexity

The complexity depends on the shape of the recursion tree:

| Structure | Time | Space (call stack) |
|---|---|---|
| Linear recursion (one call per level) | O(n) — n frames, O(1) work each | O(n) — stack depth equals n |
| Binary recursion, constant work per node | O(2^n) — tree doubles at each level | O(n) — max stack depth is height, not node count |
| Binary recursion + memoization, k unique states | O(k) — each state computed once | O(k) memo + O(n) stack |
| Divide and conquer, T(n)=2T(n/2)+O(n) | O(n log n) — Master Theorem case 2 | O(log n) — tree height |

**Why the space cost is the stack depth, not the total nodes:** each call frame is pushed on entry and popped on return, so only the frames on the *current path from root to the active leaf* are live simultaneously.

## Key Properties

- **Base case:** the condition that stops recursion and returns a concrete value without a further recursive call. Every recursive path must reach a base case or the stack overflows.
- **Recursive case:** reduces the problem toward the base case. The critical invariant is that the argument passed to the recursive call must be strictly "smaller" (closer to the base case) by some well-founded measure (n-1, left/right subtree, prefix/suffix).
- **Call stack frame:** each frame stores the function's local variables, parameters, and the return address. Frames accumulate until the deepest base case resolves, then unwind in LIFO order.
- **Return value propagation:** results travel *up* the stack as each frame returns. Post-order computations (e.g., combining left and right subtree results) happen during unwinding.

## Common Pitfalls

- **Missing or incorrect base case** — the most common interview error. A base case that handles `n == 0` but not `n < 0` will loop infinitely if the caller passes a negative value. Always ask: "what are all the terminal states?"
- **Not returning the recursive result** — writing `self.helper(node.left)` instead of `return self.helper(node.left)` silently discards the answer; Python returns `None` by default.
- **Mutating shared state without restoring it (backtracking bug)** — appending to a `path` list and forgetting `path.pop()` before the frame returns corrupts results for sibling branches. The golden rule: if you mutate state before recursing, undo it after.

> [!warning] Backtracking golden rule
> If you mutate shared state before recursing, **undo it after** (`path.push(...)` → recurse → `path.pop()`). Forgetting the undo corrupts sibling branches — the most common backtracking bug.
- **Recomputing overlapping subproblems** — explaining "my solution is O(2^n)" without recognizing memoization would reduce it to O(n) is an immediate red flag to interviewers.
- **Off-by-one in the base case** — e.g., stopping at `len(arr) == 0` when the correct stop is `lo > hi` in a binary search recursion.
- **Assuming Python has tail-call optimization** — it does not. A recursive solution with O(n) depth on n=10^5 will crash unless rewritten iteratively or the recursion limit is raised.

## Implementation Notes

```javascript
// ── Example 1: linear recursion ──────────────────────────────────────────────
const factorial = (n) => {
    // Base case: stops recursion; every path must reach this
    if (n <= 1) return 1;
    // Recursive case: n is strictly smaller → guaranteed termination
    return n * factorial(n - 1);
};


// ── Example 2: tree recursion (post-order) ───────────────────────────────────
class TreeNode {
    constructor(val = 0, left = null, right = null) {
        this.val = val;
        this.left = left;
        this.right = right;
    }
}

const treeHeight = (node) => {
    if (node === null) return 0;  // base case: empty subtree has height 0
    const leftH  = treeHeight(node.left);   // results travel UP the stack
    const rightH = treeHeight(node.right);
    return 1 + Math.max(leftH, rightH);    // combine after both subtrees resolve
};


// ── Example 3: backtracking with state restoration ───────────────────────────
const subsets = (nums) => {
    const result = [];
    const path = [];              // shared mutable state

    const backtrack = (start) => {
        result.push([...path]);   // snapshot — NOT a reference; spread copies the array
        for (let i = start; i < nums.length; i++) {
            path.push(nums[i]);   // choose
            backtrack(i + 1);     // explore
            path.pop();           // UNDO — critical: restores state for siblings
        }
    };

    backtrack(0);
    return result;
};


// ── Example 4: memoization to eliminate recomputation ───────────────────────
const fib = (() => {
    const memo = new Map();       // caches n → result; O(n) unique states
    return (n) => {
        if (n <= 1) return n;
        if (memo.has(n)) return memo.get(n);  // return cached result instead of recomputing
        const result = fib(n - 1) + fib(n - 2);  // without cache: O(2^n); with cache: O(n)
        memo.set(n, result);
        return result;
    };
})();


// ── Example 5: JS has no built-in recursion limit knob ──────────────────────
// Unlike Python's sys.setrecursionlimit, JS engines impose their own call-stack
// limit (typically ~10k–15k frames in V8). For deep recursion, convert to an
// explicit iterative stack using an Array as a stack (.push() / .pop()).
```

## Trade-offs

| Recursive | Iterative (explicit stack) |
|---|---|
| Code mirrors the problem's natural structure | No stack-overflow risk for deep inputs |
| Backtracking state managed by the call stack automatically | Full control over stack frame contents (memory efficiency) |
| Hard to profile frame-by-frame | Easier to convert to tail-call / loop |
| Python default limit: ~1000 frames | Heap-allocated; limited by available memory |

## Resources

- Skiena, *The Algorithm Design Manual* (3rd ed.), Ch. 5 — Divide and Conquer
- Sedgewick & Wayne, *Algorithms* (4th ed.), Ch. 2.2 — Mergesort (recursion tree analysis)
- Python docs — `sys.setrecursionlimit`: https://docs.python.org/3/library/sys.html#sys.setrecursionlimit
- Python docs — `functools.lru_cache`: https://docs.python.org/3/library/functools.html#functools.lru_cache

## Related

- [[dynamic-programming]]
- [[backtracking]]
- [[dfs]]
- [[divide-and-conquer]]
- [[memoization]]
