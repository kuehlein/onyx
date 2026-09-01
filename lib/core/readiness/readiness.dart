import 'dart:math';

import '../../shared/models/card.dart';
import '../interview/transfer.dart';
import 'target.dart';

/// Phase A of the readiness model (see docs/readiness-dashboard.md): the honest
/// **knowledge-base (recall)** dimension, computed from data we already store —
/// FSRS stability per section + card domains/tiers. It deliberately does NOT
/// claim "interview readiness" (that needs the applied/mock/transfer dimensions);
/// it measures how well the studied material is retained and how much of a domain
/// has been started.
///
/// Per domain: `score = coverage^γ · strength`, where strength is a
/// tier-weighted mean blended with a 20th-percentile floor so a strong average
/// can't hide a weak pocket. Coverage is multiplicative so grinding a small
/// subset can't fake readiness. Reported as a band, not a point.

/// Readiness for one domain.
class DomainReadiness {
  const DomainReadiness({
    required this.domain,
    required this.coverage,
    required this.strength,
    required this.score,
    required this.low,
    required this.high,
    required this.studied,
    required this.total,
    double? recall,
    this.transfer,
    this.appliedN = 0,
  }) : recall = recall ?? score;

  final String domain;
  final double coverage; // 0..1 — fraction of required sections started
  final double strength; // 0..1 — weakest-link-aware retention of studied ones
  final double score; // 0..1 — coverage^γ · strength · transfer factor

  /// The recall-only score (`coverage^γ · strength`), *before* the transfer
  /// factor gates it. Always ≥ [score] because `factor ∈ [τ, 1]`. In the
  /// recall-only view this equals [score]; once mocks graduate the domain it's
  /// the lighter "you know it" ceiling the darker "proven it" fill sits inside.
  final double recall;

  final double low; // band lower bound
  final double high; // band upper bound
  final int studied;
  final int total;

  /// Proven-transfer estimate (0..1) from applied attempts, or null in the
  /// recall-only (Phase A) view.
  final double? transfer;

  /// Weighted count of applied attempts backing [transfer].
  final double appliedN;

  /// A plain-language state for the UI.
  String get label {
    if (studied == 0) return 'Not started';
    if (score >= 0.75) return 'Strong';
    if (score >= 0.45) return 'Developing';
    return 'Needs work';
  }
}

/// The overall knowledge-base readiness plus its per-domain breakdown.
class Readiness {
  const Readiness({
    required this.domains,
    required this.overall,
    required this.low,
    required this.high,
    this.interview = false,
  });

  /// Per-domain, sorted weakest-first (so the UI can flag "focus here").
  final List<DomainReadiness> domains;
  final double overall;
  final double low;
  final double high;

  /// True once applied/mock evidence exists and the transfer factor is in play —
  /// the headline has graduated from "knowledge-base" to "interview" readiness.
  final bool interview;

  bool get isEmpty => domains.isEmpty;

  /// The weakest domain by score, or null if none.
  String? get weakestDomain => domains.isEmpty ? null : domains.first.domain;
}

/// Maps FSRS stability (days-to-90%-retention) to a 0..1 durability. Uses
/// stability, not momentary retrievability, so cramming (which spikes recall but
/// not stability) can't inflate the score. `S = stabilityTarget` → ~1.0.
double durability(double stability, {double stabilityTarget = 90}) {
  if (stability <= 0) return 0;
  return (log(1 + stability) / log(1 + stabilityTarget)).clamp(0, 1).toDouble();
}

/// Weight a section by its card's tier in the domain (1 = most foundational =
/// heaviest). Unknown tier → light default.
double _tierWeight(int? tier) =>
    tier == null ? 1 : (5 - tier).clamp(1, 4).toDouble();

double _percentile(List<double> sortedAsc, double q) {
  if (sortedAsc.isEmpty) return 0;
  // floor (not round) so a weak pocket isn't skipped at small n — the floor
  // should stay conservative / weakest-link.
  final i = (q * (sortedAsc.length - 1)).floor();
  return sortedAsc[i];
}

