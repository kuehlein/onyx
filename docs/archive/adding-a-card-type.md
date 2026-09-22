# Adding a card type (a "flow")

Onyx is **data-driven**: a card `type:` and how it behaves are described by a
`FlowSpec`, not a hardcoded `switch`. Adding a new type is mostly declaring one
`FlowSpec` — the parser, Browse, filters, and scheduling pick it up from there.

## The model

`lib/core/subject/flow_spec.dart` defines `FlowSpec` — the declarative
description of one flow, keyed to a card `type:` value:

| field | meaning |
|---|---|
| `cardType` | the `type:` frontmatter value this flow applies to (e.g. `flashcard`, `interview-question`, `algorithm`, `system-design`, `behavioral`) |
| `scheduling` | `SchedulingModel.recall` (FSRS Learn/Review), `.twoClock` (algorithms: solve + explain), or `.mock` (AI-graded system-design/behavioral) |
| `quizzability` | which H2 sections become scheduled recall units: `allSections`, `noSections`, `approachOnly`, or `blocklist` (everything but shared reference headings) |
| `label` | human label for Browse tiles / filter chips (falls back to a prettified `cardType`) |
| `iconKey` / `colorKey` | display keys the UI maps to an `IconData` / `Color` (core holds no Flutter types) |
| `skill` | optional vault path to an AI prompt file (interviewer/grader), or null for an in-code flow |

A subject ships one `FlowSpec` per `cardType`. The SWE subject's live in
`lib/core/subject/software_interviews.dart`.

## Steps

1. **Declare the flow.** Add a `FlowSpec` to the subject config's flow list
   (`software_interviews.dart`) with your `cardType`, `scheduling`,
   `quizzability`, `label`, and `iconKey`/`colorKey`.

2. **Nothing to change in the parser.** `CardParser` (`lib/core/vault/
   card_parser.dart`) treats a file as a card iff `subject.isCardType(type)` —
   which just checks the configured flows — and reads section quizzability from
   `subject.flowForType(type)?.quizzability`. No `switch` to edit.

3. **Wire the display keys** if you introduced new ones: map `iconKey` in
   `flowIcon()` (`lib/features/browse/browse_screen.dart`) and `colorKey` in
   `SubjectColor.forKey()` (`lib/shared/design/subject_color.dart`). Unknown
   keys fall back to a generic card icon / a neutral slate hue.

4. **Author cards.** Any `.md` with `type: <your-cardType>` in its frontmatter
   now indexes, appears in Browse, and schedules per the flow's `scheduling` +
   `quizzability`. See `docs/card-schema.md` for the frontmatter/section shape.

5. **Session UI (only for `twoClock` / `mock`).** `recall` flows reuse the
   Learn/Review/Quiz screens automatically. A `twoClock` or `mock` flow needs
   its own session screen + (for `mock`) a rubric/grader; follow the existing
   algorithm / system-design / behavioral tracks as templates, and — if the
   flow's interlocutor lives in the vault — point `skill` at its prompt file
   (assembled by `assembleFlowPrompt`, `lib/core/subject/flow_prompt.dart`).

## References

- `lib/core/subject/flow_spec.dart` — the `FlowSpec` / `SchedulingModel` /
  `QuizzabilityPolicy` definitions.
- `lib/core/subject/software_interviews.dart` — the SWE subject's flows.
- `lib/core/vault/card_parser.dart` — how a `type:` becomes a card + quizzable
  sections.
- `docs/card-schema.md` — the on-disk card format.
