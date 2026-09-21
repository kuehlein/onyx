/// The configurable definition of a study *subject* — the spine of the
/// multi-subject generalization (task #30, see docs/multi-subject-plan.md).
///
/// Everything currently hardcoded for SWE-interview prep (the target dimensions,
/// domain weights, tier-relevance curves, durability bar — and, in later phases,
/// flows, rubrics, coach persona, and terminology) becomes data on this object.
/// The engine reads it; a subject is config, not code. The SWE reference subject
/// lives in `software_interviews.dart`.
///
/// Phase 0 populates only [id] + [target] (enough to mirror the readiness math and
/// lock it with golden tests). Later phases grow the object (domains/labels, flows,
/// coach persona, lexicon) — kept intentionally minimal here to avoid speculative
/// structure.
library;

import 'flow_spec.dart';

export 'flow_spec.dart';

/// One selectable value of the ordered **level** slot — "how deep must knowledge
/// go". [tierCurve] index `i` maps to tier `i+1`; the last entry applies to that
/// tier and everything deeper. Higher levels carry curves that stay high into the
/// advanced tiers (a strictly harder bar).
class LevelValue {
  const LevelValue({
    required this.id,
    required this.label,
    required this.tierCurve,
  });

  final String id;
  final String label;
  final List<double> tierCurve;
}

/// One value of the **context** slot — "how locked-in must recall be". Sets the
/// FSRS stability (days) at which recall counts as fully durable.
class ContextValue {
  const ContextValue({
    required this.id,
    required this.label,
    required this.stabilityTargetDays,
  });

  final String id;
  final String label;
  final double stabilityTargetDays;
}

/// One value of the **track** slot — "which domains weigh most". [familyWeights]
/// maps a [DomainFamily.id] to a multiplier; a domain in no listed family weighs
/// 1.0.
class TrackValue {
  const TrackValue({
    required this.id,
    required this.label,
    this.familyWeights = const {},
  });

  final String id;
  final String label;
  final Map<String, double> familyWeights;
}

/// A group of domain tags that share a track multiplier. A domain matches if its
/// lowercased key is in [exact] or contains any substring in [contains].
class DomainFamily {
  const DomainFamily({
    required this.id,
    this.exact = const {},
    this.contains = const [],
  });

  final String id;
  final Set<String> exact;
  final List<String> contains;

  bool matches(String lowerDomain) =>
      exact.contains(lowerDomain) || contains.any(lowerDomain.contains);
}

/// The 3-slot target model (decision #2 in docs/multi-subject-plan.md). The
/// slot *roles* are fixed — level → knowledge depth, context → durability bar,
/// track → domain weights — while the *values* are configured per subject.
class TargetSpec {
  const TargetSpec({
    required this.levels,
    required this.contexts,
    required this.tracks,
    required this.families,
    required this.fallbackLevelId,
    required this.fallbackContextId,
    required this.fallbackTrackId,
  });

  final List<LevelValue> levels;
  final List<ContextValue> contexts;
  final List<TrackValue> tracks;
  final List<DomainFamily> families;

  final String fallbackLevelId;
  final String fallbackContextId;
  final String fallbackTrackId;

  LevelValue levelById(String id) => levels.firstWhere(
        (v) => v.id == id,
        orElse: () => levels.firstWhere((v) => v.id == fallbackLevelId),
      );

  ContextValue contextById(String id) => contexts.firstWhere(
        (v) => v.id == id,
        orElse: () => contexts.firstWhere((v) => v.id == fallbackContextId),
      );

  TrackValue trackById(String id) => tracks.firstWhere(
        (v) => v.id == id,
        orElse: () => tracks.firstWhere((v) => v.id == fallbackTrackId),
      );

  /// Relevance (0..1) of knowledge at [tier] for [levelId]. Mirrors the legacy
  /// `tierRelevance()`: a null/`<1` tier is treated as foundational.
  double tierRelevance(String levelId, int? tier) {
    final curve = levelById(levelId).tierCurve;
    if (tier == null || tier < 1) return curve.first;
    return curve[(tier - 1).clamp(0, curve.length - 1)];
  }

  double stabilityTargetDays(String contextId) =>
      contextById(contextId).stabilityTargetDays;

  /// The track multiplier for a domain. Mirrors the legacy `domainWeight()`: the
  /// first matching family (in declared order) wins; an unmatched domain is 1.0.
  double domainWeight(String trackId, String domain) {
    final d = domain.toLowerCase();
    final track = trackById(trackId);
    for (final family in families) {
      if (family.matches(d)) return track.familyWeights[family.id] ?? 1.0;
    }
    return 1.0;
  }
}

/// Per-subject assessment **terminology** (task #30, G3) — so shared engine copy
/// reads right for each subject instead of a hardcoded SWE voice (a Korean
/// learner shouldn't be told to "answer the interviewer"). The coach *voice* is
/// the vault coach-skill lever; this is the orthogonal *noun* lever. Small on
/// purpose: only the grading persona's agent noun today, since that's the one
/// shared site with a consumer — it grows (assessment noun, verb, whether it has
/// rounds) when a consumer needs it, not before.
class Vocabulary {
  const Vocabulary({this.examinerNoun = 'examiner'});

