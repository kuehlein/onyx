# ADR NNNN — <short title>

- **Status:** Proposed | Accepted | Superseded by ADR-XXXX
- **Date:** YYYY-MM-DD
- **Deciders:** <who>
- **Related:** <ADRs, docs, tasks, code paths>

## Context

What problem forces a decision? The constraints, the current behaviour, and why
the status quo is inadequate. State any facts a reviewer needs (measurements, the
relevant code paths, the locked principles at stake).

## Decision

The choice, stated plainly and decisively. Include the essential mechanics or the
contract (interfaces, invariants, keys) — enough that the implementation and its
tests are pinned by this document.

## Alternatives considered

Each realistic option, and why it lost. Name the one that was closest so it isn't
"helpfully" re-introduced later.

## Consequences

- **Positive:** what this buys us.
- **Negative / trade-offs:** what it costs.
- **Known limitations & follow-ups:** what this deliberately does *not* solve, and
  the seam or task that would.

## Validation

How we know it works: the tests (especially the pure/deterministic ones), the
invariants they assert, and any CI guard that protects the decision.
