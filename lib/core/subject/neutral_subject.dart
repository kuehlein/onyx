import 'subject_config.dart';

/// The built-in **neutral** subject — the subject-agnostic default for a folder
/// that declares no `onyx-subject.yaml` of its own (task #88 / G7f). One flat
/// level/context/track and a single `flashcard` flow; neutral vocabulary (no
/// assessment framing → no "interview" chrome), the standard parse profile, and
/// no domain labels. A folder opts into a richer subject by declaring its own
/// config — or the built-in SWE reference via `id: software-interviews`.
///
/// Deliberately minimal but VALID (non-empty target slots) so every engine path
/// that reads a subject works without special-casing. `cardType: 'flashcard'` is
/// the universal recall card type (matching the scaffolder's neutral YAML).
const neutralSubjectConfig = SubjectConfig(
  id: 'general',
  target: TargetSpec(
    levels: [
      LevelValue(id: 'all', label: 'All', tierCurve: [1.0])
    ],
    contexts: [
      ContextValue(id: 'standard', label: 'Standard', stabilityTargetDays: 90),
    ],
    tracks: [TrackValue(id: 'everything', label: 'Everything')],
    families: [],
    fallbackLevelId: 'all',
    fallbackContextId: 'standard',
    fallbackTrackId: 'everything',
  ),
  flows: [
    FlowSpec(
      cardType: 'flashcard',
      scheduling: SchedulingModel.recall,
      quizzability: QuizzabilityPolicy.blocklist,
      label: 'Cards',
      iconKey: 'flashcard',
    ),
  ],
);
