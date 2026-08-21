---
id: fff9d057-143c-401b-a5cc-788c70d211bd
type: flashcard
tags:
  - ds-a
  - dynamic-programming
  - memoization
  - tabulation
tiers:
  ds-a: 2
created: 2026-08-20
confidence: high
---

# Dynamic Programming — 2D Patterns

2D DP solves problems where the optimal answer at each cell `(i, j)` depends on previously computed answers in the same grid or table — the core insight is that two independent dimensions of choice or constraint interact, so a 1D array of subproblems cannot capture the full state.

## When to Use

**Problem signals that suggest 2D DP:**
- Two sequences are compared, aligned, or matched (strings, arrays) — classic: edit distance, LCS, regex matching
- A 2D grid with movement constraints (only right/down, or 4-directional with visited state)
- A knapsack-style problem with two varying dimensions: item index and remaining capacity/budget
- "How many ways…" or "minimum cost to…" across a matrix or between two sequences
- Problem has two independent indices that both shrink/grow toward a base case (e.g., `i` from left, `j` from right on same string: palindrome DP)
- Constraints fit in O(n*m) time and space (e.g., n, m ≤ 1000)

**Prefer 2D DP over alternatives when:**
- Over 1D DP: the state cannot be compressed to one dimension without losing information about which sub-problem combination produced it
- Over BFS/DFS alone: you need optimal substructure across two dimensions, not just reachability
- Over greedy: locally optimal choices do not globally hold (e.g., editing two strings requires tracking all alignments)

**Do not use when:**
- Only one sequence/dimension varies → use 1D DP
- Grid paths require tracking visited cells dynamically (cycles) → use BFS/DFS with explicit visited set, not a static DP table
- Constraints are too large (n, m > 10^4 each) and O(n*m) space is infeasible → look for math or greedy reductions

## Decision Framework

Apply this checklist before writing any code:

1. **Optimal substructure check:** Can `answer(i, j)` be expressed cleanly in terms of `answer(i-1, j)`, `answer(i, j-1)`, `answer(i-1, j-1)`, or similar smaller sub-problems? If yes, 2D DP applies.

2. **State definition:** Be explicit. Write it in English first:
   - `dp[i][j]` = "minimum operations to convert `s1[0..i-1]` to `s2[0..j-1]`"
   - `dp[i][j]` = "length of LCS of `s1[0..i-1]` and `s2[0..j-1]`"
   - `dp[i][j]` = "number of unique paths to reach cell `(i, j)`"
   Ambiguous state definitions cause wrong recurrences every time.

3. **Recurrence relation:** Derive it from the state definition. Ask: "What choices exist at `(i, j)`, and which sub-problems cover each choice?"

4. **Base cases:** What are `dp[0][j]` and `dp[i][0]`? Initialize these before filling.

5. **Answer location:** Is the answer `dp[n][m]`? `max over entire table`? `min of last row`? Identify before implementation.

6. **Memoization vs. tabulation:** Prefer tabulation (bottom-up iteration) in interviews — no recursion stack overhead, easier to reason about. Use memoization when the state space is sparse (many sub-problems never needed).

## Time & Space Complexity

| Pattern | Time | Space | Notes |
|---|---|---|---|
| Edit distance / LCS | O(n·m) | O(n·m) → O(m) optimized | Full table; rolling array drops to O(m) |
| Grid unique paths | O(n·m) | O(n·m) → O(m) optimized | Only need previous row |
| 0/1 Knapsack 2D | O(n·W) | O(n·W) → O(W) optimized | n items, W capacity |
| Palindrome substrings | O(n²) | O(n²) | `i` to `j` on same string |
| Regex / wildcard match | O(n·m) | O(n·m) | State: pattern index × string index |

**Why O(n·m):** Each cell is computed exactly once using O(1) previously computed neighbors — the table fills in a consistent topological order (usually top-left to bottom-right).

**Space optimization:** When `dp[i][j]` depends only on the current and previous row, a single 1D array iterated right-to-left (for knapsack) or a rolling two-row approach eliminates the second dimension.

## Key Properties

