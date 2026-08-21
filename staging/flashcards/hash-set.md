---
id: 7f3a1c2e-84b5-4d9f-a031-6e2c5b8d0f47
type: flashcard
tags:
  - ds-a
  - hash-set
  - data-structures
tiers:
  ds-a: 2
created: 2026-08-20
confidence: medium
---

# Hash Set

A hash set stores an unordered collection of unique values with O(1) average-case lookup, insertion, and deletion by mapping each element through a hash function to a bucket index — collisions are handled by chaining or open addressing, but with a good hash function and load factor control, constant-time access holds in practice.

## When to Use

**Problem signals that suggest Hash Set:**
- "Find duplicates," "check if already seen," or "detect a cycle" — you need membership testing over a stream of elements
- "Return unique elements" or "remove duplicates" from an array or sequence
- Two-array intersection or difference problems: "elements in A but not B"
- "Does X exist in the collection?" asked repeatedly — linear scan would be O(n) per query
- Cycle detection in linked lists or graphs (track visited nodes)
- Sliding window problems where you need to know if a new element already appears in the current window
- "Find the element that appears only once" — XOR works too, but a set generalizes to k-unique variants

**Prefer Hash Set over alternatives when:**
- Over sorted array + binary search: when you need O(1) vs O(log n) lookup and insertion order does not matter
- Over Array.includes(): when the collection is large — `.includes()` is O(n) per call, Set is O(1)
- Over Bit vector: when values are not dense integers in a known small range (bit vectors require domain knowledge)
- Over Bloom filter: when false positives are unacceptable (Set gives exact answers)

**Do not use when:**
- You need to count occurrences → use a `Map` (hash map) instead
- You need sorted iteration or range queries → use a sorted structure (BST, sorted array) instead
- You need to find the k-th smallest/largest element → use a heap or sorted structure instead
- Values are large objects you need to associate data with → use a `Map` instead

## Key Properties

| Property | Value |
|---|---|
| Lookup (average) | O(1) |
| Insert (average) | O(1) |
| Delete (average) | O(1) |
| Lookup (worst case) | O(n) — all keys collide into one bucket |
| Space | O(n) |
| Ordering | None (insertion order preserved in JS `Set`, but not guaranteed by spec for all engines) |
| Duplicates | Not stored — adding an existing value is a no-op |

JS `Set` uses SameValueZero equality: `NaN === NaN` is true in a Set (unlike `===`), and `-0` and `+0` are treated as equal.

## Time & Space Complexity

**Why O(1) average?**
The hash function maps each value to a bucket index in O(1). With a load factor kept below a threshold (e.g., 0.75), the expected chain length per bucket is O(1), so lookup walks a constant-length chain on average.

**Why O(n) worst case?**
A pathological hash function (or deliberate hash-flooding attack) can map all n elements to the same bucket, degrading every operation to a linked-list scan — O(n).

**Space:** O(n) — one entry per unique element, plus bucket array overhead proportional to capacity.

## Common Pitfalls

- **Object identity vs. value equality:** JS `Set` uses reference equality for objects. `new Set([{a:1}, {a:1}])` has size 2, not 1. Serialize to a primitive key (e.g., JSON string) if you need structural equality.
- **Mutating elements after insertion:** If you store objects and mutate them, the set's internal state becomes inconsistent. Treat stored objects as immutable.
- **Assuming sorted output:** `Set` preserves insertion order in modern JS engines, but this is an implementation detail for primitive values — do not rely on it for sorted output.
- **Using `==` to check membership:** Always use `.has()`, never array-style checking; `set == value` does nothing useful.
- **NaN handling surprise:** `set.has(NaN)` returns true after `set.add(NaN)` — unlike `NaN !== NaN` in regular JS equality.

## Implementation Notes

```javascript
// --- Basic API ---
const seen = new Set();

seen.add(1);          // insert
seen.add(2);
seen.add(1);          // no-op — already present
seen.has(1);          // true  — O(1) lookup
seen.has(3);          // false
seen.delete(2);       // remove
seen.size;            // 1

// --- Pattern: Deduplicate an array ---
const unique = [...new Set([1, 2, 2, 3, 3, 3])];
// [1, 2, 3]

// --- Pattern: Two-sum (check complement existence) ---
function twoSum(nums, target) {
  const seen = new Set();
  for (const n of nums) {
    if (seen.has(target - n)) return true;
    seen.add(n);
  }
  return false;
}

// --- Pattern: Longest consecutive sequence (LC 128) ---
// Key insight: only start counting from the beginning of a streak
// (i.e., when num-1 is NOT in the set), avoiding O(n^2) nested loops.
function longestConsecutive(nums) {
  const numSet = new Set(nums);
  let best = 0;

  for (const n of numSet) {
    if (!numSet.has(n - 1)) {   // n is the start of a streak
      let cur = n, streak = 1;
      while (numSet.has(cur + 1)) { cur++; streak++; }
      best = Math.max(best, streak);
    }
  }
  return best;
}
// Time: O(n) — each element is visited at most twice (outer loop + inner while)
// Space: O(n)

// --- Pattern: Cycle detection in a linked list (Floyd's is O(1) space,
//     but set approach is intuitive and worth knowing) ---
function hasCycle(head) {
  const visited = new Set();
  let cur = head;
  while (cur) {
    if (visited.has(cur)) return true;
    visited.add(cur);
    cur = cur.next;
  }
  return false;
}

// --- Pattern: Graph visited tracking (BFS) ---
function bfs(graph, start) {
  const visited = new Set([start]);
  const queue = [start];
  while (queue.length) {
    const node = queue.shift();
    for (const neighbor of (graph.get(node) ?? [])) {
      if (!visited.has(neighbor)) {
        visited.add(neighbor);   // mark before enqueue to avoid duplicate processing
        queue.push(neighbor);
      }
    }
  }
}

// --- Pattern: Set intersection / difference ---
const a = new Set([1, 2, 3, 4]);
const b = new Set([3, 4, 5, 6]);

const intersection = new Set([...a].filter(x => b.has(x))); // {3, 4}
const difference   = new Set([...a].filter(x => !b.has(x))); // {1, 2}
const union        = new Set([...a, ...b]);                   // {1,2,3,4,5,6}

// --- Pattern: Structural equality for objects (serialize to string key) ---
const coordSet = new Set();
const addCoord = (r, c) => coordSet.add(`${r},${c}`);
const hasCoord = (r, c) => coordSet.has(`${r},${c}`);
// Trade-off: O(k) string construction per op where k = key length
```

## Trade-offs

| Scenario | Hash Set | Sorted Array | BST (balanced) |
|---|---|---|---|
| Membership test | O(1) avg | O(log n) | O(log n) |
| Insert | O(1) avg | O(n) (shift) | O(log n) |
| Sorted iteration | Not supported | O(n) | O(n) |
| Range query | Not supported | O(log n + k) | O(log n + k) |
| Space constant | ~1.3–2× n | 1× n | ~3× n (pointers) |

Use a hash set when you only need membership testing and do not require ordering. As soon as you need sorted output or range queries, reach for a sorted structure.

## Resources

- MDN: [Set — JavaScript](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Set)
- CLRS Chapter 11 — Hash Tables (covers collision resolution and load factor theory)
- NeetCode Arrays & Hashing playlist: https://neetcode.io/roadmap

## Related

- [[hash-map]]
- [[sliding-window]]
- [[bfs]]
- [[dfs]]
- [[two-pointers]]
