---
id: 34247cec-5cd7-4c1e-a61e-bab1ca7b62cc
type: flashcard
tags:
  - ds-a
  - two-pointers
  - array
  - string
tiers:
  ds-a: 1
created: 2026-08-19
confidence: low
---

# Two Pointers

Two pointers is a technique where two indices traverse the same data structure — often from opposite ends or at different speeds — to reduce an O(n²) brute-force search to O(n). The core insight is that a sorted order or monotone property lets you eliminate whole swaths of candidates with each pointer move, so you never need to try all pairs.

> [!tip] Recognition signal
> Reach for two pointers when the input is **sorted** (or sorting is acceptable) and you need a pair/triplet meeting a sum/difference target — or when a **monotone** window constraint lets you infer that moving one pointer is provably better than the other.

## When to Use

**Problem signals that suggest Two Pointers:**
- The input is a **sorted array or sorted string** and you need to find a pair (or triplet) that satisfies a sum/difference/product target
- The problem asks for a **subarray or substring** satisfying a constraint that is monotone in window size (grows when you expand, shrinks when you contract) — often paired with sliding window
- The problem mentions "**in-place**" and asks you to remove duplicates, filter elements, or partition an array without extra space
- You are asked to **reverse** a string, list, or portion of an array in-place
- The phrase "**two sum**", "**three sum**", "**closest to target**", or "**container with most water**" appears — these are canonical two-pointer shapes
- Linked list problems involving **cycle detection**, **finding the middle node**, or **detecting intersection** — fast/slow pointer variant
- The problem involves matching characters from **two separate sequences** (e.g., is string A a subsequence of string B?)

**Prefer Two Pointers over alternatives when:**
- Over hash map (two-sum on unsorted): if the array is already sorted or sorting is acceptable, two pointers uses O(1) extra space vs. O(n) for the map
- Over nested loops: whenever the sorted order lets you infer that moving one pointer is strictly better than the other — the nested loop tries all pairs, two pointers skips impossible ones provably
- Over binary search (pair search): two pointers finds all valid pairs in one pass; binary search finds one pair per outer loop iteration at O(n log n) total — same asymptotic cost but two pointers has a smaller constant and simpler code

**Do not use when:**
- The array is unsorted and sorting would change the problem semantics (e.g., the problem requires original indices) → use a hash map
- The constraint is not monotone — expanding the window can both satisfy and violate it depending on values → use a hash map or prefix sums
- You need more than two interacting indices where no simple ordering argument reduces the search space → use dynamic programming or backtracking

## Time & Space Complexity

| Operation | Time | Space |
|---|---|---|
| Opposite-end pointer scan | O(n) | O(1) |
| Sorted pair / 2-Sum (after sort) | O(n log n) | O(1) extra (O(n) for Timsort) |
| 3-Sum (sort + outer loop + two-pointer) | O(n²) | O(1) extra (O(n) for Timsort) |
| k-Sum (general) | O(n^(k-1)) | O(1) extra (O(n) for Timsort) |
| Fast/slow pointer (linked list) | O(n) | O(1) |
| Subsequence check (two sequences) | O(n + m) | O(1) |

**Why O(n) time for opposite-end scan:** each pointer only moves in one direction (left pointer only increases, right pointer only decreases). Together they take at most n steps total — not n steps each — so the scan is a single linear pass regardless of how many pair checks seem to happen.

**Why O(n²) for 3-Sum:** the outer loop fixes one element in O(n) iterations; each iteration runs a full O(n) two-pointer scan. The sort at O(n log n) is dominated by the O(n²) scan. Similarly, k-Sum adds k-2 nested loops giving O(n^(k-1)).

**Why O(1) extra space:** the two indices are scalar variables. No auxiliary data structure proportional to input size is allocated by the two-pointer logic itself. Note that JavaScript's `Array.sort()` (V8 uses Timsort) uses O(n) auxiliary space internally, so the total space including the sort step is O(n).

## Key Properties

