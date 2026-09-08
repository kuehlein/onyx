# Vault-Directory-Driven App Structure (target architecture for #30)

**Status:** design note / north star. NOT built yet — see "Sequencing" for why we
approach it incrementally. Idea originated with the user (2026-09-08); refined here.

## The idea

Use the **Obsidian vault's directory structure to define the app's structure** —
themes (subjects), flows, and their features — via config files at each level.
The vault is already the source of truth for card *content*; extend it to be the
source of truth for *structure and configuration* too. A new flow, or a whole new
subject, becomes **config + folders, not new code** — which is exactly task #30
(generalize Onyx into a configurable multi-subject platform).

## Proposed layout (refined)

```
<vault>/
  _onyx/                         # one reserved root — everything Onyx lives here,
                                 # so the user's other Obsidian notes stay untouched
    config.md                    # GLOBAL app config (YAML frontmatter)
    software-interviews/         # a THEME (subject)
      config.md                  # theme config (dimensions, domains, coach, rubric…)
      general/                   # a FLOW — concept recall (FSRS Learn/Review)
        config.md                # flow config: scheduling + feature toggles
        database-indexing.md     # …cards (the .md files with `type:` frontmatter)
        caching.md
        …
      algorithms/                # a FLOW — coding practice (two clocks)
        config.md
        algo-arrays-and-hashing.md
        …
      behavioral/                # a FLOW — behavioral prep (future)
        config.md
        …
    spanish/                     # a second THEME (validates the abstraction)
      config.md
      vocabulary/  grammar/  …
```

### Config format
`config.md` with **YAML frontmatter** for the machine-readable settings + a prose
body documenting the options. Rationale: Obsidian-native (frontmatter is what
Obsidian already uses), user-editable as a normal note, and it reuses the
existing markdown+frontmatter parser. Config files have no `type:` field, so the
card parser already skips them (returns null) — no special-casing needed.

### What each level's config holds
- **Root `config.md`** — global: which theme(s) are active, app-wide toggles,
  default theme.
- **Theme `config.md`** — the SWE-specific *seams* become data here (this is the
  #30 "seam catalog" made config): the target **dimensions** (replaces the
  `SeniorityLevel × CompanyTier × Track` enums), the **domain list + weights**
  (replaces the hardcoded `domainWeight()`), the **coach persona/prompts**, the
  **rubric dimensions**, the **stability target**, and **terminology/labels**
  ("interview"/"mock"/"readiness" → per-subject words).
- **Flow `config.md`** — the *practice-track* configuration (the declarative half
  of the extracted practice-track engine): the **scheduling model**
  (`recall` = FSRS Learn/Review · `two-clock` = solve/explain · `behavioral`),
  the **interaction/grading** type, how it **feeds readiness**, and a set of
  **feature toggles**, e.g.:
  ```yaml
  scheduling: two-clock          # recall | two-clock | behavioral
  features:
    ai_coach: true
    explain_mode: true
    external_practice_link: true # "Solve on LeetCode"
    daily_min: 1
    daily_max: 3
  ```

The feature-toggle set + scheduling model per flow **is** the practice-track
abstraction, expressed as data. The engine reads this; each flow is a thin config
of one shared core.

## Why it's a good fit
- Realizes the generalization vision as a concrete, legible file layout.
- Stays true to Onyx's ethos: local-first, vault-as-truth, config-as-data,
  Obsidian-native, no hosted server.
- The per-flow config is the declarative counterpart to the shared practice-track
  engine we'll extract (see docs/curriculum.md "DRY the practice flows").

## Sequencing (don't refactor to this speculatively)
Same rule-of-three discipline as the practice-track engine:
1. Build the **system-design flow** as the 2nd concrete practice track (mirroring
   the algorithms track); extract the shared practice-track **engine** as we go.
2. THEN introduce the config layer + `_onyx/` layout, migrating the current SWE
   deck as the **reference theme config** (fold `_meta/onyx-*.json` into a theme
   `config.md`).
3. THEN a second theme (e.g. language learning) validates that a new subject is
   config-only.
Keep incremental choices *config-shaped* now (e.g. domain→weight as a map, not
more enums) so this migration stays cheap.

