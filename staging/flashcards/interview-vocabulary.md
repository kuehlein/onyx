---
id: c7e2a91b-4d83-4f05-8b6e-1a3c9d7f2e50
type: flashcard
tags:
  - ds-a
  - interview-meta
tiers:
  ds-a: 0
created: 2026-08-19
confidence: high
---

# Interview & Competitive Programming Vocabulary

Terms you'll encounter in problem descriptions, editorial discussions, and
interview feedback that may not appear in day-to-day engineering work.

## Judge Verdicts

| Term | Meaning |
|---|---|
| **AC** (Accepted) | Correct output, within time and memory limits |
| **TLE** (Time Limit Exceeded) | Solution is too slow — wrong complexity class |
| **MLE** (Memory Limit Exceeded) | Too much memory — reduce space complexity |
| **WA** (Wrong Answer) | Output is incorrect — logic error, edge case missed |
| **RE** (Runtime Error) | Crash at runtime — null pointer, index out of bounds, infinite recursion causing stack overflow |
| **OLE** (Output Limit Exceeded) | Printed far too much — usually an infinite loop with a print inside |

## Complexity Terms

| Term | Meaning |
|---|---|
| **Amortized O(1)** | Occasionally costs more (e.g., O(n) to resize), but averages O(1) per operation over many calls. Dynamic array `append` is amortized O(1). |
| **In-place** | Modifies the input directly; uses O(1) *auxiliary* space (extra space beyond the input itself) |
| **Auxiliary space** | Extra memory allocated beyond the input — what "space complexity" measures in interview context |
| **Bottleneck** | The step that dominates total complexity; optimizing anything else is wasted effort |
| **Monotonic** | Strictly non-decreasing or non-increasing. A property exploited by two pointers and sliding window to safely discard candidates |
| **Invariant** | A condition that remains true throughout an algorithm. Maintaining and proving invariants is how you verify correctness |
| **Reduction** | Solving problem A by transforming it into problem B (e.g., reducing 3-Sum to repeated 2-Sum) |
| **Trade-off** | Exchanging one resource for another. The classic: O(n) extra space in a hash map to achieve O(1) lookup instead of O(n) linear scan |
| **Stable sort** | Preserves the relative order of equal elements. Merge sort is stable; most quicksort implementations are not |
| **Sentinel** | A special boundary value (∞, -1, None, dummy node) that simplifies edge cases by eliminating special-case branches |

## DP (Dynamic Programming) Vocabulary

| Term | Meaning |
|---|---|
| **Memoization** | Top-down DP: cache results of recursive calls to avoid recomputation |
| **Tabulation** | Bottom-up DP: fill a table iteratively from base cases upward |
| **Optimal substructure** | The optimal solution to the problem contains optimal solutions to its subproblems — prerequisite for DP |
| **Overlapping subproblems** | The same subproblem is solved multiple times in naive recursion — prerequisite for DP |
| **State** | The set of variables that uniquely identifies a DP subproblem (e.g., `(i, remaining_capacity)`) |

## Interview Process Terms

| Term | Meaning |
|---|---|
| **Brute force** | The naive solution that tries all possibilities; establish this first, then optimize |
| **Edge case** | Input at the boundary of validity: empty input, single element, all duplicates, maximum n, negative numbers |
| **Optimal** | The best possible complexity class for this problem. Once you're at optimal, stop — further micro-optimization is not the point |
| **Clarifying question** | A question asked before coding to resolve ambiguity: "Can the input contain duplicates?" "Should the result be sorted?" |

## Resources

- NeetCode roadmap: https://neetcode.io/roadmap

## Related

- [[reading-constraints]]
- [[big-o-notation]]
