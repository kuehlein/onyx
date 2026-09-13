# Generalization Plan (task #30) — SWE-prep → configurable multi-subject

**Status:** approved plan, not yet built. Realizes the north star in
`docs/vault-structure.md`. Companion to the seam catalog in the
`generalization-vision` memory. Execute phase-by-phase; every phase keeps the app
green (analyze clean + full test suite passing) and is independently committable.

## Goal

Make Onyx run *any* configured study subject, with the current SWE-interview deck
as the built-in reference subject. Adding a subject should become **config, not
code**. The engine (FSRS, reveal/grade, Learn/Review queues, drift schema, card
parsing by free-form `domain` tag) is already subject-agnostic; this is a
*configuration* refactor of the SWE-specific seams, not an engine rewrite.

## Decisions locked (2026-09-13)

1. **Abstraction first, vault second.** Introduce an in-Dart `SubjectConfig`,
   route every seam through it with SWE as the built-in default (no behavior
   change), THEN add the vault `_onyx/config.md` loader. Two separable risk
   surfaces.
2. **Fixed 3-slot target, configurable values.** Keep the shape
   *level × context × track*; a subject supplies the values, labels, and weights.
   Do NOT build arbitrary N-dimensional targets (speculative; the ladder/forecast/
   tier math rely on an ordered level + a focus track).
3. **Authoring kit is OUT of scope** — the generic card-authoring skill, in-vault
   `.claude/skills`, the "update authoring tools" installer, and the `CLAUDE.md`
   knowledge map are a separate follow-up (**#30b**). This pass generalizes the
   running app only.
4. **Validate with a minimal throwaway theme** — a tiny `demo` subject (~2 domains,
   a handful of cards) proves "new subject = config only". No real second
   curriculum in this pass.

## The spine: `SubjectConfig`

One value object every seam reads from. New dir `lib/core/subject/`.

```
class SubjectConfig {
  final String id;                 // 'software-interviews'
  final SubjectLexicon lexicon;    // subject words: assessment/mock/readiness/target/…
  final TargetSpec target;         // the 3 slots (below)
  final List<DomainSpec> domains;  // domain key → label (+ base weight)
  final List<FlowSpec> flows;      // practice tracks, as data
  final CoachPersona coach;        // persona + terminology fragments for prompts
}
```

### The 3-slot target (decision #2)

Each slot keeps a fixed *role*; the values come from config. A slot a subject
doesn't need is given one default value and effectively disappears.

```
class TargetSpec {
  final LevelSlot   level;    // ordered; controls knowledge DEPTH required
  final ContextSlot context;  // controls the durability (FSRS stability) BAR
  final TrackSlot   track;    // controls WHICH domains weigh most
}

class LevelValue   { String id, label; List<double> tierCurve; } // → tierRelevance
class ContextValue { String id, label; double stabilityTargetDays; } // → stabilityTarget
class TrackValue   { String id, label; Map<String,double> domainWeights; } // → domainWeight
```

Mapping to today's SWE values (must reproduce current numbers exactly):
- **level** = `newGrad|mid|senior|staff`, each carrying the current
  `_tierRelevanceByLevel` row.
- **context** = `typical(90d)|faang(120d)` (today's `stabilityTarget`).
- **track** = `general|backend|frontend|fullStack|ml|mobile`, each a domain→weight
  map reproducing today's `domainWeight()` families (algo down-weight for
  frontend/mobile; systems/backend up-weight for backend/ml).

`ReadinessTarget` becomes `{levelId, contextId, trackId, interviewDate}` resolved
against the active `SubjectConfig`. The ladder generates from `level × context`
values instead of the hardcoded 8-rung const.

## Phased plan

### Phase 0 — Config model + SWE reference config + golden tests (no behavior change)
- New `lib/core/subject/`: `SubjectConfig` + sub-types; `softwareInterviewsConfig`
  as a Dart const reproducing today's exact values (tier curves, 90/120 bars,
  domain-weight families, domains, rubric dims, coach persona strings).
- `activeSubjectProvider` → returns the SWE config (hardcoded this phase).
- **Golden tests** (the linchpin): assert the config reproduces the current
  `domainWeight()` / `tierRelevance()` / `stabilityTarget` / ladder outputs
  bit-for-bit across all level×context×track combos. These guard every later phase.
- Pure addition; nothing rewired. Ships green trivially.

### Phase 1 — Route the readiness/target CORE through the config (riskiest math)
- Rewrite `domainWeight`, `tierRelevance`, `tierWeightsFor`, `stabilityTarget`
  (`lib/core/readiness/target.dart`) to read the active `TargetSpec`.
- `ReadinessTarget` → id-based selection resolved against config; keep a thin
  compat surface so call sites migrate incrementally.
