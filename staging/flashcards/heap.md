---
id: 7f3a2c1e-8b4d-4f9a-a6e2-3d5c0b1e9f72
type: flashcard
tags:
  - ds-a
  - heap
  - min-heap
  - max-heap
  - data-structures
tiers:
  ds-a: 2
created: 2026-08-20
confidence: low
---

# Heap and Priority Queue

A heap is a complete binary tree stored as an array where every parent satisfies a fixed ordering invariant with its children (min-heap: parent ≤ children; max-heap: parent ≥ children) — this invariant guarantees O(1) peek at the extreme element and O(log n) insert/remove without sorting the entire collection.

> [!tip] "Top-k / kth largest" without a full sort → size-k heap
> Keep a heap of size `k` (min-heap for k *largest*, max-heap for k *smallest*) and evict when it overflows. That's O(n log k) instead of O(n log n). Repeatedly pulling the next cheapest/nearest item is also a heap signal.

## When to Use

**Problem signals that suggest a heap / priority queue:**
- "Find the k largest / k smallest / kth element" — especially when you cannot sort the full input
- "Always process the next cheapest / nearest / highest-priority item" — greedy scheduling, Dijkstra, Prim's [MST](_meta/glossary.md#mst)
- "Merge k sorted lists / arrays / streams" — multi-way merge with O(log k) per step
- "Running median" or "sliding window median" — two-heap split (max-heap for lower half, min-heap for upper half)
- "Top-K frequent elements" — heap over frequency counts
- Constraints say n is large (10^5–10^6) but k is small — sorting would be O(n log n) but a heap keeps it O(n log k)
- Repeated extraction of the minimum or maximum across dynamic insertions

**Prefer heap over alternatives when:**
- Over full sort: you only need the top-k elements, not a full ordered sequence — heap is O(n log k) vs O(n log n)
- Over a sorted array/BST: insertions are frequent and you only query the extreme — heap insert is O(log n) vs O(n) for a sorted array
- Over a deque/monotonic structure: elements must be globally ordered by an arbitrary priority, not just insertion order

