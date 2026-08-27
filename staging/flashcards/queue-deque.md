---
id: 3f8a2c1d-9b47-4e2a-a3f5-7d6e8c0b1f94
type: flashcard
tags:
  - ds-a
  - queue
  - deque
  - data-structures
tiers:
  ds-a: 1
created: 2026-08-19
confidence: medium
---

# Queue and Deque

A queue enforces FIFO (First-In, First-Out) ordering — the first element enqueued is the first dequeued — making it the natural structure for any problem where processing order must mirror arrival order. A deque (double-ended queue) generalizes this by allowing O(1) insertion and removal from both ends, enabling it to function as a queue, stack, or sliding-window buffer simultaneously.

> [!tip] Recognition signal
> "Level by level", "shortest path in an unweighted grid/graph", "minimum steps to reach X" → **BFS with a queue**. "Sliding window max/min" → **monotonic deque** of indices.

## When to Use

**Problem signals that suggest a Queue:**
- "Process nodes level by level" or "find the shortest path" in an unweighted graph/grid — BFS requires a queue to guarantee level-order traversal
- "First available", "first request served", "task scheduling" — arrival order must equal processing order
- "Minimum number of steps/moves/jumps to reach X" in a grid or graph — BFS via queue gives the guarantee
- "Serialize/deserialize a binary tree" — level-order traversal is the natural representation
- "Rotting oranges", "walls and gates", "01 matrix" — multi-source BFS starts with multiple seeds enqueued simultaneously

**Problem signals that suggest a Deque:**
- "Sliding window maximum/minimum" — the deque maintains a monotonic window of candidates in O(1) amortized per element
- "Jump game" — BFS with deque when edge weights are 0 or 1 (0-1 BFS)
- "Implement a stack using a queue" or vice versa — deque satisfies both interfaces
- "Palindrome check on a sequence" — remove from both ends symmetrically
- You see constraints like "k most recent" combined with "oldest element also needed"

**Prefer Queue/Deque over alternatives when:**
- Over Stack: you need to preserve arrival order or explore level by level (BFS), not depth-first
- Over Heap/Priority Queue: all elements have equal priority and O(1) enqueue/dequeue matters more than ordering by value
- Over List (Python): `list.pop(0)` is O(n) because it shifts all elements; `collections.deque.popleft()` is O(1)
- Over Deque (use plain Queue): you only need one end — a plain `collections.deque` used only on the right is fine, but signals intent more clearly

**Do not use when:**
- You need to access an arbitrary element by index → use an array/list
- You need the minimum or maximum across the entire structure at query time → use a heap
- You need to process in priority order, not arrival order → use a `heapq` / priority queue
- DFS is more appropriate (e.g., cycle detection, topological sort with recursion, path enumeration) → use a stack or the call stack

## Time & Space Complexity

| Operation | Queue (`deque`) | Deque |
|---|---|---|
| Enqueue / append right | O(1) | O(1) |
| Dequeue / pop left | O(1) | O(1) |
| Append left | N/A | O(1) |
| Pop right | O(1) | O(1) |
| Peek (either end) | O(1) | O(1) |
| Search (arbitrary) | O(n) | O(n) |
| Space | O(n) | O(n) |

**Why O(1) at both ends:** CPython's `collections.deque` is implemented as a doubly-linked list of fixed-size blocks (not a contiguous array). Head and tail pointers allow pointer manipulation in constant time regardless of size. This is why `list.pop(0)` is O(n) — lists are contiguous arrays that must shift every element left after removing index 0.

**BFS overall complexity:** O(V + E) — every vertex is enqueued and dequeued once (O(V)), and every edge is examined once when its source vertex is dequeued (O(E)).

## Key Properties

- **Queue:** FIFO — elements exit in the same order they entered. Supports enqueue (right), dequeue (left), and peek-front.
- **Deque:** Double-ended — O(1) at both ends. Can model a queue (append right, pop left), a stack (append right, pop right), or a sliding window.
- **Thread safety:** `collections.deque` is thread-safe for `append` and `popleft` operations (GIL-protected atomic ops). For producer-consumer across threads use `queue.Queue` which adds blocking and `maxsize`.
- **`queue.Queue` vs `collections.deque`:** `queue.Queue` is for thread synchronization (blocking `get`/`put`, `maxsize`). `collections.deque` is for single-threaded algorithmic use — it is faster and has no overhead.
- **Monotonic deque:** A deque maintained in monotonically increasing or decreasing order. When a new element arrives, pop from the back until the invariant holds, then append. This enables O(1) window max/min queries.

## Common Pitfalls

> [!warning] Mark visited on enqueue, not on dequeue
> If you mark a node visited only when dequeuing, it can be enqueued many times before processing — causing O(V²) blowup or infinite loops on cyclic graphs.

