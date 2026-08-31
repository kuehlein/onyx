---
id: 3a7f2c91-e845-4b8a-9d63-f1c058e72a04
type: flashcard
tags:
  - ds-a
  - string
  - array
  - two-pointers
tiers:
  ds-a: 1
created: 2026-08-19
confidence: low
priority: normal
---

# String Manipulation Patterns

Strings are arrays of characters, so nearly every array technique applies — but strings add immutability constraints (in Python/Java) and character-frequency semantics that shift which patterns dominate. The central insight is that most string problems reduce to one of four operations: scanning with two pointers, tracking character counts in a fixed-size (O(26)) hash map, building a result incrementally with a stack, or exploiting a sorted/canonical form to group anagrams and detect permutations.

## When to Use

**Problem signals that suggest string manipulation patterns:**

Two-pointer / sliding window:
- "Find the longest substring with at most K distinct characters"
- "Find the smallest window containing all characters of T"
- "Check if a string is a palindrome" or "find the longest palindromic substring"
- Constraints mention contiguous subarray/substring — the window slides, never resets from scratch

Character frequency / counting:
- "Determine if one string is an anagram/permutation of another"
- "Find all anagrams of P in S" — fixed-length window with frequency comparison
- "Group anagrams" — canonical form (sorted string or frequency tuple) as hash key
- Problem involves a character set ≤ 26 — the map is O(1) space by domain bound

Stack-based construction:
- "Remove all adjacent duplicates" or "remove K adjacent duplicates"
- "Decode string" with nested brackets (e.g., `3[a2[bc]]`)
- "Evaluate expression" or "simplify path" — stack mirrors the call depth

In-place reversal / rotation:
- "Rotate string by K positions" — reverse whole, then reverse first K chars, then reverse the remainder
- "Reverse words in a string in-place" — reverse entire string, then reverse each word individually

