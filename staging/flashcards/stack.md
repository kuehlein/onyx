---
id: 41f06795-35a8-49a8-a307-7e0a188e83c2
type: flashcard
tags:
  - ds-a
  - stack
  - data-structures
tiers:
  ds-a: 1
created: 2026-08-19
confidence: medium
priority: normal
---

# Stack

A stack is a last-in, first-out ([LIFO](_meta/glossary.md#lifo)) linear data structure where every insert and delete operates on the same end (the "top"). LIFO is the key invariant: the most recently added item is always the first to be removed, which makes a stack the natural model for any problem where you must undo, reverse, or defer processing until a matching or closing condition is found.

> [!tip] Recognition trigger
> Reach for a stack on **matching/paired delimiters**, **next greater/smaller element** (monotonic stack), or anything phrased "most recent / last opened / innermost / undo". LIFO is the tell.

## When to Use

**Problem signals that suggest a stack:**
- The problem involves **matching or validating paired delimiters**: parentheses, brackets, braces, HTML/XML tags, or any open/close pairs (e.g., "valid parentheses", "balanced brackets").
- You must process items **in reverse order of arrival** or "undo the last action" (e.g., browser history, text editor undo, call stack simulation).
- The problem asks you to **find the next greater/smaller element** for each position in an array — classic monotonic stack pattern.
- A recursive solution is required but recursion depth is prohibitive — the call stack itself is a stack, so you can **simulate [DFS](_meta/glossary.md#dfs)/recursion explicitly**.
- The phrase "**most recent**", "**last opened**", "**innermost**", or "**previous state**" appears in the problem description.
- You need to **evaluate or parse an expression** left-to-right where operator precedence or nesting must be respected (infix → postfix, calculator problems).
- The problem involves **maintaining a running minimum or maximum** that must update as elements are pushed and popped (e.g., "Min Stack").

**Prefer a stack over alternatives when:**
- Over a queue: the problem requires LIFO access, not [FIFO](_meta/glossary.md#fifo). If the order of processing must be reversed from the order of arrival, use a stack.
- Over recursion: stack depth would exceed system limits (Python default ~1000 frames) or you need explicit control over the call frames.
- Over a deque: you only need one end. Using a deque adds no value and obscures intent.
- Over an array with arbitrary access: you never need to read or modify elements below the top; if you do, a stack is the wrong abstraction.

**Do not use when:**
- You need FIFO ordering → use a queue or deque instead.
- You need to access an arbitrary element by index → use a plain list/array.
- You need the minimum/maximum globally without push/pop correlation → use a heap instead.
- The problem requires merging or splitting sequences at both ends → use a deque.

## Time & Space Complexity

| Operation | Time  | Why |
|-----------|-------|-----|
| push      | O(1)  | Appending to the end of a dynamic array is amortized O(1); no shifting required. |
| pop       | O(1)  | Removing from the end of a dynamic array is O(1); no shifting required. |
| peek/top  | O(1)  | Index access to the last element is direct. |
| search    | O(n)  | No random access guarantee; must scan from the top down in the worst case. |

Space: O(n) — one slot per element stored; no auxiliary structure needed beyond the backing array.

## Key Properties

- **LIFO invariant:** only the top element is accessible; all others are hidden. This is a feature, not a limitation — it enforces the access pattern the algorithm depends on.
- **Implemented with a dynamic array in Python:** `list` already provides O(1) `append` and `pop` from the right end, making it the idiomatic backing structure. No `collections.deque` needed unless you also need O(1) `popleft`.
- **Implicit call stack:** every recursive function call uses the program's call stack. Iterative DFS with an explicit stack is semantically equivalent and avoids stack overflow.
- **Monotonic stack variant:** maintaining a stack that is always strictly increasing or decreasing (by popping elements that violate the invariant before pushing) solves next-greater-element, largest-rectangle-in-histogram, and daily-temperatures problems in O(n).

## Common Pitfalls

- **Popping from an empty stack:** failing to check `if stack` before calling `.pop()` raises `IndexError`. Always guard pops, especially inside loops where the empty case may only occur on certain inputs.
- **Peeking via `stack[-1]` on an empty list:** same root cause as above; accessing `stack[-1]` on `[]` raises `IndexError` rather than returning `None`. Interviewers test edge cases with empty or single-element inputs.
- **Using a stack when the problem needs a queue:** confusing [BFS](_meta/glossary.md#bfs) (queue, FIFO, shortest path) with DFS (stack, LIFO). BFS cannot be correctly implemented with a stack.
- **Off-by-one in monotonic stack:** deciding whether to pop on `>=` vs `>` (strict vs. non-strict monotonicity) changes which duplicates are kept and is a frequent source of wrong answers in next-greater-element variants.
- **Mutating the stack while iterating over it:** Python's `for x in stack` iterates a snapshot only if you convert to a list first; iterating the live list while popping produces undefined traversal behavior.
- **Forgetting that `.pop()` in Python returns the removed value:** many candidates write `val = stack[-1]; stack.pop()` when `val = stack.pop()` is equivalent and cleaner.
- **Not handling the "leftover" elements after the main loop:** in bracket-matching and monotonic-stack problems, elements remaining in the stack after processing all input often represent unmatched or unresolved items — ignoring them is a common bug.

## Implementation Notes

```javascript
// JS Array is the canonical stack.
// push = .push(), pop = .pop() (from right end), both O(1) amortized.

const stack = [];

// --- Basic operations ---
stack.push(42);                          // push: O(1) amortized
const top = stack[stack.length - 1];    // peek without removing: O(1)
const val = stack.pop();                // pop and return: O(1)
const isEmpty = stack.length === 0;     // explicit length check; no truthy shortcut for arrays

// --- Pattern 1: Valid Parentheses ---
const isValid = (s) => {
    const stack = [];
    // Map each closer to its expected opener for O(1) lookup
    const matching = new Map([[')','('], [']','['], ['}','{']]);

    for (const ch of s) {
        if (matching.has(ch)) {
            // Guard: stack may be empty on a leading close bracket
            if (stack.length === 0 || stack[stack.length - 1] !== matching.get(ch)) {
                return false;
            }
            stack.pop();
        } else {
            stack.push(ch);
        }
    }
    return stack.length === 0; // unmatched open brackets remain if non-empty
};

// --- Pattern 2: Monotonic Stack (Next Greater Element) ---
const nextGreater = (nums) => {
    const n = nums.length;
    const result = new Array(n).fill(-1);
    const stack = []; // stores indices, not values

    for (let i = 0; i < n; i++) {
        const num = nums[i];
        // Pop indices whose element has found its next greater
        while (stack.length > 0 && nums[stack[stack.length - 1]] < num) {
            const idx = stack.pop();
            result[idx] = num; // current num is the answer for idx
        }
        stack.push(i);
    }
    // Remaining indices in stack have no greater element; result stays -1
    return result;
};

// --- Pattern 3: Min Stack (O(1) getMin) ---
class MinStack {
    constructor() {
        this.stack = [];
        // Parallel stack tracking the running minimum at each push level
        this.minStack = [];
    }

    push(val) {
        this.stack.push(val);
        // If minStack is empty, current val is the minimum by default
        const prevMin = this.minStack.length > 0
            ? this.minStack[this.minStack.length - 1]
            : val;
        this.minStack.push(Math.min(val, prevMin));
    }

    pop() {
        this.stack.pop();
        this.minStack.pop(); // keep in sync; both stacks always same size
    }

    top() {
        return this.stack[this.stack.length - 1];
    }

    getMin() {
        return this.minStack[this.minStack.length - 1];
    }
}
```

## Variants

- **Monotonic stack (increasing/decreasing):** maintains a sorted invariant on the stack to answer next-greater/smaller-element queries in O(n) total across all elements.
- **Min/Max stack:** a parallel auxiliary stack tracks the running minimum (or maximum) at each depth level, giving O(1) `getMin`/`getMax` without a heap.
- **Two-stack queue:** two stacks can simulate a queue with amortized O(1) enqueue and dequeue (used in functional languages without mutable queues).
- **Call stack simulation:** replacing recursion with an explicit stack to implement iterative DFS, iterative tree traversal (inorder, preorder, postorder), or iterative backtracking.

## Resources

- CLRS 4th ed., Chapter 10.1 — Stacks and Queues
- NeetCode — Stack playlist: https://neetcode.io/roadmap (Stack section)
- Python docs — list as a stack: https://docs.python.org/3/tutorial/datastructures.html#using-lists-as-stacks

## Related

- [[monotonic-stack]]
- [[queue]]
- [[deque]]
- [[dfs]]
- [[dynamic-programming]]
