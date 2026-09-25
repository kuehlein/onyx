# ADR 0012 — Card model: a shared component layer, quizzability precedence, edit-identity

- **Status:** Accepted
- **Date:** 2026-09-24
- **Deciders:** Kyle Uehlein
- **Related:** `docs/user_stories/card.md` (the spine — this ADR records the load-bearing rulings), `browse.md`
  (entry + stubs), `deck_creation.md` (authoring), `settings.md` (parsing rules / read-only MVP). ADR-0003
  (card status / draft gate / the eventual `(deckId,cardId,sectionSlug)` key — deferred). `architecture.md`
  invariant #2 (no card-type branch) + #5 (FSRS join = `cardId::sectionSlug`). Tasks: **1f** (this),
  **1f.1** (engine gaps), **#84** (parse-profile editor), **#20** (unresolved links), **#28** (in-app create).

## Context

`card.md` wants a card shown across four **modes** — view / study / authoring / stub — that *"share layout +
section rendering and differ only in affordances"* (explicitly *"not four half-overlapping screens"*). Today
those modes are genuinely SPREAD across ~7 surfaces with duplicated section/markdown rendering:
`browse/card_detail_screen` (view), `learn/learn_screen` + `quiz/quiz_screen` (study), `editor/card_editor_screen`
(authoring), `browse/unresolved_links_screen` (stub), plus the invariant-#2-**exempt** engine screens
(`algorithms/algo_screen`, `system_design/*`, behavioral). A deep scope (10-agent workflow: SoT + code map of
each surface + arch + UX research → plan → 3 adversarial critics) converged on a reframe and surfaced two
present-day bugs and a missing test net.

**The reframe (the load-bearing call).** A literal *"one `CardView(mode)` widget"* is the wrong shape: below
the shared chrome the four modes are largely **disjoint** (different cues, action bars, grade sets, session
notifiers, reveal gates), so a `switch(mode){…}` over disjoint bodies just moves divergence from four files
into four branches of one file — a mode-branch smell, and it funnels the highest-risk path (study grading)
through shared code with stub null-identity guards leaking into the hot paths. card.md's actual goal —
*shared layout + section rendering, differ only in affordances* — is satisfied by a **shared component layer**
that each thin screen composes. This keeps learn/quiz as their own screens (far lower risk) while deleting the
real duplication.

**Two real bugs the scope confirmed:** (1) the view surface hardcodes the type label `'Interview question'` /
`'Flashcard'` instead of resolving the flow's `displayLabel` (a subject-neutrality + invariant-#2 leak);
(2) editing a card **orphans** FSRS history on a heading rename — `saveCardEdit` never touches `srs_state`, so
a renamed heading gets a new `slugify(heading)` slug, the old `cardId::oldSlug` row is stranded (persists,
uncounted) and the section re-enters study as brand-new. (This *orphans*, it does not "reset".)

**A missing safety net:** no test drives a real grade through the real Learn/Review notifier (the one review
widget test *fakes* the session provider), and there are no goldens for card_detail/learn/quiz. So
"byte-identical" cannot be asserted until characterization tests are written **first**.

## Decision

**1f delivers a shared card-rendering component LAYER (not a universal `CardView(mode)` widget); each surface
composes it. Study keeps its own screens + schedulers. Two present-day bugs are fixed. Two behaviour-changing
engine gaps are split into 1f.1.**

1. **Shared components** (in `lib/shared/widgets/` + `lib/shared/design/`), lifted from the private members of
   `card_detail_screen`: **CardScaffold** (the `Scaffold` › `Center` › `ConstrainedBox(maxContentWidth)` ›
   `FadingScrollEdges` › `ListView` chrome + an actions/bottomBar slot), **CardSection** (the collapsible
   section renderer: accent rail, quizzable heading tint, study-unit indicator, `CardMarkdown` body — the
   SINGLE section renderer for every surface), **CardHead** (meta chips + `ConfidenceBadge` + overview; the
   type chip resolves `activeTemplate.flowForType(type)?.displayLabel` + `flowIcon(iconKey)`), **CardMetaChip**,
   **CardLinks**, and a pure **`sectionExpandDefault(section, state, now)`**. `CardMarkdown`/`onyxCodeTheme`
   stay the one body renderer. Each surface (view, learn, quiz, editor, stub) COMPOSES these — there is no
   universal mode-switch container.
