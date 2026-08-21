# Card Schema

Cards are standard Obsidian markdown files with YAML frontmatter. Each file
represents one concept. The quiz engine treats each H2 section as an
independently schedulable unit.

The design of this schema is grounded in learning science research. See
`docs/learning-science.md` for the evidence base. The short version:
- **Encode rules and principles, not rote facts.** Rule-based knowledge is
  empirically more durable over multi-day delays than memorized answers.
- **Prioritize conditional knowledge** ("when to use") — this is what
  interviewers test and what is hardest to build via flashcards alone.
- **Card granularity is flexible.** There is no peer-reviewed evidence that
  splitting one rich card into six atomic cards produces better outcomes.
  Use your judgment; aim for section coherence, not minimal word count.

---

## File Format

### Frontmatter

```yaml
---
id: 550e8400-e29b-41d4-a716-446655440000  # UUID v4 — stable primary key, never change
type: flashcard                            # required for Onyx to index this file
tags:
  - ds-a                                  # domain tag — always required
  - data-structures
  - trees
  - bst
tiers:
  ds-a: 2                                 # per-domain tier (1=foundational → 4=specialist)
  system-design: 1                        # include only domains where this card is relevant
created: 2024-01-15                        # ISO 8601 date
quiz: []                                   # optional: explicit list of section slugs to quiz
                                           # when empty, all H2 sections are quizzed (minus blocklist)
---
```

**Field notes:**
- `id` — UUID v4. Generated at card creation time. This is the foreign key in
  SQLite for SRS state and review history. Never rename it.
- `type` — must be `flashcard` exactly. Files without this field are ignored.
- `tags` — kebab-case strings. Always include a domain tag (`ds-a`,
  `system-design`, `blockchain`, `behavioral`). See `_meta/tags.md` in the
  vault for the full index and conflict-resolution rules.
- `tiers` — map of domain → tier level (1–4). Tier is per-domain: a card can
  be tier 1 in `system-design` and tier 3 in `ds-a`. Cards without `tiers` are
  indexed and quizzed normally but excluded from readiness calculations.
- `confidence` — `high` / `medium` / `low`. Set at card creation based on verification outcome. Guides how much to trust the card before cross-checking with Resources.
  - `high` — clean verification pass; study with confidence
  - `medium` — minor issues were flagged; verify the specific sections noted in REVIEW.md
  - `low` — major issues were auto-corrected by an AI verifier; read the Resources link before relying on this card
- `quiz` — optional override. List section slugs to restrict which sections are
  quizzed. When empty or absent, automatic discovery applies.

---

### Body

```markdown
# Binary Search Tree

A binary tree where left subtree values are always less than the node and right
subtree values are always greater. The BST property is what enables O(log n)
operations — each comparison eliminates half the remaining search space.

## When to Use

**Problem signals that suggest a BST:**
- You need ordered iteration over a dynamic set (a sorted array won't do because
  you also need inserts/deletes)
- You need range queries: "find all elements between X and Y"
- You need rank queries: "find the kth smallest element"
- The problem implies both ordering and mutation — static sorted data doesn't
  need a BST

**Prefer BST over alternatives when:**
- Over hash map: when ordering or range operations matter (hash map gives O(1)
  lookup but loses order entirely)
- Over heap: when you need arbitrary queries, not just min/max access
- Over sorted array: when you need O(log n) inserts, not just O(log n) search

**Do not use when:**
- You only need fast lookup and insertion order doesn't matter → hash map
- You only need the current minimum/maximum repeatedly → heap
- The dataset is static → sorted array + binary search is simpler

## Time & Space Complexity

The O(log n) average case derives from the BST property halving the search
space at each level. This guarantee disappears without balancing.

| Operation | Average  | Worst (unbalanced) |
|-----------|----------|--------------------|
| Search    | O(log n) | O(n)               |
| Insert    | O(log n) | O(n)               |
| Delete    | O(log n) | O(n)               |
| In-order  | O(n)     | O(n)               |

Space: O(n) storage. O(h) stack for recursive operations where h = height.
Worst case O(n) height occurs with sorted insertion order (degenerates to a
linked list). Use [[avl-tree]] or [[red-black-tree]] to guarantee O(log n).

## Key Properties

- **BST invariant:** every node's left subtree contains only smaller values;
  right subtree contains only greater values. This holds recursively.
- **In-order traversal** visits nodes in sorted ascending order — a direct
  consequence of the invariant.
- No balance constraint in a plain BST — balance must be maintained explicitly
  by the variant (AVL rotations, Red-Black rules, etc.)
- Duplicate handling is undefined by the BST property — you must choose: reject
  duplicates, allow left, allow right, or use a count per node.

## Common Pitfalls

- **Sorted insertion degrades to O(n).** If you insert 1, 2, 3, 4... in order,
  every node becomes a right child and the tree is a linked list. Always
  consider whether your input might be pre-sorted.
- **Deletion with two children.** Removing a node with two children requires
  replacing it with the in-order successor (smallest in right subtree) or
  in-order predecessor — then deleting that replacement from its original
  position. Not removing the node in place.
- **Equality.** Forgetting to define where duplicates go causes silent bugs.

## Implementation Notes

Search, insert, and delete are all variations of the same traversal pattern:
go left if target < current, go right if target > current.

```js
function search(node, target) {
  if (node === null || node.val === target) return node;
  if (target < node.val) return search(node.left, target);
  return search(node.right, target);
}
```

Delete is the hardest operation:
1. Find the node (standard search)
2. If leaf: remove directly
3. If one child: replace node with child
4. If two children: find in-order successor → copy its value → delete successor

## Related

- [[avl-tree]]
- [[red-black-tree]]
- [[heap]]
- [[binary-tree]]
- [[hash-map]]
```