/// Computes Phase-A knowledge-base readiness. [stabilityByKey] maps
/// `"cardId::sectionSlug"` → FSRS stability (days); a missing key means the
/// section is unstudied (counts against coverage, not strength).
Readiness computeReadiness({
  required List<Card> cards,
  required Map<String, double> stabilityByKey,
  double stabilityTarget = 90,
  double coverageGamma = 0.7,
  Map<String, double>? domainWeights,
  Map<String, TransferEstimate>? transferByDomain,
  double transferTau = 0.5,
}) {
  final byDomain = <String, List<Card>>{};
  for (final c in cards) {
    final d = c.domain;
    if (d == null) continue;
    byDomain.putIfAbsent(d, () => []).add(c);
  }

  final domains = <DomainReadiness>[];
  for (final entry in byDomain.entries) {
    final domain = entry.key;
    final studiedStrengths = <double>[];
    var weightedSum = 0.0;
    var weightTotal = 0.0;
    var total = 0;

    for (final card in entry.value) {
      final weight = _tierWeight(card.tiers[domain]);
      for (final section in card.quizzableSections) {
        total++;
        final stability = stabilityByKey['${card.id}::${section.slug}'];
        if (stability == null) continue; // unstudied → hits coverage only
        final s = durability(stability, stabilityTarget: stabilityTarget);
        studiedStrengths.add(s);
        weightedSum += weight * s;
        weightTotal += weight;
      }
    }

    if (total == 0) continue;
    final studied = studiedStrengths.length;
    final coverage = studied / total;

    double strength = 0;
    if (studied > 0) {
      final mean = weightTotal == 0 ? 0.0 : weightedSum / weightTotal;
      final p20 = _percentile(studiedStrengths..sort(), 0.2);
      strength = 0.5 * mean + 0.5 * p20; // weakest-link aware
    }

    final recall = pow(coverage, coverageGamma).toDouble() * strength;
    // Band widens with low coverage and few studied items.
    final recallMargin =
        (0.20 * (1 - coverage) + 0.30 / sqrt(studied + 1)).clamp(0.03, 0.30);

    // Recall-only by default; when applied evidence is in play, gate recall by
    // the transfer factor (τ + (1-τ)·Transfer_d) — a conjunctive weakest-link so
    // a low/unproven applied score caps the domain even if recall is high.
    var score = recall;
    var low = recall - recallMargin;
    var high = recall + recallMargin;
    double? transferValue;
    var appliedN = 0.0;
    if (transferByDomain != null) {
      final te = transferByDomain[domain] ?? zeroEvidenceTransfer;
      transferValue = te.value;
      appliedN = te.effectiveN;
      double factor(double t) => transferTau + (1 - transferTau) * t;
      score = recall * factor(te.value);
      low = (recall - recallMargin) * factor(te.low);
      high = (recall + recallMargin) * factor(te.high);
    }

    domains.add(DomainReadiness(
      domain: domain,
      coverage: coverage,
      strength: strength,
      score: score.clamp(0, 1).toDouble(),
      recall: recall.clamp(0, 1).toDouble(),
      low: low.clamp(0, 1).toDouble(),
      high: high.clamp(0, 1).toDouble(),
      studied: studied,
      total: total,
      transfer: transferValue,
      appliedN: appliedN,
    ));
  }

  domains.sort((a, b) => a.score.compareTo(b.score)); // weakest first

  // Overall roll-up blends per-target priority with how much material a domain
  // has: weight = targetWeight · itemCount. With no target weights this reduces
  // to pure size-weighting (the Phase-A default).
  double combineWeight(DomainReadiness d) =>
      (domainWeights?[d.domain] ?? 1.0) * d.total;
  final weightSum = domains.fold(0.0, (a, d) => a + combineWeight(d));
  double weightedScore(double Function(DomainReadiness) f) => weightSum == 0
      ? 0
      : domains.fold(0.0, (a, d) => a + f(d) * combineWeight(d)) / weightSum;

  return Readiness(
    domains: domains,
    overall: weightedScore((d) => d.score),
    low: weightedScore((d) => d.low),
    high: weightedScore((d) => d.high),
    interview: transferByDomain != null,
  );
}

/// Convenience wrapper: compute readiness for a specific [target] — its
/// durability bar plus per-domain weights. Shared by the dashboard provider and
/// the post-session summary so their numbers line up exactly.
Readiness computeReadinessForTarget({
  required List<Card> cards,
  required Map<String, double> stabilityByKey,
  required ReadinessTarget target,
  Map<String, TransferEstimate>? transferByDomain,
}) {
  final domains = <String>{
    for (final c in cards)
      if (c.domain != null) c.domain!,
  };
  return computeReadiness(
    cards: cards,
    stabilityByKey: stabilityByKey,
    stabilityTarget: target.stabilityTarget,
    domainWeights: {for (final d in domains) d: domainWeight(target, d)},
    transferByDomain: transferByDomain,
  );
}

/// The change in one domain's score between two readiness snapshots.
class DomainDelta {
  const DomainDelta(
      {required this.domain, required this.before, required this.after});

  final String domain;
  final double before;
  final double after;

  double get change => after - before;
}

/// The overall + per-domain movement between two readiness snapshots — the
/// honest "you moved this much toward your goal" signal for a session summary.
class ReadinessDelta {
  const ReadinessDelta({
    required this.overallBefore,
    required this.overallAfter,
    required this.domains,
  });

  final double overallBefore;
  final double overallAfter;

  /// Per-domain deltas, in the "after" ordering (weakest-first).
  final List<DomainDelta> domains;

  double get overallChange => overallAfter - overallBefore;

  /// Domains whose score actually moved this session (touched sections).
  List<DomainDelta> get touched => [
        for (final d in domains)
          if (d.change.abs() > 1e-9) d
      ];
}

/// Diffs two readiness snapshots by domain name.
ReadinessDelta diffReadiness(Readiness before, Readiness after) {
  final beforeByDomain = {for (final d in before.domains) d.domain: d.score};
  return ReadinessDelta(
    overallBefore: before.overall,
    overallAfter: after.overall,
    domains: [
      for (final d in after.domains)
        DomainDelta(
            domain: d.domain,
            before: beforeByDomain[d.domain] ?? 0,
            after: d.score),
    ],
  );
}

/// A display label for a domain tag, e.g. `ds-a` → "DS & A".
String prettyDomain(String domain) {
  switch (domain) {
    case 'ds-a':
      return 'DS & A';
    case 'system-design':
      return 'System design';
  }
  return domain
      .split(RegExp(r'[-_]'))
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
