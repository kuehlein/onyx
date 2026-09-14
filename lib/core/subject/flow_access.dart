import 'dependency_gating.dart';

/// How a flow may be entered right now (task #30c / Phase 3, see
/// docs/practice-flow-plan.md). The soft-gate + override model as pure logic; the
/// "Open anyway" button, the "started early" badge, and routing weak deps back
/// into the concept queue are UI wired in a later phase.
enum FlowAccess {
  /// Prerequisites unmet and not opened early — offer "Open anyway" (soft gate,
  /// never a hard wall).
  locked,

  /// Opened early via override while prerequisites are still below the bar. It
  /// **self-heals** to [unlocked] once the foundation catches up, never counts as
  /// a satisfied prerequisite for anything downstream (taint containment), and
  /// never confers competence or moves the readiness number (access-only).
  provisional,

  /// Prerequisites legitimately met.
  unlocked,
}

/// Derive a flow's access from its dependency [gate] and whether the learner has
/// chosen to open it early ([overridden]). Pure and self-healing: a legitimately
/// met gate is [unlocked] regardless of a past override — so "provisional" is a
/// *derived* state, not a stored flag that needs clearing.
FlowAccess flowAccess({required GateStatus gate, required bool overridden}) {
  if (gate.unlocked) return FlowAccess.unlocked;
  return overridden ? FlowAccess.provisional : FlowAccess.locked;
}

/// Whether a flow's state counts as a satisfied prerequisite for OTHER flows.
/// Only a legitimately [unlocked] flow does — a provisionally-opened one never
/// unlocks anything downstream (this is the taint containment that stops
/// "food-1 started too early" from cascading into food-2).
bool satisfiesDownstream(FlowAccess access) => access == FlowAccess.unlocked;
