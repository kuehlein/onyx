---
id: 15e55c1f-9268-4f94-bd35-8b5cfa699a83
type: flashcard
tags:
  - ds-a
  - hash-map
  - data-structures
tiers:
  ds-a: 1
created: 2026-08-19
confidence: medium
---

# Hash Map

A hash map stores key-value pairs by running each key through a hash function to compute a bucket index, collapsing arbitrary-key lookups to an expected O(1) operation — the hash function distributes keys so that retrieval requires examining at most a constant number of entries per bucket on average.

## When to Use

**Problem signals that suggest a hash map:**
- "Find if a value exists / has been seen before" — any membership or deduplication problem over a stream or list
- "Count the frequency / occurrences of each element" — words, characters, numbers, anything countable
- "Find two elements that sum / differ / combine to a target" — signals a complement lookup (`target - x`)
- "Group elements by a property" — anagram grouping, bucketing by remainder, grouping by sorted key
- "Cache previously computed results during traversal" — memoization tables, visited-node sets
- Constraints contain phrases like "return indices," "return the pair," or "at most one duplicate" — the answer requires pairing an element with metadata (its index, count, etc.)
- Input is unsorted and sorting would cost O(n log n); a hash map recovers O(n)

**Prefer a hash map over alternatives when:**
- Over a sorted array + binary search: when you need true O(1) lookup and insertion, not O(log n); use sorted array when order or range queries matter
- Over a set: when you need to store a value alongside each key (index, count, list of elements), not just membership
- Over a list scan: any time "does X exist?" is asked more than once — a list scan is O(n) per query; a hash map amortizes to O(1)
- Over a trie: when keys are arbitrary hashable types, not only strings with shared-prefix queries

**Do not use when:**
- You need **sorted** key iteration → JS has no built-in sorted map; sort `[...map.entries()]` on demand or use a BST
- You need range queries ("all keys between A and B") → use a BST or segment tree
- You need JSON serialization of the map → plain object `{}` serializes with `JSON.stringify`; `Map` does not
- Worst-case guarantees are required and hash collisions are adversarially controlled → use a tree map (O(log n) guaranteed, no built-in in JS)

## Time & Space Complexity

| Operation | Average | Worst Case |
|-----------|---------|------------|
| Insert    | O(1)    | O(n)       |
| Lookup    | O(1)    | O(n)       |
| Delete    | O(1)    | O(n)       |
| Iteration | O(n)    | O(n)       |

**Why average O(1):** A good hash function spreads n keys across k buckets uniformly. With a load factor α = n/k kept below a constant (V8 rehashes around 0.5–0.75 depending on key type), the expected number of keys per bucket is O(1), so each lookup inspects O(1) entries.

**Why worst O(n):** All n keys can hash to the same bucket (deliberate collision attack or a pathological hash function), degrading each lookup to a linear scan of that bucket's chain.

**Space:** O(n) — one slot (or chain node) per stored key-value pair, plus O(k) for the bucket array; since k = O(n) after resizing, total space is O(n).

## Key Properties

- **`Map` vs plain object `{}`:** `Map` accepts any value as a key (objects, numbers, `NaN`, `undefined`) using SameValueZero equality (like `===` but `NaN === NaN`). Plain objects coerce all keys to strings — `obj[1]` and `obj["1"]` are the same key.
- **Insertion-order preservation:** `Map` iteration order is guaranteed to match insertion order (ES2015+). Plain objects guarantee this for string keys in modern engines but not for numeric keys (they sort numerically first).
- **Load factor and rehashing:** when stored entries exceed a threshold relative to bucket count, the engine rehashes into a larger table. Each insertion is O(1) *amortized* — rehashing cost is spread over prior cheap insertions.
- **`map.size` not `.length`:** `map.size` returns the number of entries. `map.length` is `undefined`.
- **Object keys by reference:** when using objects as `Map` keys, equality is by reference identity — two `{a: 1}` literals are different keys. Use primitives (strings, numbers) when you want value-based keying.

## Common Pitfalls

1. **Using `{}` when keys aren't strings.** `{}["1"]` and `{}[1]` are the same slot — numeric keys are coerced to strings. If keys are non-strings (numbers, objects), use `Map`.

2. **Checking `map.get(k)` truthiness when `0`, `""`, or `false` are valid values.** `if (map.get(k))` is wrong when the stored value is falsy. Use `map.has(k)` to check existence, then `map.get(k)` to retrieve.

