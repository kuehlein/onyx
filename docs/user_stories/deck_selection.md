# Deck selection

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.

**Purpose.** The vault-level view of all decks (query lenses) — in effect the "whole vault"
hub. Manage which decks are active and how study time is split across them.
**Scope.** Vault level.
**Personas.** P3/P4/P5 running several subjects at once; anyone with one deck skips it.
**Reached from.** After onboarding; as the landing page **when ≥2 decks are active** (skipped
straight to Home for a single deck); and via a persistent path back from Home (see below).
**MVP.** List / select / add / pause. **Partial/later:** archive, cross-deck time allocation,
a global calendar.

## What it does
From here the user can:
- **Select a deck** → enter that deck's [Home](home.md). [MVP]
- **Add a deck** → the [deck_creation](deck_creation.md) flow. [MVP]
- **Pause a deck** — stop allocating study time to its lens (kept, just idle). [MVP]
- **Archive a deck** — hide it without losing work. [later]
- **Manage study-time allocation** across active decks (each deck's **proportion** of the daily
  budget). **Warn on too-little-time**: a share that leaves a deck too few minutes to learn or retain
  anything, or below its **heaviest flow's unit cost** — e.g. a 40-min system-design session can never
  run in a deck allotted < 40 min/day — and on too-many-subjects. [MVP-ish] A global calendar of
  upcoming tests across all decks is [later, tricky].

## Open questions → recommendations
- **Should the app recommend each deck's proportion (from deadlines / aims / coverage)?**
  **Rec.** Eventually yes — suggest shares from each deck's **feasibility** (deadline pressure,
  coverage remaining, aim urgency) — but **only as suggestions the user can override.** The app can't
  model real-world urgency: learning Korean may have no "test" yet be the most urgent thing (a
  grandparent is dying and the user wants to speak with them), outweighing an SWE loop they aren't even
  sure they want. So surface the recommendation + the too-little-time warning, but **the user's set
  share always wins** (autonomy-supporting, SDT — like the coach: propose-with-rationale, never
  auto-override). MVP ships manual shares + warnings; recommended shares are a later layer.
  **Status.** Accepted (suggestions-only, later).
- **Archive semantics — lens only? cards too? mark + hide? or delete?**
  **Rec.** Archive the **lens only, never the cards.** Cards belong to the vault and may be
  shared across decks, so deleting them here would be surprising + destructive. Mark the deck
  archived, hide it from the active list, and add an **"Archived" section** to restore or remove
  the *lens*. Deleting actual card files stays a vault operation the user does in their own tool.
  **Status.** Accepted. On your note — when removing a lens, surface the cards **unique to it**
  (in no other active/archived deck) as safe-to-delete, behind an explicit confirmed "also delete
  these N files from the vault" — destructive, never default.
- **Should the app bar appear here?** (Its items — Browse / Analytics / Settings — are currently
  deck-scoped, but this view is vault-level.)
  **Rec.** At the vault level the app bar should host only **vault-scoped** actions:
  vault-wide **Settings**, and optionally a cross-deck **calendar**. Deck-scoped Browse /
  Analytics belong *inside* a deck (reached from its Home), not here. Keep this bar minimal;
  don't force deck-scoped tabs at the vault level. (This is the deck-vs-vault scope question —
  see [browse](browse.md), [analytics](analytics.md), [settings](settings.md).)
  **Status.** Accepted

## Known bugs
- **Pausing one of two decks strands you.** With 2 decks, pausing one drops the active count to
  1, the app collapses to that deck's single-deck Home, and there's **no path back to deck
  selection to unpause** the other.
  **Rec.** This is the degradation rule (single active deck → Home) with a missing escape hatch.
  Fix: always keep a route back to Deck selection (a "Decks" affordance) even with one active
  deck, so paused/archived decks stay reachable to resume.

## View accessed from
Onboarding · the landing view when ≥2 decks are active · a persistent "Decks" affordance from
Home (present even with one deck, so you can always add/switch/resume — secondary, not a
prominent back arrow that reads as "leaving").

## Cross-refs
[home](home.md) · [deck_creation](deck_creation.md) · [scheduler](scheduler.md) (the cross-deck
calendar idea) · older: `multi-subject-plan.md`, `ux-vision.md` (lanes hub), ADR-0005 (degradation).
