# The Onyx card-authoring method (universal)

This is the **domain-agnostic** method for authoring Onyx cards — the same whether
the vault studies software interviews, a spoken language, anatomy, or case law. It
encodes *why* cards are shaped the way they are (so you can apply judgment), the
format, and the generate → self-test/audit loop. Domain specifics (which topics,
which sources, tags, tiers) live in this subject's **profile** docs (e.g.
`curriculum.md`, `tags.md`); this file never hardcodes a domain.

> Cards are the backbone: a wrong or poorly-structured card teaches the learner bad
> material or wastes their retrieval effort. Optimize for **correctness** and
> **retrievability**. Don't shortcut the audit.

## 1. What a card is

One card = one Markdown file = **one idea**, shaped so the learner can (a) be shown
a *cue*, (b) *recall* the answer from memory, (c) *reveal* it, and (d) *grade*
themselves honestly. Each quizzable `## section` is scheduled independently, so
each must stand alone as a retrieval target. If a chunk can't be recalled and
self-graded on its own, it isn't a card — it's a note; make it reference or cut it.

## 2. Learning science — the quality bar (the *why*)

These are the load-bearing principles. When a formatting rule and a principle
conflict, the principle wins.

- **Lead with the recognition trigger.** The highest-value knowledge is
  *conditional*: "what observable signals mean *use this idea here*." Put it first
  and make it concrete. [SWE example: a `When to Use` section listing problem
  signals. Language example: the situation a grammar pattern is used in. Medicine:
  the presenting symptoms that point to a diagnosis.] Vague triggers ("when you need
  speed") train nothing; name the *observable* cue.
- **Encode the principle, not the fact.** Write the back so the learner can
  *reconstruct* specifics from a rule they understand, not memorize a string.
  ("BFS explores level by level, which is *why* it finds shortest paths in an
  unweighted graph" beats "BFS uses a queue.")
- **Atomic-ish, not atomised.** One idea per card, but a rich section (a short
  explanation + a small table) is fine — don't shatter naturally-joined facts
  (time and space complexity belong together). The test: could a learner hold the
  answer in their head and grade it cleanly?
- **The generation effect is the whole point.** Memory is built by *producing* an
  answer, not reading one. Every card must demand production. This is also why Onyx
  makes new cards `draft` and promotes them only after a retrieval pass — authoring
  a card is not the same as learning it.
- **Design for discriminability.** Cards that are too similar interfere. If two
  cards could be confused, sharpen the cue so each has a distinct trigger, or merge
  them. Contrast is a feature: a good card often says "…and NOT when {near-miss}."
- **Spacing is the app's job, never yours.** Don't build "review schedules" into
  content or split a card to force more reps. FSRS schedules each card optimally;
  your job is the *content*, not the timing.

## 3. The format (authoritative: `_meta/conventions.md`)

One file per card, in the shape the parser expects:
- **Frontmatter**: `id` · `type:` (must match a flow in `_meta/onyx-subject.yaml`) ·
  `tags` (the first is the domain; check `_meta/tags.md` before inventing one) ·
  `tiers` (per-domain hierarchy — *foundational→specialist*, NOT importance) ·
  `created` · `confidence` (see §5).
- **Body**: H1 title → one principle-first overview sentence → an optional
  recognition callout → `## sections`.
- **Sections** split on the heading level this subject configures (default `##`).
  Some headings are **reference-only, never quizzed** (the never-quizzed list — by
  default Resources, Related, Variants, and implementation/code, since code is
  reconstructed from the approach, not memorized). Everything else is a retrieval
  unit: write each to be self-contained.

Use a real high-confidence card in this vault as your style template rather than
inventing a layout.

## 4. The authoring loop

1. **Decide the unit.** One idea. Pick its `type:` (a configured flow) and its
   place in the domain profile (domain tag + tier). Check `tags.md` first.
2. **Draft** in the format, leading with the recognition trigger, encoding the
   principle. Keep prose tight; prefer a table to a paragraph for comparisons.
3. **Self-test / audit** (§5) — the non-negotiable step.
4. **Link** related cards with `[[wikilinks]]` (dangling is fine — it marks a gap).

## 5. The audit — don't skip it

- **Self-test every section.** Read *only* the cue and answer from scratch. If you
  can't, or the answer isn't reconstructable from a stated principle, the card is
  wrong — fix the card, don't lower the bar.
- **Verify correctness for factual domains.** For anything a learner could be
  misled by, check claims against a real source (name it in `## Resources` /
  `## References`). Do **not** copy sources verbatim (paraphrase; respect
  copyright). A strong pattern for high-stakes decks: generate the card, then audit
  it with a *fresh, adversarial* pass whose only job is to find errors and
  under-specified triggers — treat that pass's verdict as authoritative.
- **`confidence`** records trust-at-authoring (`high` when you verified it;
  `medium`/`low` when unsure). It is orthogonal to a card's review schedule — it
  tells the learner how skeptical to be.

## 6. Specializing for a domain (the profile)

Everything domain-specific — which topics deserve cards, how deep, in what order,
the tag vocabulary, the tier meanings, the authoritative sources — lives in the
**profile** docs, not here. This vault ships one example profile (see
`curriculum.md` + `tags.md`). To author for a different subject, replace those; the
method above does not change.

## 7. Anti-patterns (cut these on sight)

- A section that just **lists facts** with no generating principle.
- The back **restating the front** ("Key properties of X include…").
- **Over-granular** cards that shatter one idea into many (fights bounded sessions).
- A **missing or vague recognition trigger** — the most common and most costly flaw.
- **Inventing tags/tiers** instead of using the profile — it silently breaks
  grouping and readiness.
- Building **schedule/importance** into content — that's the engine's job, not the
  card's.
