# _meta

Config + the authoring kit for this Onyx study vault. Onyx never indexes `_meta/`
as cards (nothing here has a card `type:`), so it's a safe home for machine config
and author-facing docs.

**Start at the vault root `CLAUDE.md`** — it orients you and maps everything here.

## Contents

| File | Layer | Purpose |
|---|---|---|
| `onyx-subject.yaml` | config | The machine config: readiness target, flows (card types), parse rules, terminology. Makes this folder a loadable Onyx subject. |
| `authoring-method.md` | **universal** | The domain-agnostic card-authoring method + quality bar. The same in every Onyx vault. |
| `conventions.md` | **universal** | Card format + section conventions (frontmatter, headings, what's quizzed). |
| `curriculum.md` | **profile** | THIS subject's study sequence, sources, tiers. Example: software-interview prep. |
| `tags.md` | **profile** | THIS subject's tag/domain vocabulary. Check before adding a tag. |
| `card-creation-skill.md` | profile | The subject-specific card templates (an older, SWE-shaped companion to `authoring-method.md`). |
| `coach.md` | profile *(optional)* | Domain framing that AUGMENTS the coach's built-in voice (never replaces it). |

## Two layers, kept separate

- **Universal** (`authoring-method.md`, `conventions.md`): the app model + the
  method. Identical across subjects — a language or medicine vault reuses them
  unchanged.
- **Profile** (`curriculum.md`, `tags.md`, and the domain parts of
  `card-creation-skill.md`): what *this* vault studies. Here it's software
  interviews — one example. Replace these to describe a different subject; the
  universal layer doesn't move.

## Why this folder exists

Without a tag index, tags drift — `binary-search` vs `binary_search` vs
`binarySearch` — and the graph, quiz filtering, and readiness all degrade. Check
`tags.md` before adding any tag; if it's missing, add it there first. And without a
single authoring method, cards drift in quality; `authoring-method.md` is the bar.
