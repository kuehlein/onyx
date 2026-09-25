/// The **study policy** — three orthogonal axes that decide how material is held,
/// introduced, and gated (task #30c / Phase 1, see docs/practice-flow-plan.md).
///
/// Keeping the axes separate is the whole point: collapsing them into one
/// "difficulty" slider is how this gets dirty. Each has a sensible default, a
/// data-bounded range, and is resolved from the goal + timeline by
/// [resolveStudyPolicy], overridable via the card > flow > subject cascade.
library;

import '../../shared/models/card.dart' show Priority;

// ── Retention intensity (axis 1) — data-bounded range ───────────────────────
// (See coach-feedback-design memory: FSRS 0.80–0.95 sane, ~0.97 is where review
//  load explodes, 0.90 default.) Retention already has a LIVE per-card path
//  (Priority + the FSRS-safe near-deadline targeting override); this axis
//  formalizes the subject/goal baseline + the hard ceiling.
const retentionFloor = 0.80;
const retentionDefault = 0.90;
const retentionCramTarget = 0.95;
const retentionCeiling = 0.97; // never exceed — review load explodes above

double clampRetention(double r) => r.clamp(retentionFloor, retentionCeiling);

/// The per-card target recall for a chosen [base] normal-retention, preserving the
/// [Priority] nudge (high/low sit a fixed step above/below normal) and clamped to
/// the policy band. At [base] == [retentionDefault] this reproduces each Priority's
/// own `desiredRetention` exactly (0.93/0.90/0.85) — so the global retention knob
/// (n0014) is byte-identical at its default. The near-deadline interview ramp
/// (ADR-0008, `Targeting.desiredRetentionForCard`) still applies on top of this base.
double retentionForPriority(Priority p, {double base = retentionDefault}) =>
    clampRetention(
        base + (p.desiredRetention - Priority.normal.desiredRetention));

/// Within this many days of a terminal deadline, cramming may kick in.
const cramWindowDays = 14;

/// Does the material need to LAST, or is it for a one-off dated event? Drives
/// whether cramming is ever auto-enabled (axis 2).
enum DeckPermanence { durable, terminal }

/// The introduction/scheduling shape (axis 2). `durable` = long-term (Learn is
/// the first exposure → graduate straight to a spaced interval; interleave after
/// first exposure). `cram` = short-term (same-day learning steps; massed).
class ScheduleProfile {
  const ScheduleProfile({
    required this.learningSteps,
    required this.interleaveFirstExposure,
  });

  /// Same-day FSRS learning steps. Empty = graduate straight to a spaced interval
  /// (Onyx's durable default — Learn IS the first-exposure step).
  final List<Duration> learningSteps;

  /// Interleave after the first (blocked) exposure — better long-term
  /// discrimination; off when massing for the short term.
  final bool interleaveFirstExposure;

  static const durable =
      ScheduleProfile(learningSteps: [], interleaveFirstExposure: true);

  /// Short-term: same-day steps so just-learned material is re-tested today.
  static const cram = ScheduleProfile(
    learningSteps: [Duration(minutes: 1), Duration(minutes: 10)],
    interleaveFirstExposure: false,
  );
}

/// The resolved policy — three orthogonal axes.
class StudyPolicy {
  const StudyPolicy({
    required this.desiredRetention,
    required this.scheduleProfile,
    required this.prereqCompetenceBar,
  });

  /// Axis 1: FSRS target recall, clamped to [retentionFloor]..[retentionCeiling].
  final double desiredRetention;

  /// Axis 2: how material is introduced/re-tested (durable vs cram).
  final ScheduleProfile scheduleProfile;

  /// Axis 3: the durability threshold a prerequisite must clear before its
  /// dependents unlock (and below which a flow is "provisional"). 0..1.
  final double prereqCompetenceBar;

  bool get isCram => scheduleProfile.learningSteps.isNotEmpty;
}

/// Resolve sensible defaults from the goal + timeline. Pure.
///
/// Cram is auto-enabled ONLY for a terminal, deadline-near goal that does NOT
/// gate downstream flows — a prerequisite is always held to the durable profile
/// so timeline pressure never hollows out the foundation the dependency graph
/// relies on (see docs/practice-flow-plan.md).
StudyPolicy resolveStudyPolicy({
  DeckPermanence permanence = DeckPermanence.durable,
  int? daysToTarget,
  bool gatesDownstream = false,
  double baseRetention = retentionDefault,
  double competenceBar = 0.7,
}) {
  final near = daysToTarget != null &&
      daysToTarget >= 0 &&
      daysToTarget <= cramWindowDays;
  final cram =
      permanence == DeckPermanence.terminal && near && !gatesDownstream;
  return StudyPolicy(
    desiredRetention:
        clampRetention(cram ? retentionCramTarget : baseRetention),
    scheduleProfile: cram ? ScheduleProfile.cram : ScheduleProfile.durable,
    prereqCompetenceBar: competenceBar.clamp(0.0, 1.0),
  );
}
