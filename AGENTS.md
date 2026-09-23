# AGENTS.md — working in Onyx

Onyx is a calm, local-first study/flashcard app (Flutter/Dart; drift/SQLite; FSRS-6;
Claude BYO-key; Obsidian-vault markdown). This is the entry point for any AI coding
agent. It's deliberately terse and points to the canonical docs rather than
duplicating them.

## Read first
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — full conventions (setup, commands, commits, tests, review).
- **[docs/INDEX.md](docs/INDEX.md)** — the doc map + reading order.
- **[docs/user_stories/](docs/user_stories/index.md)** — product intent + the anti-drift contract. **This is the source of truth.**
- **[docs/roadmap.md](docs/roadmap.md)** — sequenced work (what to build next). **Drive work from here, not from memory.**
- **[docs/adr/README.md](docs/adr/README.md)** — Architecture Decision Records: the *why* behind load-bearing choices.
- **[docs/architecture.md](docs/architecture.md)** — invariants · **[docs/glossary.md](docs/glossary.md)** — terminology.

## Environment & commands
The toolchain is pinned with Nix. With direnv the shell auto-loads; otherwise prefix
every command with `nix develop --command bash -c '…'`.

```sh
dart format lib/ test/                 # before committing (or the pre-commit hook reflows + aborts)
flutter analyze                        # must be clean — info-level lints fail CI
flutter test                           # full suite; or: flutter test test/unit/foo_test.dart
flutter pub run build_runner build --delete-conflicting-outputs   # after @riverpod / drift edits
```
Desktop preview against the dev vault:
```sh
ONYX_VAULT_PATH="$PWD/staging/flashcards" nix develop --command bash -c 'flutter run -d linux'
```

## Commits
- **Conventional Commits**, subject **≤72 chars**. Types: `feat|fix|docs|refactor|test|chore|perf|style|revert`. Card-content edits use `chore(cards): …` (never a bare `cards:`).
- A lefthook `commit-msg` hook enforces the format; a `pre-commit` hook runs format + analyze — **format before you commit** or the reflow aborts it.
- AI-authored commits carry a `Co-Authored-By:` trailer. Ship each change as one small, green, reviewable unit; keep `main` releasable. (Branch/PR policy: see CONTRIBUTING.md.)

## Boundaries — do not touch
- **`staging/`** — live user vault content (the CS deck). Never modify it; the app writes it at runtime.
- **`*.g.dart`** — generated (riverpod/drift) and gitignored. **Regenerate** with `build_runner`; never hand-edit.

## Working norms (how we avoid drift)
- **Green before commit:** `dart format` + `flutter analyze` clean + `flutter test` green.
- **Decisions:** load-bearing or hard-to-reverse → write an **ADR** in `docs/adr/` (see its README for the bar + template). Pick the next number by **listing `docs/adr/`** — not grep; an unreferenced file is easy to miss. Cite the ADR from the code it governs as `nNNN`.
- **Refactors:** **delete** dead/excess code — don't rename-and-carry it. When restructuring behavior, keep the safe/degraded case **byte-identical** and prove it with the suite ("make readers honor the new shape first, then flip the writers").
- **Docs vs memory:** durable decisions live in ADRs; the roadmap + user-stories are the source of truth. Auto-memory (`~/.claude/…`) holds preferences/process, not repo facts — don't duplicate the repo there.
- **Copy:** engine + user-facing copy stays subject-neutral via the `Vocabulary` seam (see `docs/glossary.md`) — e.g. "folder" not "vault", "AI" not "Claude".