**Prefer string-specific patterns over alternatives when:**
- Over generic [DFS](_meta/glossary.md#dfs)/[BFS](_meta/glossary.md#bfs): character-frequency problems have O(26) state, making an explicit graph unnecessary — a fixed-size array/map suffices
- Over [DP](_meta/glossary.md#dp) for anagram detection: sorting or frequency count is O(n) or O(n log n) vs. O(n²) DP; use DP only when you need edit distance or longest common subsequence
- Over brute-force O(n²) substring search: sliding window reduces to O(n) by maintaining a running invariant rather than recomputing from scratch

**Do not use when:**
- You need substring *position* with overlap → use [KMP](_meta/glossary.md#kmp) or Rabin-Karp instead of naive sliding window
- The alphabet is unbounded (e.g., Unicode code points in the millions) → fixed-size array trick breaks; use a general hash map and note the space cost
- The problem asks for *edit distance* or *longest common subsequence* → two-pointer/frequency won't work; reach for DP

## Time & Space Complexity

| Pattern | Time | Space | Why |
|---|---|---|---|
| Two-pointer palindrome check | O(n) | O(1) | Each pointer moves at most n/2 steps total; no auxiliary storage |
| Sliding window (at most K distinct) | O(n) | O(K) | Left and right pointers each advance at most n times; window map holds ≤ K+1 entries at once |
| Minimum window substring | O(n + m) | O(m) | One pass over S with two pointers; map stores only chars of T (size m) |
| Anagram detection (sort) | O(n log n) | O(n) | Sorting dominates; sorted copy is the only extra allocation |
| Anagram detection (frequency) | O(n) | O(1) | Single pass; map bounded by alphabet size (26) regardless of n |
| Group anagrams | O(n · k log k) | O(n · k) | Each of n strings is sorted in O(k log k); all strings stored in output groups |
| Stack-based decode string | O(n) | O(n) | Each character pushed/popped once; stack depth proportional to nesting, worst case n |
| Triple-reverse rotation | O(n) | O(1) | Three linear passes; reversal is done in-place with pointer swap |

## Key Properties

> [!tip] Fixed-alphabet trick
> Character set ≤ 26? Swap the hash map for an `int[26]` indexed by `ord(c) - ord('a')`. Space becomes provably **O(1)** (constant, doesn't grow with n) and indexing is faster — the go-to for anagram/frequency problems.

**The fixed-alphabet trick.** When the character set is exactly lowercase ASCII (26 chars), replace `dict` with `int[26]`. Array indexing is faster in practice and the space is provably O(1) — the constant never grows with input size. Use `ord(c) - ord('a')` as the index.

**Canonical form for grouping.** Two strings are anagrams iff they have the same canonical form. Two canonical forms work:
1. Sorted string: `''.join(sorted(s))` — simple but O(k log k) per string
2. Frequency tuple: `tuple(freq_array)` — O(k) per string, hashable, preferred at scale

**Sliding window invariant.** Every sliding window problem has an invariant (e.g., "window contains all chars of T", "window has ≤ K distinct chars"). The right pointer expands to try to satisfy it; the left pointer contracts to restore it when violated. Maintaining the invariant incrementally rather than recomputing it is what gives O(n).

**String immutability in Python.** `s[i] = c` raises `TypeError`. To mutate, convert with `list(s)` first, then `''.join(result)` at the end. Every `s = s + c` in a loop is O(n²) — use `list` + `append` instead.

## Common Pitfalls

**Off-by-one in window shrinkage.** A common interview mistake: shrinking the window before updating the "best" result, or vice versa. The rule: record the result *before* shrinking when you want the largest valid window; record *after* shrinking when you want the smallest.

**Forgetting to handle the empty-string edge case.** Functions like `min()` on an empty collection crash; `s[0]` on an empty string raises `IndexError`. Interviewers frequently pass `""` as the first test. Guard at the top: `if not s: return ...`.

**Two-pointer palindrome with non-alphanumeric characters.** The classic "valid palindrome" problem filters non-alphanumeric chars. Candidates often forget `.isalnum()` and `.lower()` must both be applied, or they strip the string upfront (allocating O(n) extra space) when the two-pointer skip approach is O(1) space.

**Mutating the frequency map before checking the window condition.** In minimum-window substring, candidates decrement the count for a char in T before checking if the window is valid. The correct order: update the map, then check if the count for that char just dropped to zero (meaning T's requirement for that char is newly satisfied), then increment `formed`.

**Returning the wrong type.** Python `sorted(s)` returns `list`, not `str`. Using a sorted list as a dict key raises `TypeError` — it must be `tuple(sorted(s))` or `''.join(sorted(s))`. Interviewers spot this when you run the code.

**Assuming O(1) string concatenation.** In Python and Java, `result += char` in a loop is O(n²) total because each concatenation copies the entire string. Use `list` + `''.join` in Python, or `StringBuilder` in Java.

## Implementation Notes

```javascript
// ── Pattern 1: Minimum Window Substring (hard, high-frequency) ──────────────

function minWindow(s, t) {
  if (!s || !t) return "";

  const need = new Map();          // chars we still need, with required counts
  for (const c of t) need.set(c, (need.get(c) ?? 0) + 1);

  const have = new Map();          // chars currently in window
  let formed = 0;                  // how many chars in `need` are fully satisfied
  const required = need.size;      // total distinct chars that must be satisfied

  let left = 0;
  let bestLen = Infinity, bestL = 0, bestR = 0;  // track best window boundaries

  for (let right = 0; right < s.length; right++) {
    const c = s[right];
    have.set(c, (have.get(c) ?? 0) + 1);
    // Only increment `formed` when we EXACTLY meet the requirement
    // (not on every increment — avoids double-counting)
    if (need.has(c) && have.get(c) === need.get(c)) formed++;

    // Shrink from left while the window is valid
    while (formed === required) {
      // Record best before shrinking
      if (right - left + 1 < bestLen) {
        bestLen = right - left + 1;
        bestL = left;
        bestR = right;
      }

      const lc = s[left];
      have.set(lc, have.get(lc) - 1);
      // Dropping below the required count breaks the invariant
      if (need.has(lc) && have.get(lc) < need.get(lc)) formed--;
      left++;
    }
  }

  return bestLen === Infinity ? "" : s.slice(bestL, bestR + 1);
}


// ── Pattern 2: Group Anagrams (frequency-array canonical form) ───────────────
function groupAnagrams(strs) {
  const groups = new Map();
  for (const s of strs) {
    const freq = new Array(26).fill(0);
    for (const c of s) {
      freq[c.charCodeAt(0) - 97]++;   // O(1) space: fixed alphabet (97 = 'a')
    }
    const key = freq.join(",");        // join to string so Map uses value equality
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(s);
  }
  return [...groups.values()];
}


// ── Pattern 3: Longest Substring with At Most K Distinct Chars ───────────────
function longestKDistinct(s, k) {
  if (k === 0) return 0;
  const window = new Map();
  let left = 0;
  let best = 0;
  for (let right = 0; right < s.length; right++) {
    const c = s[right];
    window.set(c, (window.get(c) ?? 0) + 1);
    // Shrink until we have at most k distinct chars
    while (window.size > k) {
      const lc = s[left];
      window.set(lc, window.get(lc) - 1);
      if (window.get(lc) === 0) window.delete(lc);  // remove key to keep window.size accurate
      left++;
    }
    best = Math.max(best, right - left + 1);
  }
  return best;
}


// ── Pattern 4: Valid Palindrome (two-pointer, O(1) space) ────────────────────
function isPalindrome(s) {
  // Helper: check if char is alphanumeric without allocating a filtered copy
  const isAlnum = c => /[a-zA-Z0-9]/.test(c);
  let lo = 0, hi = s.length - 1;
  while (lo < hi) {
    // Skip non-alphanumeric from both ends before comparing
    while (lo < hi && !isAlnum(s[lo])) lo++;
    while (lo < hi && !isAlnum(s[hi])) hi--;
    if (s[lo].toLowerCase() !== s[hi].toLowerCase()) return false;
    lo++;
    hi--;
  }
  return true;
}


// ── Pattern 5: Decode String  e.g. "3[a2[bc]]" → "abcbcabcbcabcbc" ──────────
function decodeString(s) {
  const stack = [];    // each frame: [repeatCount, builtStringSoFar]
  let currStr = "";
  let currNum = 0;
  for (const c of s) {
    if (c >= "0" && c <= "9") {
      currNum = currNum * 10 + Number(c);   // handles multi-digit numbers
    } else if (c === "[") {
      stack.push([currNum, currStr]);        // push frame
      currStr = "";
      currNum = 0;
    } else if (c === "]") {
      const [repeat, prev] = stack.pop();
      currStr = prev + currStr.repeat(repeat);  // restore outer context
    } else {
      currStr += c;
    }
  }
  return currStr;
}
```

## Variants

**Palindrome variants.** Longest palindromic substring: expand-around-center in O(n²) time and O(1) space, or Manacher's algorithm in O(n) time and O(n) space. Palindrome partitioning: DP + DFS.

**Sliding window with replacement.** "Longest repeating character replacement" (LC 424): track the count of the *most frequent* char in the window; if `window_size - max_freq > k`, shrink. The max_freq variable never needs to decrease (monotonic trick).

**Trie for multi-string problems.** When the problem involves a *set* of strings (autocomplete, word search, longest word in dictionary), a trie over the character set is more efficient than repeated hash lookups.

**Rolling hash (Rabin-Karp).** For substring search with exact match or repeated pattern detection (LC 1044 Longest Duplicate Substring), rolling hash gives O(n) average time by hashing the window and updating in O(1) per step.

## Resources

- Neetcode.io — "Sliding Window" and "Two Pointers" playlists
- LeetCode Patterns: [https://seanprashad.com/leetcode-patterns/](https://seanprashad.com/leetcode-patterns/)
- *Elements of Programming Interviews* — Chapter 6 (Strings)
- CPython `str` source: [https://github.com/python/cpython/blob/main/Objects/unicodeobject.c](https://github.com/python/cpython/blob/main/Objects/unicodeobject.c)

## Related

- [[sliding-window]]
- [[two-pointers]]
- [[hash-map-and-hash-set]]
- [[trie]]
- [[dynamic-programming-on-strings]]
