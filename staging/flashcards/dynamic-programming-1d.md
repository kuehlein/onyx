---
id: 7f3a2c81-94e6-4b17-bc2d-e05f18a63d94
type: flashcard
tags:
  - ds-a
  - dynamic-programming
  - memoization
  - tabulation
tiers:
  ds-a: 2
created: 2026-08-20
confidence: medium
---

# Dynamic Programming — 1D Patterns

1D DP solves problems where the optimal answer at position `i` depends only on a fixed number of earlier positions — the key insight is that overlapping subproblems let you trade redundant recursion for O(n) stored results, turning exponential brute-force into linear time.

## When to Use

**Problem signals that suggest 1D DP:**
- "Find the maximum/minimum/number of ways to reach the end" over a linear sequence (array, string, number line)
- "Can you achieve exactly X?" (subset-sum, coin change feasibility)
- The word "subsequence" (not subarray — subsequences allow skipping elements, which creates branching that DP collapses)
- You write a recursive solution and notice the same arguments repeat (draw the recursion tree — if two branches call `f(3)` identically, DP applies)
- Constraints look like n ≤ 10,000 — exponential brute-force is ruled out, O(n²) or O(n log n) is acceptable
- The problem has a "last step" decomposition: the optimal solution for n must have come from some optimal solution for n-k

**Prefer 1D DP over alternatives when:**
- Over greedy: the locally optimal choice is not globally safe — you need to compare multiple prior states (e.g., you can skip elements, making greedy fail for longest increasing subsequence)
- Over divide-and-conquer: subproblems overlap (share inputs); D&C is for independent subproblems (merge sort)
- Over BFS/DFS with no memoization: state space has repeated subproblems — memoized DFS is equivalent to top-down DP

**Do not use when:**
- Subproblems are independent → use divide-and-conquer or simple recursion
- Problem asks for the actual path/choices, not just the value → DP still works but you must store parent pointers or backtrack through the table
- n is tiny (≤ 20) and state space is large → bitmask DP or backtracking may be cleaner
- Input is a 2D grid with two free indices → use 2D DP instead

## Decision Framework

Before writing a single line of DP, answer these three questions in order:

**1. Optimal substructure — does it exist?**
Ask: "Can I express the optimal answer for a larger input in terms of optimal answers for smaller inputs?"
If removing one element (or making one choice) from the optimal solution leaves an optimal sub-solution, yes.
If not (e.g., problems requiring global knowledge), DP will not work.

**2. What is the state?**
State = the minimum information needed to answer "what is the best result I can achieve from here?"
For 1D patterns, state is almost always a single index `i` (current position) plus any small bounded parameter (remaining capacity, last element picked). Keep state small — each dimension multiplies your space.

**3. What is the recurrence?**
Write the recurrence as: `dp[i] = f(dp[i-1], dp[i-2], ...)`.
Enumerate every valid "last decision" that could have led to state `i`, take the result of each, and combine with max/min/sum.

**State definition template:**
```
dp[i] = optimal value considering the first i elements (or: ending at index i)
```
The phrasing matters. "Ending at i" includes element i; "considering i elements" may or may not include it — pick one and be consistent.

## Key Properties

- **Overlapping subproblems:** the same subproblem is solved multiple times in naive recursion. DP caches results.
- **Optimal substructure:** an optimal solution contains optimal solutions to its subproblems.
- **Memoization (top-down):** recursive, cache results on the way down. Natural when the recurrence is easy to write but the iteration order is complex.
- **Tabulation (bottom-up):** iterative, fill a table from base cases upward. Usually faster in practice (no call-stack overhead, better cache locality).
- **Space optimization:** if `dp[i]` only depends on a constant number of prior values, you can reduce O(n) space to O(1) by keeping only those values.

## Common Pitfalls

- **Off-by-one in state definition:** mixing "ending at i" with "considering first i+1 elements" causes wrong base cases. Choose one convention and write it in a comment.
- **Missing base cases:** forgetting `dp[0]` or the empty-input case causes incorrect results on small inputs — always verify n=0 and n=1 by hand.
- **Recurrence direction:** if `dp[i]` depends on `dp[i+1]` (right-to-left), iterate from the end. Getting direction wrong silently produces wrong answers.
- **Integer overflow on count problems:** "number of ways" problems accumulate sums that can exceed 32-bit range — use BigInt or modular arithmetic if the problem says "mod 10^9+7".
- **Greedy trap:** if you can prove the greedy choice is safe, greedy beats DP. Always check greedy first — it's O(n) vs O(n²) for some problems.

## Implementation Notes

### Pattern 1 — Linear scan (Fibonacci-style)
Each state depends on the previous 1–2 states. Classic example: climbing stairs (each step you can climb 1 or 2 stairs).

```js
function climbStairs(n) {
  // dp[i] = number of distinct ways to reach step i
  // recurrence: dp[i] = dp[i-1] + dp[i-2]
  // (came from step i-1 with a 1-step, or from i-2 with a 2-step)

  if (n <= 2) return n;

  // Space-optimized: only need last two values
  let prev2 = 1; // dp[1]
  let prev1 = 2; // dp[2]

  for (let i = 3; i <= n; i++) {
    const curr = prev1 + prev2;
    prev2 = prev1;
    prev1 = curr;
  }
  return prev1;
}
// Time: O(n) | Space: O(1)
```

