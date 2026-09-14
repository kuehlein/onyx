# Multi-Subject Concurrent Platform (task #30d)

**Status:** approved plan, not yet built. Extends the (now-proven) per-subject
config machinery from #30/#30c to run **multiple subjects at once in one vault**,
sharing one daily study budget. Companion to `docs/generalization-plan.md` and
`docs/practice-flow-plan.md`. Execute phase-by-phase; **single-subject behavior
must stay byte-identical at every step** — which also satisfies the "1 subject →
today's Home" requirement for free.

## The target model (user, 2026-09-14)

- One Obsidian vault. **Various directories carry a config** marking their files
  as quizzable cards for a subject; files without card metadata (`type:`) are
  ignored (the second-brain notes coexist). Directories without a config are not
  card sources.
- **Multiple subjects run concurrently** — CS, Korean, statistics all quizzable
  at once. Each has its own config, target/deadline, domains, flows, readiness.
- **One shared daily study budget** across all subjects, with the user able to
  set per-subject **proportions** and **pause** any/all subjects (paused → its
  share redistributes to the active ones).

## UX — the "Today's mix" lanes hub (approved)

Home stays one page: the single today-progress **ring** (shared-budget hero) over
**one compact lane per active subject** (name · deadline/urgency · share % ·
readiness · today's `~min` + item chips · pause). Tap a lane's items → *that
subject's* blended session; tap the lane header → that subject's page
(readiness/target/browse). "Adjust mix" sheet = proportion sliders + pause.
Batches by subject (interleave within a subject, not across). Browse gains a
subject facet; Insights becomes per-subject. Bottom nav unchanged (4 tabs).

**Degradation (required):** with exactly ONE subject, skip the hub — Home renders
today's queue for that subject exactly like now.

## The core shift: `activeSubject` singleton → subject registry + card binding

Today a card's behavior (isPracticeTrack, flow, quizzability, readiness weight)
resolves against the single global `activeSubject`. In the multi-subject model it
must resolve against **its own subject**:
- **`SubjectRegistry`** — `{subjectId → SubjectConfig}`, discovered by scanning the
  vault for per-directory configs. Replaces the single `_meta/onyx-subject.yaml`
  load (that becomes the 1-entry case).
- **Card → subject binding** — each card carries its `subjectId` (from its
  directory's config); `Card.isPracticeTrack`/flow/quizzability resolve via
  `registry[card.subjectId]`, not a global.
- **Per-subject readiness/target/goals** — target, readiness, ready-by, prep goals
  become per-subject (provider families keyed by subjectId; per-subject
  persistence).
- **Two-level daily budget** — allocate the total budget across subjects
  (proportion × pause), then within each subject across its tracks (the existing
  meta-scheduler, unchanged, runs per subject).

What carries over unchanged: `SubjectConfig`, `FlowSpec`, gating, study policy,
prompt assembly — all already per-subject building blocks.

## Phased build (single-subject identical at every step)

1. **M1 — Registry + discovery + `Card.subjectId`.** Scan the vault for
   per-directory configs → `SubjectRegistry`; tag each parsed card with its
   subjectId. Keep `activeSubject` as a compat shim (= the sole/first subject) so
   nothing breaks. Legacy `_meta/onyx-subject.yaml` and the SWE default map to a
   1-entry registry. Green, single-subject identical.
2. **M2 — Card behavior via registry.** `Card.isPracticeTrack`/flow/quizzability +
   the parser's card-ness resolve via `registry[card.subjectId]` instead of the
   global. Retire the `activeSubject` global for card behavior (keep for
   not-yet-migrated call sites, or remove). 1 subject → identical.
3. **M3 — Per-subject readiness/target/goals.** Make target/readiness/ladder/pace
   provider families keyed by subjectId; persist per-subject. 1 subject → identical
   (the family has one key).
4. **M4 — Cross-subject budget.** Two-level allocator: split the daily budget
   across subjects by proportion, honoring pause (paused → share redistributes);
   per-subject settings persisted. 1 subject → the whole budget, as now.
5. **M5 — Lanes-hub UI + degradation.** Home = lanes hub when ≥2 subjects, current
   single-subject Home when 1. Subject-detail page, adjust-mix sheet, Browse
   subject facet, per-subject Insights.
6. **M6 — Validation.** A 2-subject vault (CS + Korean) exercised end-to-end
   (discovery, per-subject readiness, shared budget with a proportion + a pause,
   the hub, and degradation to a 1-subject vault).

## Open decisions (resolve at M1)
- **Config marker/location per directory** — a per-dir `onyx-subject.yaml` (mirrors
  today's meta file) vs `config.md` with frontmatter (vault-structure.md's
  `_onyx/<theme>/config.md`). Cards belong to the nearest ancestor config
  directory. Decide the exact rule (nearest-ancestor vs same-dir-only).
- **Subject id** — derive from the directory name, or an `id:` in the config
  (config `id:` wins; dir name is the fallback/label).
- **Per-subject persistence keys** — `onyx-target-<id>.json` etc. (migrate the
  legacy single-subject files to the sole subject's id).
- **Pause redistribution** — proportions renormalize over active subjects (keep the
  full budget in use). Confirmed as the default.

## Adversarial safeguards
- This is a second big cross-cutting migration — same discipline as the CardType
  flip: characterization tests for single-subject behavior FIRST (readiness
  numbers, card-ness, the daily plan) so every phase proves "1 subject unchanged";
  golden + full suite green at each commit; the registry/binding lands as an
  isolated, staged change, not one mega-diff.
- Watch: the drift `card_cache` may need a `subjectId` column (derived cache — no
  migration if never read back, but verify); the `activeSubject` global's readers
  must all move to card/subject-scoped resolution (grep-audit like the enum flip).

## Out of scope / later
- Live conversation/practice **screen + routing** (still deferred from #30c Phase 4).
- STT (#61). AI authoring kit distribution (#30b).
