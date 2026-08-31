---
id: 5b372944-bba4-4eb5-9dd3-e3833236d735
type: interview-question
category: coding
difficulty: easy
frequency: high
domains: [ds-a]
tiers:
  ds-a: 1
concepts:
  - hash-map
  - array
source: blind-75
practice_url: https://neetcode.io/problems/two-integer-sum
created: 2026-08-20
confidence: high
priority: normal
---

# Two Sum

Given an array of integers `nums` and an integer `target`, return the indices of
the two numbers that add up to `target`. You may assume exactly one solution
exists, and you may not use the same element twice.

Constraints: `2 <= nums.length <= 10^4`, `-10^9 <= nums[i] <= 10^9`.

## Approach

**Pattern:** Hash map complement lookup

> [!tip] Core trick
> For each `x` the missing partner is fixed: `target - x`. Store value → index as you go and check for the complement *before* inserting — this turns the O(n) search per element into an O(1) map lookup.

**Key insight:** For every element `x`, the number that would complete the pair
is fully determined: it must be `target - x`. Instead of searching the rest of
the array for that complement (O(n) per element), store each element's value →
index in a hash map as you go. Before inserting `x`, check whether its
complement already exists in the map. If it does, you have your answer in O(1).
The map turns the "search" step from linear into constant time.

**Recognition signals:**
- Problem asks for a *pair* of elements satisfying a sum condition
- Return values are *indices*, not the elements themselves (rules out sorting)
- Exactly one valid answer is guaranteed (no need to handle multiple results)

```js
function twoSum(nums, target) {
  const seen = new Map(); // value → index of elements visited so far

  for (let i = 0; i < nums.length; i++) {
    const complement = target - nums[i];

    if (seen.has(complement)) {
      // complement was seen earlier; its index + current index = answer
      return [seen.get(complement), i];
    }

    // Record this element so future iterations can find it as a complement
    seen.set(nums[i], i);
  }
}
```

## Complexity

Time: O(n) — single pass; each hash map lookup and insert is O(1) amortized.
Space: O(n) — the map holds at most n entries in the worst case (no pair found until the last element).

## Follow-up Questions

- **What if the array is already sorted?** → Use two pointers (left + right) instead — O(1) space, still O(n) time, and no hash map needed. Sorting to enable this costs O(n log n) if the input is unsorted, which is worse than the hash map approach.
- **What if multiple valid pairs exist and you need all of them?** → Collect all indices rather than returning on the first hit; be careful to skip using the same index twice.
- **What if you need to return the values instead of indices?** → Sorting + two pointers becomes viable and uses O(1) extra space; hash map is still fine if you store values.
- **Can you solve it in O(1) space?** → Yes, with a nested loop (O(n²) time) or with two pointers on a sorted copy — but sorting requires O(n) space for the index mapping unless you sort in place and discard index requirements.

## Resources

- NeetCode: https://neetcode.io/problems/two-integer-sum
- LeetCode #1: https://leetcode.com/problems/two-sum/

## Related Concepts

- [[hash-map]]
- [[array]]
- [[two-pointers]]