  /// What the mock grading persona is CALLED in shared UI. The SWE reference
  /// overrides to "interviewer"; the neutral default ("examiner", matching the
  /// coach's own foundation prompt) suits any subject. Lowercase — display sites
  /// that need title case use [examinerNounTitle].
  final String examinerNoun;

  /// [examinerNoun] in title case (e.g. "Interviewer") for headings/labels.
  String get examinerNounTitle => examinerNoun.isEmpty
      ? examinerNoun
      : examinerNoun[0].toUpperCase() + examinerNoun.substring(1);

  /// Neutral, subject-agnostic terminology — the default when a subject sets none
  /// (e.g. a config loaded from a vault YAML that declares no vocabulary).
  static const neutral = Vocabulary();
}

/// How a subject's notes become cards — the **parse profile** (task #30, G4). The
/// engine reads these rules instead of hardcoding them, so a subject can declare
/// its own conventions (H3 sections, extra file types, no wikilinks, a different
/// never-quizzed set) in `onyx-subject.yaml`. The [standard] defaults reproduce
/// Onyx's built-in parser EXACTLY, so a subject that declares nothing (SWE,
/// Korean) parses identically. Custom section markers (`---` / start-end) and the
/// frontmatter field-map are the "advanced" tier — added when a consumer needs
/// them, not speculatively (docs/settings-ux.md §4).
class ParseProfile {
  const ParseProfile({
    this.sectionHeadingLevel = 2,
    this.fileExtensions = const {'md'},
    this.wikilinks = true,
    this.neverQuizzed,
  });

  /// Sections split on Markdown headings at this level (2 = `##`, 3 = `###`); the
  /// H1 stays the card title.
  final int sectionHeadingLevel;

  /// File extensions (lowercase, no dot) the file walk reads as candidate cards;
  /// card-ness is still decided per file by `type:`.
  final Set<String> fileExtensions;

  /// Whether `[[wikilinks]]` are extracted from card bodies.
  final bool wikilinks;

  /// Headings never scheduled for review (lowercased) — overrides the engine's
  /// built-in blocklist. Null = use that default (the common case); a non-null set
  /// (even empty) replaces it wholesale. Nullable rather than defaulted so the
  /// authoritative blocklist can live next to the parser without an import cycle.
  final Set<String>? neverQuizzed;

  /// Onyx's built-in parsing rules — the default when a subject declares none.
  static const standard = ParseProfile();
}

/// A configured study subject. Grows across the #30 phases; currently [id],
/// [target] (Phase 0/2), [flows] (Phase 3), [vocabulary] (G3), and
/// [parseProfile] (G4).
class SubjectConfig {
  const SubjectConfig({
    required this.id,
    required this.target,
    this.flows = const [],
    this.coachSkill,
    this.vocabulary = Vocabulary.neutral,
    this.parseProfile = ParseProfile.standard,
    this.domainLabels = const {},
  });

  final String id;
  final TargetSpec target;

  /// Assessment terminology for shared engine copy. Neutral by default; the SWE
  /// reference sets "interviewer" so its UI is unchanged.
  final Vocabulary vocabulary;

  /// How this subject's notes become cards (task #30, G4). Defaults reproduce
  /// Onyx's built-in parser exactly.
  final ParseProfile parseProfile;

  /// Pretty display labels for domain tags (e.g. `ds-a` → "DS & A"), so shared
  /// readiness/insights copy reads right per subject rather than a hardcoded SWE
  /// map. A domain with no entry falls back to generic title-casing.
  final Map<String, String> domainLabels;

  /// One flow per card `type:`. See [flowForType].
  final List<FlowSpec> flows;

  /// The `_meta/` file name of this subject's **coach skill** (read via
  /// `VaultSource.readMeta`, e.g. `coach.md`) — the domain framing that augments
  /// the coach's research-backed foundation (task #30, coach de-privileging).
  /// Null / missing → the foundation stands alone (`CoachSkill.none`).
  final String? coachSkill;

  /// The flow describing a card `type:` value, or null if the subject declares
  /// none (callers fall back to a safe default).
  FlowSpec? flowForType(String cardType) {
    for (final f in flows) {
      if (f.cardType == cardType) return f;
    }
    return null;
  }

  /// Whether a card type is a separate paced practice track (its flow schedules
  /// as two-clock/mock) rather than part of the spaced concept deck (recall).
  /// An unknown/unconfigured type is treated as a concept card (not practice).
  bool isPracticeTrackType(String cardType) {
    final f = flowForType(cardType);
    return f != null && f.scheduling != SchedulingModel.recall;
  }

  /// Whether [cardType] is a recognized flow for this subject (used to decide a
  /// markdown file is an Onyx card).
  bool isCardType(String cardType) => flowForType(cardType) != null;
}
