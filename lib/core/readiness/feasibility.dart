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

/// A dated aim's feasibility. `requiredPerDay` is the minimum new-sections/day that
/// still hits the date (null when infeasible); `readyBy` is the projected ready
/// date at the *current* pace.
class AimFeasibility {
  const AimFeasibility({
    required this.status,
    this.date,
    this.readyBy,
    this.requiredPerDay,
    this.currentPerDay,
  });

  final FeasibilityStatus status;
  final DateTime? date;
  final DateTime? readyBy;
  final int? requiredPerDay;
  final int? currentPerDay;

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
  final required = forecast.requiredPerDayFor(daysLeft);
  final FeasibilityStatus status;
  if (forecast.alreadyReady) {
    status = FeasibilityStatus.ready;
  } else if (required == null) {
    status =
        FeasibilityStatus.infeasible; // even the fastest pace misses the date
  } else if (readyBy != null && !readyBy.isAfter(date)) {
    status = FeasibilityStatus.onTrack; // current pace makes it
  } else {
    status = FeasibilityStatus.behind; // reachable, needs a faster pace
  }
  return AimFeasibility(
    status: status,
    date: date,
    readyBy: readyBy,
    requiredPerDay: required,
    currentPerDay: forecast.currentPerDay,
  );
}
