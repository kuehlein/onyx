# Onyx study vault — authoring guide (Knowledge Map)

You are working inside an **Onyx study vault**: a plain folder of Markdown files
that Onyx turns into spaced-repetition study cards. This file is your always-on
orientation — a map, not a manual. Skim it, then **load the linked doc on demand**
for the task in front of you.

> **The vault is the source of truth.** Onyx reads these files; it never owns your
> content. Everything that defines this subject — its cards, its config, its coach
> voice, and this authoring kit itself — lives here, so an AI working in this vault
> needs nothing from the Onyx app's source repo.

## The one framing that governs everything: Onyx REVIEWS, it does not cram

The load-bearing loop is *see a cue → recall from memory → reveal → grade
honestly*. A card exists to make **retrieval** effective. So the whole job of
authoring is: write cards a learner can be *tested* on and *reconstruct from a
principle* — not walls of notes to re-read. If a card can't be recalled and
self-graded, it's a note, not a card. When in doubt, cut.

## Knowledge Map — what to read, and when

| Consult when… | Read |
|---|---|
| Authoring or editing **any** card (the method + quality bar) | `_meta/authoring-method.md` |
| You need the exact **card format** (frontmatter, sections, quizzable rules) | `_meta/conventions.md` → then the app schema `docs/card-schema.md` if present |
| Choosing **tags / domains / tiers** for a card | this subject's profile: `_meta/tags.md`, `_meta/curriculum.md` |
| Deciding **what this subject even is** (levels, flows, file types, terminology) | `_meta/onyx-subject.yaml` (the machine config — see "How this subject is configured") |
| Writing for a **specific domain** (its sources, depth, sequencing) | the domain profile in `_meta/` (here: `curriculum.md`) — treat as ONE example, not the universal rule |
| Understanding **why** cards are shaped this way (the science) | `_meta/authoring-method.md` §Learning science → the app's `docs/learning-science.md` if present |

If a linked file is absent, the method still stands on its own — the profile docs
only *specialize* it for a subject.

## How this vault is laid out

```
<this vault>/
  CLAUDE.md                 # you are here — orientation + knowledge map
  _meta/                    # config + authoring kit; Onyx never indexes _meta as cards
    onyx-subject.yaml       # the machine config: levels, flows, parse rules, terminology
    authoring-method.md     # the UNIVERSAL, domain-agnostic card-authoring method
    conventions.md          # card format + section conventions
    curriculum.md, tags.md  # THIS subject's domain profile (example: software interviews)
    coach.md                # (optional) domain framing that augments the coach's voice
  <slug>.md                 # cards — one card per file, `type:` in frontmatter
  skills/                   # (optional) per-flow AI scripts (e.g. a conversation partner)
```

Two layers of knowledge, kept separate on purpose:
- **Universal** (the app model, spaced repetition, the authoring *method*): the same
  in every Onyx vault. Lives at the top level / `authoring-method.md`.
- **Domain profile** (this subject's sources, tags, tiers, sequence): specific to
  what *this* vault studies. `curriculum.md` + `tags.md` here are an example profile
  (software-interview prep) — a language, medicine, or law vault would swap them out
  and change nothing about the method.

## How this subject is configured (read `_meta/onyx-subject.yaml`)

A subject is **config, not code**. `onyx-subject.yaml` declares:
- **`flows`** — the card `type:`s this subject uses and how each is scheduled
  (`recall` = the spaced Learn/Review deck · `mock`/`two-clock` = practice tracks).
  A card's `type:` must match a flow, or Onyx won't treat the file as a card.
- **`parse`** *(optional)* — how notes become cards: section heading level, file
  extensions, wikilinks on/off, the never-quizzed heading list. Omitted → Onyx's
  built-in defaults (H2 sections, `.md`, wikilinks on).
- **`vocabulary`** *(optional)* — the subject's assessment noun (e.g. `interview`
  vs `exam`) so shared copy reads right.
- **`target`** — the readiness model (levels, contexts, tracks, domain weights).

Before authoring, skim it so your cards fit this subject's flows and conventions.

## The authoring loop, in one breath

1. **Decide the unit.** One idea per card; pick its `type:` (a flow in the config)
   and its place in the domain profile (tags/tier).
2. **Draft** in the card format (`_meta/conventions.md`), leading with the
   recognition trigger and encoding the *principle*, not the fact.
3. **Self-test / audit.** Read only the cue and try to answer. If you can't, or the
   answer isn't reconstructable from a principle, the card is wrong — fix it. For
   correctness-critical domains, verify claims against a real source.
4. **Link.** Add `[[wikilinks]]` to related cards (dangling links are fine — they
   mark a gap to fill).

Depth for each step is in `_meta/authoring-method.md`. Read it before a batch.
