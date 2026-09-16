# Study Goals — a query-lens overlay on the vault (#30d + #50 fused)

**Status:** DONE 2026-09-16. Model locked 2026-09-14; built M1–M2 + G1–G7 with
three adversarial passes. Interpretation layer (M1/M2) + the study-goal grouping
layer (G1–G7) shipped: goals persist, are created/edited/graduated in-app, drive
per-goal readiness + a shared cross-goal budget, and surface as the lanes hub —
with single-goal vaults byte-identical to before (the "one goal → today's Home"
degradation). Post-#30d follow-ups also done: the in-lane study queues
(review/learn/algo/SD) scope to the active goal, and **all** per-goal scoring —
readiness, ladder, and forecast — grades against each goal's own template
(multi-template; `ReadinessTarget` carries a transient `TargetSpec`, pace was
already goal-correct). The multi-template story is now complete. Remaining: a live
conversation/practice screen (deferred from #30c); then #50 second-brain.

## North star

**Onyx overlays *study goals* on a plain Obsidian vault.** A goal is a named,
configured, scheduled *view* of a set of related cards, where the set is defined
by a **query** (tag, folder, links, explicit list) — not by where the files live.
Cards are found by scanning; goals are lenses over them; a card can belong to many
goals; each goal has its own target / deadline / budget / readiness; the shared
daily time drains across the active goals. This is "accessing Obsidian
orthogonally": the vault is organized however the user likes, and a goal draws a
boundary around a relevant slice without reorganizing anything.

It subsumes every use case discussed:

| Goal | Membership (query) | Target | Deadline |
|---|---|---|---|
| SWE interview | whole vault / a tag | level · company · track | interview date |
| Calculus 101 | folder `Math/Calculus/101` or a tag | course level · exam | final exam |
| Saints debate | tag `#intercession` / a MOC's links (cross-cutting) | familiarity depth | debate date |
| Korean | folder or tag | beginner · casual | none (ongoing) |

Folders are just one selector (so the college hierarchy nests naturally); a tag
query ignores folders entirely (so the debate's scattered cards work). Goals can
be grouped for navigation (Math ▸ Calculus ▸ 101) but membership is always a
query, never a required directory layout. **We never reject a vault for its
structure** — only card metadata or a config can be "invalid."

## Three layers (keep them separate)

1. **Cards + flows — *interpretation*.** A card is any scanned note whose
   frontmatter `type:` matches a **vault-level flow vocabulary** (FlowSpec:
   scheduling, quizzability, label/icon/color, skill). A card interprets exactly
   one way regardless of how many goals include it. FSRS state is **per card /
   section, shared across goals** — you study shared knowledge once and it counts
   toward every goal that includes it. *(This is what M1/M2 built.)*
2. **Templates — *target vocabulary*.** A reusable definition of the target
   dimensions (levels / contexts / tracks / domain families) + flow relevance —
   today's `SubjectConfig`/`TargetSpec`. Discovered from vault config notes. A
   vault has ≥1 (the built-in SWE reference is the default).
3. **Goals — *grouping + assessment*.** `{ name, template, target selection,
   membership query, deadline, budget weight, lifecycle state }`. Readiness is
   computed **per goal** over its member cards using its template. Many-to-many
   with cards. This is the new primitive; grouping lives here, **not** stamped on
   the card.

## Storage (matches the "`_meta/` = app-managed" principle)

- **Cards** — normal vault notes, found by scan. Location-independent.
- **Templates** — authored, editable vault notes discovered by scan (a folder
  note or `onyx-subject.yaml`, recognized by its shape). Out of `_meta/`.
- **Goals** — **app-managed state** (my deadline, budget split, target selection,
  membership query, lifecycle) → `_meta/` keyed by goal id. Not hand-edited.
- FSRS/SRS state — per card/section, unchanged.

## What changes vs. what stands

- **Stands:** the interpretation layer — `SubjectRegistry` (id→template),
  type→flow resolution, vault-level flow vocabulary (M1/M2). `SubjectConfig`
  becomes "the template."
- **Changes:** the grouping seam moves off the card. `Card.subjectId` as a
  *grouping* mechanism is retired (a card isn't in one group); readiness/budget
  group by **goal membership queries** instead. `Card.subjectId` may be removed or
  left inert.
- **Reconcile:** the existing `PrepGoal`/goals_service (interview targeting: date +
  company + active) is a proto-goal — fold its date/target into a StudyGoal's
  target+deadline (G3). Resolve the naming collision (existing `PrepGoal`) then.

## Phases (single-subject identical throughout)

- **M1 ✅** Registry + discovery + `Card.subjectId` (interpretation foundation).
- **M2 ✅** Card behavior (card-ness/quizzability/flow) resolves per-template.
- **G1 — Goal model + implicit default goal.** Pure `StudyGoal` +
  `MembershipQuery` (all / tag / folder) evaluator over cards. A "goals" provider
  yields ONE implicit default goal for today's vault (template = discovered
  primary, membership = all cards, target + deadline = current selection).
  Downstream still reads "the goal"; one goal == today.
- **G2 — Readiness per goal.** Parameterize readiness/target/ladder/pace by
  (goal member cards, goal target). Single goal → identical numbers.
- **G3 — Multiple goals + per-goal state.** Persist each goal in `_meta/` by id;
  membership by tag/folder; fold in `PrepGoal`. Readiness per goal.
- **G4 — Cross-goal budget.** Two-level allocator: split the daily budget across
  active goals (proportion + pause; paused share redistributes), then the existing
  per-goal track meta-scheduler runs unchanged.
- **G5 — Hub UI.** Lanes = active goals; ≥2 → the "Today's mix" lanes hub, exactly
  1 → today's single-goal Home (the degradation rule). Browse gains a goal facet;
  Insights becomes per-goal.
- **G6 — Goal management + lifecycle.** Create/edit a goal (pick template,
  membership query, deadline, weight); pause / graduate / archive (term churn).
- **G7 — Validation.** A cross-cutting tag goal (debate-style) + a folder goal +
  single-goal degradation, end to end.

## Near-term selectors
Ship **tag** + **folder** membership first (a folder is a path-prefix tag). Defer
link-neighborhood/MOC, explicit lists, and boolean combinations. Tag alone covers
the cross-cutting (debate) case.

## Deferred / later
- Knowledge-graph view of a goal's card subgraph (natural #50 tie-in).
- Nested-goal rollup UI (expandable Math ▸ Calculus ▸ 101) — the model allows it
  (grouping + hierarchical queries); build the flat active-lanes experience first.
- Live conversation/practice screen + routing (from #30c Phase 4). STT (#61).

## Adversarial safeguards
Characterization tests pin single-(default-)goal behavior FIRST (readiness
numbers, card-ness, the daily plan); golden + full suite green at each commit; the
goal layer lands staged, not as one mega-diff. Watch: `card_cache` may want a
membership-friendly shape later; grep-audit remaining `activeSubject`/`subjectId`
grouping readers as they migrate to goal membership.
