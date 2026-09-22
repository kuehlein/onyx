# G7 — Surface-layer generalization (task #88)

**Status:** scoped 2026-09-20, not started · **Owner:** #88 (the remaining core of #30).

> **One line.** The generalization *engine* is config-driven and acceptance-tested, but
> the *presentation layer* still hardcodes SWE-interview framing for every subject. G7
> migrates the surfaces onto the seams the engine already exposes so the app is *honestly*
> general. **SWE stays byte-identical** throughout (its config supplies the interview words).

## 1. The problem (verified 2026-09-20 deep audit)

A non-SWE learner (the in-repo Korean vault; a future exam/hobby subject) sees the SWE app:
Home says "Set your **interview** target" → `/interview-prep`; the target sheet asks for a
"Company"; readiness says "**Interview** readiness"; Insights shows five SWE applied-skill
sections; the coach nudges about "the interview." The lever built to fix this
(`Vocabulary.examinerNoun`) is consumed in **one** file, and the **no-config default subject
is SWE**, so a folder-created user lands in the SWE experience.

## 2. The model — two orthogonal axes

The engine already separates these; the surface must too.

- **Terminology = per-TEMPLATE** (`SubjectConfig.vocabulary`). What the assessment is *called*
  ("interview" / "exam" / "recital" / none). SWE sets it; a neutral subject leaves it null.
- **Presence of a dated assessment = per-GOAL** (`ReadinessTarget.interviewDate` +
  `StudyGoal.interviews` / `InterviewAim`). Whether *this* goal has a date/rounds. A goal can
  be open-ended (no date) even in a subject that supports assessments.

**The gate:** a surface shows assessment chrome when the goal's template declares an
assessment noun (`vocabulary.hasAssessment`), and shows the *dated* bits (countdown, rounds)
only when the goal actually has a date. Copy is always drawn from `Vocabulary`, never a
literal. Everything reads the **focused goal's template** vocab (via the registry), not the
process-global `activeSubject` — this is what makes it correct under multi-subject.

Note the target's **dimensions** (level × context × track) are *already* generalized
(`TargetSpec`; Korean = A1/B1 · casual/exam · speaking/reading). Only the *wording* and the
*route target* leak. The "target card" itself is a legitimate general concept (what you're
aiming at); it just must not say "interview" unless the template does.

## 3. Leak inventory (all verified in code)

| # | Surface | File | Leak |
|---|---|---|---|
| 1 | Home target card | `features/home/home_screen.dart:188-262` | "Set your interview target" / "interview is today"; unconditional; → `/interview-prep` |
| 2 | Target sheet | `features/home/target_sheet.dart` | "Company", "Interview date"; SWE round types |
| 3 | Interview-prep hub | `features/interview/interview_prep_screen.dart` | whole SWE hub reachable from every Home |
| 4 | Readiness panel | `features/home/readiness_panel.dart:264-283,434,455,499` | "Interview readiness" / "interview-tested" |
| 5 | Insights applied group | `features/insights/insights_screen.dart:225-231` | 5 hardcoded SWE sections, ungated by `flows` |
| 6 | Coach nudges | `core/coach/coach_update.dart`, `core/ai/coach.dart` | "interview in N days", "prep for a specific interview" |
| 7 | Default subject | `core/subject/active_subject.dart:13`, `shared/providers/subject.dart:28,56` | no-config fallback = `softwareInterviewsConfig` |
| 8 | "vault"/"Obsidian" nouns | `home_screen.dart:149-151`, `browse_screen.dart:114`, story/settings | user-facing "vault"; product-direction §4 says "folder" |

## 4. `Vocabulary` extension (the mechanism)