- **Requires a monotone invariant.** The reason you can move a pointer and skip candidates is that some property is guaranteed to get strictly better or worse as you move in one direction. Without this guarantee, you cannot safely discard candidates.
- **Opposite-end variant:** `left` starts at index 0, `right` at n-1. Move the pointer whose current element is "less useful" — e.g., for two-sum move the smaller value up if current sum is too low, move the larger value down if too high.
- **Same-direction (slow/fast) variant:** both pointers start at 0 (or head). The fast pointer finds candidates; the slow pointer marks the boundary of the "accepted" prefix. Used for in-place deduplication and linked list cycle detection (Floyd's algorithm).
- **Subsequence variant:** one pointer per sequence, both moving forward only. Advance the subsequence pointer only when characters match.

## Common Pitfalls

- **Forgetting to handle duplicates in 3Sum / k-Sum.** After fixing one element and using two pointers for the rest, failing to skip duplicate values of the fixed element (and of the two pointer results) causes duplicate triplets in the output. Interviewers check this explicitly.
- **Off-by-one on the convergence condition.** Using `left < right` vs. `left <= right` changes whether the middle element is processed. For palindrome checks or odd-length arrays, `left < right` is almost always correct; using `<=` processes the center element twice.
- **Moving both pointers simultaneously after a match.** In pair/triplet problems you must advance both `left` and `right` after recording a match (and skip duplicates), not just one. Moving only one misses valid pairs.
- **Applying two pointers to an unsorted input without sorting first.** The technique silently produces wrong answers on unsorted arrays — no error is thrown. Always verify or assert sorted order before using opposite-end pointers.
- **Fast/slow pointer: not handling the empty list or single-node list.** If `head` is `None` or `head.next` is `None`, dereferencing `fast.next.next` raises an exception. Always guard at the top.
- **Confusing "in-place" with "no new variables."** O(1) space means no data structures scaled to n. Two scalar pointer variables are fine and do not violate in-place constraints.

## Implementation Notes

```javascript
// ── 1. OPPOSITE-END: Two Sum II (sorted array, 1-indexed) ──────────────────
const twoSumSorted = (numbers, target) => {
    let left = 0, right = numbers.length - 1;
    while (left < right) {                    // strict <: never use same element twice
        const s = numbers[left] + numbers[right];
        if (s === target) {
            return [left + 1, right + 1];     // problem is 1-indexed
        } else if (s < target) {
            left++;                           // sum too small → increase it
        } else {
            right--;                          // sum too large → decrease it
        }
    }
    return [];                                // guaranteed to find a solution per problem
};


// ── 2. THREE SUM (sort + two pointers per fixed element) ───────────────────
// Time: O(n²)  |  Space: O(1) extra (O(n) for sort)
const threeSum = (nums) => {
    nums.sort((a, b) => a - b);               // numeric sort — bare .sort() would mangle negatives
    const result = [];
    for (let i = 0; i < nums.length - 2; i++) {
        if (i > 0 && nums[i] === nums[i - 1]) continue; // skip duplicate fixed elements
        let left = i + 1, right = nums.length - 1;
        while (left < right) {
            const s = nums[i] + nums[left] + nums[right];
            if (s === 0) {
                result.push([nums[i], nums[left], nums[right]]);
                while (left < right && nums[left] === nums[left + 1]) left++;  // skip duplicate left values
                while (left < right && nums[right] === nums[right - 1]) right--; // skip duplicate right values
                left++;                       // advance both after recording match
                right--;
            } else if (s < 0) {
                left++;
            } else {
                right--;
            }
        }
    }
    return result;
};


// ── 3. SAME-DIRECTION: remove duplicates from sorted array in-place ─────────
const removeDuplicates = (nums) => {
    if (!nums.length) return 0;
    let slow = 0;                             // slow marks end of deduplicated prefix
    for (let fast = 1; fast < nums.length; fast++) { // fast scans for new values
        if (nums[fast] !== nums[slow]) {
            slow++;
            nums[slow] = nums[fast];          // write new unique value into place
        }
    }
    return slow + 1;                          // length of deduplicated prefix
};


// ── 4. FAST/SLOW: detect cycle in linked list (Floyd's algorithm) ───────────
class ListNode {
    constructor(val, next = null) {
        this.val = val;
        this.next = next;
    }
}

const hasCycle = (head) => {
    let slow = head, fast = head;
    while (fast && fast.next) {               // fast exhausts the list if no cycle
        slow = slow.next;
        fast = fast.next.next;                // fast moves 2 steps, slow moves 1
        if (slow === fast) return true;       // they meet only inside a cycle
    }
    return false;
};


// ── 5. SUBSEQUENCE CHECK ────────────────────────────────────────────────────
const isSubsequence = (s, t) => {
    let i = 0;                                // pointer into s (the subsequence)
    for (const ch of t) {                     // iterate t with implicit pointer
        if (i < s.length && ch === s[i]) {
            i++;                              // advance s pointer only on match
        }
    }
    return i === s.length;
};
```

## Variants

- **Sliding Window** — same-direction two pointers where you also maintain aggregate state (sum, count, frequency map) of the window between the pointers. Use when the problem asks for a contiguous subarray optimizing a value under a constraint.
- **Three Pointers** — one fixed outer loop + two-pointer inner search, as in 3Sum (O(n²)). Extends to k-Sum with k-2 nested loops and two-pointer innermost (O(n^(k-1))).
- **Floyd's Cycle Detection (Tortoise and Hare)** — fast/slow applied to linked lists and functional graphs. After detecting a cycle, a second phase finds the cycle entrance.
- **Dutch National Flag (3-way partition)** — three pointers: `low`, `mid`, `high` partition an array into three regions in one pass. Used in sort colors / quicksort partition.

## Resources

- Neetcode Two Pointers playlist: https://neetcode.io/roadmap (Two Pointers section)
- LeetCode tag: https://leetcode.com/tag/two-pointers/
- *Grokking Algorithms* ch. 4 (quicksort partition) — Dutch National Flag variant

## Related

- [[sliding-window]]
- [[fast-slow-pointers]]
- [[sorting]]
- [[binary-search]]
