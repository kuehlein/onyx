/// A **flow** (practice/study mode) described as data — task #30 Phase 3.
///
/// Each flow corresponds to a card `type:` and declares how that card is
/// scheduled and which of its sections are quizzable. This replaces the
/// hardcoded `switch (CardType)` in the parser and is the substrate Phase 4 hangs
/// per-flow rubrics and coach personas on. SWE ships one FlowSpec per CardType in
/// `software_interviews.dart`.
library;

/// How a flow's cards are scheduled/practiced.
enum SchedulingModel {
  /// FSRS spaced recall (the Learn/Review concept deck).
  recall,

  /// The Algorithms two-clock: solve (execution) + explain (recognition).
  twoClock,

  /// An AI mock (system-design / behavioral) graded against a rubric.
  mock,
}

/// Which sections of a card are scheduled as quizzable recall units.
enum QuizzabilityPolicy {
  /// Every H2 section is its own unit (e.g. each algorithm problem).
  allSections,

  /// No sections — the whole card is practiced as one unit (mock flows).
  noSections,

  /// Only the "Approach" section (interview-question cards).
  approachOnly,

  /// Every section except the shared reference/blocklist headings (concept cards).
  blocklist,
}

/// The declarative description of one flow, keyed to a card `type:` value.
class FlowSpec {
  const FlowSpec({
    required this.cardType,
    required this.scheduling,
    required this.quizzability,
    this.label = '',
    this.iconKey = 'card',
    this.colorKey = 'default',
    this.skill,
  });

  /// The card `type:` frontmatter value this flow applies to.
  final String cardType;
  final SchedulingModel scheduling;
  final QuizzabilityPolicy quizzability;

  /// Vault path to this flow's AI skill file (the interviewer/interlocutor/grader
  /// prompt authored in the vault), or null for an in-code flow (the SWE flows).
  /// Loaded at runtime and assembled by `assembleFlowPrompt` (flow_prompt.dart).
  final String? skill;

  /// Human label for the type (Browse tiles, filter chips). Falls back to a
  /// prettified [cardType] when empty.
  final String label;

  /// Display keys the UI maps to a Flutter `IconData` / `Color` (core can't hold
  /// Flutter types). Unknown keys fall back to a generic card icon/color.
  final String iconKey;
  final String colorKey;

  /// The label, or a prettified [cardType] when none is configured.
  String get displayLabel => label.isNotEmpty
      ? label
      : cardType.isEmpty
          ? 'Card'
          : (cardType[0].toUpperCase() + cardType.substring(1))
              .replaceAll('-', ' ');
}