- **Using `list` as a queue in Python:** `list.pop(0)` is O(n). Interviewers will catch this. Always use `collections.deque` and call `.popleft()`.
- **Forgetting to mark nodes visited before enqueuing (BFS):** If you mark visited only when dequeuing, the same node can be enqueued multiple times before being processed, causing O(V²) or worse behavior and infinite loops on cyclic graphs. Mark visited immediately upon enqueue.
- **Confusing deque with a sorted structure:** A deque has O(1) ends but O(n) search. Interviewers probe this when asking about the sliding window maximum — the deque stores *indices*, not sorted values, and the invariant is maintained by the caller, not the structure itself.
- **Not handling the empty deque before peeking:** `deque[0]` or `deque[-1]` on an empty deque raises `IndexError`. Always guard with `if dq:` or `len(dq) > 0`.
- **Sliding window: forgetting to evict indices out of the window:** The deque front must be checked on every iteration: `while dq and dq[0] < i - k + 1: dq.popleft()`. Omitting this causes stale out-of-window indices to produce wrong answers.
- **Multi-source BFS: not enqueuing all sources at the start:** A common mistake is to run BFS from each source separately. True multi-source BFS enqueues all starting nodes simultaneously at step 0, then processes level by level. Running separate BFS passes is incorrect and O(S × (V+E)).

## Implementation Notes

```javascript
// ── Basic Queue (FIFO) ───────────────────────────────────────────────
const q = [];
q.push("a");          // enqueue to right — O(1)
q.push("b");
const front = q[0];   // peek without removing — O(1)
const item = q.shift(); // dequeue from left — O(1); shift() is O(n) for arrays,
                        // but JS has no built-in O(1) deque — acceptable for interviews

// ── Basic Deque (both ends) ──────────────────────────────────────────
const dq = [];
dq.push(1);           // right end — O(1)
dq.unshift(0);        // left end — O(n) for arrays; use a doubly-linked list for true O(1)
dq.pop();             // remove from right — O(1)
dq.shift();           // remove from left — O(n) for arrays; same caveat as above

// ── BFS Template (shortest path in unweighted graph) ─────────────────
const bfs = (graph, start, target) => {
    const visited = new Set([start]); // mark visited ON ENQUEUE, not on dequeue
    const queue = [[start, 0]];       // store [node, distance] pairs
    while (queue.length > 0) {
        const [node, dist] = queue.shift();
        if (node === target) return dist;
        for (const neighbor of graph[node]) {
            if (!visited.has(neighbor)) {
                visited.add(neighbor);           // mark here to prevent duplicate enqueues
                queue.push([neighbor, dist + 1]);
            }
        }
    }
    return -1; // unreachable
};

// ── Sliding Window Maximum (monotonic deque) ─────────────────────────
const maxSlidingWindow = (nums, k) => {
    const dq = [];  // stores indices; front always holds index of current window max
    const result = [];
    for (let i = 0; i < nums.length; i++) {
        // evict indices that have fallen outside the window
        while (dq.length > 0 && dq[0] < i - k + 1) {
            dq.shift();
        }
        // maintain decreasing order: pop smaller values from back
        // because they can never be the max while nums[i] is in the window
        while (dq.length > 0 && nums[dq[dq.length - 1]] < nums[i]) {
            dq.pop();
        }
        dq.push(i);
        if (i >= k - 1) {             // window is full; front is the max index
            result.push(nums[dq[0]]);
        }
    }
    return result;
};

// ── Multi-Source BFS (e.g. Rotting Oranges) ──────────────────────────
const multiSourceBfs = (grid) => {
    const rows = grid.length;
    const cols = grid[0].length;
    const queue = [];
    let fresh = 0;
    for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
            if (grid[r][c] === 2) {
                queue.push([r, c, 0]); // all sources enqueued at time 0
            } else if (grid[r][c] === 1) {
                fresh++;
            }
        }
    }
    let minutes = 0;
    const dirs = [[-1,0],[1,0],[0,-1],[0,1]];
    while (queue.length > 0 && fresh > 0) {
        const [r, c, t] = queue.shift();
        for (const [dr, dc] of dirs) {
            const nr = r + dr;
            const nc = c + dc;
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && grid[nr][nc] === 1) {
                grid[nr][nc] = 2;
                fresh--;
                minutes = t + 1;
                queue.push([nr, nc, t + 1]);
            }
        }
    }
    return fresh === 0 ? minutes : -1;
};
```

## Variants

- **Circular Queue (Ring Buffer):** Fixed-size queue backed by an array with head/tail pointers that wrap around using modulo. O(1) all operations, zero allocation after init. Used in producer-consumer buffers and audio streaming. Python: implement with a list of size `n` and `(head + 1) % n`.
- **Monotonic Deque:** A deque maintained in sorted order by evicting from one end before appending. Enables O(n) total sliding window max/min (amortized O(1) per element). Every element is appended and popped at most once.
- **0-1 BFS:** When edge weights are only 0 or 1, use a deque instead of Dijkstra's heap. Weight-0 edges prepend (`appendleft`), weight-1 edges append. Achieves O(V + E) vs O((V + E) log V) for Dijkstra.
- **`queue.Queue` (thread-safe):** Wraps a deque with a `threading.Condition` lock. Supports `block=True` for consumer threads to wait when empty, and `maxsize` for backpressure. Do not use in single-threaded algorithms — the lock overhead is unnecessary.

## Resources

- [Python docs — collections.deque](https://docs.python.org/3/library/collections.html#collections.deque)
- [Python docs — queue.Queue](https://docs.python.org/3/library/queue.html)
- [CPython deque source (C implementation)](https://github.com/python/cpython/blob/main/Modules/_collectionsmodule.c)
- *Introduction to Algorithms* (CLRS), Chapter 10.1 — Stacks and Queues

## Related

- [[bfs]]
- [[monotonic-stack]]
- [[sliding-window]]
- [[heap-priority-queue]]
- [[graph-traversal]]
