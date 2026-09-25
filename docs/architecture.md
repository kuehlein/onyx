# Onyx — architecture (how it's built + the invariants)

> The **how** reference for builders. *What* + *why* live in [`user_stories/`](user_stories/index.md)
> (the source of truth); this is the implementation contract that serves it. Lean by design — if a
> rule is load-bearing it's here; everything else is in the code.

## Stack
Flutter / Dart (via Nix) · drift / SQLite (the local DB is a **derived cache**) · FSRS-6
scheduling · Riverpod 3 (codegen; `.g.dart` gitignored — regenerate with `build_runner`) · Claude
BYO-key (seamed transport; managed tier deferred). Build + test via `nix develop --command`:
`flutter analyze lib test`, `flutter test`, `flutter pub run custom_lint`.

## Layers
- `lib/core/` — pure domain logic, no Flutter/Riverpod (parsing, FSRS, readiness, registry, subject
  config). Unit-tested directly.
- `lib/shared/providers/` — Riverpod providers wiring core to state / DB / vault.
- `lib/features/` — UI (screens, sheets, widgets).
- `lib/shared/design/` — design tokens (`Dim`, `StatusColor`, `showOnyxSheet`, …).

## Data model
- **Vault** — the file tree, the source of truth. Content in user-land; app config under `_meta/`.
- **DB** — a *derived cache of one vault at a time*. Each vault's `_meta` snapshot is its durable
  copy of progress; switching vaults exports → clears → restores. **Nothing authoritative lives
  only in the DB.**
- **Card** — a markdown file: frontmatter (`id`, `type`, `tags`, `tiers`, `status`, …) + an H1
  title + sections split by the deck's parse rules. A study unit is a section (or the whole file);
  `neverQuizzed` sections + per-card `quizzable: false` are excluded.
- **Deck** — a query lens over the vault; the unit the user works in. Membership is a `CardQuery` —
  a boolean lens/filter tree (tag · folder · domain · type · tier, composed with `And`/`Or`/`Not`)
  shared with Browse (ADR-0013). (Code: `Deck` + `CardQuery`.)
- **Aim** — a target on a deck (difficulty / emphasis / durability / date); a deck holds a *set*, and
  readiness takes the **weakest link** across them. Each aim OWNS its four knobs (ADR-0006). (Code:
  `Aim` on `Deck.aims`; `ReadinessTarget` is derived from an aim for scoring.)
- **Schedule** — FSRS state / reviews / recognition / applied attempts, keyed `cardId::sectionSlug`.
- **card_links** — the card→card graph (backlinks, wikilinks).

## Invariants (load-bearing — don't break)
1. **Vault = SSoT; the DB is derived.** Never store authoritative data only in the DB.
2. **Config, not code.** The engine reads the deck/subject config; **no `if/else` on card type** —
   dispatch through the flow/scheduling config. A new subject is config, never an app-code branch.
   Enforced by the `no_card_type_branch` custom-lint (`tools/onyx_lints`); comparing to a config
   value (`c.type == flow.cardType`) is the right pattern and passes. The only exemptions are a
   built-in flow's *own* engine (the algorithm / system-design / behavioral providers + screens),
   each carrying a visible `ignore` — a new subject runs on the generic `flow_runner` path, not
   these, so the invariant still holds.
3. **Scheduling never travels.** Deck import/publish carries content only; imported cards land
   `status: draft`. Nothing about *your* schedule crosses a deck boundary.
4. **Draft exclusion.** `status: draft` cards are excluded from FSRS **and every**
   readiness / coverage / analytics denominator.
5. **Card identity = slug.** Ids are slug-normalized; joins key on `cardId::sectionSlug`, never a
   filename.
6. **Weakest-link readiness.** Readiness rolls up weakest-link (p20 floor) across domains + aims —
   never an average that lets a strong area mask a weak one.
7. **Capability-gated cloud.** Sync / accounts / managed-AI / sharing render only when a backend
   capability is reachable — **absent, never a disabled row**.
8. **Single-deck / single-aim byte-identical degradation.** One deck / one aim behaves exactly like
   the pre-multi case; the multi machinery engages only when there are several.

> **Conformance:** all 8 invariants audited **conformant** on 2026-09-25 (six-agent pass; see
> roadmap 1h). The only sanctioned type-branch residual is the `type == flashcard` concept
> predicate (invariant #2), which stays coupled to #32's concept-vs-applied model call.

## ADRs (decisions of record)
- **ADR-0001 / 0002** — the DB is a derived cache of one vault; the `_meta` snapshot is durable;
  `VaultRef` is persisted and the snapshot is swapped on a vault switch.
- **ADR-0003** — the `draft` / `active` card status + its universal exclusion.
- **ADR-0004** — the AI provider seam (BYO-key transport; managed tier deferred).
- **ADR-0005** — degradation: a single active deck shows its Home directly (with an escape hatch
  back to deck selection).
- **ADR-0006** — Deck = a pure lens; the target lives on the **Aim** (a deck holds a set of aims).
- **ADR-0007** — daily-plan allocation across aims (feasibility urgency + soft fair-queuing).
- **ADR-0008** — cram-vs-durable: honor deadlines without corrupting FSRS.
- **ADR-0009** — the Aims surface (S5) + the target-writer flip.
- **ADR-0010** — study workload: the user sets budget + proportions; the engine derives the mix.
- **ADR-0011** — load control: the engine auto-adjusts the MIX; it PROPOSES the SIZE.
- **ADR-0012** — card model: a shared component layer + quizzability precedence + edit-identity.
- **ADR-0013** — one query/lens engine: Browse filters == deck membership.
- Add new ADRs here as decisions are made; keep this the index.

## Where the rest lives
Intent (*what / why*) → [`user_stories/`](user_stories/index.md). Research foundation →
[`learning-science.md`](learning-science.md). Visual language → [`design-system.md`](design-system.md).
Sequenced work → [`roadmap.md`](roadmap.md). Historical detail → [`archive/`](archive/README.md).
