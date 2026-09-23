/// How much a dated aim should pull in the daily plan (S3 / ADR-0007) — the bridge
/// from the per-aim FEASIBILITY signal (readiness) to allocation (the plan). It is
/// deliberately NOT a raw time-ramp: an aim that is *on track* does not get more
/// urgent as its date nears, but one that is *behind* does. Feasibility STATUS is
/// the primary driver and dominates proximity — a behind aim far out still outranks
/// an on-track aim due tomorrow. Open-ended aims get a steady baseline. Pure.
library;

import '../readiness/feasibility.dart';

/// Baseline pull for an aim with no deadline pressure — open-ended, or dated but not
/// yet forecastable. Steady and moderate: makes progress, never dominates a
/// behind-and-dated aim. Tunable.
const double kBaselineUrgency = 0.3;

/// Pull for an aim that its current pace already clears in time. Flat (no proximity
/// amplification — being on track means the date nearing isn't a threat). Tunable.
const double kOnTrackUrgency = 0.3;

/// Floor pull for a BEHIND aim before proximity ramps it up (at/over its date it
/// reaches 1.0). Kept above [kOnTrackUrgency] so status dominates proximity. Tunable.
const double kBehindUrgencyFloor = 0.6;

/// Days over which a behind aim's urgency ramps from [kBehindUrgencyFloor] to 1.0 as
/// its date nears; beyond this it's "behind but not yet time-critical". Tunable.
const double kUrgencyProximityWindowDays = 60;

/// Urgency 0..1 for [f] as of [today] (ADR-0007). `ready` → 0; `onTrack` →
/// [kOnTrackUrgency]; `open-ended`/`unknown` → [kBaselineUrgency]; `behind` ramps
/// [kBehindUrgencyFloor]→1.0 by date proximity; `infeasible` → 1.0 (max — the coach
/// handles the incoherent-cram case, #103). Pure.
double aimUrgency(AimFeasibility f, {required DateTime today}) {
  switch (f.status) {
    case FeasibilityStatus.openEnded:
    case FeasibilityStatus.unknown:
      return kBaselineUrgency;
    case FeasibilityStatus.ready:
      return 0;
    case FeasibilityStatus.onTrack:
      return kOnTrackUrgency;
    case FeasibilityStatus.behind:
      const span = 1 - kBehindUrgencyFloor;
      return (kBehindUrgencyFloor + span * _proximity(f.date, today))
          .clamp(0.0, 1.0)
          .toDouble();
    case FeasibilityStatus.infeasible:
      return 1;
  }
}

/// 0 when [date] is ≥ the proximity window away (or null) → 1 on/after the date.
double _proximity(DateTime? date, DateTime today) {
  if (date == null) return 0;
  final daysLeft = date.difference(today).inDays;
  if (daysLeft <= 0) return 1;
  return (1 - daysLeft / kUrgencyProximityWindowDays)
      .clamp(0.0, 1.0)
      .toDouble();
}
