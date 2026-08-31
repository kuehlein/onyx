---
id: d2f6d565-8ab8-477d-a519-1cfe45077f58
type: interview-question
category: coding
difficulty: easy
frequency: high
domains: [ds-a]
tiers:
  ds-a: 1
concepts:
  - array
  - sliding-window
source: blind-75
practice_url: https://neetcode.io/problems/buy-and-sell-crypto
created: 2026-08-20
confidence: medium
priority: normal
---

# Best Time to Buy and Sell Stock

Given an array `prices` where `prices[i]` is the price of a stock on day `i`,
return the maximum profit you can achieve by buying on one day and selling on a
later day. If no profit is possible, return `0`.

You may complete at most one transaction (one buy, one sell).

Constraints: `1 <= prices.length <= 10^5`, `0 <= prices[i] <= 10^4`.

## Approach

**Pattern:** Single-pass min tracking

> [!tip] Recognition heuristic
> "Buy before you sell" is a forward-only ordering constraint — it collapses the O(n²) pair search into one left-to-right pass tracking the running minimum.

**Key insight:** You never need to look backward. At every day, the best you
could have done is buy at the lowest price seen *so far* and sell today. That
means a single left-to-right pass is sufficient: track the running minimum and
check whether selling today beats the best profit you've recorded. There is no
need for a nested loop comparing every pair — the minimum resets itself
naturally as you scan forward, because any future sell price is compared against
the cheapest historical buy automatically.

**Recognition signals:**
- "Buy before you sell" — the ordering constraint collapses the problem to a
  running minimum, not a full search over pairs.
- Asking for max profit with a single transaction signals one buy + one sell,
  which is exactly the one-pass min/max pattern.
- The brute-force O(n²) comparison of every (buy, sell) pair is the obvious
  trap; recognizing the forward-only constraint unlocks O(n).

```js
function maxProfit(prices) {
  let minPrice = Infinity; // cheapest buy seen so far
  let maxProfit = 0;       // best profit seen so far

  for (const price of prices) {
    if (price < minPrice) {
      minPrice = price;    // found a cheaper buy day — update; no sell today
    } else {
      // selling today at `price`, having bought at the historical minimum
      maxProfit = Math.max(maxProfit, price - minPrice);
    }
  }

  return maxProfit;
}
```

The `else` branch is optional — you can always compute `price - minPrice`
without the branch; the `Math.max` handles the non-improvement case. The
branch just makes the intent explicit for an interview whiteboard.

## Complexity

Time: O(n) — single pass through the array; each price is visited exactly once.
Space: O(1) — only two scalar variables regardless of input size.

## Follow-up Questions

- **What if you can make at most k transactions?** → Dynamic programming with
  a `k × n` table tracking max profit with at most `k` buys used up to day `i`.
  Classic "Best Time to Buy and Sell Stock IV" (LC #188).
- **What if you can make unlimited transactions (but must sell before buying again)?** →
  Greedy: sum every upward price difference `prices[i] - prices[i-1]` when
  positive. O(n) time, O(1) space. (LC #122)
- **What if there is a cooldown of one day after selling?** → [DP](_meta/glossary.md#dp) with three
  states per day: holding, sold (cooldown), idle. (LC #309)
- **What if buying/selling has a transaction fee?** → Greedy/DP variant; subtract
  the fee from profit on every sell to decide whether the trade is worthwhile.
  (LC #714)

## Resources

- NeetCode: https://neetcode.io/problems/buy-and-sell-crypto
- LeetCode #121: https://leetcode.com/problems/best-time-to-buy-and-sell-stock/

## Related Concepts

- [[array]]
- [[sliding-window]]
