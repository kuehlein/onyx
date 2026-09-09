---
id: fast-and-slow-pointers
type: flashcard
tags:
  - ds-a
  - linked-list
  - two-pointers
tiers:
  ds-a: 1
created: 2026-09-08
confidence: high
priority: normal
---

# Fast & Slow Pointers

Fast & slow pointers (the "tortoise and hare") run two pointers through a sequence at **different speeds** — typically fast moving two steps for every one step of slow. The speed difference is the whole trick: it turns a positional question ("is there a loop?", "where is the middle?", "which node is k from the end?") into a *meeting* or *gap* question that resolves in a single pass with only two scalar pointers. It is the canonical O(1)-space tool for linked lists, where you cannot index and random access is impossible.

> [!tip] Recognition signal
> Reach for fast/slow when you have a **linked list** (or an implicit "next"-function / functional graph) and need to **detect a cycle**, **find the middle node**, or find the **k-th node from the end** — especially when the problem forbids extra space (no visited-set / hash of nodes) or you cannot know the length up front.

## When to Use

**Problem signals that suggest Fast & Slow:**
- "**Detect a loop / cycle**" in a linked list, or find where the cycle **begins** → Floyd's cycle detection
- Find the **middle** of a linked list in one pass without first counting length → fast reaches the end when slow is at the midpoint
- Find the **k-th node from the end** → give fast a k-node head start, then move both in lockstep
- **Happy Number** or any "iterate f(x) until it repeats" problem — the sequence is a functional graph, so cycle detection applies with no linked list at all
- Detect a **palindrome linked list** (find middle, reverse second half, compare)

**Prefer Fast & Slow over alternatives when:**
- Over a **hash set of visited nodes** (cycle detection): fast/slow is O(1) space vs. O(n); use the hash set only if you also need the actual set of cycle nodes
- Over **two passes** (count length, then walk to length/2 or length−k): fast/slow does it in a single pass and needs no length

**Do not use when:**
- The structure is a **sorted array** and you need a pair/triplet meeting a sum target → use opposite-end two pointers (see contrast below)
- You need cycle detection but also want the shortest cycle / all cycles / distances in a general graph → use [BFS](_meta/glossary.md#bfs)/[DFS](_meta/glossary.md#dfs) with a visited set

> [!note] Contrast vs. confusable siblings
> - **vs. general [[two-pointers]]:** general two pointers is usually **opposite ends of a sorted array moving toward each other at the same speed** (or a same-speed slow/fast write-pointer for in-place filtering). Fast/slow is defined by a **speed differential** (2× vs 1×) used to make pointers *meet* or hold a *fixed gap* — the array's sortedness is irrelevant here.
> - **vs. [[linked-list]] traversal:** ordinary traversal walks one pointer to read/mutate nodes. Fast/slow is a specific *pattern over* a linked list that exploits relative speed to answer cycle/midpoint/k-from-end questions.

## Key Properties

- **The speed differential closes gaps at rate 1 per step.** If fast moves 2 and slow moves 1, the distance between them changes by exactly 1 each step. Inside a cycle of length λ this guarantees they are eventually congruent mod λ, so they **must** meet — a cycle can never be "stepped over."
- **Meeting proves a cycle; running off the end disproves one.** If fast (or `fast.next`) reaches null, the list is acyclic. Fast and slow meeting is possible only inside a loop.
- **Cycle-start (phase 2):** after they meet, reset one pointer to head and advance **both one step at a time**; they meet again exactly at the cycle entrance. Why: with cycle-start at distance μ from head, the meeting point sits distance μ *before* the start going forward — so both need μ more steps.
- **Middle:** with `while fast and fast.next`, when fast falls off the end slow is at the midpoint. For **even length**, slow lands on the **second** of the two middles (the (n/2)-th node, 0-indexed).
- **k-th from end:** advance fast k nodes first, then move both until fast hits the end; slow is then k nodes from the end.

## Time & Space Complexity

| Task | Time | Space |
|---|---|---|
| Cycle detection (phase 1) | O(n) | O(1) |
| Cycle start (phase 1 + 2) | O(n) | O(1) |
| Find middle | O(n) | O(1) |
| k-th from end | O(n) | O(1) |

**Why O(n) time:** slow advances at most n steps before fast either exits (acyclic) or laps it (within a cycle of length ≤ n), so total work is linear. **Why O(1) space:** state is just two node references — no auxiliary structure scales with input.

## Common Pitfalls

- **Not guarding the loop condition for null.** Fast moves two links per step, so you must test **`while fast and fast.next`** before doing `fast = fast.next.next`. Guarding only `fast` dereferences null on the second hop and crashes on even-length or empty lists.
- **Wrong middle convention.** Starting both at head with `while fast and fast.next` gives the **second** middle on even length; if the problem wants the **first** middle, start fast one node ahead (or check `fast.next.next`). Interviewers care which one.
- **Phase 2 using the wrong speed.** To find the cycle *entrance* you move **both pointers one step at a time** after the meeting — not 2× and 1×. Keeping the speed differential in phase 2 is a classic bug.
- **Checking equality at the wrong time.** Advance both pointers *first*, then compare, so the shared start (both at head) is not falsely reported as an immediate meeting.
- **Assuming it needs a sorted array.** Sortedness is irrelevant to fast/slow — that requirement belongs to opposite-end two pointers, not this pattern.

## Implementation Notes

```python
# ── PHASE 1: detect a cycle (Floyd) ─────────────────────────────
def has_cycle(head):
    slow = fast = head
    while fast and fast.next:      # guard BOTH hops
        slow = slow.next           # 1x
        fast = fast.next.next      # 2x
        if slow is fast:           # meet only inside a loop
            return True
    return False

# ── PHASE 2: find the cycle START ───────────────────────────────
def cycle_start(head):
    slow = fast = head
    while fast and fast.next:
        slow, fast = slow.next, fast.next.next
        if slow is fast:                       # meeting point
            p = head
            while p is not slow:               # both move 1 step now
                p, slow = p.next, slow.next
            return p                            # == cycle entrance
    return None                                # no cycle

# ── MIDDLE (second middle on even length) ───────────────────────
def middle(head):
    slow = fast = head
    while fast and fast.next:
        slow, fast = slow.next, fast.next.next
    return slow

# ── k-th FROM END ───────────────────────────────────────────────
def kth_from_end(head, k):
    fast = head
    for _ in range(k):             # give fast a k-node head start
        if not fast: return None   # list shorter than k
        fast = fast.next
    slow = head
    while fast:                    # keep the fixed gap of k
        slow, fast = slow.next, fast.next
    return slow
```

## Resources

- NeetCode — Linked List roadmap (Linked List Cycle, Middle of the Linked List): https://neetcode.io/roadmap
- LeetCode 141 Linked List Cycle: https://leetcode.com/problems/linked-list-cycle/
- LeetCode 142 Linked List Cycle II (cycle start): https://leetcode.com/problems/linked-list-cycle-ii/
- Wikipedia — Cycle detection (Floyd's tortoise and hare): https://en.wikipedia.org/wiki/Cycle_detection

## Related

- [[two-pointers]]
- [[linked-list]]
- [[sliding-window]]