---

## Quiz Section Rules

### Automatic discovery

All `##` (H2) sections are quizzable by default, except those matching the
**blocklist**. The default blocklist:

```
Related, Related Concepts, References, Notes, See Also, Links, Overview,
Background, Resources, Follow-up Questions
```

Configurable in app settings. Blocklist matching is case-insensitive.

### Explicit override

```yaml
quiz:
  - when-to-use
  - time-space-complexity
  - common-pitfalls
```

Section slugs are computed by the app: H2 heading text, lowercased, spaces to
hyphens, special characters removed. You do not need to hand-write slugs unless
using an explicit override.

### Quiz item construction

During a session, Onyx:

1. Queries SQLite for due `(card_id, section_slug)` pairs
2. Reads the card file and extracts the relevant section's markdown
3. **Front:** `{Card Title} — {Section Heading}`
   e.g. `"Binary Search Tree — When to Use"`
4. **Back:** full section markdown, rendered

The user grades 1–4 (Again / Hard / Good / Easy). FSRS updates `stability`
and `difficulty` and computes the next `due_at` for that pair independently.

---

## Recommended Section Headings

Consistent headings enable tag-based filtering and future AI analysis. The
table below is sorted by learning science priority — not by where they'd appear
in a card.

| Heading | Knowledge type | Priority | Purpose |
|---|---|---|---|
**For `type: flashcard` (concept cards):**

| Heading | Knowledge type | Priority | Purpose |
|---|---|---|---|
| `## When to Use` | Conditional | **Highest** | Recognition triggers — observable problem signals |
| `## Time & Space Complexity` | Declarative | High | Big-O with justification of *why* |
| `## Key Properties` | Declarative | High | Invariants, constraints, non-obvious behaviors |
| `## Common Pitfalls` | Conditional | High | Mistakes that signal incomplete understanding |
| `## Trade-offs` | Conditional | High | Comparison vs. alternatives — when NOT to use this |
| `## Implementation Notes` | Procedural | Medium | Pseudocode, key steps, subtle implementation details |
| `## Variants` | Declarative | Low | Subtypes, specializations, related algorithms |
| `## Resources` | — | Not quizzed | Links to docs, book chapters, authoritative sources |

**For `type: interview-question`:**

| Heading | Quizzed | Purpose |
|---|---|---|
| `## Approach` | **Yes** (primary) | Pattern name, key insight, solution sketch |
| `## Complexity` | Optional | Time/space with one-line justification |
| `## Follow-up Questions` | No | Common interviewer follow-ups with brief answers |
| `## Resources` | No | LeetCode link, NeetCode video, book reference |
| `## Related Concepts` | No | Wikilinks to concept cards |

**For `type: flashcard` (language/framework cards):**

