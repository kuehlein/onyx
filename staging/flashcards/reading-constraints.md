---
id: a3f1d8c2-7b4e-4a91-9c3d-2e8f05b6a174
type: flashcard
tags:
  - ds-a
  - interview-meta
  - big-o
  - time-complexity
tiers:
  ds-a: 0
created: 2026-08-19
confidence: high
priority: high
---

# Reading Constraints → Required Complexity

Before writing any code, read the input size constraint. The value of n directly
tells you what complexity class your solution must achieve. This is how
experienced engineers immediately rule out approaches before touching code.

**The rule of thumb:** most judge systems and interview mental models allow
~10⁸ simple operations per second. Work backwards from n to the required
complexity.

> [!tip] Read n first
> Before touching code, read the input constraint and work backwards from ~10⁸ ops/sec. n tells you which complexity classes are ruled out — this is how experienced engineers eliminate approaches instantly.

## Constraint → Complexity Table

| Input size n | Required complexity | Typical approaches |
|---|---|---|
| n ≤ 10^18 | O(log n) or O(1) | Binary search on answer space, closed-form math |
| n ≤ 10^12–10^14 | O(√n) | Trial division for primality, counting divisors, sqrt decomposition |
| n ≤ 10^8–10^9 | O(n) | Linear scan, two pointers, sliding window, hash map |
| n ≤ 10^6–10^7 | O(n) to O(n log n) | Sort, [BFS](_meta/glossary.md#bfs)/[DFS](_meta/glossary.md#dfs), monotonic stack |
| n ≤ 10^4–10^5 | O(n log n) | Sort + binary search, heap |
| n ≤ 10^3–10^4 | O(n²) | Nested loops, 2D [DP](_meta/glossary.md#dp) |
| n ≤ 200–500 | O(n³) | 3D DP, Floyd-Warshall |
| n ≤ 20–25 | O(2^n) | Bitmask DP, backtracking |
| n ≤ 12–15 | O(n!) or O(n·2^n) | Permutations, [TSP](_meta/glossary.md#tsp)-style DP |

## Key Properties

- **Why 10^8:** a single loop iteration doing simple arithmetic takes roughly
  1–10 ns; 10^8 iterations ≈ 0.1–1 second. Constants vary by language and
  operation, but the order of magnitude holds for ruling things in or out.
- **It's a filter, not a prescription:** the table tells you what is *too slow*,
  not necessarily what to use. n ≤ 10^5 rules out O(n²); it doesn't tell you
  whether to sort or BFS.
- **Multiple constraint variables:** if both n and m appear (e.g., n × m matrix),
  the required complexity is usually O(n·m) or O(n·m·log(n·m)) — treat the
  product as the effective input size.
- **Space constraints:** most problems allow O(n) space. O(n²) space (e.g., a
  full n × n matrix) becomes tight at n ≈ 10^4.

## Common Pitfalls

- **n ≤ 10^5 with an O(n²) solution:** 10^10 operations → [TLE](_meta/glossary.md#tle). If you find
  yourself writing nested loops over the full array, check the constraint first.
- **Ignoring hidden O(n) inside a loop:** a loop that calls a library sort or
  string copy inside it is O(n²), not O(n). Every inner operation counts.
- **Assuming recursion is O(1) space:** DFS on n = 10^5 nodes is O(n) stack
  space (fine). Naive exponential recursion without memoization is O(2^n) stack
  frames (not fine).

## Implementation Notes

When you see the constraint in an interview, say it aloud before proposing
anything:

> "n can be up to 10^5, so I need O(n log n) or better — nested loops won't
> work. I'm thinking sort-based or a hash map."

This is a senior-level signal. It shows you think about feasibility before
committing to an approach.

## Resources

- NeetCode roadmap — complexity discussion: https://neetcode.io/roadmap

## Related

- [[interview-vocabulary]]
- [[big-o-notation]]
- [[binary-search]]
- [[dynamic-programming]]
