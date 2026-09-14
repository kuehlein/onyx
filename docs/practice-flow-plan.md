# Practice-Flow Generalization + Study Policy (task #30c / Phase 7)

**Status:** approved design, not yet built. The deferred "practice-flow half" of
#30, un-deferred once we grounded it in a real abstraction (system design *is*
the template for the language conversation flow). Companion to
`docs/generalization-plan.md` and `docs/vault-structure.md`. Execute
phase-by-phase; every phase keeps the app green (analyze + full suite) and is
independently committable. SWE behavior stays identical throughout (golden tests).

## The unifying abstraction

A **practice flow** = three things (user's framing, confirmed):
1. a **problem file** — the card (an SD problem; a "order food at a restaurant"
   conversation; a stats problem set),
2. a **per-flow/difficulty AI skill** — the interviewer/interlocutor/grader prompt,
   authored as a **file in the vault**, and
3. **conceptual dependencies** — the concept cards that must be known to a degree
   before the flow is legitimately available.

Algorithms (two-clock), system design (mock), behavioral (mock) are three existing
instances; a language conversation is a fourth. The engine (AI conversation +
grade, gated on concept competence) already exists generically
(`core/practice/mock_session.dart`, `## Related` gating, comfort thresholds). This
work generalizes the *registry, routing, gating, prompt-location, and card types*
so a new flow is **config + vault files, not code**.

## Decisions locked (2026-09-13)

1. **AI skills live in the vault**, loaded at runtime (merges the old #30b): a
   flow = config + a problem file + a skill file. Authoring lives in the vault.
2. **Subject-defined flow / card types** — replace the fixed `CardType` enum with
   config-declared flow ids (so a subject can have a `conversation` or
   `problem-set` type), resolved via the subject's `flows`.
3. **Three-axis study policy** (below), auto-derived from goal + timeline with
   manual override — NOT one "difficulty" slider (that's the dirt).
4. **Competence-based dependencies** — gating is on concept *competence*
   (durability), not mere coverage; the "AI only uses covered vocabulary"
   constraint is the *same* mechanism, not a special feature.
5. **Soft gate + informed override** — a flow can be opened before its prereqs are
   met; honest, never a hard wall, never inflates readiness.

## Study policy — three ORTHOGONAL axes (the anti-dirt core)

The mess comes from collapsing these into one knob. Keep them separate; each has a
sensible default, a data-bounded range, and a single override point. All three are
resolved by one pure function `resolveStudyPolicy(goal, daysToTarget, difficulty)`
and cascade **card > flow > subject-config > goal-derived default**, clamped.

1. **Retention intensity** — `desiredRetention`, how tightly material is held
   (FSRS target recall; already per-card via Priority). Range **[0.80, 0.95]**,
   hard ceiling **0.97** (review load explodes above it), default **0.90**. May
   ramp up toward a near exam deadline.
2. **Schedule profile** — short-term vs long-term introduction: `durable`
   (learningSteps off — Learn *is* first exposure — + spacing + interleave after
   first exposure) vs `cram` (same-day steps on + massing + higher retention).
   Chosen by goal permanence + deadline proximity. `SrsScheduler.learningSteps`
   (today hardcoded `[]`) becomes policy-driven.
3. **Prerequisite competence bar** — the durability threshold at which a prereq
   counts as "known enough to build on." Durability (FSRS-stability-derived, the
   cramming-resistant measure Onyx already uses for readiness), NOT retrievability
   (which flickers between reviews). Default by rigor/level (~0.6 entry-level exam
   → ~0.8 professional fluency); a heuristic, not research-pinned like retention.

**Goal → defaults:** permanence drives axis 2 (durable subject vs one-off exam);
timeline drives the ramp (retention 0.90→0.95 + cram profile in the final stretch
for *terminal* goals); target level drives axis 3's bar. **Guardrail:** cram is
auto-enabled ONLY for terminal, deadline-bound goals; **prerequisites that gate
downstream flows are always held to the durable profile** so timeline pressure
never hollows out the foundation the dependency graph relies on.

**Transparency (anti-black-box):** always surface the effective policy —
"Holding at 92% · cram (exam in 9d) · flows unlock at 70% competence." Matches the
confidence-display / coach "why now" ethos; user can always see and override.

Ties to task **#32** (FSRS tuning: desired-retention knob, learn-mode handling)
and `fsrs-exam-targeting` (raise desiredRetention + non-rescheduling cram near a
date — never hack due dates).

## Dependency gating (generalizes `## Related`)

- Any flow/card declares `depends-on: [conceptId|tag, ...]` in frontmatter.
- Satisfied when a configurable **fraction** (today's `kPrereqFraction`) of the
  deps clear the **competence bar** (durability ≥ bar) — competence, not coverage.
- **One engine, two consumers:** (a) unlock a flow; (b) compute the AI's usable
  concept set = `{concepts with durability ≥ bar}`, handed to the flow's vault AI
  skill as a hard "stay within these" constraint (the language-frontier case).

## Soft gate + override + the provisional state (downstream analysis)

A locked flow shows the reason + which prereqs are weak + an explicit **"Open
anyway."** Rationale: attempting-before-ready genuinely helps (pretesting effect;
productive failure; exam realism) — on a **gradient** that decays to ~zero as the
gap approaches total. So permit it, informed, and turn it into a *diagnostic*.

**The cascade worry — and why it dissolves.** "food-2 needs food-1, but food-1 was
started too early." The fix is anchoring gates to **concept recall-competence**,
which the override never confers:

- **Gating = recall competence (concept-card durability).** Sourced ONLY from
  concept-card reviews — never from flow attempts.
- **Flows = applied/transfer evidence** (the existing second readiness axis). A
  flow attempt feeds transfer, not the recall competence that gates. So
  override-attempting food-1 does **not** make food-1's vocab durable → food-2 is
  still legitimately gated by honest recall competence → **no false cascade.**
- **Provisional never satisfies a real gate.** If a flow ever depends on *another
  flow's* completion, a provisionally-opened flow does NOT count as satisfied for
  anything downstream (taint containment). Prefer concept-based deps to minimize
  flow→flow edges in the first place.

**The provisional / "started early" state is derived, not stored** — a flow is
provisional exactly while it's been opened AND its concept prereqs are below the
bar. It **self-heals**: as concept study catches up and durability crosses the
bar, the flow graduates to legitimately-unlocked with no manual step. Indicate it
plainly — "Started early — foundations catching up (food vocab 60%)."

**Effect on the user's relationship with prerequisites** (must stay healthy):
- Override affects *access only* — it never marks prereqs known and never moves the
  readiness number. Skipping the work is therefore *visible*, not rewarded.
- Designed right it *strengthens* the relationship: the early attempt creates a
  need-to-know (pretesting) and **routes the diagnosed gaps back into the concept
  queue** ("your convo stalled on numbers → here are the number cards"), so the
  override *accelerates* foundation study instead of replacing it. Close the loop:
  preemptive attempt → diagnose gaps → prioritize those concept cards → foundation
  catches up → flow graduates.
- Coach *stance* is policy-aware: pro-override for terminal cram (exam realism, no
  downstream to protect); pro-foundation-first for durable goals / prereq flows.
- Provisional/hinted attempts self-discount in the transfer estimate (low
  appliedScore, high hintLevel already); optionally weight them less until the
  foundation is met.

**Knowledge-frontier flows** (language): "Open anyway" is a **mode change**, not
just an unlock — the AI shifts to *immersion* (may use uncovered words, but
glosses/translates them: comprehensible-input style) rather than the constrained
mode. Frame it as "switch to immersion (new words, with help)," honest that it's a
different, less-targeted mode.

## Flow types & `CardType` removal

`CardType` (fixed enum) → a card's `type:` is an arbitrary string resolved against
the subject's configured `flows`. Cross-cutting: parser, analytics, browse icons,
routing, daily-plan `TrackId`. Generic screens per scheduling model (recall →
Learn/Review; two-clock → algo screen; mock → the shared mock screen) routed by
flow, so a new flow reuses an existing screen — no new screen code.

## Vault-loaded AI skills (merges #30b)

Each flow's interviewer/grader/tutor prompt is a vault file (e.g.
`_onyx/<theme>/<flow>/skills/*.md`), loaded at runtime; the in-app builders become
generic templates that inject the vault skill + the (card, level, covered-concept
frontier, policy) context. Distribution of the universal authoring kit → the app
as installer (see vault-structure.md); no symlinks/live-sync.

## Phased breakdown (each green + committable)

1. **Study policy core** — `StudyPolicy` (3 axes) + `resolveStudyPolicy` +
   cascade + clamps, wired to `SrsScheduler` (learningSteps/retention now
   policy-driven) and the existing Priority mapping. SWE default == today. Golden.
2. **Competence gating engine** — generalize `## Related`/comfort to `depends-on` +
   durability-bar + fraction; one pure resolver; expose the covered-concept
   frontier. Keep SWE gating identical.
3. **Soft gate + override + provisional state** — derived provisional/self-healing
   state; "Open anyway" (informed); honest record (access-only); coach routes
   diagnosed gaps into the concept queue.
4. **Flow types + `CardType` removal** — arbitrary type ids via config flows;
   generic screens routed per scheduling model; parser/analytics/browse updated.
5. **Vault-loaded AI skills** — load per-flow prompts from the vault; generic
   prompt templates inject skill + context (incl. the frontier constraint).
6. **Validation** — extend the demo theme with a gated `conversation` flow proving
   flow-as-files + gating + override + frontier constraint end-to-end.

## Deferred / out of scope
- STT for spoken flows (task #61 — needs device).
- The full multi-theme `_onyx/` directory + theme switcher (still "one active
  subject at a time").
- Authoring-kit *distribution* installer polish (the app-as-distributor).

## Risk register
- **Conflated knobs** → the three-axis separation + one resolver is the antidote.
- **Override hollowing the foundation** → recall-competence gating (override never
  confers) + cram-only-for-terminal-goals + gaps routed back to concept study.
- **`CardType` removal is broad** → sub-split (phase 4); golden + full suite each step.
- **Vault-loaded prompts drift from app expectations** → generic templates own
  structure/format; vault skill owns persona/terminology only.
