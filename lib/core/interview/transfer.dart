import 'dart:math';

/// Estimates the **transfer** factor for a domain — how well proven applied /
/// problem-solving performance is, from the interview coach's sparse, noisy
/// applied scores. This is the signal recall can't provide (docs/readiness-
/// dashboard.md §2.2: `Readiness_d = Coverage^γ · Strength · (τ+(1-τ)·Transfer)`).
///
/// The method is grounded in a deep-research pass (see [[phase-b-readiness-math]]):
///   * **Shrink** the weighted applied mean toward a pessimistic prior with
///     pseudo-counts (a Beta/Normal-Normal conjugate update) — so a handful of
///     attempts, or one lucky mock, can't spike readiness. Shrinkage is heavier
///     the thinner the evidence (Efron 2021; Brown-Cai-DasGupta 2001).
///   * Report a **Beta credible band** whose width scales ~1/√(n_eff) — NOT the
///     Wald/CLT normal approximation, which underestimates uncertainty at small
///     n (Bowyer et al. ICML 2025; Brown-Cai-DasGupta 2001).
///   * **Weight** attempts before shrinking: novel/transfer problems carry the
///     most information (Pan & Rickard 2018); older attempts decay exponentially
///     (skill fades); hint-reliance is already reflected in the coach's score.

/// One applied attempt, normalised for the transfer estimate.
class AppliedSample {
  const AppliedSample({
    required this.score,
    required this.novel,
    required this.ageDays,
  });

  /// Applied performance in 0..1 (appliedScore / 100).
  final double score;

  /// Whether it was a novel/transfer problem (the truest signal).
  final bool novel;

  /// Age of the attempt in days (drives recency decay).
  final double ageDays;
}

/// The shrunk transfer point estimate plus an honest credible band.
class TransferEstimate {
  const TransferEstimate({
    required this.value,
    required this.low,
    required this.high,
    required this.effectiveN,
  });

  final double value; // 0..1, shrunk toward the prior
  final double low; // credible-band lower bound
  final double high; // credible-band upper bound
  final double effectiveN; // weighted attempt count (evidence strength)

  bool get hasEvidence => effectiveN > 0;
}

/// A pessimistic prior mean: with no applied evidence a domain sits here, well
/// below "proven". Tunable once real data accrues.
const transferPriorMean = 0.4;

/// Prior strength in pseudo-attempts — how much evidence it takes to move off
/// the prior. ~3 novel attempts to meaningfully shift.
const transferPriorStrength = 3.0;

/// Applied-skill recency half-life (days): a 60-day-old mock counts half.
const transferHalfLifeDays = 60.0;

/// Routine (non-novel) attempts carry less transfer information than novel ones.
const nonNovelWeight = 0.5;

const _z = 1.96; // ~95% band

/// Computes the transfer estimate for one domain's [samples]. With no samples it
/// returns the prior mean and a wide band (honest "no evidence").
TransferEstimate computeTransfer(
  List<AppliedSample> samples, {
  double priorMean = transferPriorMean,
  double priorStrength = transferPriorStrength,
  double halfLifeDays = transferHalfLifeDays,
}) {
  var nEff = 0.0;
  var weighted = 0.0;
  for (final s in samples) {
    final recency = pow(0.5, s.ageDays / halfLifeDays).toDouble();
    final w = (s.novel ? 1.0 : nonNovelWeight) * recency;
    nEff += w;
    weighted += w * s.score.clamp(0.0, 1.0);
  }
  final mean = nEff > 0 ? weighted / nEff : priorMean;

  // Beta posterior with prior pseudo-counts placed at [priorMean].
  final alpha = nEff * mean + priorStrength * priorMean;
  final beta = nEff * (1 - mean) + priorStrength * (1 - priorMean);
  final value = alpha / (alpha + beta);
  final variance = value * (1 - value) / (alpha + beta + 1);
  final half = _z * sqrt(variance);

  return TransferEstimate(
    value: value,
    low: (value - half).clamp(0.0, 1.0),
    high: (value + half).clamp(0.0, 1.0),
    effectiveN: nEff,
  );
}

/// The zero-evidence transfer estimate (a domain with no applied attempts) —
/// used to cap recall-only domains once the dashboard has graduated.
final zeroEvidenceTransfer = computeTransfer(const []);