**Do not use when:**
- You need arbitrary lookup or deletion by value → use a [BST](_meta/glossary.md#bst) (sorted set) or hash map
- You need the k-th element with frequent rank changes → use an order-statistics tree
- k equals n (you need everything sorted) → just sort; a heap gives no advantage
- The priority is insertion order → use a queue

## Time & Space Complexity

All complexities assume a binary heap.

| Operation | Time | Why |
|---|---|---|
| peek min/max | O(1) | Root is always the extreme element |
| insert | O(log n) | Sift up traverses at most one root-to-leaf path |
| extract min/max | O(log n) | Replace root with last element, sift down |
| build heap (heapify) | O(n) | Bottom-up sift-down — most nodes are near leaves and travel short distances (sum of heights converges to n) |
| decrease-key | O(log n) | Sift up from updated position — requires an indexed priority queue (position tracking); not supported by a plain binary heap |
| search | O(n) | No ordering across siblings |

Space: O(n) for the array backing.

For the **top-k pattern**: O(n log k) time — iterate n elements, maintain a k-size heap; each heap operation is O(log k).

## Key Properties

1. **Complete binary tree stored as a flat array.** For a node at index `i` (0-based):
   - Left child: `2i + 1`
   - Right child: `2i + 2`
   - Parent: `Math.floor((i - 1) / 2)`
   No pointer overhead; excellent cache locality.

2. **Heap invariant is local, not global.** Siblings have no ordering relationship — only the parent-child axis is constrained. This is why search is O(n).

3. **Heapify is O(n), not O(n log n).** Building from an unordered array using bottom-up sift-down is linear. This makes top-k O(n log k) rather than O(n log n).

4. **JavaScript has no built-in heap.** In interviews you must either implement one inline or declare a `MinHeap` / `MaxHeap` helper class as an assumption. A max-heap can be simulated from a min-heap by negating values.

## Common Pitfalls

- **Forgetting JS has no priority queue.** State your assumption explicitly: "I'll use a MinHeap class with `push(val)`, `pop()` returning the minimum, and `peek()`."
- **Max-heap via negation.** To get a max-heap from a min-heap implementation, push `-val` and negate on pop. Easy to forget the negation when reading results.
- **Off-by-one in array indexing.** 0-based vs 1-based indexing changes the parent/child formulas — pick one and be consistent.
- **Not heapifying on construction.** Inserting n elements one-by-one is O(n log n). Use bottom-up heapify for O(n) when you have all elements upfront.
- **Mutating priority after insertion.** Standard binary heaps do not support efficient arbitrary decrease-key without tracking node positions. If priorities change, either rebuild or use a lazy-deletion pattern (push new entry, ignore stale ones on pop).
- **Confusing heap with heap memory.** Completely unrelated concepts — clarify if an interviewer seems confused.

## Trade-offs

| | Binary Heap | Sorted Array | BST / Sorted Set |
|---|---|---|---|
| Peek min | O(1) | O(1) | O(log n) |
| Insert | O(log n) | O(n) | O(log n) |
| Extract min | O(log n) | O(n) shift from front | O(log n) |
| Arbitrary search | O(n) | O(log n) binary search | O(log n) |
| Build from array | O(n) | O(n log n) | O(n log n) |
| Use case | Repeated extreme extraction | Static data, range queries | Dynamic ordered access |

## Implementation Notes

JS has no built-in heap. Below is a minimal correct `MinHeap` suitable for interviews, followed by the canonical usage patterns.

```js
class MinHeap {
  constructor() {
    this.heap = [];
  }

  // O(1) — root is always the minimum
  peek() {
    return this.heap[0];
  }

  size() {
    return this.heap.length;
  }

  // O(log n) — append then sift up
  push(val) {
    this.heap.push(val);
    this._siftUp(this.heap.length - 1);
  }

  // O(log n) — swap root with last, remove last, sift down
  pop() {
    const min = this.heap[0];
    const last = this.heap.pop();
    if (this.heap.length > 0) {
      this.heap[0] = last;
      this._siftDown(0);
    }
    return min;
  }

  _siftUp(i) {
    while (i > 0) {
      const parent = Math.floor((i - 1) / 2);
      if (this.heap[parent] <= this.heap[i]) break;
      [this.heap[parent], this.heap[i]] = [this.heap[i], this.heap[parent]];
      i = parent;
    }
  }

  _siftDown(i) {
    const n = this.heap.length;
    while (true) {
      let smallest = i;
      const l = 2 * i + 1;
      const r = 2 * i + 2;
      if (l < n && this.heap[l] < this.heap[smallest]) smallest = l;
      if (r < n && this.heap[r] < this.heap[smallest]) smallest = r;
      if (smallest === i) break;
      [this.heap[smallest], this.heap[i]] = [this.heap[i], this.heap[smallest]];
      i = smallest;
    }
  }
}

// --- Max-heap via negation ---
// Push -val, negate on pop.
const maxHeap = new MinHeap();
maxHeap.push(-5);
maxHeap.push(-1);
maxHeap.push(-3);
const max = -maxHeap.pop(); // 5

// --- Pattern 1: K smallest elements ---
// Keep a MAX-heap of size k. If current element < heap top, swap it in.
// Result: heap holds the k smallest seen so far.
function kSmallest(nums, k) {
  const maxH = new MinHeap(); // use negation for max-heap
  for (const n of nums) {
    maxH.push(-n);                       // negate to simulate max-heap
    if (maxH.size() > k) maxH.pop();     // evict the largest among current k+1
  }
  return maxH.heap.map(x => -x);         // un-negate
}

// --- Pattern 2: K largest elements ---
// Keep a MIN-heap of size k. If current element > heap top, swap it in.
function kLargest(nums, k) {
  const minH = new MinHeap();
  for (const n of nums) {
    minH.push(n);
    if (minH.size() > k) minH.pop();     // evict the smallest among current k+1
  }
  return minH.heap;
}

// --- Pattern 3: Merge k sorted lists ---
// Push [value, listIndex, elementIndex] into the heap.
// O((n * k) log k) where n is avg list length.
function mergeKSorted(lists) {
  const heap = new MinHeap();
  // Custom heap would compare by value — shown conceptually here
  const result = [];

  // Seed with the head of each list
  for (let i = 0; i < lists.length; i++) {
    if (lists[i].length > 0) {
      heap.push([lists[i][0], i, 0]); // [val, listIdx, elemIdx]
    }
  }

  // MinHeap must compare by val — in a real interview, adapt _siftUp/_siftDown
  // to use entry[0] as the key, or wrap with a comparator.
  while (heap.size() > 0) {
    const [val, li, ei] = heap.pop();
    result.push(val);
    if (ei + 1 < lists[li].length) {
      heap.push([lists[li][ei + 1], li, ei + 1]);
    }
  }
  return result;
}

// --- Pattern 4: Running median (two-heap split) ---
// maxHeap holds lower half, minHeap holds upper half.
// Invariant: |maxHeap.size() - minHeap.size()| <= 1
// Median = top of larger heap, or average of both tops.
class MedianFinder {
  constructor() {
    this.lo = new MinHeap(); // max-heap (negated) for lower half
    this.hi = new MinHeap(); // min-heap for upper half
  }

  addNum(num) {
    this.lo.push(-num);                          // always push to lo first
    this.hi.push(-this.lo.pop());                // balance: move lo's max to hi
    if (this.hi.size() > this.lo.size()) {
      this.lo.push(-this.hi.pop());              // keep lo >= hi in size
    }
  }

  findMedian() {
    if (this.lo.size() > this.hi.size()) return -this.lo.peek();
    return (-this.lo.peek() + this.hi.peek()) / 2;
  }
}

// --- Pattern 5: Dijkstra shortest path ---
// MinHeap on [distance, node]. Lazy-ignore stale entries.
function dijkstra(graph, src) { // graph: adjacency list {node: [[neighbor, weight]]}
  const dist = new Map();
  const heap = new MinHeap(); // entries: [dist, node] — compare by dist[0]
  heap.push([0, src]);
  dist.set(src, 0);

  while (heap.size() > 0) {
    const [d, u] = heap.pop();
    if (d > (dist.get(u) ?? Infinity)) continue; // stale entry — skip

    for (const [v, w] of (graph.get(u) ?? [])) {
      const newDist = d + w;
      if (newDist < (dist.get(v) ?? Infinity)) {
        dist.set(v, newDist);
        heap.push([newDist, v]);
      }
    }
  }
  return dist;
}
// NOTE: Dijkstra requires the heap to compare by entry[0].
// In an interview, either adapt MinHeap with a comparator param or state the assumption.
```

**Comparator-based MinHeap (interview-ready variant):**

```js
class MinHeap {
  // comparator(a, b) < 0 means a has higher priority (comes first)
  constructor(comparator = (a, b) => a - b) {
    this.heap = [];
    this.cmp = comparator;
  }
  // ... (same structure; replace all `<=` / `<` comparisons with this.cmp())
}

// Usage for Dijkstra:
const heap = new MinHeap((a, b) => a[0] - b[0]); // compare by distance
```

## Variants

- **Binary heap (covered above):** Most common; O(log n) insert/extract.
- **d-ary heap:** Each node has d children. Shallower tree → faster decrease-key, slower extract-min. Used in practice (d=4 is common for cache performance).
- **Fibonacci heap:** O(1) amortized insert and decrease-key; O(log n) extract-min. Optimal for Dijkstra theoretically but rarely implemented in interviews due to complexity.
- **Indexed priority queue:** Tracks position of each element for O(log n) arbitrary decrease-key. Required for true Prim's/Dijkstra with mutable priorities.
- **Soft heap:** Allows controlled corruption for approximate selection; used in near-linear MST algorithms.

## Resources

- [Heap (data structure) — Wikipedia](https://en.wikipedia.org/wiki/Heap_(data_structure))
- [NeetCode — Heap / Priority Queue playlist](https://neetcode.io/roadmap)
- *Introduction to Algorithms* (CLRS) 4th ed., Chapter 6: Heapsort; Chapter 19: Fibonacci Heaps
- [JavaScript MinHeap implementation reference — LeetCode Discuss](https://leetcode.com/discuss/general-discussion/1105728/priority-queue-in-javascript)

## Related

- [[dijkstra-shortest-path]]
- [[top-k-elements-pattern]]
- [[merge-k-sorted-lists]]
- [[sliding-window-median]]
- [[minimum-spanning-tree]]
- [[greedy-algorithms]]
