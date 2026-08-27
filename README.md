# Onyx

A local-first flashcard app for SWE technical-interview prep. Cards live as
Markdown in an Obsidian vault (the source of truth); Onyx parses and indexes
them, schedules review with [FSRS](https://github.com/open-spaced-repetition),
and — eventually — uses Claude to help author and grade. iOS is the real target;
there is **no** hosted server, API, or database — everything runs on-device.

See [`docs/architecture.md`](docs/architecture.md) for the full design, and
[`docs/roadmap.md`](docs/roadmap.md) for where it's headed.

## Status

Working today: the vault parser, the drift (SQLite) schema, the vault indexer
(`card_cache` + wikilink graph), the Riverpod data layer, and a Material 3 app
shell (Home · Browse · Study · Settings). Browse lists every indexed card. The
FSRS study loop is next.

## Dev environment

The toolchain is pinned with a Nix flake (Flutter, Dart, lefthook, sqlite, and a
Linux-desktop build toolchain for local preview). With
[direnv](https://direnv.net/):

```sh
direnv allow      # loads the flake dev shell automatically on cd
```

or enter it manually:

```sh
nix develop
```

The shell installs the lefthook git hooks and puts `libsqlite3` on the loader
path (drift's tests `dlopen` it by name).

## Common tasks

Run inside the dev shell.

```sh
# Tests (unit + widget). Needs host libsqlite3, provided by the flake.
flutter test

# Regenerate code after touching drift tables or Riverpod providers.
# NB: after a major build_runner bump, clear .dart_tool/build first.
dart run build_runner build

# Static analysis + formatting (also enforced by the pre-commit hook).
flutter analyze
dart format .
```

## Running the app

### iOS (the real target — on a Mac)

```sh
flutter run            # simulator or a connected device
```

### Linux desktop (a dev convenience — preview without a Mac round-trip)

The Linux build is **not** a maintained target; it exists so the UI and the
parse → index → browse pipeline can be previewed in a native window here. The
data layer is identical across platforms, so it's a faithful preview of
everything except iOS-native bits (Keychain, the document picker, safe-area
insets).

```sh
# Point the app at a folder of card Markdown via ONYX_VAULT_PATH, then run.
ONYX_VAULT_PATH="$PWD/staging/flashcards" flutter run -d linux
```

`staging/flashcards/` holds the current staged cards, so this shows the full set
in Browse. On-device, the vault path instead comes from the document
picker/security-scoped bookmark (persisted in Settings) — `ONYX_VAULT_PATH` is a
dev-only shortcut around that.

The app's derived database lives in the application-support dir
(`~/.local/share/com.example.onyx/onyx.sqlite` on Linux) and is rebuilt from the
vault on launch, so it's safe to delete.

## TODO

possible features to add
- readiness gauge - progress bar that indicates how close to interview ready i am in a given subject (put on dashboard?)
- during quizzes, perhaps link to a leetcode problem, optionally solve it separately and self report result
- possibly have a feature to verbally answer and listen with mic, ai would analyze correctness of answer (maybe even prompt more if not fully answered)