### Pattern 2 — "Ending at i" (maximum subarray / LIS style)
`dp[i]` is defined as the optimal value of a subsequence/subarray that ends exactly at index `i`. You must take a final max over all `dp[i]`.

```js
// Longest Increasing Subsequence — O(n²) DP
function lengthOfLIS(nums) {
  const n = nums.length;
  // dp[i] = length of longest increasing subsequence ending at index i
  const dp = new Array(n).fill(1); // every element alone is a subsequence of length 1

  for (let i = 1; i < n; i++) {
    for (let j = 0; j < i; j++) {
      if (nums[j] < nums[i]) {
        // nums[i] can extend the subsequence ending at j
        dp[i] = Math.max(dp[i], dp[j] + 1);
      }
    }
  }

  return Math.max(...dp); // answer is the max over ALL ending positions
  // Time: O(n²) | Space: O(n)
}
```

### Pattern 3 — Memoization (top-down) vs Tabulation (bottom-up)
Both are equivalent; choose based on what's easier to reason about.

```js
// House Robber — you cannot rob two adjacent houses
// dp[i] = max money robbing houses 0..i

// --- Top-down (memoization) ---
function robMemo(nums) {
  const memo = new Map();

  function dp(i) {
    if (i < 0) return 0;
    if (memo.has(i)) return memo.get(i); // cache hit

    // At house i: skip it (dp[i-1]) or rob it (nums[i] + dp[i-2])
    const result = Math.max(dp(i - 1), nums[i] + dp(i - 2));
    memo.set(i, result);
    return result;
  }

  return dp(nums.length - 1);
}

// --- Bottom-up (tabulation) ---
function robTab(nums) {
  const n = nums.length;
  if (n === 0) return 0;
  if (n === 1) return nums[0];

  // Space-optimized: dp[i] depends only on dp[i-1] and dp[i-2]
  let prev2 = 0;        // dp[-1] conceptually — no houses
  let prev1 = nums[0];  // dp[0]

  for (let i = 1; i < n; i++) {
    const curr = Math.max(prev1, nums[i] + prev2);
    prev2 = prev1;
    prev1 = curr;
  }

  return prev1;
  // Time: O(n) | Space: O(1)
}
```

### Pattern 4 — Unbounded knapsack (coin change)
Items can be reused. The inner loop iterates forward so the same coin can be picked multiple times.

```js
// Coin Change — minimum coins to make amount
function coinChange(coins, amount) {
  // dp[i] = min coins needed to make amount i
  // Infinity signals "impossible"
  const dp = new Array(amount + 1).fill(Infinity);
  dp[0] = 0; // base case: 0 coins needed to make amount 0

  for (let i = 1; i <= amount; i++) {
    for (const coin of coins) {
      if (coin <= i && dp[i - coin] !== Infinity) {
        // Use this coin: adds 1 coin to the solution for (i - coin)
        dp[i] = Math.min(dp[i], dp[i - coin] + 1);
      }
    }
  }

  return dp[amount] === Infinity ? -1 : dp[amount];
  // Time: O(amount × coins.length) | Space: O(amount)
}
```

### Recognizing the pattern: decision checklist

```
1. Can I define dp[i] as "best answer for a subproblem of size i"?
2. Can I write dp[i] = f(dp[i-1], ..., dp[i-k]) for small constant k?
3. Are there O(n) or fewer unique states?
   → If yes to all three: 1D DP. Start with memoization to validate recurrence,
     then convert to tabulation for performance.
```

## Time & Space Complexity

| Pattern | Time | Space | Space-optimized |
|---|---|---|---|
| Linear (Fibonacci) | O(n) | O(n) table | O(1) — keep 2 vars |
| Ending-at-i (LIS n²) | O(n²) | O(n) | O(n) — no reduction |
| Coin change (unbounded) | O(n × k) | O(n) | O(n) — no reduction |
| 0/1 knapsack | O(n × W) | O(n × W) | O(W) — 1D rolling array |

**Why O(n) for linear scan:** one pass, constant work per state.
**Why O(n²) for LIS:** for each of n positions, you scan all prior positions.
**Why O(n × k) for coin change:** for each amount, you try k coin denominations.

Space optimization is possible when `dp[i]` only reads from a fixed-size window of prior values — replace the array with those variables directly.

## Variants

- **2D DP:** state has two indices (e.g., edit distance, 0/1 knapsack grid) — same decision framework, add a second dimension
- **Interval DP:** `dp[i][j]` = optimal for subarray `[i..j]`; used for matrix chain multiplication, burst balloons
- **Bitmask DP:** state includes a bitmask of chosen items; used when n ≤ 20 and you need to track subsets
- **DP on trees:** `dp[node]` = optimal for the subtree rooted at node; computed in post-order DFS

## Resources

- NeetCode DP playlist: https://neetcode.io/roadmap (Dynamic Programming section)
- LeetCode Explore — Dynamic Programming: https://leetcode.com/explore/learn/card/dynamic-programming/
- Competitive Programmer's Handbook, Ch. 7 (Dynamic Programming): https://cses.fi/book/book.pdf

## Related

- [[greedy]]
- [[memoization]]
- [[tabulation]]
- [[divide-and-conquer]]
- [[backtracking]]
