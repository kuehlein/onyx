# Onboarding

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.

**Purpose.** The first-run path after installing: set up a local identity + a vault, then land
the user in their first deck.
**Scope.** App / vault level.
**Personas.** All. P4 brings their own key; P2/P3 create a deck; P1 joins a class; P5 may pull a
deck they'll later publish; P6 pulls a deck.
**Reached from.** Fresh install only (or after deleting/resetting the account — see below).
**MVP.** Local identity + point-at/create a vault + create the first deck. **Non-MVP:** upstream
sync account, managed-AI billing, class membership.

## What it does
- **Create a local "account"** — identity is local-first; the "account" is mostly optional
  capability toggles, each *absent* until it's reachable (never a dead row):
  - Password-protect the app? (set a password) — [MVP-optional]
    - Encrypt the contents of the vault as well? — [MVP-optional]
  - Push/pull from upstream? → a real account + email verification — [later, cloud track]
    - Can users pull without an account? I think that that should be fine?
  - Backups? → a real account + email verification — [later, cloud track]
  - Let us manage your AI usage? → payment + usage limits — [later, cloud track]
  - Are you in a class? → a class code; read/write permissions on class-published content — [non-MVP]
    - This question should perhaps be earlier on in the flow to 
- **Get started** — [MVP]
  - No decks yet → route straight into the **create-a-deck** flow ([deck_creation](deck_creation.md)) or pull a deck from upstream.
  - Optional: FAQ link, a few tips, seed a couple of useful settings.

## Open questions → recommendations
- **"None of this is coded out yet — needs ideation."**
  **Rec.** MVP onboarding is two steps: **(1) choose or create a folder (the vault)**, then
  **(2) create (or pull) your first deck**. Everything else (password, sync, managed AI, class)
  is a capability-gated add-on, absent unless its backend is reachable — so the account/billing/
  class screens don't exist in the offline MVP. This resolves the tracked
  folder-first-vs-"three co-equal choices" tension (old #86 / `product-direction §5`): folder
  first, and the *three on-ramps* (existing lens / create cards / pull upstream) live inside
  step 2, not on the welcome screen.
  **Status.** Accepted
- **"Accessed only after a fresh download / deleting the account?"**
  **Rec.** Yes for the *guided* first-run. Also make the same steps reachable non-guided from
  Settings ("switch / reset vault") so a returning user can re-point without reinstalling — but
  the guided flow itself fires once.
  **Status.** Accepted
- **Consider adding a QR code scan to set up an account with defaults?** It would put you in a class and pull one or more decks into your vault with pre configured settings. This would not be MVP and would need a bit of ideation (e.g., a student that already has the app from a different class setting up the app for a new class, we wouldn't want to overwrite all of their existing data).
  **Status.** New question, needs rec (you can ask me via the prompt)

## Cross-refs
[deck_creation](deck_creation.md) · [settings](settings.md) (account/sync/AI rows) ·
older: `product-direction.md §5`, `settings-ux.md §3`, `registry-and-sync.md` (cloud track).
