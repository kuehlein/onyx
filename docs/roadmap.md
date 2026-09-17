# Onyx — Roadmap (two tracks)

> The phasing behind [product-direction.md](product-direction.md), from the UX rework
> ([ux-rework-stage1.md](ux-rework-stage1.md) §9). The key reframe: the old docs equated
> **`sync == server == accounts == deferred`** — broken apart here. The **client track**
> ships a complete local-first product with **zero server**; the **cloud track** layers on
> optional capabilities and is genuinely deferred (seams reserved now). `ux-vision.md` §9's
> UI phasing stays valid for the client track; this doc is the two-track superset.

## Guiding rule
Every phase keeps the app green (analyze clean + full suite) and is independently
committable; single-goal degradation stays byte-identical; nothing ships a UI that *lies*
about being general or about a capability that isn't reachable.

---

## CLIENT TRACK (offline, no server — the shippable product)

### Phase 0 — Foundations & seams (the true critical path)
- **The `focusedGoalProvider` spine** + `activeGoalCount` helper (currently unbuilt — the
  "one spine" has zero code hits today).
- **On-device `VaultSource` + `VaultRef` persistence** — the linchpin blocker: the app
  cannot obtain a folder on a real iPhone today. A content-origin-agnostic writable card
  store serving three producers (AI drafts, pulled decks, chosen folder).
- **Reserve seams now** (cheap now, migration-nightmare later): `draft`/`active` card
  status; `deckId` + the `(deckId, cardId, sectionSlug)` join key; duplicate-UUID detection
  in the indexer; `ClaudeService(baseUrl, authHeader)` + `AiProvider{off, managed, byoKey}`;
  deck `visibility`/`author`/`license` fields; one account concept + three capability flags.
- **Real fixes:** merge-correct snapshot (retire the last-write-wins blob that corrupts
  progress across devices) + fold goals into the synced payload; **delete the loss-aversion
  streak** + `StreakInfo.best`; add `progressPolicy` + fix the `_Thinking` spinner.
- **Docs:** product-direction + README + architecture stamp + this roadmap + INDEX (done).

### Phase 1 — Client/UX debt (offline, direction-neutral; much already planned)
- Per-goal honesty: analytics providers → `goalId` `.family` + the overlapping-membership
  helper (today only readiness is goal-scoped — the rest is a per-goal lie under multi-goal).
- Goal-scoped Browse segment + "Referenced by" backlinks.
- One `SharedBudgetBar` (read-only) + one adjust-mix sheet (the sole budget editor).
- Home single-Filled plan-driven loop; caught-up = full stop.
- Insights two-altitude (small-multiples overview + per-goal detail); parameterize `ReadinessPanel` by goal.
- Settings 6-group IA (move pace planner to Insights; demote Algorithms/Gym to per-goal drill-downs).
- Aim storage unification (`PrepGoal`→`Interview`/milestone under `StudyGoal`; retire `target_sheet`; kill the default-goal short-circuit).
- **De-privilege the coach** (`buildCoachSystem` → `SubjectConfig` persona; no more "interviewer" mid-recall for a 7th-grader).
- **Build the base design primitives** (`StatusPill`/`CoverageBar`/`CompletionRing`/`showOnyxSheet`/`SkeletonBlock`/`EmptyState`/the N-of-7 indicator) so every new surface is a config of them.

### Phase 2 — Intent-gate onboarding + AI generation (BYO-key first, no account needed)
- `/welcome` **intent-gate** (three co-equal paths) + the on-device folder create/choose.
- The **content on-ramps**: import/pull (content half), AI-generate (Paste + Topic first),
  light manual create-a-deck / edit-a-card.
- The **Draft/Review gate** + full-screen `/draft-review` + **self-test-then-promote** (no bulk accept).
- The **3-state AI affordance** + JIT choice at first AI use + `showApiKeySheet` tier chooser
  (managed shown as an honest disabled "coming soon" row until the server lands).
- Scheduling-never-travels invariant + the airplane-mode / single-goal CI invariants.

---

## CLOUD TRACK (optional, seamed-now / build-later — needs a server + legal/moderation work)

**Seamed-but-deferred** (seams reserved in Phase 0; built when audience + cost + legal justify it):
- **Managed "Onyx AI" server** — proxy + per-account quota + billing + cost controls + the
  `quota-exhausted` state + `CoverageBar` usage.
- **Accounts + account-sync** — deferred *because* folder-sync + the merge-correct snapshot
  already cover solo/power progress-sync; accounts arrive driven by managed-AI + restricted
  deck pull (migration designed now, reversible; accounts carry progress+goals only, never content).
- **Restricted / group deck registry** — maintainer/subscriber roles, class-code auth,
  group ACL, draft-gated upstream updates. The classroom distribution MVP (needs accounts).
- **Browse library / registry browser UI**.

**Defer-hard** (explicit gates):
- **Public deck tier** — blocked on moderation / report / takedown. Restricted-only first
  (teacher→known-students needs no open moderation).
- **Managed AI for minors / direct child accounts** — blocked on a COPPA/FERPA stance + the
  unresearched K-12 motivation pass. Teacher/guardian-provisioned only, if at all, at first.
- AnkiHub-style suggestion-queue/merge/co-authoring; institution/admin (P6); the full
  configurable parser; `FlowRunnerScreen`; second-brain #50; STT (#61).

---

*See [ux-rework-stage1.md](ux-rework-stage1.md) §9 for the full reasoning and the P0/P1
fix list, and [registry-and-sync.md](registry-and-sync.md) for the cloud-track designs.*
