---
id: 819897d2-3995-4cc5-9108-702f3cf27c3e
type: flashcard
tags:
  - ds-a
  - linked-list
  - data-structures
tiers:
  ds-a: 1
created: 2026-08-19
confidence: low
priority: normal
---

# Linked List

A linked list is a linear data structure where each element (node) stores a value and a pointer to the next node, forming a chain. Because nodes live in arbitrary memory locations connected by pointers, insertions and deletions at known positions are O(1) — no shifting required — but random access is O(n) since you must traverse from the head.

> [!tip] Recognition signal
> The problem hands you a **node reference** (not an index) and asks to insert/delete/rewire in-place: "remove Nth from end", "merge two sorted lists", "detect cycle", "reverse". Default to a **dummy head** to kill first-element edge cases.

## When to Use

**Problem signals that suggest a linked list:**
- The problem says "insert" or "delete" a node and gives you a pointer/reference to that node directly (not an index to search for)
- Constraints mention O(1) insertion/deletion at arbitrary positions (middle, after a given node)
- The problem involves merging, reversing, or rearranging node sequences in-place without allocating extra arrays
- Keywords: "in-place rearrangement," "remove Nth node from end," "merge two sorted lists," "detect cycle," "find intersection," "reverse linked list"
- The data is inherently sequential but the size is unknown or highly dynamic (e.g., implementing a queue, [LRU](_meta/glossary.md#lru) cache, or adjacency list)
- The problem asks you to interleave or split lists (e.g., odd/even partition, zip two lists)

**Prefer a linked list over alternatives when:**
- Over array: you need O(1) insert/delete at a known node reference and can tolerate O(n) lookup; arrays shift O(n) elements on insert/delete
- Over doubly-ended queue (deque): you need to splice or rewire arbitrary interior nodes, not just push/pop ends
- Over skip list or [BST](_meta/glossary.md#bst): problem is straightforward sequential access with no need for sorted order or O(log n) search

**Do not use when:**
- You need O(1) random access by index → use an array
- You need O(log n) search → use a BST or sorted array with binary search
- Cache locality matters (tight inner loop over all elements) → arrays are dramatically faster due to prefetching; linked list nodes scatter across the heap
- The problem involves range queries or prefix sums → use a segment tree or prefix sum array

## Time & Space Complexity

| Operation | Singly Linked | Doubly Linked | Why |
|-----------|--------------|---------------|-----|
| Access by index | O(n) | O(n) | No random access; must traverse from head |
| Search | O(n) | O(n) | Must scan until value found |
| Insert at head | O(1) | O(1) | Rewire one pointer; no shifting |
| Insert at tail | O(1) with tail ptr | O(1) with tail ptr | Direct pointer update |
| Insert at known node | O(1) | O(1) | Rewire next/prev pointers only |
| Delete at known node | O(n) | O(1) | Singly requires predecessor traversal; doubly has prev pointer |
| Delete by value | O(n) | O(n) | Must find the node first |

Space: O(n) — each of n nodes holds a value plus 1 (singly) or 2 (doubly) pointers; no wasted capacity unlike arrays with reserved slots.

## Key Properties

- **Singly linked:** each node has `val` and `next`. Deletion of a node requires its predecessor (or the "copy-value-forward" trick for self-deletion).
- **Doubly linked:** each node adds `prev`, enabling O(1) deletion of any node given only that node's reference. Required for LRU cache and most ordered-set implementations.
- **Sentinel/dummy head:** a dummy node before the real head eliminates special-casing for operations on the first element — the most common interview simplification.
- **Cycle detection:** Floyd's two-pointer algorithm (slow moves 1, fast moves 2) detects a cycle in O(n) time and O(1) space; the meeting point math lets you also find the cycle entry node.
- **Two-pointer gap technique:** to find the Nth node from the end, advance one pointer N steps, then move both until the lead reaches the tail — the trailer is at the target.

## Common Pitfalls

1. **Forgetting to update the tail pointer.** When inserting at the end or deleting the last node, forgetting to update a `self.tail` reference leaves a dangling pointer. Interviewers add "now do it with an O(1) append" to expose this.

2. **Off-by-one in the "remove Nth from end" gap.** Advancing the fast pointer N steps vs. N+1 steps shifts whether the slow pointer lands *on* the target or *before* it (needed to rewire `slow.next`). Getting this wrong silently passes most cases but fails when N equals list length.

3. **Losing the rest of the list during reversal.** In-place reversal must save `curr.next` before overwriting the `next` pointer. Classic mistake: `curr.next = prev; curr = curr.next` — `curr` is now `prev`, not the original `curr.next`.

4. **Cycle in "delete node without head" trick.** The copy-value-forward trick (`node.val = node.next.val; node.next = node.next.next`) fails silently if `node` is the tail (no `node.next`). Interviewers will ask "what if it's the last node?"

5. **Equality vs. identity when comparing nodes.** Using `==` on node objects checks value equality if `__eq__` is overridden, not pointer identity. For cycle and intersection problems you need `is` (identity) not `==` (value).

6. **Not handling the empty list or single-node list.** Reversal, merge, and cycle problems all have degenerate cases at length 0 and 1. Missing these is an immediate red flag.

## Implementation Notes

```javascript
class ListNode {
  constructor(val = 0, next = null) {
    this.val = val;
    this.next = next;
  }
}


// --- Iterative reversal ---
const reverseList = (head) => {
  let prev = null;
  let curr = head;
  while (curr) {
    const nxt = curr.next;  // save before overwriting
    curr.next = prev;       // reverse the pointer
    prev = curr;            // advance prev to current node
    curr = nxt;             // advance curr to saved next
  }
  return prev;              // prev is the new head when curr is null
};


// --- Detect cycle (Floyd's) ---
const hasCycle = (head) => {
  let slow = head;
  let fast = head;
  while (fast && fast.next) {
    slow = slow.next;
    fast = fast.next.next;
    if (slow === fast) return true;  // identity check, not value equality
  }
  return false;
};


// --- Find cycle entry node ---
const detectCycle = (head) => {
  let slow = head;
  let fast = head;
  let found = false;
  while (fast && fast.next) {
    slow = slow.next;
    fast = fast.next.next;
    if (slow === fast) {
      found = true;
      break;
    }
  }
  if (!found) return null;  // no cycle
  // Reset one pointer to head; both now move at speed 1.
  // They meet at the cycle entry due to the distance math:
  // dist(head→entry) == dist(meeting_point→entry within cycle)
  slow = head;
  while (slow !== fast) {
    slow = slow.next;
    fast = fast.next;
  }
  return slow;
};


// --- Merge two sorted lists (dummy head pattern) ---
const mergeTwoLists = (l1, l2) => {
  const dummy = new ListNode();  // sentinel eliminates head-special-casing
  let curr = dummy;
  while (l1 && l2) {
    if (l1.val <= l2.val) {
      curr.next = l1;
      l1 = l1.next;
    } else {
      curr.next = l2;
      l2 = l2.next;
    }
    curr = curr.next;
  }
  curr.next = l1 ?? l2;  // attach remaining non-empty list
  return dummy.next;
};


// --- Remove Nth node from end (two-pointer gap) ---
const removeNthFromEnd = (head, n) => {
  const dummy = new ListNode(0, head);  // handles removal of the real head
  let fast = dummy;
  let slow = dummy;
  for (let i = 0; i <= n; i++) {  // advance fast n+1 so slow stops BEFORE target
    fast = fast.next;
  }
  while (fast) {
    slow = slow.next;
    fast = fast.next;
  }
  slow.next = slow.next.next;  // unlink target
  return dummy.next;
};
```

## Trade-offs

| Criterion | Linked List | Array/Dynamic Array |
|-----------|------------|---------------------|
| Insert/delete at known position | O(1) | O(n) shift |
| Random access | O(n) | O(1) |
| Memory overhead | +1–2 pointers per node | None (contiguous) |
| Cache performance | Poor (pointer chasing) | Excellent (prefetch) |
| Resize cost | O(1) per node | Amortized O(1), spikes on growth |

Use a linked list when insert/delete frequency dominates access frequency. In practice, arrays outperform linked lists for most sequential workloads due to cache effects, even when the asymptotic complexity favors linked lists.

## Variants

- **Doubly linked list:** adds `prev` pointer; required for O(1) node removal without predecessor traversal (LRU cache, `collections.OrderedDict` internals)
- **Circular linked list:** tail points back to head; useful for round-robin schedulers
- **Skip list:** layered linked lists with express lanes; achieves O(log n) average search, insert, and delete (probabilistic); used in Redis sorted sets
- **[XOR](_meta/glossary.md#xor) linked list:** stores `prev XOR next` in a single pointer field; halves pointer memory; rarely seen in interviews but occasionally asked as a follow-up

## Resources

- CLRS 4th ed., Chapter 10.2 — Linked Lists
- NeetCode Linked List playlist: https://neetcode.io/roadmap (Linked List section)
- Python `collections.deque` source (doubly linked list + array hybrid): https://github.com/python/cpython/blob/main/Modules/_collectionsmodule.c

## Related

- [[two-pointers]]
- [[fast-slow-pointers]]
- [[dummy-head-pattern]]
- [[lru-cache]]
- [[stack]]
- [[queue]]
