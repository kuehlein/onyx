/// The interview the user is preparing for. It parameterises readiness three
/// ways (see docs/readiness-dashboard.md §3): **level × company tier × track**
/// decide which domains matter and how heavily, and an optional **interview
/// date** drives the pace readout.
///
/// In Phase A (recall only) the target does two honest things:
///   * re-weights the per-domain recall scores into the overall roll-up by
///     TRACK (e.g. a backend track leans on system design); seniority is carried
///     separately by [tierRelevance] (deeper tiers required as level rises), not
///     by reshuffling whole domains — that let a harder target read as *closer*;
///   * raises the durability bar for FAANG (recall must be more locked-in).
/// It deliberately does not fabricate the applied/mock dimensions it can't yet
/// measure.
library;

import 'dart:convert';
import '../template/active_template.dart';
import '../template/deck_template.dart';
import '../util.dart';

enum SeniorityLevel { newGrad, mid, senior, staff }

enum CompanyTier { typical, faang }

enum Track { general, backend, frontend, fullStack, ml, mobile }

extension SeniorityLevelLabel on SeniorityLevel {
  String get label => switch (this) {
        SeniorityLevel.newGrad => 'New-grad',
        SeniorityLevel.mid => 'Mid',
        SeniorityLevel.senior => 'Senior',
        SeniorityLevel.staff => 'Staff',
      };
}

extension CompanyTierLabel on CompanyTier {
  String get label => switch (this) {
        CompanyTier.typical => 'Typical',
        CompanyTier.faang => 'FAANG',
      };
}

extension TrackLabel on Track {
  String get label => switch (this) {
        Track.general => 'General',
        Track.backend => 'Backend',
        Track.frontend => 'Frontend',
        Track.fullStack => 'Full-stack',
        Track.ml => 'ML',
        Track.mobile => 'Mobile',
      };
}

/// The chosen target, stored as subject-config slot **ids** (level × context ×
/// track) plus an optional interview date. #30 Phase 2 moved this off the SWE
/// enums so the picker/persistence can carry any subject's values; the enums
/// remain as SWE's value set (exposed via [level]/[company]/[track] views) until
/// Phase 4 makes the AI calibration config-driven too.
class ReadinessTarget {
  const ReadinessTarget({
    required this.levelId,
    required this.contextId,
    required this.trackId,
    this.interviewDate,
    this.templateTarget,
  });

  /// Ergonomic construction from the SWE enums (maps to slot ids). Transitional.
  factory ReadinessTarget.of({
    required SeniorityLevel level,
    required CompanyTier company,
    required Track track,
    DateTime? interviewDate,
    TargetSpec? templateTarget,
  }) =>
      ReadinessTarget(
        levelId: level.name,
        contextId: company.name,
        trackId: track.name,
        interviewDate: interviewDate,
        templateTarget: templateTarget,
      );

  final String levelId;
  final String contextId;
  final String trackId;

  /// Date-only (local midnight) of the interview, or null if not set.
  final DateTime? interviewDate;

  /// The owning goal's template dimensions (durability bars, domain weights, tier
  /// curves, ladder slots), carried transiently so per-goal scoring uses the
  /// goal's OWN template rather than the process-global primary (#30d
  /// multi-template). Null → default to the active subject. NOT serialized and NOT
  /// part of equality (it's derived config, not stored state).
  final TargetSpec? templateTarget;

  /// The [TargetSpec] to score against — the goal's template, or the active
  /// subject's when unset.
  TargetSpec get spec => templateTarget ?? activeTemplate.target;

  static const fallback = ReadinessTarget(
    levelId: 'mid',
    contextId: 'faang',
    trackId: 'general',
  );

  /// Enum views of the slot ids — resolve to the SWE enums, falling back to the
  /// default for ids outside the SWE value set. Lets the many enum-based readers
  /// (AI calibration, projection, ladder scoring) stay unchanged this phase.
  SeniorityLevel get level =>
      enumByName(SeniorityLevel.values, levelId) ?? SeniorityLevel.mid;
  CompanyTier get company =>
      enumByName(CompanyTier.values, contextId) ?? CompanyTier.faang;
  Track get track => enumByName(Track.values, trackId) ?? Track.general;

  /// A compact human label, e.g. "Senior · FAANG · Backend" — from the active
  /// subject's slot labels.
  String get label {
    final t = spec;
    return '${t.levelById(levelId).label} · ${t.contextById(contextId).label} · '
        '${t.trackById(trackId).label}';
  }

