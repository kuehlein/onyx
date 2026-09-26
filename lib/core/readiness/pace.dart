/// Coverage-pace toward a target interview date (Phase A). It answers the
/// honest, bounded question "at your recent rate, will you have *studied* your
/// in-scope material by the date?" — not "will you be interview-ready", which
/// needs the applied/mock dimensions Phase A can't measure. Keep the UI copy
/// scoped to coverage accordingly.
library;

enum PaceStatus {
  /// Recent rate meets or beats what's required.
  onTrack,

  /// Making progress but under the required rate.
  slightlyBehind,

  /// Well under the required rate.
  behind,

  /// Every in-scope section already started — only maturation remains.
  coverageComplete,

  /// A date is set and work remains, but no recent studying to project from.
  notStarted,
}

class PaceEstimate {
  const PaceEstimate({
    required this.daysLeft,
    required this.remainingSections,
    required this.requiredPerDay,
    required this.recentPerDay,
    required this.status,
  });

  final int daysLeft;
  final int remainingSections;

  /// New sections per day needed from now to finish coverage by the date.
  final double requiredPerDay;

  /// Recent actual new-sections-per-day rate.
  final double recentPerDay;

  final PaceStatus status;
}

/// Estimates coverage pace. [today] and [interviewDate] should be date-only
/// (local midnight). [remainingSections] is the count of in-scope sections not
/// yet started; [recentPerDay] is the recent new-sections-per-day rate.
PaceEstimate computePace({
  required DateTime today,
  required DateTime interviewDate,
  required int remainingSections,
  required double recentPerDay,
}) {
  final daysLeft = interviewDate.difference(today).inDays.clamp(0, 1 << 30);

  if (remainingSections <= 0) {
    return PaceEstimate(
      daysLeft: daysLeft,
      remainingSections: 0,
      requiredPerDay: 0,
      recentPerDay: recentPerDay,
      status: PaceStatus.coverageComplete,
    );
  }

  // With no days left, the whole remainder is "due now".
  final requiredPerDay = daysLeft <= 0
      ? remainingSections.toDouble()
      : remainingSections / daysLeft;

  if (recentPerDay <= 0) {
    return PaceEstimate(
      daysLeft: daysLeft,
      remainingSections: remainingSections,
      requiredPerDay: requiredPerDay,
      recentPerDay: 0,
      status: PaceStatus.notStarted,
    );
  }

  final ratio = recentPerDay / requiredPerDay;
  final status = ratio >= 0.95
      ? PaceStatus.onTrack
      : ratio >= 0.6
          ? PaceStatus.slightlyBehind
          : PaceStatus.behind;

  return PaceEstimate(
    daysLeft: daysLeft,
    remainingSections: remainingSections,
    requiredPerDay: requiredPerDay,
    recentPerDay: recentPerDay,
    status: status,
  );
}

/// The denominator for the recent new-sections/day rate: the ACTUAL days of
/// history — from [firstLearnDate] (date-only) to [today] — clamped to
/// `[1, window]`. Never a flat [window]: a short history (e.g. 5 days in) would
/// otherwise read at a fraction of its real daily rate and falsely trip
/// "behind". With no history ([firstLearnDate] null) it assumes the full [window]
/// so an untouched deck shows a plan-based outlook, not a spike. Clamped to ≥ 1
/// so a same-day first learn never divides by zero.
int recentPaceDenominator({
  required DateTime? firstLearnDate,
  required DateTime today,
  int window = 14,
}) {
  final f = firstLearnDate;
  final historyDays = f == null
      ? window
      : today.difference(DateTime(f.year, f.month, f.day)).inDays;
  return historyDays.clamp(1, window);
}
