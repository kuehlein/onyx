import 'subject_config.dart';

/// The SWE card-type values — the single source of truth so `system-design` vs
/// `behavioral` comparisons in the SWE-specific providers can't be mistyped as
/// camelCase (the values are hyphenated; the enum NAMES were not).
const kTypeFlashcard = 'flashcard';
const kTypeInterviewQuestion = 'interview-question';
const kTypeAlgorithm = 'algorithm';
const kTypeSystemDesign = 'system-design';
const kTypeBehavioral = 'behavioral';

/// The SWE-interview-prep subject as data — the built-in **reference** config for
/// task #30. Every value here reproduces the behavior currently hardcoded in
/// `lib/core/readiness/target.dart` and `ladder.dart`, so routing those seams
/// through this config (Phase 1) is a no-op for SWE. The golden tests in
/// `test/unit/subject_config_test.dart` lock that equivalence.
///
/// The slot `id`s deliberately equal the legacy enum `.name`s
/// (`SeniorityLevel`/`CompanyTier`/`Track`) so persisted `onyx-target.json` /
/// `onyx-goals.json` values resolve unchanged.
const softwareInterviewsConfig = SubjectConfig(
  id: 'software-interviews',
  // The SWE domain augmentation lives in the shipped vault's `_meta/coach.md`
  // (read via readMeta, parsed by coachSkillFromMarkdown); absent → the
  // learning-science foundation stands alone.
  coachSkill: 'coach.md',
  target: TargetSpec(
    // level → tier-depth curve (was _tierRelevanceByLevel in target.dart).
    levels: [
      LevelValue(
          id: 'newGrad', label: 'New-grad', tierCurve: [1.0, 0.7, 0.35, 0.15]),
      LevelValue(id: 'mid', label: 'Mid', tierCurve: [1.0, 0.9, 0.55, 0.30]),
      LevelValue(
          id: 'senior', label: 'Senior', tierCurve: [1.0, 1.0, 0.90, 0.50]),
      LevelValue(
          id: 'staff', label: 'Staff', tierCurve: [1.0, 1.0, 1.00, 0.65]),
    ],
    // context → FSRS durability bar (was ReadinessTarget.stabilityTarget).
    contexts: [
      ContextValue(id: 'typical', label: 'Typical', stabilityTargetDays: 90),
      ContextValue(id: 'faang', label: 'FAANG', stabilityTargetDays: 120),
    ],
    // track → per-family domain multipliers (was the switch in domainWeight).
    tracks: [
      TrackValue(id: 'general', label: 'General'),
      TrackValue(
          id: 'backend',
          label: 'Backend',
          familyWeights: {'systems-backend': 1.15}),
      TrackValue(
        id: 'frontend',
        label: 'Frontend',
        familyWeights: {'algo': 0.7, 'systems-backend': 0.9},
      ),
      TrackValue(id: 'fullStack', label: 'Full-stack'),
      TrackValue(
          id: 'ml', label: 'ML', familyWeights: {'systems-backend': 1.1}),
      TrackValue(id: 'mobile', label: 'Mobile', familyWeights: {'algo': 0.85}),
    ],
    // The two domain families domainWeight() special-cased (order matters: algo
    // is checked before systems-backend, matching the legacy if/else).
    families: [
      DomainFamily(
        id: 'algo',
        exact: {'ds-a', 'dsa'},
        contains: ['algorithm', 'data-structure'],
      ),
      DomainFamily(
        id: 'systems-backend',
        exact: {
          'system-design',
          'systems',
          'databases',
          'database',
          'distributed-systems',
          'distributed',
          'networking',
          'concurrency',
          'security',
          'backend',
          'api-design',
          'reliability',
        },
        contains: ['system-design'],
      ),
    ],
    // Was ReadinessTarget.fallback (mid · FAANG · general).
    fallbackLevelId: 'mid',
    fallbackContextId: 'faang',
    fallbackTrackId: 'general',
  ),
  // One flow per card type — mirrors the parser's per-type rules + the Browse
  // display (icon/color/label) that used to be a switch over CardType.
  flows: [
    FlowSpec(
      cardType: kTypeFlashcard,
      scheduling: SchedulingModel.recall,
      quizzability: QuizzabilityPolicy.blocklist,
      label: 'Flashcard',
      iconKey: 'flashcard',
      colorKey: 'indigo',
    ),
    FlowSpec(
      cardType: kTypeInterviewQuestion,
      scheduling: SchedulingModel.recall,
      quizzability: QuizzabilityPolicy.approachOnly,
      label: 'Interview question',
      iconKey: 'interview',
      colorKey: 'teal',
    ),
    FlowSpec(
      cardType: kTypeAlgorithm,
      scheduling: SchedulingModel.twoClock,
      quizzability: QuizzabilityPolicy.allSections,
      label: 'Algorithm',
      iconKey: 'algorithm',
      colorKey: 'deepOrange',
    ),
    FlowSpec(
      cardType: kTypeSystemDesign,
      scheduling: SchedulingModel.mock,
      quizzability: QuizzabilityPolicy.noSections,
      label: 'System design',
      iconKey: 'systemDesign',
      colorKey: 'purple',
    ),
    FlowSpec(
      cardType: kTypeBehavioral,
      scheduling: SchedulingModel.mock,
      quizzability: QuizzabilityPolicy.noSections,
      label: 'Behavioral',
      iconKey: 'behavioral',
      colorKey: 'green',
    ),
  ],
);
