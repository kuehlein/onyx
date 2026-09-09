---
name: create-cards
description: Author new study flashcards for the Onyx vault (staging/flashcards/*.md). Use when generating or adding concept cards for a domain/topic. Encodes the card schema, learning-science structure, the glossary policy + linking, and the generate → independent-adversarial-audit method with its operational lessons.
---

# Creating Onyx study cards

Cards are the app's backbone — a wrong or poorly-structured card means the user
learns bad material. Optimize for **correctness** and **retrieval**. Follow this
method; don't shortcut the audit.

## 1. Format (authoritative: `docs/card-schema.md`)
One card = one markdown file in `staging/flashcards/<slug>.md`:
- Frontmatter: `id: <slug>` · `type: flashcard` (or `algorithm`) · `tags: [domain, …]`
  (the **first tag is the domain**) · `tiers: { <domain>: <N> }` (1 = most
  foundational → higher = more specialist; see §3 — tier is hierarchy, NOT
  importance) · `created: <today ISO>` · `confidence: high|medium|low` · `priority`.
- Body: H1 title → 1-paragraph **principle-first** overview → a `> [!tip]
  Recognition …` callout → H2 sections. Use a real existing high-confidence card
  as the style template (e.g. `database-indexing.md` for systems, `two-pointers.md`
  for DS&A).
- Sections: `## When to Use`, `## Key Properties`, `## Time & Space Complexity`
  (only if genuinely meaningful — omit for most systems topics; use a comparison
  table instead), `## Common Pitfalls`, `## Trade-offs`, `## Implementation Notes`
  (reference code/config), `## Variants` (optional), `## Resources` (2–4 real,
  verified URLs), `## Related` (kebab-case `[[wikilinks]]`).
- Blocklisted from review (reference-only): Resources, Related, Variants,
  Implementation Notes/code. So the *load-bearing* quizzed sections are When to
  Use, Key Properties, Complexity, Common Pitfalls, Trade-offs — write each as a
  self-contained retrieval unit.

## 2. Learning-science structure (authoritative: `docs/learning-science.md`)
- **Lead with the recognition trigger.** Conditional knowledge ("what observable
  signals mean *use this*") is the single highest-value thing — the interview
  bottleneck is pattern recognition. Make the callout + `When to Use` crisp and
  first-class.
- **Encode principles, not rote facts** — the learner should reconstruct an
  answer from the principle. Code is *reference* (reconstruct from the approach),
  never a memorize-verbatim target.
- **Tight, atomic-ish sections** — don't obsess over one-fact-per-card (no RCT
  backs that), but each quizzed section should target one coherent idea with the
  shortest sufficient answer; split a section that bundles independent facts.
- **Answerable-from-cue** — effortful recall helps *only on success*; a section so
  overloaded/ambiguous that recall fails just churns in FSRS. Make it winnable.
- **Disambiguate interference (highest-value)** — interference between confusable
  sibling cards is the top cause of forgetting. When a card is near-adjacent to
  others, add an explicit contrast cue ("vs. X" line / comparison row naming the
  distinguishing signal) and use precise prompts, not generic ones.
- **No rote-enumeration recall targets** — make the recall target the principle
  that generates a list; never "turn lists into narratives" (evidence-refuted).
- Presentation: one clear through-line, segmented sections, syntax-highlighted code.

## 3. Domains, tiers, weighting
- Domains in use: `ds-a`, `system-design`, `databases`, `distributed-systems`,
  `networking`, `concurrency`, `security`, `backend`. `domainWeight()`
  (`core/readiness/target.dart`) treats the systems/backend family as one
  weighted group; new backend domains ride it. Tag the domain as the first tag.
- **Tier = knowledge-hierarchy depth within a domain, NOT importance.** Set it by
  "how much must you already know to reach this?", never by "how much does the
  backend interview care?" (importance/relevance is derived from the target, not
  stored). Open-ended; today the deck uses 1–3. SWE rubric:
  - **Tier 1 — foundational:** primitives learned first, prerequisites for the
    rest (e.g. `array`, `hash-map`, `stack`, `big-o-complexity`; `http-https`,
    `dns`, `caching`, `load-balancing`, `sql-vs-nosql`, `acid-properties`;
    `authentication-vs-authorization`).
  - **Tier 2 — intermediate:** standard patterns/mechanisms built on tier 1
    (e.g. `bfs`, `dfs`, `two-pointers`, `sliding-window`, `binary-search`,
    `heap`, `prefix-sum`; `database-indexing`, `replication-models`,
    `rate-limiting`, `message-queues`, `transaction-isolation-levels`,
    `jwt-and-sessions`).
  - **Tier 3 — advanced:** specialist/deep, assume 1–2 (e.g. `dijkstra`, `mst`,
    `union-find`, `trie`, `topological-sort`, `dynamic-programming-2d`;
    `consensus`, `two-phase-commit`, `saga-pattern`, `consistency-models`,
    `mvcc`, `change-data-capture`, `event-sourcing`, `consistent-hashing`;
    `digital-signatures`, `oauth2-and-oidc`).
  A tier-3-but-essential topic (e.g. `consensus` for backend) stays high-value
  via *relevance*, not by demoting its tier. (These examples are SWE-domain
  specific; the tier *concept* above is generic — when #30 splits the skill, the
  examples move to the SWE profile.)
- Curriculum of what to build + priority tags: `docs/curriculum.md`. Build
  CORE → IMPORTANT. Progress tracked in the `backend-curriculum-build` memory.

## 4. Glossary policy + linking (authoritative: `docs/card-schema.md` "Glossary linking")
- Glossary = `staging/flashcards/_meta/glossary.md`; tap-to-define popover;
  anchors are **GitHub-slugs** of headings (`## Consistent Hashing` →
  `#consistent-hashing`), resolved by `glossarySlug` in `core/ai/glossary.dart`.
- It holds **acronyms AND nuanced technical terms** whose particulars are easy to
  misremember or aren't everyday vocabulary (idempotency, quorum, write skew,
  linearizability). Be liberal, not exhaustive — **skip trivially basic** concepts
  (binary search, array, for loop).
- Link the **first prose occurrence** of a term that has a heading (not in code,
  frontmatter, Resources/Related). If a term deserves a definition and none
  exists, **add the entry** (alphabetically; `## Term` + 1–2 sentence verified
  definition) then link it. First occurrence only; don't over-link.
- **Trap:** never link "write amplification" to `#wa` — that anchor is "Wrong
  Answer". Use `#write-amplification`.

## 5. The method: generate → INDEPENDENT adversarial audit
Do this as background `Workflow`s (see saved scripts under the session's
`workflows/scripts/`; e.g. `card-gen-*`, `card-audit-new-2-*`).

**Phase A — generate.** One `agentType: 'general-purpose'` agent per card:
read `card-schema.md` + `learning-science.md` + a template card + the glossary;
author the card grounded in **primary sources** (DDIA, RFCs, official docs,
papers) — prioritize DDIA for data/distributed; corroborate version-/vendor-
sensitive claims with WebSearch; **adversarially self-verify** every claim; set
honest confidence; add glossary links.

**Phase B — independent audit (do NOT skip).** A *different* skeptic agent per
card (one it didn't write) that tries to **falsify** every claim, checks
learning-structure, fixes surgically, links the glossary, and sets an honest
confidence. Self-verification alone is too weak for the backbone — the
independent pass reliably catches real errors (clustered-PK O(log n) not O(1);
OAuth 2.1 removed implicit/ROPC; Cassandra num_tokens 256→16; snapshot isolation
allows write skew; etc.).

Use a StructuredOutput schema so results come back parseable.

## 6. Operational lessons (learned the hard way)
- **Keep each agent's task LEAN or it drops the final StructuredOutput call.**
  Inline the key rules rather than making it read every doc; scope WebSearch to
  version/vendor/spec-sensitive claims; keep the schema small; end the prompt
  with "you MUST finish by calling StructuredOutput." Audit **≤ ~20 cards/run**.
- After each batch: run the parser smoke test
  (`flutter test test/unit/card_parser_test.dart` — it parses every staged card
  and catches malformed frontmatter), then commit + push. Commit-msg must be a
  conventional type with a **≤72-char** subject and end with the project's
  Co-Authored-By trailer.
- `created:` = today. `id:` = the filename slug. Don't invent UUIDs.
- Forward `[[wikilinks]]` to not-yet-built cards are fine (inert until authored).
- The format pre-commit hook reformats then aborts; re-`git add` + re-commit.
