import 'dart:math';

import '../../shared/models/card.dart';

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
  });

  final String domain;
  final double coverage; // 0..1 — fraction of required sections started
  final double strength; // 0..1 — weakest-link-aware retention of studied ones
  final double score; // 0..1 — coverage^γ · strength
  final double low; // band lower bound
  final double high; // band upper bound
  final int studied;
  final int total;

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
  });

  /// Per-domain, sorted weakest-first (so the UI can flag "focus here").
  final List<DomainReadiness> domains;
  final double overall;
  final double low;
  final double high;

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

    final score = pow(coverage, coverageGamma).toDouble() * strength;
    // Band widens with low coverage and few studied items.
    final margin =
        (0.20 * (1 - coverage) + 0.30 / sqrt(studied + 1)).clamp(0.03, 0.30);

    domains.add(DomainReadiness(
      domain: domain,
      coverage: coverage,
      strength: strength,
      score: score,
      low: (score - margin).clamp(0, 1).toDouble(),
      high: (score + margin).clamp(0, 1).toDouble(),
      studied: studied,
      total: total,
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
  );
}