3. **Off-by-one in complement lookups.** In Two Sum, check `seen.has(complement)` *before* inserting the current element. Inserting first allows self-pairing when `target === 2 * x` and the element appears only once.

> [!warning] Check membership with `.has()`, not truthiness
> `if (map.get(k))` is wrong when the stored value can be `0`, `""`, or `false`. Use `map.has(k)` to test existence, then `map.get(k)`. Same trap: use `map.size`, never `map.length` (`undefined`).

4. **Forgetting `map.size` — using `.length` instead.** `map.length` is `undefined`, which is always falsy. Size checks will silently return wrong results. Always use `map.size`.

5. **Object keys compared by reference.** `map.set({a:1}, 'x'); map.get({a:1})` returns `undefined` — the second `{a:1}` is a different object. If you need value-based keying on objects, serialize to a string key: `JSON.stringify(obj)`.

6. **Iterating and modifying simultaneously.** Adding entries during `for (const [k, v] of map)` is defined but newly-added keys may or may not be visited depending on insertion position. Deleting the current key is safe; deleting others may cause skips. Safest: collect mutations and apply after the loop.

## Implementation Notes

```js
// --- Pattern 1: frequency count ---
const charFrequency = (s) => {
  const freq = new Map();
  for (const ch of s) {
    freq.set(ch, (freq.get(ch) ?? 0) + 1); // ?? 0 avoids undefined + 1 when key is absent
  }
  return freq;
};


// --- Pattern 2: Two Sum (complement lookup) ---
const twoSum = (nums, target) => {
  const seen = new Map(); // value -> index
  for (let i = 0; i < nums.length; i++) {
    const x = nums[i];
    const complement = target - x;
    if (seen.has(complement)) {       // O(1) lookup
      return [seen.get(complement), i];
    }
    seen.set(x, i);                   // insert AFTER lookup to avoid self-pairing
  }
  return [];
};


// --- Pattern 3: grouping (anagrams) ---
const groupAnagrams = (words) => {
  const groups = new Map();
  for (const w of words) {
    const key = w.split('').sort().join(''); // sorted string is a valid Map key; array is not
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(w);
  }
  return [...groups.values()];
};


// --- Pattern 4: memoization cache ---
const fib = (n, memo = new Map()) => {
  if (memo.has(n)) return memo.get(n);
  if (n <= 1) return n;
  const result = fib(n - 1, memo) + fib(n - 2, memo);
  memo.set(n, result); // cache before returning so repeated calls short-circuit
  return result;
  // Prefer a top-level Map closed over by the function in production; explicit param for interview clarity
};


// --- Common Map idioms ---
// new Map()                          → empty map (counters, grouping, adjacency lists)
// map.get(k) ?? 0                    → default 0 for missing keys (counters)
// map.set(k, [...(map.get(k) ?? []), v]) → append to a grouped list (or use the has/get/push pattern above)
const adj = new Map(); // adjacency list: node -> neighbors
const addEdge = (u, v) => {
  if (!adj.has(u)) adj.set(u, []);
  adj.get(u).push(v); // no key-absent error because we initialise above
};
addEdge(0, 1);
```

## Variants

- **Plain object `{}`** — simpler than `Map` when keys are always strings or symbols and you need JSON serialization. Avoid for numeric or object keys.
- **`Set`** — `Map` without values; O(1) membership testing and deduplication. Use `new Set(arr)` to deduplicate an array.
- **`WeakMap`** — keys must be objects; does not prevent garbage collection of keys. Used for caching computed values on DOM nodes or objects without memory leaks.
- **LRU Cache (Map trick)** — `Map` preserves insertion order; implement LRU by deleting and re-inserting on access (moves to end), evicting with `map.keys().next().value` (the oldest key).
- **Bidirectional map** — two `Map`s (`key→val` and `val→key`) for O(1) lookup in both directions; used in problems requiring inverse mapping (e.g., encode/decode).
- **Frequency counter pattern** — `map.set(k, (map.get(k) ?? 0) + 1)` is the idiomatic JS counter; no special class needed.

## Resources

- MDN — `Map`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Map
- MDN — Map vs Object: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Map#objects_vs_maps

## Related

- [[hash-set]]
- [[two-pointers]]
- [[sliding-window]]
- [[dynamic-programming]]
