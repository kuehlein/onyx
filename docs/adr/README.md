# Architecture Decision Records

An **ADR** captures one architecturally significant decision: the context, the
choice, the alternatives considered, and the consequences. ADRs are the durable
record a maintainer or reviewer reads to understand *why* the system is the way it
is — especially important here, where scaffolding is AI-assisted and intent must
survive the handoff to human review.

## When to write one

Write an ADR when a decision is **load-bearing or hard to reverse**: data
schema/identity, sync/merge semantics, the state-management spine, security or
privacy posture, a cross-cutting seam, or anything that would be expensive to
change once data or callers depend on it. Small, local, easily-reversed choices
belong in code comments + the PR description, not an ADR.

## How

1. Copy [`0000-template.md`](0000-template.md) to `NNNN-short-title.md` (next number).
2. Fill it in; keep it concise and decisive. Status starts `Proposed`; set
   `Accepted` when merged.
3. Reference the ADR from the code it governs and from the PR.
4. Never rewrite history: to change a past decision, add a new ADR that
   **supersedes** the old one (and mark the old one `Superseded by NNNN`).

## Index

| ADR | Title | Status |
|----|-------|--------|
| [0001](0001-progress-sync-merge.md) | Progress sync via a convergent snapshot merge | Accepted |
| [0002](0002-on-device-content-source.md) | On-device content source | Accepted |
| [0003](0003-card-status-and-deck-seam.md) | Card status & deck seam | Accepted |
| [0004](0004-ai-provider-seam.md) | AI provider seam | Accepted |
| [0005](0005-focused-goal-spine.md) | The focusedGoalProvider spine | Accepted |
| [0006](0006-deck-and-aims-model.md) | Deck as a lens; the target lives on the aim | Accepted |
| [0007](0007-daily-plan-allocation-across-aims.md) | Daily-plan allocation across aims (feasibility urgency, soft fair-queuing) | Accepted |
| [0008](0008-cram-vs-durable-fsrs-safe-deadlines.md) | Cram-vs-durable: honor deadlines without corrupting FSRS | Accepted |
| [0009](0009-aims-surface-design.md) | The Aims surface (S5e): design + the target-writer flip | Accepted |
| [0010](0010-workload-budget-and-proportions.md) | Study workload: user sets budget + proportions; the engine derives the mix | Accepted |
| [0011](0011-load-control-auto-mix-propose-size.md) | Load control: the engine auto-adjusts the mix; it proposes (never auto-writes) the size | Accepted |
| [0012](0012-card-model-shared-components.md) | Card model: a shared component layer (not a mode-widget), quizzability precedence, edit-identity | Accepted |
| [0013](0013-unified-query-lens-engine.md) | One query/lens engine: Browse filters == deck membership | Accepted |
| [0014](0014-fsrs-tuning-retention-knob-learn-easy-optimizer.md) | FSRS tuning (#32): global retention knob, guarded Learn-Easy, deferred optimizer | Accepted |