- **Optimal substructure:** The globally optimal solution is built from locally optimal sub-problem solutions. This is the formal prerequisite for DP of any kind.
- **Overlapping sub-problems:** The same `(i, j)` sub-problem is needed by multiple parent cells — this is what makes memoization/tabulation worthwhile vs. plain recursion.
- **Fill order matters:** For tabulation, cells must be computed before they are referenced. The standard left-to-right, top-to-bottom sweep works when dependencies only come from `(i-1, *)` and `(*, j-1)`. Diagonal fills (e.g., `i <= j` palindrome problems) require a different traversal order.
- **Off-by-one discipline:** 2D DP is particularly prone to index errors. Consistently decide: does `dp[i][j]` represent "first `i` elements" (1-indexed, 0 = empty prefix) or "element at index `i`" (0-indexed). Pick one and never mix.

## Implementation Notes

### Pattern 1: Edit Distance (two sequences, character alignment)

```js
// dp[i][j] = min operations to convert s1[0..i-1] → s2[0..j-1]
// Operations: insert, delete, replace (each costs 1)
function editDistance(s1, s2) {
  const n = s1.length, m = s2.length;

  // (n+1) × (m+1) table; row 0 = empty s1, col 0 = empty s2
  const dp = Array.from({ length: n + 1 }, (_, i) =>
    Array.from({ length: m + 1 }, (_, j) => (i === 0 ? j : j === 0 ? i : 0))
  );
  // Base cases: dp[i][0] = i deletions, dp[0][j] = j insertions

  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      if (s1[i - 1] === s2[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1]; // characters match — free
      } else {
        dp[i][j] = 1 + Math.min(
          dp[i - 1][j],     // delete from s1
          dp[i][j - 1],     // insert into s1
          dp[i - 1][j - 1]  // replace
        );
      }
    }
  }
  return dp[n][m];
}
```

### Pattern 2: Longest Common Subsequence

```js
// dp[i][j] = LCS length of s1[0..i-1] and s2[0..j-1]
function lcs(s1, s2) {
  const n = s1.length, m = s2.length;
  const dp = Array.from({ length: n + 1 }, () => new Array(m + 1).fill(0));
  // Base: dp[0][*] = dp[*][0] = 0 (empty prefix has LCS 0)

  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      if (s1[i - 1] === s2[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1; // extend the common subsequence
      } else {
        dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]); // best without one char
      }
    }
  }
  return dp[n][m];
}
```

### Pattern 3: Grid Unique Paths (movement-constrained grid)

```js
// dp[i][j] = number of unique paths to reach (i, j) from (0, 0)
// Movement: right or down only
function uniquePaths(m, n) {
  // Space-optimized: only need one row at a time
  const dp = new Array(n).fill(1); // base: top row all 1s (only one way along top)

  for (let i = 1; i < m; i++) {
    for (let j = 1; j < n; j++) {
      dp[j] += dp[j - 1]; // dp[j] = paths from above + paths from left
      // dp[j] (old) = paths from above row; dp[j-1] (just updated) = paths from left
    }
  }
  return dp[n - 1];
}

// With obstacles (LC 63): same pattern, set dp[i][j] = 0 if grid[i][j] === 1
function uniquePathsWithObstacles(grid) {
  const m = grid.length, n = grid[0].length;
  const dp = new Array(n).fill(0);
  dp[0] = grid[0][0] === 1 ? 0 : 1;

  for (let j = 1; j < n; j++) dp[j] = grid[0][j] === 1 ? 0 : dp[j - 1];

  for (let i = 1; i < m; i++) {
    dp[0] = grid[i][0] === 1 ? 0 : dp[0]; // update leftmost column
    for (let j = 1; j < n; j++) {
      dp[j] = grid[i][j] === 1 ? 0 : dp[j] + dp[j - 1];
    }
  }
  return dp[n - 1];
}
```

### Pattern 4: 0/1 Knapsack (item index × remaining capacity)

