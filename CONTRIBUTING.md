# Contributing to Onyx

Onyx is a calm, local-first study app (Flutter/Dart). This guide is the entry
point for a human maintainer or reviewer. Start with **[`docs/user_stories/`](docs/user_stories/index.md)**
(what Onyx is — the source of truth) and **[`docs/README.md`](docs/README.md)** (the doc map and reading order).

> **AI coding agents:** start with **[`AGENTS.md`](AGENTS.md)** — the terse agent-facing
> entry (commands, boundaries, working norms) that all agent tools read; it links back
> here for the full conventions.

## Getting started

The toolchain is pinned with a Nix flake (Flutter, Dart, lefthook, sqlite, and a
Linux-desktop build toolchain). With [direnv](https://direnv.net/) the shell loads
automatically; otherwise prefix commands with `nix develop --command`.

```sh
nix develop --command bash -c 'flutter pub get'
# run the desktop preview against the dev vault (see README)
ONYX_VAULT_PATH="$PWD/staging/flashcards" nix develop --command bash -c 'flutter run -d linux'
```

Riverpod/drift codegen (regenerate after touching `@riverpod` or drift tables;
`*.g.dart` is gitignored):

```sh
nix develop --command bash -c 'flutter pub run build_runner build --delete-conflicting-outputs'
```

## Everyday commands

```sh
nix develop --command bash -c 'dart format lib/ test/'      # format (do this before committing)
nix develop --command bash -c 'flutter analyze'             # must be clean — info-level lints fail CI
nix develop --command bash -c 'flutter test'                # full suite
nix develop --command bash -c 'flutter test test/unit/foo_test.dart'
```

## Conventions

- **Commits:** Conventional Commits — `type(scope): subject` with the subject ≤72
  chars. Valid types: `feat|fix|docs|refactor|test|chore|perf|style|revert`. (Card
  content edits use `chore(cards): …`, never a bare `cards:`.) A lefthook `commit-msg`
  hook enforces the regex; a `pre-commit` hook runs `dart format --set-exit-if-changed`
  + `flutter analyze` — so **format before you commit** or the reflow aborts it.
- **Branches & PRs:** land non-trivial work on a **feature branch** (`phase-0/…`,
  `feat/…`, `fix/…`) and open a PR for human review. Keep each PR a **single,
  self-contained, reviewable unit** with tests. `main` stays releasable.
- **Tests:** new logic ships with tests. Pure logic → a plain unit test (no
  sqlite/Flutter deps where avoidable). DB-touching tests use an in-memory drift
  DB and skip cleanly when host `libsqlite3` is unavailable (see
  `test/unit/snapshot_test.dart` for the pattern).
- **Code style:** `dart format` is authoritative; `flutter analyze` must be clean.
  Public APIs and any non-obvious behaviour carry doc comments explaining the
  *why*. Match the surrounding code's idiom, naming, and comment density.

## Architecture Decision Records (ADRs)

Load-bearing or hard-to-reverse decisions (schema/identity, sync/merge semantics,
the provider spine, cross-cutting seams) are recorded as **ADRs** in
[`docs/adr/`](docs/adr/). Before implementing one of these, write an ADR from
[`docs/adr/0000-template.md`](docs/adr/0000-template.md); reference it from the code
and the PR. A reviewer should be able to understand *why* a design is the way it is
from its ADR without archaeology. Smaller decisions live in code comments + the PR.

## AI-assisted development (provenance)

Parts of this codebase are scaffolded with AI assistance under a deliberate split:
a **max-effort model writes the load-bearing contract + a reference implementation
+ tests**; a **lower-effort model fills in the spec-driven and mechanical work**
against it (see the triage in the project notes). Consequences for reviewers:

- AI-authored commits are co-authored (`Co-Authored-By:` trailer) and scoped to
  one reviewable unit, exactly like a human PR.
- **The ADR + tests are the contract.** Review those first; they encode the intent
  the fill-in work must satisfy.
- Treat AI output as a proposal, not ground truth — the same review bar as any
  contributor. Verify claims against the code and the tests.

## Reviewer checklist

- [ ] Scope is one coherent unit; `main` stays releasable.
- [ ] `dart format` clean, `flutter analyze` clean, `flutter test` green.
- [ ] New/changed behaviour is covered by tests; correctness-critical logic has a
      pure, deterministic test.
- [ ] A load-bearing decision has an ADR; the code references it.
- [ ] No regression of the load-bearing invariants in `docs/architecture.md`
      (honesty, calm, anti-gamification, local-first degradation, per-aim/weakest-link truth).
- [ ] User-facing copy stays subject-neutral via the `Vocabulary` seam (“folder”
      not “vault”, “AI” not “Claude”; assessment nouns like “interview” come from the
      subject template, never hardcoded in shared engine copy).
