import '../../core/readiness/prep_goal.dart';
import 'round_editing.dart';

/// Pure lifecycle transitions for an interview ([PrepGoal]) — the single place
/// that mutates the current-round + status pipeline, so every surface behaves
/// identically. UI calls these and persists the result via the prep-goals
/// notifier.
///
/// The model: an active interview has exactly one [PrepGoal.currentRound] (the
/// upcoming, pending round). You reschedule it, or log its result — passing
/// schedules the next round; not passing (or an offer) ends the loop. Ended
/// interviews are kept as history (archive-by-default), never silently dropped.

/// Reschedule the current round (its date and/or type). No-op if the loop has
/// already ended.
PrepGoal rescheduleCurrentRound(
  PrepGoal g, {
  required DateTime? date,
  required InterviewRoundType type,
}) {
  final cur = g.currentRound;
  if (cur == null) return g;
  return goalWithRound(g, cur.copyWith(date: date, type: type));
}

/// Log the current round as passed and schedule the next one, which becomes the
/// new current round.
PrepGoal passAndScheduleNext(PrepGoal g, InterviewRound next) {
  final cur = g.currentRound;
  final rounds = [
    for (final r in g.effectiveRounds)
      if (r.id == cur?.id) r.copyWith(outcome: GoalOutcome.passed) else r,
    next,
  ];
  return syncedGoal(g, rounds).copyWith(status: InterviewStatus.active);
}

/// End the loop with a final [status] (offer / rejected / withdrawn / archived).
/// The current round's outcome is set to match where it's meaningful (passed for
/// an offer, failed for a rejection); a withdrawal/archive leaves it pending.
/// The interview stops biasing study.
PrepGoal endInterview(PrepGoal g, InterviewStatus status) {
  final cur = g.currentRound;
  final roundOutcome = switch (status) {
    InterviewStatus.offer => GoalOutcome.passed,
    InterviewStatus.rejected => GoalOutcome.failed,
    _ => null, // withdrawn / archived: leave the round as-is
  };
  final rounds = [
    for (final r in g.effectiveRounds)
      if (r.id == cur?.id && roundOutcome != null)
        r.copyWith(outcome: roundOutcome)
      else
        r,
  ];
  return syncedGoal(g, rounds).copyWith(status: status, active: false);
}

/// Archive an interview — the quick "stop tracking this" action (swipe / menu).
/// Kept in the past section, reversible via [reopenInterview].
PrepGoal archiveInterview(PrepGoal g) =>
    endInterview(g, InterviewStatus.archived);

/// Bring an ended/archived interview back to active (undo an end/archive).
PrepGoal reopenInterview(PrepGoal g) =>
    g.copyWith(status: InterviewStatus.active, active: true);
