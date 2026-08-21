# Card Writing Conventions

Quick reference for card authors. Full rationale in `docs/learning-science.md`
and `docs/card-schema.md` in the project repo.

## The Three Non-Negotiables

1. **Encode the rule, not the fact.** The back of every section should teach
   the principle that generates the answer, not just the answer. A reader should
   be able to reconstruct specific facts from the principle.

2. **"When to Use" is required for every algorithm/DS card.** It encodes
   recognition triggers — observable problem signals that say "reach for this
   pattern." This is the hardest knowledge to build and the most tested in
   interviews.

3. **Check `tags.md` before adding any new tag.** Tag drift breaks the graph.

---

## Section Order

Write sections in this priority order (most interview-relevant first):

1. `## When to Use` — recognition triggers, comparisons, anti-patterns
2. `## Time & Space Complexity` — with justification of *why*
3. `## Key Properties` — invariants, non-obvious behaviors
4. `## Common Pitfalls` — what breaks, what interviewers probe
5. `## Trade-offs` — vs. specific alternatives, with conditions
6. `## Implementation Notes` — pseudocode, key steps
7. `## Variants` — subtypes, related algorithms
8. `## Related` — wikilinks (not quizzed)

Not every card needs all sections. Use what's relevant.

---

## "When to Use" Format

```markdown
## When to Use

**Problem signals that suggest [concept]:**
- [Specific observable signal from a problem statement]
- [Keywords or phrases: "top K", "minimum of stream", etc.]
- [Data shape or constraint that implies this pattern]

**Prefer [concept] over alternatives when:**
- Over [A]: [specific reason — what makes this better here]
- Over [B]: [specific reason]

**Do not use when:**
- [Condition] → use [alternative] instead
```

Be concrete. "When you need fast lookup" is too vague. "When the problem asks
for O(1) average-case lookup with no ordering requirement" is actionable.

---

## Complexity Section Format

Always include justification. Listing O(n log n) without explaining *why*
trains the wrong thing — the derivation is what's actually useful.

```markdown
## Time & Space Complexity

The O(log n) time derives from [reason — e.g., "each comparison halves the
remaining search space"]. This guarantee depends on [condition].

| Operation | Average  | Worst |
|-----------|----------|-------|
| ...       | ...      | ...   |

Space: [explanation]. [Any notable edge cases for space.]
```

---

## Frontmatter Template

```yaml
---
id: <uuid-v4>            # generate with uuidgen or the AI skill
type: flashcard
tags:
  - <domain-tag>         # ds-a, system-design, blockchain, or behavioral
  - <specific-tag>       # from tags.md — check before adding
  - <category-tag>       # broader category (tree, graph, sorting, etc.)
tiers:
  <domain>: <1-4>        # per-domain tier; omit domains where not applicable
created: <YYYY-MM-DD>
---
```

Example for a cross-domain card:
```yaml
---
id: 550e8400-e29b-41d4-a716-446655440000
type: flashcard
tags:
  - ds-a
  - system-design
  - database-indexing
  - tree
  - database
tiers:
  ds-a: 3
  system-design: 1
created: 2024-01-15
---
```

---

## Wikilinks

- Use `[[filename]]` — the filename without `.md`
- Use `[[filename|Display Name]]` for aliases
- Link to related concepts inline and/or in `## Related`
- It's fine to link to cards that don't exist yet — it marks a gap to fill
- Links outside `Flashcards/` work in Obsidian but show as unresolved in Onyx

---

## What Not to Do

- **Don't just list facts.** "BFS uses a queue" is not a useful section back.
- **Don't repeat the front in the back.** If the front is "BST — Key Properties",
  the back shouldn't start with "Key properties of a BST include...".
- **Don't create overly granular cards.** A rich section with a table and three
  bullets is fine. You don't need to split time complexity and space complexity
  into separate cards — they're naturally discussed together.
- **Don't skip the domain tag.** Without `ds-a`, `system-design`, `blockchain`,
  or `behavioral`, the card won't appear in readiness tracking.
- **Don't invent tags.** Check `tags.md` first.
