import 'projection.dart';

/// How a dated aim is tracking toward its date — derived purely from the aim's
/// readiness [ReadinessForecast] vs that date. This is the **feasibility** signal:
/// "can you be durably ready by [date] at your current pace?" It's the substrate
/// the daily plan weights urgency on (S3) and the coach warns from (#103), and the
/// per-aim readout the Aims surface shows (S5). Open-ended aims have no date, so
/// they're judged by coverage/pace instead — never a ready-by.
enum FeasibilityStatus {
  /// No date — an open-ended aim; judge by coverage/pace, not a ready-by.
  openEnded,

  /// Dated, but no forecast yet (no concept cards / nothing studied).
  unknown,

  /// Already at/above the readiness bar for this aim.
  ready,

  /// At the current pace, ready on or before the date.
  onTrack,

  /// Reachable, but only at a faster pace than the current one.
  behind,

  /// Even the fastest sampled pace can't reach the bar by the date.
  infeasible,
}

/// A dated aim's feasibility. `requiredBudget` is the minimum daily time-budget
/// (minutes) that still hits the date (null when infeasible) — the user's actual
/// lever (ADR-0010), not a new/day dial; `readyBy` is the projected ready date at
/// the *current* budget.
class AimFeasibility {
  const AimFeasibility({
    required this.status,
    this.date,
    this.readyBy,
    this.requiredBudget,
    this.currentBudget,
  });

  final FeasibilityStatus status;
  final DateTime? date;
  final DateTime? readyBy;
  final double? requiredBudget;
  final double? currentBudget;

  /// The aim needs more attention now — the urgency signal S3 weights on and the
  /// coach warns from (behind = ramp up; infeasible = the cram-coherence case).
  bool get needsAttention =>
      status == FeasibilityStatus.behind ||
      status == FeasibilityStatus.infeasible;
}

/// Classify a dated aim's feasibility from its [forecast]. [date] null → the aim is
/// open-ended (coverage, no ready-by). [forecast] null → dated but not yet
/// forecastable (unknown). Pure.
AimFeasibility classifyAimFeasibility({
  DateTime? date,
  ReadinessForecast? forecast,
}) {
  if (date == null) {
    return const AimFeasibility(status: FeasibilityStatus.openEnded);
  }
  if (forecast == null) {
    return AimFeasibility(status: FeasibilityStatus.unknown, date: date);
  }
  final readyBy = forecast.currentReadyDate;
  final daysLeft = date.difference(forecast.today).inDays;
  if (daysLeft < 0) {
    // The date has already passed but the round is still pending — the event
    // happened and its outcome just isn't logged yet (awaiting debrief, #90). It's
    // not a FUTURE deadline, so it must never read as `infeasible` (which would max
    // this aim's daily-plan urgency for a done interview). Judge it by coverage,
    // exactly like an open-ended aim.
    return const AimFeasibility(status: FeasibilityStatus.openEnded);
  }
  final required = forecast.requiredBudgetFor(daysLeft);
  final FeasibilityStatus status;
  if (forecast.alreadyReady) {
    status = FeasibilityStatus.ready;
  } else if (required == null) {
    status = FeasibilityStatus
        .infeasible; // even the largest sustainable budget misses the date
  } else if (readyBy != null && !readyBy.isAfter(date)) {
    status = FeasibilityStatus.onTrack; // the current budget makes it
  } else {
    status = FeasibilityStatus.behind; // reachable, needs a bigger budget
  }
  return AimFeasibility(
    status: status,
    date: date,
    readyBy: readyBy,
    requiredBudget: required,
    currentBudget: forecast.currentBudget,
  );
}
