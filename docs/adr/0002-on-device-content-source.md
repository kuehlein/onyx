# ADR 0002 — On-device content source (`VaultRef` + resolution)

- **Status:** Accepted
- **Date:** 2026-09-17
- **Deciders:** Kyle Uehlein (+ AI-assisted scaffolding)
- **Related:** ADR-0001 (snapshot); `docs/settings-ux.md` §3 (folder source flow),
  `docs/content-creation.md` §2.3, `docs/product-direction.md` §3–4; task #65,
  Phase-0 of `docs/roadmap.md`. Code: `lib/core/vault/vault_ref.dart`,
  `vault_ref_store.dart`, `folder_picker.dart`, `lib/shared/providers/vault.dart`.

## Context

`VaultSource` abstracts file access, but the only way to *obtain* one was
`ONYX_VAULT_PATH` (a dev/desktop env var). On a real phone `vaultSourceProvider`
returns `null` — **the app cannot get a folder on-device at all.** This blocks
onboarding and every downstream flow. The target is now **any phone (iOS +
Android)**, not iOS-only, so the mechanism must span both platforms; desktop
remains the dev/preview target.

The platforms differ in how a folder is referenced durably:

- **App-created folder** — a directory the app makes inside its **own sandbox**
  (`path_provider` documents dir). Readable by `dart:io` on *every* platform with
  **no special permission** — it's ours.
- **Existing external folder** — needs a *persistable* handle: iOS a
  **security-scoped bookmark**, Android a **Storage Access Framework `content://`
  tree URI** with persisted permission. Desktop just needs the path string.

## Decision

Introduce a small, persistable **`VaultRef`** and resolve it to a `VaultSource`:

```
VaultRef { kind: path | appManaged | iosBookmark | androidTree, value: String }
  encode() -> "<kind>:<value>"   // stored in the Preferences table under "vault_ref"
```

- **`path`** / **`appManaged`** → `DesktopVaultSource(value)` (a plain filesystem
  path; `dart:io`). `appManaged` is an app-sandbox folder and therefore works on
  **iOS and Android too**, not just desktop.
- **`iosBookmark`** (base64 bookmark) / **`androidTree`** (`content://` URI) →
  the native external-folder sources. **Not implemented in this unit** — they
  need device testing + a plugin (iOS bookmark resolve+`startAccessingSecurity…`;
  Android SAF `DocumentFile`). `resolveVaultSource` throws a documented
  `UnsupportedError` for them; the `VaultRef` persistence format already carries
  the handle, so the fill-in is contained.

**Resolution order** (`vaultSourceProvider`, kept a *sync function* so the ~13
consumers and the `overrideWithValue` test seams are unchanged): `ONYX_VAULT_PATH`
(dev wins) → the in-memory `VaultRefController` (seeded from persistence at startup
by `loadVaultRef`) → `null`.

**Picking** (`FolderPicker`): `createManaged()` — make an app-sandbox folder +
return an `appManaged` ref — works on **every platform now** (`path_provider` +
`dart:io`). `pickExisting()` (choose an *existing* external folder) is the
per-platform fill-in: it needs a directory picker + a durable handle (a plain path
on desktop, an iOS bookmark, an Android SAF URI) and device testing, so
`PlatformFolderPicker` returns null for now.

## Alternatives considered

- **Make `vaultSourceProvider` async** (read prefs in the provider). Rejected for
  this unit: it turns ~13 sync consumers into `AsyncValue` and breaks 7
  `overrideWithValue` test seams — a large, risky ripple. The controller +
  `loadVaultRef` seeding keeps the sync contract.
- **One filesystem path for everything.** Rejected: a raw external path is not
  durably readable on iOS/Android under scoped storage; needs bookmark/SAF.
- **Require an app-created folder only (no external pick).** Rejected as the *only*
  option (the power user wants their existing Obsidian folder), but it is exactly
  why `createManaged` ships first and cross-platform.

## Consequences

- **Positive:** unblocks on-device use *now* via `createManaged` (cross-platform,
  no native code); a clean persistable `VaultRef` seam; env still wins so dev is
  unchanged; sync provider + test overrides preserved; the hard native work is
  isolated behind two `VaultRef` kinds.
- **Trade-offs / known limitations (fill-in):** external-folder pick on iOS
  (security-scoped bookmark) and robust Android SAF (persisted `content://` +
  a `DocumentFile`-backed `VaultSource`) are **not implemented here** — they throw
  `UnsupportedError` and need device testing. `pickExisting()` likewise returns
  null until the per-platform picker + durable handle are wired; `createManaged`
  is the working cross-platform on-ramp meanwhile. The Settings/onboarding UI that *calls*
  the picker + persists the ref is a separate (UI) unit; this provides the store,
  controller, resolver, and picker service it will use.

## Validation

- `test/unit/vault_ref_test.dart` (pure): `encode`/`decode` round-trips for every
  kind; `decode` of null/empty/garbage → `null`; `resolveVaultSource` returns a
  `DesktopVaultSource` rooted at `value` for `path`/`appManaged` and throws
  `UnsupportedError` for `iosBookmark`/`androidTree`; value equality.
- `test/unit/vault_ref_store_test.dart` (in-memory DB): save→load round-trip,
  empty→null, clear→null.