- Ladder (`lib/core/readiness/ladder.dart`) generates rungs from config values.
- Persistence: `onyx-target.json` stores `subjectId` + slot ids (today stores enum
  `.name` — same shape); graceful fallback on unknown ids (data is disposable).
- Guardrail: Phase-0 golden tests must stay green → SWE numbers unchanged.

### Phase 2 — Target picker + goals/planner off the enums
- `target_sheet.dart`: build chips from `config.target.*.values`, not enum
  `.values`.
- `prep_goal.dart`, `interview_plan.dart`, `ForecastDims` (`providers/readiness.dart`):
  store slot ids/strings instead of enum types; JSON serde by id.
- AI planner schema enum lists come from config.
- Tests: target-sheet widget test (renders configured values); prep_goal serde
  round-trip; forecast memo key still stable.

### Phase 3 — Flows / practice tracks as config
- `FlowSpec` from config: scheduling model (`recall|two-clock|behavioral`), card
  type(s), rubric dims, persona, feature toggles, route. Drives the daily-plan
  `TrackId` set + `today_flows.dart` routing + `practiceAvailability`.
- CardType section-quizzability rules (`lib/core/vault/card_parser.dart`) read the
  flow's scheduling model instead of `switch (CardType)`.
- Largest structural phase — sub-split if needed (registry → parser → daily-plan →
  routing). Leave the *product* choice of "behavioral not in daily plan" as-is;
  just make inclusion config-expressible.
- Tests: adding a flow to the demo config surfaces it; existing track tests green.

### Phase 4 — AI persona + rubric + terminology from config
- Prompt builders (`coach.dart`, `system_design_interviewer.dart`,
  `behavioral_interviewer.dart`, the graders, `readiness_report.dart`,
  `interview_plan.dart`, `interview_debrief.dart`) take persona + terminology +
  rubric from config; SWE strings move into `softwareInterviewsConfig`.
- Rubric dims (`assessment.dart`) + `rubricLabel` read per-flow from config.
- `SubjectLexicon` supplies user-facing words; parameterize the shared UI strings
  ("interview"/"mock"/"target" → configured term). Terms already neutral
  ("review", "learn", "readiness") can stay.
- Tests: prompt-builder unit tests assert SWE persona reproduced; a config with a
  different lexicon changes the output.

### Phase 5 — Vault config loader (`_onyx/config.md`) — the "vault second" half
- Parse `_onyx/config.md` (+ theme/flow `config.md`) YAML frontmatter →
  `SubjectConfig`, reusing the existing markdown+frontmatter parser (config files
  have no `type:`, so the card parser already skips them).
- `activeSubjectProvider` loads from vault, falling back to `softwareInterviewsConfig`
  when absent → existing users are unaffected until they add config.
- Resolve open questions from `vault-structure.md`: root name (`_onyx/`), whether
  card content relocates (recommend **not yet** — point config at the current
  `staging/flashcards/`), and whether the theme config subsumes
  `onyx-target.json`/`onyx-goals.json`.
- Tests: sample `config.md` → `SubjectConfig`; partial/missing config falls back.

### Phase 6 — Validation: minimal throwaway theme (acceptance test)
- Add `_onyx/demo-*/config.md` + ~5 cards using different 3-slot values; confirm
  the app runs it with **zero code change**. Fix any abstraction leaks it exposes.
- Keep as a test fixture or delete.

## Cross-cutting

- **One active theme at a time** for this pass (Home/nav stay single-subject; no
  per-theme DB namespacing). A theme switcher / concurrent themes is deferred —
  it's the main thing that would force drift schema changes, so we avoid it now.
- **Persistence/migration:** slot ids + `subjectId` in the existing JSON files;
  disposable dev data means no heavy migration, but keep graceful fallbacks.
- **Testing discipline:** Phase-0 golden tests are the safety net — every phase
  proves "SWE behaves identically" before moving on.

## Out of scope (explicit)
- #30b: authoring kit in the vault + distribution + `.claude/skills` + knowledge map.
- A real second subject / curriculum (only the throwaway demo here).
- Physical relocation of card content out of the repo.
- Concurrent/multiple active themes + a theme switcher.
- #50 second-brain / knowledge-graph work (unblocked once this lands).

## Risk register
- **R1 — the readiness math (Phase 1).** Mitigation: Phase-0 golden tests lock SWE
  numbers before any rewrite.
- **R2 — leaky abstraction (wrong seams).** Mitigation: Phase-6 demo theme is the
  real proof; do it as early as the config loader allows.
- **R3 — scope creep into #30b / a real subject.** Mitigation: decisions #3/#4
  above; keep the demo throwaway.
- **R4 — flow generalization (Phase 3) is broad.** Mitigation: sub-split; the
  shared mock engine (`core/practice/mock_session.dart`) is already extracted.