  /// The FSRS stability (days) at which recall counts as fully durable — the
  /// goal template's **context** slot (SWE: FAANG 120 else 90). See #30.
  double get stabilityTarget => spec.stabilityTargetDays(contextId);

  ReadinessTarget copyWith({
    SeniorityLevel? level,
    CompanyTier? company,
    Track? track,
    String? levelId,
    String? contextId,
    String? trackId,
    Object? interviewDate = _unset,
  }) =>
      ReadinessTarget(
        levelId: levelId ?? level?.name ?? this.levelId,
        contextId: contextId ?? company?.name ?? this.contextId,
        trackId: trackId ?? track?.name ?? this.trackId,
        interviewDate: interviewDate == _unset
            ? this.interviewDate
            : interviewDate as DateTime?,
        // Preserve the template across copies (e.g. per-rung ladder scoring).
        templateTarget: templateTarget,
      );

  // JSON keys stay level/company/track (values are slot ids == legacy enum
  // names), so existing onyx-target.json / onyx-goals.json files load unchanged.
  // Read-only now: the legacy file is migration INPUT, no longer written.
  static ReadinessTarget fromJson(Map<String, dynamic> m) => ReadinessTarget(
        levelId: (m['level'] as String?) ?? fallback.levelId,
        contextId: (m['company'] as String?) ?? fallback.contextId,
        trackId: (m['track'] as String?) ?? fallback.trackId,
        interviewDate: _parseDate(m['interviewDate']),
      );

  /// Decode from stored JSON; returns null on any malformed input so callers can
  /// fall back to a default rather than crash.
  static ReadinessTarget? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

const _unset = Object();

DateTime? _parseDate(Object? v) {
  if (v is! String) return null;
  final d = DateTime.tryParse(v);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// Relative weight of a domain in the overall recall roll-up for [target] — the
/// **track** slot of the active subject config (domain families → per-track
/// multipliers; unmatched domains weigh 1.0). See #30 Phase 1.
///
/// Deliberately NOT level-dependent: seniority is expressed by [tierRelevance]
/// (raising the depth bar), not by reshuffling which domains count. The old
/// per-level swing (algo↓ / system-design↑ with seniority) could make a *harder*
/// target read as *closer* whenever the learner was strong in the up-weighted
/// domains — an inversion (verified 2026-09). Track still shapes emphasis
/// because interview *type* genuinely differs by track.
double domainWeight(ReadinessTarget target, String domain) =>
    target.spec.domainWeight(target.trackId, domain);

/// Relevance weight (0..1) of knowledge at a given **tier** (knowledge-hierarchy
/// depth, 1 = foundational → higher = specialist) for a target [level]'s
/// interview. This is THE seniority knob: level affects readiness ONLY through
/// tier depth here (higher levels require deeper tiers → a strictly harder bar),
/// never by reshuffling whole-domain weights in [domainWeight] — doing the latter
/// let a harder target read as *closer* (an inversion; verified 2026-09). The
/// other half of card relevance is [domainWeight] (track-only). Together they let
/// peripheral-for-this-target cards contribute ~0 to readiness (so adding them
/// never lowers the number) while an advanced-but-essential card counts fully for
/// a senior.
///
/// Grounded in a verified research pass (2026-09-09, deep-research): foundations
/// stay FULLY required (table-stakes) at every level — "less differentiating" is
/// a candidate-ranking notion, not a readiness one, and weak foundations are
/// already gated by readiness's weakest-link (p20) floor. Advanced tiers matter
/// more as seniority rises. The deepest specialist tier is < 1 for everyone
/// because breadth-with-selective-depth (not total mastery) is the norm. The
/// staff differentiator (judgment) is orthogonal to tiers and is captured by the
/// applied/transfer dimension, not here. Now read from the active subject's
/// **level** slot (tier curves) — see #30 Phase 1.
double tierRelevance(SeniorityLevel level, int? tier) =>
    activeTemplate.target.tierRelevance(level.name, tier);

/// The tier→weight map for a [target]'s level, covering tiers 1..[maxTier].
/// Passed to `computeReadiness` so coverage + strength are relevance-weighted.
Map<int, double> tierWeightsFor(ReadinessTarget target, {int maxTier = 8}) => {
      for (var t = 1; t <= maxTier; t++)
        t: target.spec.tierRelevance(target.levelId, t),
    };
