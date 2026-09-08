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

## Open questions
- Reserved-root name: `_onyx/` (matches the existing single-`_` convention) vs
  `.onyx/` (hidden from Obsidian) vs the user's `__onyx/`. Leaning `_onyx/`.
- One active theme at a time, or multiple concurrently? (affects Home/nav.)
- Migration: today cards live flat in `staging/flashcards/` with `_meta/`; the
  current two flows map to `general/` (concept recall) + `algorithms/` (coding).
- Does the theme config subsume `onyx-target.json` / `onyx-goals.json`?
