/// The recognition ("explain") clock — the second clock of the Algorithms
/// track. Where FSRS schedules re-*solving* a problem (the execution clock),
/// this schedules re-*explaining* it out loud: talking through approach,
/// complexity, and edge cases with the coach as interviewer. It exists because
/// explaining is phone-doable anywhere, so it keeps a pattern recognizable
/// between solves.
///
/// Deliberately NOT a second FSRS (see docs/algorithm-track-design.md — that is
/// flagged as over-engineering). It is a simple expanding interval: a solid
/// explanation grows the spacing along [_steps]; a shaky one holds you at the
/// short end; a lost one resets to tomorrow. "Explain never substitutes for
/// solve" — this clock is independent of `srs_state` and (for now) carries no
/// readiness weight.
library;

/// How an explanation went, self-graded (the coach may suggest).
enum ExplainOutcome { solid, shaky, lost }

/// The result of scheduling one explanation: the new spacing, the streak it
/// leaves you on, and when the next explain is due.
class RecognitionResult {
  const RecognitionResult({
    required this.intervalDays,
    required this.streak,
    required this.dueAt,
  });

  final int intervalDays;
  final int streak;
  final DateTime dueAt;
}

/// Expanding spacing (days) indexed by streak. A first solid explanation lands
/// at 3 days; each further solid one steps out, capping at ~3 months.
const _steps = [3, 7, 16, 35, 90];

/// Schedules the next explain from [outcome], the [priorStreak] (0 if this is
/// the first ever explanation of the problem), and [now].
///
/// - solid → streak grows, interval steps out along [_steps];
/// - shaky → streak holds (no advance), come back at the short end;
/// - lost  → streak resets to 0, come back tomorrow.
RecognitionResult scheduleRecognition({
  required ExplainOutcome outcome,
  required DateTime now,
  int priorStreak = 0,
}) {
  final int streak;
  final int intervalDays;
  switch (outcome) {
    case ExplainOutcome.solid:
      streak = priorStreak + 1;
      intervalDays = _steps[(streak - 1).clamp(0, _steps.length - 1)];
    case ExplainOutcome.shaky:
      streak = priorStreak; // hold — don't advance the spacing
      intervalDays = _steps.first;
    case ExplainOutcome.lost:
      streak = 0;
      intervalDays = 1;
  }
  return RecognitionResult(
    intervalDays: intervalDays,
    streak: streak,
    dueAt: now.add(Duration(days: intervalDays)),
  );
}