Grow the existing class (it was designed to — "grows … whether it has rounds … when a
consumer needs it"). Minimal first cut:

```dart
class Vocabulary {
  const Vocabulary({this.examinerNoun = 'examiner', this.assessmentNoun});
  final String examinerNoun;          // existing (grading persona noun)
  final String? assessmentNoun;       // NEW: 'interview' (SWE) | 'exam' | null (neutral)
  bool get hasAssessment => assessmentNoun != null;
  String get assessmentNounTitle => …; // title-cased, like examinerNounTitle
  static const neutral = Vocabulary();
}
```

- SWE config: `Vocabulary(examinerNoun: 'interviewer', assessmentNoun: 'interview')`.
- Parse `assessmentNoun` from YAML `vocabulary:` (already parsed for `examinerNoun`).
- Templated copy must reproduce SWE wording exactly: `"Set your ${v.assessmentNoun} target"`
  with `assessmentNoun:'interview'` == today's string → byte-identical.
- Grow to `assessmentVerb` / round-type labels only when a consumer needs them.

## 5. Phases (each: green + committable + a neutral-subject test + SWE byte-identical)

- **G7a — Extend `Vocabulary`.** Add `assessmentNoun` + `hasAssessment` + title-case + YAML
  parse; SWE config sets `'interview'`. Pure model + tests. No UI yet. *(SWE unchanged.)*
- **G7b — Home target card + route.** Draw copy from the focused goal's template vocab; route
  to `/interview-prep` only when `hasAssessment`, else the goal editor; neutral copy ("Set your
  target" / countdown only when dated). Widget test: a neutral subject shows no "interview" and
  routes to the editor. *(SWE: assessmentNoun='interview' → identical strings + route.)*
- **G7c — Target sheet.** Relabel via Vocabulary; gate the SWE-specific fields ("Company",
  round-type picker) on `hasAssessment`. *(Retiring `showTargetSheet` into the goal editor —
  ux-vision §3.7/Phase 4 — is a larger follow-up; relabel first.)*
- **G7d — Readiness panel + Insights applied group.** Panel copy via Vocabulary. Drive the
  Insights "Applied performance" sections off `activeSubject.flows` (render a section only for a
  flow the subject declares) instead of five hardcoded SWE sections. *(SWE declares all five →
  identical.)* Biggest sub-piece.
- **G7e — Coach nudges.** Route `coach_update.dart` + `coach.dart` interview strings through
  Vocabulary. *(SWE byte-identical.)*
- **G7f — Neutral default subject.** *(Delicate — see Risks.)* Define `neutralSubjectConfig`
  (valid target slots so nothing crashes); make the no-config fallback neutral. FIRST ensure the
  SWE experience still resolves SWE — via the goal `templateId` and/or an explicit
  `_meta/onyx-subject.yaml` in the SWE vault — guarded by a golden. Sequence last.
- **G7g — "vault"/"Obsidian" → "folder" copy sweep.** Small string sweep (overlaps #85 for the
  settings header). *(No behavior change.)*

## 6. Key decisions (recommendations — confirm if you disagree)

1. **Neutral subjects keep a target card** (level×context×track is a real aim), worded
   neutrally + routing to the goal editor — rather than hiding it. Hide only the dated countdown
   when there's no date.
2. **`Vocabulary` starts with `assessmentNoun` only** (+ derived `hasAssessment`). Add
   verb/round-type labels when a consumer needs them — the codebase's own YAGNI rule.
3. **`/interview-prep` is gated + relabelled** this pass, not deep-generalized. Its SWE-specific
   contents (STAR story bank, coding/system-design round types) stay as the SWE profile; a
   neutral subject simply doesn't reach the hub.
4. **`target_sheet` is relabelled + field-gated now; full retirement into the goal editor is a
   separate step** (it's ux-vision Phase 4 and touches persistence).
5. **Read the focused goal's template vocab, not the global `activeSubject`** — correctness
   under multi-subject.

## 7. Risks

- **SWE byte-identity via the default subject (G7f).** SWE currently relies on the no-config
  *fallback* being `softwareInterviewsConfig` (`subject.dart:28,56`). Flipping it to neutral
  **will change the SWE experience unless SWE is selected another way first.** Mitigation: pin
  SWE via the goal `templateId` resolution and/or add an explicit `_meta/onyx-subject.yaml` to
  the SWE study vault; add a golden asserting the SWE vault still resolves the SWE config; only
  then flip the fallback. Do G7f last, behind that golden.
- **Copy drift.** Every templated string must reproduce the SWE literal exactly under
  `assessmentNoun:'interview'`. Cover with widget tests that assert the SWE strings unchanged
  *and* a neutral subject's strings.
- **Multi-goal vocab source.** Using `activeSubject` (global) instead of the focused goal's
  template would mis-word a secondary goal. Always resolve via the goal's template.

## 8. Out of scope (leave as the SWE profile's own content)

`InterviewRoundType` enum (SWE round kinds), the STAR story bank, the `SeniorityLevel /
CompanyTier / Track` enum *views* in `target.dart` (AI-calibration, "until Phase 4"). These are
SWE-config content, not surface leaks — a neutral subject never sees them because the assessment
chrome is gated off. Deep-generalizing them is post-G7.

## 9. Definition of done

Running the **Korean vault** end-to-end: Home shows a neutral target/aim (no "interview", no
`/interview-prep`), the target sheet has no "Company", readiness/insights/coach copy is neutral,
and a no-config folder resolves to the neutral subject — while the **SWE vault renders
byte-identically** to today (golden + widget tests). `Vocabulary` carries the assessment noun;
no user-facing "interview"/"vault" literal remains outside the SWE config path.

*Cross-refs: [roadmap.md](roadmap.md) (#30/G7), [personas-and-stories.md](personas-and-stories.md)
(S13, the driving story), [readiness-dashboard.md](readiness-dashboard.md) (dims are the SWE
template's), [ux-vision.md](ux-vision.md) §3.3/§10 (no privileged subject).*