| Heading | Quizzed | Purpose |
|---|---|---|
| `## Syntax` | Yes | The actual syntax with a minimal working example |
| `## Common Patterns` | Yes | Idiomatic usage; when you'd reach for this |
| `## Gotchas` | Yes | Surprising behaviors, common mistakes |
| `## vs Alternative` | Optional | Comparison with a closely related construct |
| `## Resources` | No | Docs link, book reference |

### On "When to Use" — the most important section

This section trains *conditional knowledge*: knowing when a pattern applies.
Research shows this is the primary skill tested in interviews and the hardest
to build via flashcards alone. The section should encode:

1. **Problem signals** — observable characteristics in a problem statement that
   suggest this approach. Be specific: "the problem asks for the kth largest
   element in a stream" is better than "when you need fast access to extremes."

2. **Comparison vs. alternatives** — when to prefer this over the most common
   alternatives, and when NOT to use it. This comparative structure encodes the
   decision boundary, not just the answer.

3. **Anti-patterns** — explicit "do not use when" cases. Knowing what excludes
   a pattern is as important as knowing what includes it.

---

## Tag Taxonomy

Use kebab-case. Add freely — there is no enforced vocabulary.

**Data structures**
`array`, `linked-list`, `doubly-linked-list`, `stack`, `queue`, `deque`,
`hash-map`, `hash-set`, `tree`, `binary-tree`, `bst`, `trie`, `heap`,
`min-heap`, `max-heap`, `graph`, `disjoint-set`

**Algorithms**
`sorting`, `searching`, `binary-search`, `dynamic-programming`, `greedy`,
`divide-and-conquer`, `backtracking`, `bit-manipulation`, `two-pointers`,
`sliding-window`, `bfs`, `dfs`, `topological-sort`, `union-find`

**Complexity**
`time-complexity`, `space-complexity`, `big-o`, `amortized`

**System design**
`system-design`, `caching`, `load-balancing`, `database`, `sql`, `nosql`,
`distributed-systems`, `api-design`, `microservices`, `message-queue`

**Meta**
`swe-interview`, `leetcode`, `behavioral`, `language-specific`

---

## Interview Question Cards

`type: interview-question` is a second card type for actual interview questions,
distinct from concept cards (`type: flashcard`). Concept cards build your
knowledge library; interview question cards train you to apply that library
under interview conditions.

### Frontmatter

```yaml
---
id: 550e8400-e29b-41d4-a716-446655440000
type: interview-question
category: coding                # coding | system-design | conceptual | language
difficulty: medium              # easy | medium | hard
frequency: high                 # high | medium | low — how often in real interviews
domains: [ds-a]                 # list of relevant domains
tiers:
  ds-a: 2
concepts:                       # filenames (no .md) of relevant concept cards
  - hash-map
  - array
source: neetcode-150            # neetcode-150 | blind-75 | alex-xu-v1 | alex-xu-v2 | ddia | community
practice_url: https://neetcode.io/problems/two-integer-sum  # opens after Good/Easy grade
created: 2024-01-15
---
```

**Field notes:**
- `category` — how this question is typically presented in an interview loop
- `difficulty` — relative to others in the same category (not absolute)
- `frequency` — drawn from NeetCode 150 / Blind 75 ranking and community reports
- `concepts` — links the question to the concept cards it draws on; used in graph view and readiness calculation
- `source` — where the question comes from; drives the question library curation
- `practice_url` — primary URL for solving the actual problem (NeetCode preferred). After a Good or Easy grade in the quiz, the app offers a skippable prompt to open this URL. Bridges the gap between pattern recall (flashcard) and actual problem solving (LeetCode/NeetCode).

### Body

```markdown
# Two Sum

Given an array of integers `nums` and integer `target`, return the indices of
two numbers that sum to `target`. Each input has exactly one solution; you may
not use the same element twice.

## Approach

**Pattern:** Hash map for single-pass O(n) lookup — trade space for time.

**Key insight:** For each element `num`, its required complement is
`target - num`. Store complements seen so far in a hash map. If the current
element already exists as a stored complement, you've found the pair.

**Recognition signals for this pattern:**
- Problem asks for a pair (or k-tuple) with a specific sum
- You need to find two elements with a relationship — hash the "needed" value,
  check as you go

```js
function twoSum(nums, target) {
  const seen = new Map(); // complement → index
  for (let i = 0; i < nums.length; i++) {
    if (seen.has(nums[i])) return [seen.get(nums[i]), i];
    seen.set(target - nums[i], i);
  }
}
```

## Complexity

Time: O(n) — single pass through the array
Space: O(n) — hash map stores at most n entries

## Follow-up Questions

- **Array is sorted** → two pointers from both ends, O(1) space, O(n) time
- **Return all pairs, not just one** → outer loop + inner set, watch for duplicates
- **k numbers sum to target** → reduce to (k-1)-sum recursively; base case is 2Sum

## Resources

- NeetCode 150: https://neetcode.io/problems/two-integer-sum
- LeetCode #1: https://leetcode.com/problems/two-sum/

## Related Concepts

- [[hash-map]]
- [[two-pointers]]
- [[array]]
```

