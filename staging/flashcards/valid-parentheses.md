---
id: 3182bfee-72aa-4d9a-bce7-0e0fcee5a743
type: interview-question
category: coding
difficulty: easy
frequency: high
domains: [ds-a]
tiers:
  ds-a: 1
concepts:
  - stack
source: blind-75
practice_url: https://neetcode.io/problems/validate-parentheses
created: 2026-08-20
confidence: high
---

# Valid Parentheses

Given a string `s` containing only the characters `'('`, `')'`, `'{'`, `'}'`, `'['`, and `']'`, determine if the input string is valid. A string is valid if every open bracket is closed by the same type of bracket in the correct order, and every close bracket has a corresponding open bracket.

Constraints: `1 <= s.length <= 10^4`, `s` consists of bracket characters only.

## Approach

**Pattern:** Stack matching

**Key insight:** Every closing bracket must match the *most recently seen* unmatched opening bracket — and only that one. This last-in, first-out requirement is the precise definition of a stack. You don't need to track all unmatched opens at once; you only ever need to check the top. If the top doesn't match the current closer, or the stack is empty when a closer arrives, the string is invalid. After processing all characters, a valid string leaves the stack empty.

**Recognition signals:**
- The problem involves nested or paired delimiters that must close in reverse order of opening
- "Balanced" or "valid" appears in the problem name alongside bracket/parenthesis characters
- The constraint that inner pairs must close before outer pairs implies LIFO ordering

```javascript
function isValid(s) {
  const stack = [];
  // Map each closer to its expected opener for O(1) lookup
  const match = { ')': '(', '}': '{', ']': '[' };

  for (const ch of s) {
    if (!(ch in match)) {
      // It's an opener — push and wait for its corresponding closer
      stack.push(ch);
    } else {
      // It's a closer — the top of the stack must be its pair
      if (stack.pop() !== match[ch]) return false;
    }
  }

  // Any leftover openers mean unmatched brackets remain
  return stack.length === 0;
}
```

## Complexity

Time: O(n) — each character is pushed or popped at most once across a single pass.
Space: O(n) — in the worst case (all openers, e.g. `"(((("`), the stack holds every character.

## Follow-up Questions

- **What if the string can also contain non-bracket characters?** → Skip non-bracket characters in the loop; the core stack logic is unchanged.
- **How would you find the index of the first invalid character?** → Track the current index alongside the character; return the index where the mismatch or empty-stack condition fires.
- **Can you solve this without a stack?** → Only for a single bracket type — use a counter that increments on open and decrements on close, returning false if it ever goes negative. For mixed bracket types, a stack is required to remember *which* opener is pending.
- **How would you handle an extremely long string efficiently?** → Early exit on `stack.length === 0` when a closer arrives (already done above); no further optimization is possible since every character must be inspected at least once.

## Resources

- NeetCode: https://neetcode.io/problems/validate-parentheses
- LeetCode #20: https://leetcode.com/problems/valid-parentheses/

## Related Concepts

- [[stack]]