2. **Grade paths stay separate (no funnel).** `learnSessionProvider` (seed-only, 3-grade, no Easy, re-queue),
   `studySessionProvider` (full `recordReview`, 4-grade, readiness-before snapshot), and the algo two-clock
   flow remain three distinct notifiers. Shared components take data + callbacks (`onReveal`, `onGrade`,
   grade-set, cue source), **never** the scheduler; each screen keeps its own reveal flag + reveal predicate
   (Learn pretest-gated; Review always-gated) + invalidations + side effects.
3. **Type label/icon via config, not a type branch** — `FlowSpec.displayLabel` + `flowIcon(iconKey)` (move
   `flowIcon` to `lib/shared/design/`), matching browse's existing pattern. Deletes the hardcoded flavor
   strings (invariant #2 + Vocabulary rule).
4. **Edit-identity (the FSRS fix).** Keep the current `cardId::sectionSlug` key (NOT the deferred
   `(deckId,…)` join — cross-ref ADR-0003). On save, diff the **section-slug set** (old vs new headings),
   computed in provider-free testable code that is handed the pre-edit sections. **Cosmetic/body/tag edits
   (slug set unchanged) → silent KEEP.** A **material change** (a slug renamed / removed / added) → prompt
   per affected section **keep-vs-reset**: KEEP **rekeys** `cardId::oldSlug → cardId::newSlug`; RESET drops the
   row (optionally re-drafts via the ADR-0003 gate); removed sections **prune** their orphaned rows. **Never
   silent reset.**
5. **Quizzability precedence (resolved in the parser), encoded + tested:** per-card **DENY** (`quizzable:false`)
   > per-card **ALLOWLIST** (`quiz:`) > **FlowSpec policy** (template `neverQuizzed` → engine blocklist). A
   per-card `quizzable:true` is a **no-op for MVP** (it must NOT re-open an allowlisted section — that would
   move existing decks' study sets). Existing allowlist/blocklist/approachOnly cards stay **byte-identical**
   (characterization-guarded); only `quizzable:false` may newly subtract. **[1f.1]**
6. **Mastered auto-collapse = ENGINE behaviour, not config [1f.1].** A quizzable section in `state==review`
   with `lastReview != null` and **retrievability R ≥ threshold** collapses-by-default with a *"Mastered"*
   badge. Display-only — it NEVER suppresses a due retrieval in study; stop-testing stays the separate explicit
   `quizzable:false` action. R comes from **core/srs** (the `fsrs` package's `getCardRetrievability`), never a
   widget-layer reimplementation; the threshold is a single engine constant; ship a **global off-switch**. It
   REPLACES the current due-date proxy in `sectionExpandDefault` — a real behaviour change to the view surface,
   shipped with a before/after golden, not sold as a "refactor".
7. **Stub = a focused screen composing the shared components** (not a mode of a container). It synthesizes a
   fileless placeholder (title de-slugged from the broken target; a **References** section from
   `index.unresolvedLinks` filtered by target — NOT `cardNeighborhood`, which is resolved-only) and is
   **structurally barred from study**: an `isStub` sentinel, References `quizzable:false`, never added to
   `studyCards` or any queue. *"Create this note"* flips in place to authoring seeded with the title, writing a
   file whose **stem == the link target** so existing `[[wikilinks]]` resolve on re-index (the de-slug →
   re-slug round-trip must be verified against realistic targets).
8. **neverQuizzed:** ship the per-card `quizzable:false` override in MVP; keep the per-deck `neverQuizzed` set
   **read-only** (engine + template default) per `settings.md`; the **user-editable** per-deck set defers to the
   parse-profile editor (**#84**). *(A conscious partial-defer of card.md's "user-editable" wording, signed off.)*

**Sequencing.** **1f (this):** S0 characterization tests (real-notifier grade tests for Learn + Review; goldens
of card_detail/learn/quiz on `main`) → S1 lift components + rebuild VIEW byte-identical + the label fix → S2
edit keep-vs-reset on the existing editor (the orphan bug) → S3 authoring as the single entry (+ light AI chat
via the coach seam / deck authoring skill) → S4 stub screen; learn/quiz **adopt** `CardSection` for the
revealed body (additive, keep their notifiers/grade-sets). Study migrates **last**, one screen at a time, proven
against S0. **1f.1:** mastered auto-collapse (#6) + per-card `quizzable:false` (#5) — each with an off-switch /
precedence matrix + before/after golden.

## Alternatives considered

- **A universal `CardView(mode)` container.** Rejected — a mode-switch over disjoint bodies is its own smell,
  funnels the study grade paths through shared code, and leaks stub null-identity guards into the hot view/study
  paths. The component layer meets card.md's intent with less risk.
- **Fold learn/quiz into a shared study layout.** Rejected — the two grade paths (`seedState` vs `recordReview`)
  are genuinely different DB writes; keep the notifiers separate, share only chrome + `CardSection`.
- **Hand-roll retrievability in the widget layer.** Rejected — reuse the `fsrs` package math via core/srs; a
  parallel copy drifts from the scheduler's decay constants.
- **Build the user-editable per-deck neverQuizzed now.** Rejected for MVP — contradicts `settings.md` read-only
  parsing; the per-card `quizzable:false` covers the MVP need; editable set → #84.
- **Bundle the engine gaps into 1f.** Rejected — mastered-collapse + quizzability precedence are behaviour
  changes needing their own ADR-notes/off-switch/goldens; split to 1f.1 for green-per-slice revertability.

## Consequences

- **Positive:** deletes real duplication (one section renderer, one scaffold, one meta chip); fixes two live
  bugs (type label, FSRS orphan); keeps the high-risk study path on its own well-scoped screens; honors
  invariant #2 (config-driven flow labels, no card-type branch) + #5 (FSRS key). Faithful to card.md's intent.
- **Trade-offs / risk:** highest risk is grade-path regression on the study screens — mitigated by S0
  characterization-first + no-funnel + study-last. The stub adds a fileless pseudo-card — contained to its own
  screen + barred from queues. Mastered-collapse changes the view expand-set — shipped as an owned change with a
  golden + off-switch. `card.md`'s "one widget with a mode" wording is reinterpreted as "one shared component
  layer" (recorded here + amended in `card.md`).
- **Guarded invariants:** no card-type `if/else` in shared code (dispatch via FlowSpec / `isApproachCard` /
  `isPracticeTrack`); FSRS key stays `cardId::sectionSlug`; algo/SD/behavioral stay the exempt engine screens;
  subject-neutral copy; existing quizzable sets byte-identical except an explicit `quizzable:false`.

## Validation

- S0 exists and is green on `main` before any lift: a real grade tap writes `seedState` (Learn: reviewCount 0,
  no review row, re-queue on fail, no Easy) vs `recordReview` (Review: prior state threaded, review row); goldens
  captured.
- S1: VIEW renders byte-identical to its S0 golden; the type chip equals `flow.displayLabel` (a custom-flow-label
  case proves no hardcode); the private members are deleted (not carried).
- S2: rename a heading → keep-vs-reset prompt; KEEP moves the `srs_state` row (history intact, new slug); a
  typo/body edit → no prompt, row untouched; a removed section prunes its orphan; the key shape is unchanged.
- 1f.1: a high-R review section collapses with the badge; a due section never collapses (view or study); the
  quizzability precedence matrix (deny > allowlist > policy; `quizzable:true` a no-op) holds and existing decks'
  study sets are unchanged except an explicit `quizzable:false`.
