# Onyx

A local-first, general study app. Cards live as Markdown in a plain folder — an
Obsidian vault works as-is, but Obsidian is not required. Onyx parses and indexes
them, schedules review with [FSRS](https://github.com/open-spaced-repetition), and
uses AI to help draft and grade. It's education-first and subject-agnostic
(SWE-interview prep is one configuration among many). iOS is the real target; v1 is
offline/local-first, and an optional cloud layer (managed AI, sync, shared decks) is
reserved — see [`docs/product-direction.md`](docs/product-direction.md).

See [`docs/product-direction.md`](docs/product-direction.md) for the top-of-stack
design ("what Onyx is now"), and [`docs/INDEX.md`](docs/INDEX.md) for the full doc
set + reading order.

## Status

Working today: the vault parser + drift (SQLite) index (`card_cache` + wikilink
graph), the Riverpod data layer, and a Material 3 shell (Home · Browse · Insights
· Settings). The FSRS study loop is shipped — Quiz (review) and Learn (first
exposure), plus dedicated practice tracks (algorithms, system-design, behavioral),
a cross-track daily plan, a readiness dashboard, AI card generation/import/
coaching, and an in-app card editor. See [`docs/INDEX.md`](docs/INDEX.md) for the
current design set.

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
# NB: use `flutter pub run` — a plain `dart run build_runner` fails version
# solving here. After a major build_runner bump, clear .dart_tool/build first.
flutter pub run build_runner build --delete-conflicting-outputs

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