```js
// dp[i][w] = max value using items 0..i-1 with capacity w
// Space-optimized: iterate capacity right-to-left to prevent reuse of same item
function knapsack(weights, values, capacity) {
  const n = weights.length;
  const dp = new Array(capacity + 1).fill(0);

  for (let i = 0; i < n; i++) {
    // Right-to-left: ensures each item is used at most once
    // (Left-to-right would allow item i to be picked multiple times)
    for (let w = capacity; w >= weights[i]; w--) {
      dp[w] = Math.max(dp[w], dp[w - weights[i]] + values[i]);
    }
  }
  return dp[capacity];
}
```

### Memoization (top-down) template

```js
// Use when the state space is sparse or recursion is more natural to derive
function editDistanceMemo(s1, s2) {
  const memo = new Map();

  function dp(i, j) {
    if (i === 0) return j;
    if (j === 0) return i;
    const key = `${i},${j}`;
    if (memo.has(key)) return memo.get(key);

    let result;
    if (s1[i - 1] === s2[j - 1]) {
      result = dp(i - 1, j - 1);
    } else {
      result = 1 + Math.min(dp(i - 1, j), dp(i, j - 1), dp(i - 1, j - 1));
    }
    memo.set(key, result);
    return result;
  }

  return dp(s1.length, s2.length);
}
// Prefer tabulation in interviews — no stack overflow risk on large inputs
```

## Common Pitfalls

- **Wrong fill order for diagonal DP:** Palindrome problems (`dp[i][j]` = longest palindrome in `s[i..j]`) require iterating by substring length, not row-by-row. Row-by-row leaves `dp[i+1][j-1]` uncomputed when `dp[i][j]` needs it.
- **Forgetting the base case row/column:** Initializing only the `(0,0)` corner and skipping the full first row and column is the single most common 2D DP bug.
- **Mixing 0-indexed and 1-indexed:** If `dp[i][j]` means "first `i` characters," then characters are accessed as `s[i-1]` — not `s[i]`. Lock this in at the start and never deviate.
- **Space optimization breaking correctness:** Right-to-left iteration in knapsack prevents item reuse. Switching to left-to-right accidentally solves the unbounded knapsack. Know which problem you are solving.
- **Assuming O(n·m) space is always needed:** Interviewers frequently ask for the space-optimized version after you present the full table. Practice rolling-array reductions for every pattern you learn.

## Trade-offs

| Approach | Pros | Cons |
|---|---|---|
| Tabulation (bottom-up) | No recursion overhead; predictable memory; easier to optimize space | Must determine correct fill order upfront; less intuitive for some problems |
| Memoization (top-down) | Natural recursive structure; only computes needed states | Call stack depth O(n+m) can cause stack overflow; map key overhead |
| Space-optimized tabulation | O(m) or O(W) space | Loses ability to reconstruct the solution path; harder to reason about correctness |

**Reconstruction:** If the problem asks to return the actual sequence (not just the count/cost), keep the full n×m table and backtrack from `dp[n][m]` following the recurrence in reverse. Space optimization makes reconstruction impossible.

## Variants

- **Unbounded knapsack:** Same as 0/1 but iterate capacity left-to-right (items can be reused).
- **Longest Palindromic Subsequence:** LCS of string with its reverse.
- **Regex / Wildcard Matching:** State is `(pattern_index, string_index)`; `*` introduces a branching recurrence.
- **Burst Balloons (interval DP):** `dp[i][j]` = max coins from bursting all balloons in `(i, j)`; fill by interval length.
- **Matrix Chain Multiplication:** Classic interval DP; fill order by chain length.

## Resources

- NeetCode 2D DP playlist: https://neetcode.io/roadmap (DP section)
- LeetCode #72 Edit Distance: https://leetcode.com/problems/edit-distance/
- LeetCode #1143 LCS: https://leetcode.com/problems/longest-common-subsequence/
- LeetCode #62 Unique Paths: https://leetcode.com/problems/unique-paths/
- LeetCode #416 Partition Equal Subset Sum (0/1 knapsack): https://leetcode.com/problems/partition-equal-subset-sum/
- CLRS Chapter 15: Dynamic Programming

## Related

- [[dynamic-programming-1d-patterns]]
- [[memoization-vs-tabulation]]
- [[interval-dynamic-programming]]
- [[backtracking-vs-dp]]
