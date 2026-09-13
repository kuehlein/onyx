/// The configurable definition of a study *subject* — the spine of the
/// multi-subject generalization (task #30, see docs/generalization-plan.md).
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

/// The 3-slot target model (decision #2 in docs/generalization-plan.md). The
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

/// A configured study subject. Grows across the #30 phases; currently [id],
/// [target] (Phase 0/2), and [flows] (Phase 3).
class SubjectConfig {
  const SubjectConfig({
    required this.id,
    required this.target,
    this.flows = const [],
  });

  final String id;
  final TargetSpec target;

  /// One flow per card `type:`. See [flowForType].
  final List<FlowSpec> flows;

  /// The flow describing a card `type:` value, or null if the subject declares
  /// none (callers fall back to a safe default).
  FlowSpec? flowForType(String cardType) {
    for (final f in flows) {
      if (f.cardType == cardType) return f;
    }
    return null;
  }
}
