# Onyx docs — index & reading order

Start at the top and read down; each tier assumes the ones above it. When any older
doc disagrees with a higher one, **the higher one wins** (`product-direction.md` is
authoritative over everything).

## Tier 0 — start here
- **[product-direction.md](product-direction.md)** — *what Onyx is now.* The canonical
  top-of-stack: general/education-first, local-first *reviewing* app over a plain folder;
  the solo-core contract; hybrid-but-seamed AI; optional accounts/sync; the permissioned
  deck registry; the motivation stance; the locked non-negotiables. **Read first.**

## Tier 1 — the north-star specs
- **[ux-vision.md](ux-vision.md)** — ideal app layout & flows: the 4-tab IA, the
  `focusedGoalProvider` spine, per-surface designs, the daily loop, the phased roadmap.
- **[design-system.md](design-system.md)** — the buildable visual language: tokens,
  the widget catalog, data-viz rules, the accessibility checklist, adoption roadmap.

## Tier 2 — cross-cutting & surface deep-dives
- **[personas-and-stories.md](personas-and-stories.md)** — the five personas + jobs-to-be-done
  + user stories; the persona collisions resolved as config, not global.
- **[content-creation.md](content-creation.md)** — how content gets in (the three co-equal
  on-ramps) + the **Draft/Review gate** + self-test-then-promote. Onyx reviews, it doesn't author.
- **[registry-and-sync.md](registry-and-sync.md)** — the optional cloud layer (seams-now /
  build-later): accounts, sync, deck identity, the permissioned push/pull registry, managed-AI infra.
- **[settings-ux.md](settings-ux.md)** — settings placement + IA + copy; the directory-agnostic
  source flow; the parsing stub.

## Tier 3 — feature / domain design
- **[card-schema.md](card-schema.md)** — the card frontmatter + markdown contract.
- **[adding-a-card-type.md](adding-a-card-type.md)** — contributor how-to: add a new card `type:` / flow via the data-driven `FlowSpec` system.
- **[learning-science.md](learning-science.md)** — the retrieval/spacing/interference research the design rests on.
- **[readiness-dashboard.md](readiness-dashboard.md)** — the readiness/progress model.
- **[curriculum.md](curriculum.md)** — the built-in software-interviews example curriculum (one config, not the default).
- **[algorithm-track-design.md](algorithm-track-design.md)** · **[system-design-track-design.md](system-design-track-design.md)** · **[system-design-interviewer.md](system-design-interviewer.md)** · **[practice-flow-plan.md](practice-flow-plan.md)** — the practice tracks + the flow-generalization plan.
- **[study-cadence-design.md](study-cadence-design.md)** · **[study-plan-architecture.md](study-plan-architecture.md)** — the daily-plan / load system.
- **[learn-mode-design.md](learn-mode-design.md)** · **[coach-personas.md](coach-personas.md)** · **[ai-validation-checklist.md](ai-validation-checklist.md)** — learn mode, coach voice, AI-output validation.
- **[multi-subject-plan.md](multi-subject-plan.md)** — the query-lens study-goal model (#30d, done).

## Working notes & roadmap
- **[roadmap.md](roadmap.md)** — the two-track (client / cloud) phasing.
- **[ux-rework-stage1.md](ux-rework-stage1.md)** — the critique + architecture behind the
  2026-09-17 reframe (the reasoning; product-direction is the conclusion).

## Historical / superseded (kept for context; do not treat as current)
- **[architecture.md](architecture.md)** — describes the v1 offline core; the optional
  server/cloud layer is reserved (see registry-and-sync.md), not "no server, ever."
- **[vault-structure.md](vault-structure.md)** — the directory-driven config idea; the
  **power-path (Obsidian/markdown) only**, superseded as the universal model by the
  folder-substrate + on-ramps framing.
