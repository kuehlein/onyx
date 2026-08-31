---
id: d4e94aa5-dc9e-4758-b2b1-5853b1657612
type: interview-question
category: coding
difficulty: medium
frequency: high
domains: [ds-a]
tiers:
  ds-a: 1
concepts:
  - array
source: blind-75
practice_url: https://neetcode.io/problems/products-of-array-discluding-self
created: 2026-08-20
confidence: high
priority: normal
---

# Product of Array Except Self

Given an integer array `nums`, return an array `output` where `output[i]` is the product of all elements in `nums` except `nums[i]`. You must solve it in O(n) time **without using division**.

Constraints: `2 <= nums.length <= 10^5`, `-30 <= nums[i] <= 30`. The product of any prefix or suffix fits in a 32-bit integer.

## Approach

> [!tip] The core trick
> `output[i]` = (product of everything left of `i`) × (product of everything right of `i`). Two linear passes — a left prefix pass, then a right suffix pass reusing the output array — so no element ever multiplies itself. "Product except self" + "no division" is the signal.

**Pattern:** Prefix and suffix product arrays

**Key insight:** You cannot use the "total product ÷ current element" shortcut because division is forbidden (and zeros break it anyway). Instead, notice that the product of everything except `nums[i]` is exactly the product of all elements to the *left* of `i` multiplied by all elements to the *right* of `i`. You can compute these two partial products independently in two linear passes, then multiply them together. No element ever multiplies itself — the left pass stops before `i`, the right pass stops after `i`.

**Recognition signals:**
- The problem asks for a product (or sum, [XOR](_meta/glossary.md#xor), etc.) of "all except self" — a classical exclusion problem
- Division is explicitly disallowed, ruling out the naive total-product approach
- The array can contain zeros, which further rules out division
- O(n) time constraint with no extra passes budget pushes you toward a two-pass prefix/suffix pattern

```js
function productExceptSelf(nums) {
  const n = nums.length;
  const output = new Array(n).fill(1);

  // First pass: output[i] holds the product of all elements to the LEFT of i.
  // Index 0 has nothing to its left, so it stays 1.
  let prefix = 1;
  for (let i = 0; i < n; i++) {
    output[i] = prefix;
    prefix *= nums[i]; // accumulate before moving right
  }

  // Second pass: multiply each output[i] by the product of all elements to
  // the RIGHT of i. We reuse the output array — no extra array needed.
  // Index n-1 has nothing to its right, so suffix starts at 1.
  let suffix = 1;
  for (let i = n - 1; i >= 0; i--) {
    output[i] *= suffix;
    suffix *= nums[i]; // accumulate before moving left
  }

  return output;
}
```

## Complexity

Time: O(n) — two independent single passes over the array, each O(n).
Space: O(1) auxiliary — the output array is required by the problem and not counted; `prefix` and `suffix` are scalar accumulators.

## Follow-up Questions

- **What if division were allowed?** → Compute the total product, then divide by `nums[i]` for each index. Requires special-casing zeros: if two or more zeros exist every answer is 0; if exactly one zero exists only that index's answer is nonzero.
- **What if the array can contain zeros?** → The prefix/suffix approach handles zeros naturally — no division means no divide-by-zero edge case. This is actually *why* the no-division constraint exists in the problem.
- **Can you do it in a single pass?** → No — you need the full right-side product for index 0, which isn't available until you've seen the entire array. Two passes is the minimum.
- **How would you parallelize this for a very large array?** → Split the array into chunks, compute local prefix/suffix products per chunk, then do a second stage to propagate cross-chunk products — a standard parallel prefix scan (e.g., used in GPU computing and MapReduce).

## Resources

- NeetCode: https://neetcode.io/problems/products-of-array-discluding-self
- LeetCode #238: https://leetcode.com/problems/product-of-array-except-self/

## Related Concepts

- [[array]]
