/// A **flow** (practice/study mode) described as data — task #30 Phase 3.
///
/// Each flow corresponds to a card `type:` and declares how that card is
/// scheduled and which of its sections are quizzable. This replaces the
/// hardcoded `switch (CardType)` in the parser and is the substrate Phase 4 hangs
/// per-flow rubrics and coach personas on. SWE ships one FlowSpec per CardType in
/// `software_interviews.dart`.
library;

import '../query/card_query.dart';

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

/// Where a flow's cards declare their prerequisite concepts for daily-plan
/// gating — config, so the daily plan dispatches on the flow instead of
/// branching on card type (invariant #2).
enum PrereqSource {
  /// The card's `depends-on` frontmatter (the generic path). Default.
  dependsOn,

  /// The card's `## Related` wikilinks (system-design problems gate on these).
  wikilinks,
}

/// The declarative description of one flow, keyed to a card `type:` value.
class FlowSpec {
  const FlowSpec({
    required this.cardType,
    required this.scheduling,
    required this.quizzability,
    this.prereqSource = PrereqSource.dependsOn,
    this.label = '',
    this.iconKey = 'card',
    this.colorKey = 'default',
    this.skill,
    this.weightDomain,
    this.attemptSource,
    CardQuery? selector,
  }) : _selector = selector;

  /// The card `type:` frontmatter value this flow applies to.
  final String cardType;

  /// The subject-level **membership query** for this flow (ADR-0020 §2): a card
  /// belongs to this flow iff its [selector] matches. Defaults to matching the card's
  /// `type:` ([TypeIs] over [cardType]) — byte-identical to the pre-selector
  /// `flowForType` lookup — so a flow needs no explicit selector until it keys on a
  /// tag/folder/marker instead of `type:`. Held privately so the default can depend on
  /// [cardType] (a const default can't).
  final CardQuery? _selector;

  /// This flow's membership query (see [_selector]); the `type:`-matching default when
  /// none was configured.
  CardQuery get selector => _selector ?? TypeIs(cardType);
  final SchedulingModel scheduling;
  final QuizzabilityPolicy quizzability;

  /// Where this flow's cards get their prerequisite concepts for daily-plan
  /// gating (config, so the plan doesn't branch on card type — invariant #2).
  final PrereqSource prereqSource;

  /// Config-dir path to this flow's AI skill file (the interviewer/interlocutor/grader
  /// prompt) — a POSIX path under `_onyx/` read via `VaultSource.readMeta` (ADR-0023),
  /// e.g. `skills/order-water.md`. A skill is Onyx config, not a card, so it's
  /// excluded from the card index and travels with its deck on push. Null for an
  /// in-code flow (the SWE flows). Loaded + assembled by `assembleFlowPrompt`.
  final String? skill;

  /// Human label for the type (Browse tiles, filter chips). Falls back to a
  /// prettified [cardType] when empty.
  final String label;

  /// Display keys the UI maps to a Flutter `IconData` / `Color` (core can't hold
  /// Flutter types). Unknown keys fall back to a generic card icon/color.
  final String iconKey;
  final String colorKey;

  /// For a practice track in the daily plan, the readiness domain whose target
  /// weight drives its base priority (so the mix shifts with level/track).
  /// Null → weight 1.0.
  final String? weightDomain;

  /// The applied-attempt `source` string used to gauge this track's
  /// recent-practice load (for the variety down-weight). Null → no
  /// attempt-based recency.
  final String? attemptSource;

  /// The label, or a prettified [cardType] when none is configured.
  String get displayLabel => label.isNotEmpty
      ? label
      : cardType.isEmpty
          ? 'Card'
          : (cardType[0].toUpperCase() + cardType.substring(1))
              .replaceAll('-', ' ');
}
