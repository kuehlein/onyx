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