### Quiz behavior

Interview question cards default to quizzing only `## Approach` (equivalent to
`quiz: [approach]` in frontmatter). The quiz screen shows the pre-H2 problem
statement as a collapsible context panel on the front — so you can read the
problem and attempt it mentally before revealing the approach. This is
intentionally different from concept card quiz, which shows only title +
section heading on the front.

`## Complexity` can be added to `quiz` if you want it scheduled separately.
`## Follow-up Questions`, `## Resources`, and `## Related Concepts` are never
quizzed — they are in the default blocklist.

### Practice redirect

After grading an interview question **Good (3) or Easy (4)**, the quiz screen
shows a skippable prompt:

> **Ready to practice this one?** [Open NeetCode ↗] [Skip]

The URL comes from `practice_url` in frontmatter. Tapping it opens the URL in
the external browser (Safari). This bridges the gap between pattern recall
(what flashcards do well) and actual problem-solving practice (what builds
transfer). The prompt is suppressed for Again (1) and Hard (2) grades — no
point solving a problem whose approach you haven't absorbed yet.

This feature is MVP. It requires `url_launcher` in pubspec.

### Question sources and curation

The authoritative DS&A question list is **NeetCode 150** (supersedes Blind 75).
It covers all major patterns and is ranked by frequency. For system design,
**Alex Xu System Design Interview Vol 1 & 2** provides ~40 canonical design
problems. For blockchain, questions are curated from ecosystem resources.

Interview question cards are not generated in bulk at project start. They are
added incrementally, aligned with the weekly study sequence in
`_meta/curriculum.md`.

---

## Language & Framework Cards

Language and framework syntax cards use `type: flashcard` with the
`lang-frameworks` domain. They train recall of syntax, idioms, and common
patterns that are easy to forget when you use a language less frequently or
lean heavily on autocomplete.

### Frontmatter

```yaml
---
id: <uuid>
type: flashcard
tags:
  - lang-frameworks             # domain tag — always required
  - sql                         # the specific language or framework
  - postgresql                  # optionally the specific dialect/implementation
tiers:
  lang-frameworks: 1            # 1=basic syntax | 2=common patterns | 3=advanced | 4=internals
created: 2024-01-15
---
```

### Body

```markdown
# SQL — Window Functions

Window functions compute aggregates over a related set of rows without
collapsing them like GROUP BY does — the current row remains visible alongside
its computed aggregate.

## Syntax

```sql
SELECT
    name,
    salary,
    RANK() OVER (
        PARTITION BY department
        ORDER BY salary DESC
    ) AS dept_rank,
    SUM(salary) OVER (PARTITION BY department) AS dept_total
FROM employees;
```

`PARTITION BY` scopes the window (like GROUP BY but non-collapsing).
`ORDER BY` inside OVER sets the frame ordering, not the final result ordering.

## Common Functions

| Function | Behavior |
|---|---|
| `ROW_NUMBER()` | Unique sequential integer, no ties |
| `RANK()` | Rank with gaps for ties (1, 1, 3) |
| `DENSE_RANK()` | Rank without gaps (1, 1, 2) |
| `LAG(col, n)` | Value n rows before the current |
| `LEAD(col, n)` | Value n rows after the current |
| `SUM/AVG/COUNT OVER` | Running or partitioned aggregate |

## Gotchas

- Window functions execute **after** `WHERE` and `GROUP BY`, **before** the outer `ORDER BY`
- You cannot use a window function in a `WHERE` clause — wrap in a subquery or CTE
- Omitting `PARTITION BY` applies the window over the entire result set
- `ORDER BY` in `OVER` affects the frame calculation, not output row order

## Resources

- PostgreSQL docs: https://www.postgresql.org/docs/current/tutorial-window.html
```