## AI authoring lives in the vault (added 2026-09-08)

The vault is the single source of truth for **everything needed to author cards —
including the AI skills themselves**, even if that means a `.claude/skills/` dir
*inside* the Obsidian vault. Rationale (user): once #30 lands, card authoring
moves OUT of this repo and INTO the vault (opened as its own Claude Code project);
Claude working in the vault must have the full method + domain knowledge with no
dependency on this repo.

Split of knowledge:
- **General, all-domains-aware** — the Onyx app model, FSRS/spaced-repetition,
  retention/learning science, and the **domain-agnostic card-authoring method** —
  lives at the vault top level (general knowledge every theme shares).
- **Domain-specific** — the SWE curriculum, per-domain sections/tiers/glossary
  policy, example cards — lives in that theme's subtree.

Three layers of ownership (refined 2026-09-08):
- **Universal authoring kit** — the general skill + knowledge (app model, FSRS,
  retention science, the domain-agnostic method). This is *product*, shared by
  every Onyx user; **canonical source = this GitHub repo** (maintainer-edited).
- **Domain profiles** — SWE shipped as the reference; friends may author their own
  in their own vaults.
- **User content (cards)** — local to each vault, never in git.
So "the vault is the single source of truth" is really: the repo is upstream for
the universal kit; each vault holds a *copy* of it + that user's profiles/content.

Distribution (how the repo-tracked universal kit reaches a user's vault/Claude):
- Requirement: other people can use Onyx for other subjects; they need the
  universal skills + authoring tools in *their* vault, without access to the
  maintainer's phone/account. The kit is tracked in GitHub; it must land in each
  user's `_onyx/`.
- **Do NOT** build live-sync / symlinks / integrity-checking. Manual, overwrite-in-
  place re-download is the accepted tradeoff (user's call): easy to re-run, no
  merge, no corruption worry, occasional staleness is fine.
- Candidate mechanism (decide in #30): **the Onyx app is the distributor** — bundle
  the universal kit as app assets + an "Update authoring tools" action that writes/
  overwrites it into the vault's `_onyx/`. Friends never touch git; tap to (re)install.
  The kit then rides existing vault sync from phone → desktop (where Claude authors).
  A small version stamp makes app-vs-kit mismatch visible without enforcement.

Skill design:
- Generalize `create-cards` to be fully **domain-agnostic** (SWE becomes an example
  profile, not hardcoded). Do NOT hardcode domain specifics into canonical AI
  touchpoints (`.claude/skills/`); the touchpoint stays generic and reads specifics
  from the vault.
- **Discoverability** = a *Knowledge Map* in `CLAUDE.md` (a table of skills + key
  docs, each with a one-line "consult when") — cheap always-on awareness,
  load-on-demand. Sweep in the loose capabilities (card gen/audit method,
  deep-research, coach/readiness/curriculum docs).
- Candidate: **stub-loader** — a generic loader skill in `.claude/skills/` that
  reads the vault's general knowledge + the active domain profile — vs. carrying a
  full `.claude/skills/` inside the vault. Decide during #30.
- **Avoid symlinks** for sharing skills repo↔vault: fragile across Linux/Mac
  (absolute paths), Obsidian sync (may not preserve links), and git (stores the
  link, not content; vault side may not be a checkout).

## Open questions
- Reserved-root name: `_onyx/` (matches the existing single-`_` convention) vs
  `.onyx/` (hidden from Obsidian) vs the user's `__onyx/`. Leaning `_onyx/`.
- **Layout inside the reserved root:** possibly top level = configuration +
  knowledge + skills, and all card **content** under a `content/` subdir (rather
  than cards flat or nested under theme/flow dirs directly). Resolve when building.
- One active theme at a time, or multiple concurrently? (affects Home/nav.)
- Migration: today cards live flat in `staging/flashcards/` with `_meta/`; the
  current two flows map to `general/` (concept recall) + `algorithms/` (coding).
  Card content will **not be committed to git** once authoring moves to the vault;
  it's fine that cards live in the repo for now and migrate later.
- Does the theme config subsume `onyx-target.json` / `onyx-goals.json`?
