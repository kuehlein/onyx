import '../../core/deck/aim.dart';
import 'round_editing.dart';

/// Pure lifecycle transitions for an interview ([Aim]) — the single
/// place that mutates the current-round + status pipeline, so every surface
/// behaves identically. UI calls these and persists the result via the study
/// goals notifier ([Decks.upsertAim]).
///
/// The model: an active interview has exactly one current round (the upcoming,
/// pending round). You reschedule it, or log its result — passing schedules the
/// next round; not passing (or an offer) ends the loop. Ended interviews are kept
/// as history (archive-by-default), never silently dropped.

/// The one upcoming, not-yet-resolved round — what the learner is prepping for.
/// Null once the loop has ended. Reads [Aim.rounds] directly (not the
/// deadline-seeded effective rounds), as these transitions mutate stored rounds.
InterviewRound? currentRoundOf(Aim a) {
  for (final r in a.rounds) {
    if (r.outcome == AimOutcome.pending) return r;
  }
  return null;
}

/// Reschedule the current round (its date and/or type). No-op if the loop has
/// already ended.
Aim rescheduleCurrentRound(
  Aim a, {
  required DateTime? date,
  required InterviewRoundType type,
}) {
  final cur = currentRoundOf(a);
  if (cur == null) return a;
  return aimWithRound(a, cur.copyWith(date: date, type: type));
}

/// Log the current round as passed and schedule the next one, which becomes the
/// new current round.
Aim passAndScheduleNext(Aim a, InterviewRound next) {
  final cur = currentRoundOf(a);
  final rounds = [
    for (final r in a.rounds)
      if (r.id == cur?.id) r.copyWith(outcome: AimOutcome.passed) else r,
    next,
  ];
  return syncedAim(a, rounds).copyWith(status: InterviewStatus.active);
}

/// End the loop with a final [status] (offer / rejected / withdrawn / archived).
/// The current round's outcome is set to match where it's meaningful (passed for
/// an offer, failed for a rejection); a withdrawal/archive leaves it pending.
/// The interview stops biasing study.
Aim endInterview(Aim a, InterviewStatus status) {
  final cur = currentRoundOf(a);
  final roundOutcome = switch (status) {
    InterviewStatus.offer => AimOutcome.passed,
    InterviewStatus.rejected => AimOutcome.failed,
    _ => null, // withdrawn / archived: leave the round as-is
  };
  final rounds = [
    for (final r in a.rounds)
      if (r.id == cur?.id && roundOutcome != null)
        r.copyWith(outcome: roundOutcome)
      else
        r,
  ];
  return syncedAim(a, rounds).copyWith(status: status, active: false);
}

/// Archive an interview — the quick "stop tracking this" action (swipe / menu).
/// Kept in the past section, reversible via [reopenInterview].
Aim archiveInterview(Aim a) => endInterview(a, InterviewStatus.archived);

/// Bring an ended/archived interview back to active (undo an end/archive). If
/// ending it had resolved the last round (e.g. an accidental "didn't pass"),
/// that round is restored to pending so it's the current round again — otherwise
/// you'd reopen into a loop with nothing to act on. Archived/withdrawn loops
/// (whose round stayed pending) are unaffected.
Aim reopenInterview(Aim a) {
  final rounds = [...a.rounds];
  if (currentRoundOf(a) == null && rounds.isNotEmpty) {
    rounds[rounds.length - 1] =
        rounds.last.copyWith(outcome: AimOutcome.pending);
  }
  return syncedAim(a, rounds)
      .copyWith(status: InterviewStatus.active, active: true);
}