---

## Wikilinks

Use `[[concept-name]]` linking to the filename without `.md`. Aliased links:
`[[filename|Display Name]]`. Links anywhere in the body are indexed. The
`## Related` section is the canonical place for cross-links.

Links to cards outside the `Flashcards/` folder appear as unresolved in Onyx
but work normally in Obsidian. Expected behavior.

---

## AI Card Creation Skill

Save the following as a system prompt in your Neovim Claude plugin. Invoke it
when generating a new card for a topic.

**The design rationale for this skill is in `docs/learning-science.md`.** The
short version: encode rules and recognition triggers, not rote facts. Rule-based
knowledge is empirically more durable. Conditional knowledge ("when to use") is
what interviewers actually test.

```
You are a card author for the Onyx flashcard app, which is used for SWE
interview preparation. When given a topic, produce a single complete Obsidian
markdown card file.

## Core principles (read these before writing anything)

1. **Encode the underlying rule or principle, not the fact.**
   Bad: "BFS uses a queue."
   Good: "BFS explores all neighbors at the current depth before going deeper —
   the queue enforces this level-by-level guarantee, which is why BFS finds
   shortest paths in unweighted graphs."
   The reader should be able to reconstruct specific facts from the principle.

2. **The "When to Use" section is the most important section.**
   It must encode observable PROBLEM SIGNALS — specific characteristics that
   appear in a problem statement and indicate this pattern applies. Not abstract
   rules; concrete signals. Include comparison vs. alternatives and explicit
   anti-patterns ("do not use when").

3. **Three knowledge types need different treatment:**
   - Declarative (what/why): Key Properties, Time & Space Complexity
   - Procedural (how): Implementation Notes
   - Conditional (when): When to Use — HIGHEST PRIORITY

4. **Sections are independently quizzed.** Each section will be shown as a
   standalone quiz item: front = "Topic — Section Heading", back = section
   content. Every section must be self-contained and useful in isolation.

5. **Card granularity is flexible.** Do not artificially split or over-compress.
   Write as many sections as the topic warrants. Rich, coherent sections are
   better than many thin ones.

## Format requirements

- Generate a UUID v4 for the `id` field
- `type` must be exactly `flashcard`
- Tags must be kebab-case
- Prefer tables, bullet lists, and pseudocode over prose paragraphs
- Add [[wikilinks]] to related concepts in the body and in ## Related
- Do not add a `quiz` field to frontmatter unless explicitly asked

## "When to Use" section format

This section should follow this structure:

**Problem signals that suggest [topic]:**
- [Specific, observable signal from a problem statement]
- [Keywords or phrases that appear in problems using this approach]
- [Data shape or constraint that points to this pattern]

**Prefer [topic] over alternatives when:**
- Over [alternative A]: [specific reason — what makes this better here]
- Over [alternative B]: [specific reason]

**Do not use when:**
- [Specific condition where a simpler/better alternative exists → name it]

## Preferred section headings (use when applicable)

  ## When to Use           ← required for algorithm/data-structure cards
  ## Time & Space Complexity
  ## Key Properties
  ## Common Pitfalls
  ## Trade-offs
  ## Implementation Notes
  ## Variants
  ## Related

## Tag taxonomy (prefer these, add new ones as needed)

  data-structures, algorithms, sorting, searching, binary-search,
  dynamic-programming, greedy, divide-and-conquer, backtracking,
  bit-manipulation, two-pointers, sliding-window, bfs, dfs, graph,
  tree, binary-tree, bst, trie, heap, hash-map, stack, queue,
  time-complexity, space-complexity, big-o, system-design, swe-interview

## Output format

Output ONLY the markdown file content. Start with the YAML frontmatter block.
No preamble, no explanation, no trailing commentary.

---
id: <uuid-v4>
type: flashcard
tags:
  - <tag>
created: <YYYY-MM-DD>
---

# <Concept Title>

<1–2 sentence principle-first overview: what is this and why does it work>

## When to Use

**Problem signals that suggest [concept]:**
- <signal>

**Prefer [concept] over alternatives when:**
- Over <alternative>: <reason>

**Do not use when:**
- <condition> → use <alternative> instead

## <Next section>

<content>

## Related

- [[related-concept]]
```
