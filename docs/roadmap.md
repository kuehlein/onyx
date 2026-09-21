# Onyx — Roadmap (two tracks)

> The phasing behind [product-direction.md](product-direction.md). The key reframe (from
> the 2026-09-17 UX rework): the old docs equated **`sync == server == accounts == deferred`** —
> broken apart here into a **client track** (a complete local-first product, *zero server*)
> and a **cloud track** (optional capabilities, genuinely deferred; seams built against
> client-side fakes). This doc is the living source of truth for *what is done vs next vs
> deferred*; when a design doc disagrees about build-state, trust this + the code.

## Guiding rule
Every phase keeps the app green (analyze clean + full suite + custom_lint) and is
independently committable; single-goal / SWE behavior stays byte-identical when a seam is
generalized; nothing ships a UI that *lies* about being general or about a capability that
isn't reachable (capability-gated: absent, never a disabled row).

---

## Where we are now (status: 2026-09-20)

The **local-first client product is substantially built and shipped-quality** — analyze +
custom_lint clean, ~918 tests green. The big arcs are done:

- **The review core** — the daily loop (recall → reveal → self-grade), FSRS Learn/Review,
  the quiz/learn/coach flows, readiness, insights, Home. *(the original product)*
- **Generalization (#30 — ENGINE done, G1–G6; surface layer pending)** — a subject is
  **config, not code**. `SubjectConfig` (target · flows/`FlowSpec` · coachSkill · vocabulary ·
  parseProfile · domainLabels) loads from `_meta/onyx-subject.yaml`; the daily plan,
  prerequisite gating (one `evaluateGate` engine over the general `depends-on` field),
  readiness, the coach *voice*, and the **card parser** (`ParseProfile`) are config-driven.
  Config-authored practice flows run end-to-end via the `FlowRunner`. The **Korean reference
  subject** (`korean-vault/`) is acceptance-tested end-to-end (plan + readiness) with zero SWE
  code paths. Multi-subject concurrent goals (query-lens membership) shipped (#30d/#64).
  **Caveat (2026-09-20 deep audit):** this is the ENGINE. The presentation layer a non-SWE
  user actually *sees* — Home target card, target sheet, interview-prep, readiness/insights
  copy, coach nudges — still hardcodes SWE-interview framing, and the no-config default subject
  is SWE (`Vocabulary` is consumed in one file). The engine is general; the app's *surface* is
  not yet → **G7 (#88)** below.
- **Content on-ramps + the Draft/Review gate** — folder create/choose onboarding, import a
  deck (against a fake registry), AI-generate (BYO-key), the `draft`/`active` lifecycle +
  full-screen `/draft-review` self-test-then-promote, light in-app card create/edit (#28).
  Scheduling-never-travels enforced.
- **In-vault authoring kit** (#46/#63 *kit*) — `examples/vault/` reference vault: a
  `CLAUDE.md` knowledge map + domain-agnostic `authoring-method.md` + loadable config +
  exemplar; a scaffolder seeds a neutral vault on folder-create.
- **Push/pull registry — CLIENT** (against a fake, per the develop-against-fakes strategy) —
  structure-preserving **file-tree** deck payloads, import (draft-stamped, path-safe,
  verbatim non-card files), **folder-lens publish** + `PublishSheet` + capability-gated
  Settings→SHARING, and upstream-update reconciliation through the draft gate.
- **Second-brain (#50) — S1** — the `card_links` graph surfaced as tappable Links/Backlinks
  on the card detail.
- **Practice tracks** (algorithms #33 · system-design #54 · behavioral #59), the cross-track
  **study cadence / daily plan** (#57), **aim unification** (#68), the **design system +
  accessibility + release-readiness** hardening (#51, #62, #72–#81, custom_lint drift guards).

---

## CLIENT TRACK (offline, no server) — remaining

Phases 0–2 of the original client roadmap (foundations/seams, UX debt, onboarding + AI-gen +
draft gate) are **done**. What's left on the client is feature depth + polish:

- **#30 surface-layer generalization — G7 (#88): the biggest remaining #30 work.** The engine
  is config-driven but the UI still hardcodes SWE-interview framing for *every* subject: Home
  `_TargetCard` (unconditional "Set your interview target" → `/interview-prep`),
  `target_sheet.dart` ("Company"/"Interview date"), `readiness_panel.dart` + the Insights
  "Applied performance" group (5 hardcoded SWE sections), coach-nudge copy, and "vault/Obsidian"
  nouns; `Vocabulary.examinerNoun` is consumed in ONE file. Migrate these onto
  `SubjectConfig`/`Vocabulary` (extend it: assessmentNoun/verb + a has-assessment flag), gate
  interview chrome on whether the template declares an assessment, ship a **neutral default
  subject** for no-config folders (today it falls back to `softwareInterviewsConfig`), and retire
  the legacy global `showTargetSheet` (ux-vision §3.7). SWE stays byte-identical. *This is what
  makes the app honestly general, not just the engine.*
- **#50 second-brain (IN PROGRESS)** — S1 done. **S1b:** tappable `[[wikilinks]]` inside card
  bodies. **S2:** notes as first-class graph nodes (index plain `.md` without a `type:`;
  a note viewer; links/backlinks spanning cards + notes — builds on `listAllPaths` + the
  parser's null-for-notes signal; needs note stems folded into the link graph). **S3:**
  graph-aware discovery (related cards/notes during study; the note graph into the AI covered
  frontier; maybe a local graph view — speculative/heavy).
- **Small features** — #22 quiz session customization · #25 AI study suggestions · #26 reader
  comprehension questions · #58 flesh out the extra-practice overflow.
- **#32 FSRS tuning** — optimizer-from-history + Learn-mode Easy handling + the desired-
  retention knob; **includes wiring `resolveStudyPolicy` (cram/schedule-profile) into
  `SrsScheduler`** (built but unwired today — see Hygiene backlog).
- **Settings-IA residual** (per settings-ux.md, partially applied) — header renames
  (VAULT→SOURCE, DATA&PROGRESS→DATA&BACKUP, CLAUDE→AI), demote Pace-planner/Algorithms/Gym to
  per-goal drill-downs. SHARING group + Source/Card-parsing/AI-tier rows already landed.
- **Onboarding intent-gate reconciliation** — `/welcome` is folder-first today (Choose /
  Create); the specs (product-direction §5, ux-vision §3.8, settings-ux §3, personas §3.2)
  describe "three co-equal choices." Decide: update the specs to folder-first (acquisition at
  Browse `+`), or build the three-way gate. *(a spec-vs-code consistency call, not a bug.)*

### Hygiene + bug backlog (from the 2026-09-20 audits — mostly latent)
- **Draft leak (bug, #89):** the behavioral mock list (`behavioral.dart:43`) filters by `type`
  over *all* cards, not `studyCards`, so a draft behavioral card appears for practice — an
  ADR-0003 violation the other four tracks don't have. Small fix + test (quick win).
- **Unreachable flow (#90):** `/debrief/:goalId` (interview debrief, a built AI flow) has zero
  callers since the interview UI migrated — wire an entry point or retire.
- **Recall predicate leak (#87/#32):** `daily_plan.dart` + `flow_runner.dart` compute prereq
  comfort over `type == 'flashcard'`; should be `scheduling == recall` (config-driven). De-dup
  the two copied comfort builders while fixing. *(needs a "concept vs applied-recall" call — #32.)*
- **More SWE-in-engine leaks (#87):** `daily_plan.dart:134` hardcodes `kTypeSystemDesign` in the
  *generic* prereq builder; and `vault_indexer._fileStem` (strips any extension) diverges from
  learn/daily_plan/flow_runner (strip only `.md`) → silent join mismatch for a future non-`.md`
  subject.
- **`CardCache` table (#87)** is rebuilt every reindex but read nowhere — drop it (a drift
  migration) or re-label its docstring "reserved for".
- **`flow_access.dart` (#87)** (taint-containment) is tested but not wired into the live gate —
  wire it or delete it.

---

## CLOUD TRACK (optional; seams built against fakes, server deferred)

The **client halves are built against a `FakeRegistryClient` / seamed AI transport**; what's
deferred is the **server + accounts + legal/moderation** (build when there's an audience).

- **Registry SERVER last-mile (#83)** — a real `HttpRegistryClient` behind the seam; the
  update-**propagation** wire (maintainer push → subscriber "N updated" notice → draft gate;
  the *content* reconciliation is built); restricted-tier **accounts + class-code** auth; the
  §10.9 change-grading heuristic; flip `sharingReachable` onto a real account capability.
- **Managed "Onyx AI"** — server proxy + per-account quota + billing + the `quota-exhausted`
  state + `CoverageBar` usage (the `ClaudeService.managed` transport seam exists; honest
  "coming soon" disabled row until then).
- **Accounts + account-sync** — carry progress + goals only, never content; migration designed
  now. *(folder-sync + the merge-correct snapshot cover solo/power sync first.)*
- **Authoring-kit distribution (G5c, #63 remainder)** — the app bundles the universal kit as
  assets + an "Update authoring tools" action that writes it into the vault + a version stamp
  (no live-sync/symlinks; manual overwrite-in-place).
- **In-app parse-profile editor + onboarding template-picker (G4c, #84)** — turn the read-only
  "How cards are read" sheet into a preset editor that writes `onyx-subject.yaml`.

**Defer-hard** (explicit gates): the **public deck tier** (blocked on moderation/report/
takedown — restricted-first); **managed AI for minors** (COPPA/FERPA + the K-12 motivation
research pass).

---

## Mac tail (needs macOS/Xcode — can't build or test on the Linux dev box)
- **#82** iOS security-scoped bookmark + Android SAF (mobile folder picking).
- **#61** speech-to-text for the mock + explain flows.
- On-device UX pass of #30/#50; iOS build → TestFlight → release.

---

## Near-term order (suggested)
1. **Quick win:** the draft-leak bug (#89) + this pass's doc/task hygiene.
2. **#30 surface-layer generalization (G7, #88)** — highest leverage for the product thesis: it
   makes the app *honestly* general, not just the engine. (Can interleave with #50.)
3. Finish **#50** (S1b → S2 notes → S3 discovery) — S2 is the real second-brain leap and
   warrants a short design pass first.
4. Opportunistic **small features** (#22/#26) + **settings-IA (#85)** + the **hygiene/bug
   backlog** (#87/#90) + the reachability/content calls (#90/#91) as palate-cleansers.
5. **#32 FSRS tuning** (folds in the `resolveStudyPolicy` wiring + the recall-predicate call).
6. **Cloud track** when an audience justifies the server (#83 first — restricted registry),
   then managed AI; **Mac tail** on a Mac.

*Cross-refs: [product-direction.md](product-direction.md) (what Onyx is), [ux-rework-stage1.md](ux-rework-stage1.md)
(the reframe reasoning), [registry-and-sync.md](registry-and-sync.md) (cloud designs),
[content-creation.md](content-creation.md) (on-ramps + draft gate), [multi-subject-plan.md](multi-subject-plan.md)
(#30d). Task ids (#NN) are the persistent backlog.*
