---
id: 29577791-73b3-40bb-b1ca-aecb1d92fea4
type: interview-question
category: coding
difficulty: easy
frequency: high
domains: [ds-a]
tiers:
  ds-a: 1
concepts:
  - hash-set
  - array
source: blind-75
practice_url: https://neetcode.io/problems/duplicate-integer
created: 2026-08-20
confidence: high
---

# Contains Duplicate

Given an integer array `nums`, return `true` if any value appears more than once
in the array, and `false` if every element is distinct.

Constraints: `1 <= nums.length <= 10^5`, `-10^9 <= nums[i] <= 10^9`.

## Approach

**Pattern:** Hash set membership

**Key insight:** You only need to know whether you have *seen* a value before —
not how many times, not where. A set answers exactly this question in O(1). The
moment you encounter a number that already lives in the set, you have your
duplicate and can return immediately. There is no need to compare every pair;
membership alone is sufficient.

**Recognition signals:**
- The problem asks only for existence of a duplicate (true/false), not the
  duplicate value itself or its count
- No ordering constraint is given, ruling out the need for sorting as a primary
  strategy
- Input is a flat array of primitives — hash set lookup is O(1) with no edge
  cases on the key type

```js
function containsDuplicate(nums) {
  const seen = new Set();

  for (const num of nums) {
    if (seen.has(num)) return true; // duplicate found — early exit
    seen.add(num);
  }

  return false; // every element was distinct
}
```

## Complexity

Time: O(n) — each element is visited once; `Set.has` and `Set.add` are O(1) average.
Space: O(n) — in the worst case (no duplicates) every element is stored in the set.

## Follow-up Questions

- **Can you solve it with O(1) extra space?** → Sort the array in place (`nums.sort((a, b) => a - b)`) and scan for adjacent equals — O(n log n) time, O(1) extra space, but mutates the input.
- **What if the array is too large to fit in memory?** → Stream chunks and use an external hash set or a Bloom filter for a probabilistic first pass, then verify candidates.
- **What if you need to return the duplicate value, not just a boolean?** → The same set approach works; capture `num` before returning `true`.
- **How does the trade-off change if duplicates are rare?** → The set approach still wins on average; sorting is only preferable when memory is the hard constraint.

## Resources

- NeetCode: https://neetcode.io/problems/duplicate-integer
- LeetCode #217: https://leetcode.com/problems/contains-duplicate/

## Related Concepts

- [[hash-set]]
- [[array]]
