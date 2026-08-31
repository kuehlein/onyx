import 'package:fsrs/fsrs.dart' as fsrs;

/// The outcome of reviewing a section: the new persisted FSRS state plus the
/// values to append to the review log. Times are UTC.
class ReviewOutcome {
  const ReviewOutcome({
    required this.stability,
    required this.difficulty,
    required this.state,
    required this.step,
    required this.due,
    required this.lastReview,
    required this.elapsedDays,
  });

  final double stability;
  final double difficulty;

  /// FSRS state value: 1=learning, 2=review, 3=relearning.
  final int state;

  /// Learning/relearning step index; null once in the review state.
  final int? step;

  /// When the section is next due (UTC).
  final DateTime due;

  /// When this review happened (UTC).
  final DateTime lastReview;

  /// Days since the previous review (0 for a first review).
  final double elapsedDays;
}

/// Thin wrapper over the FSRS scheduler. Maps our stored per-section state to an
/// `fsrs.Card`, applies a grade, and maps the result back — keeping FSRS's Card
/// (which collides with our model and Material's widget) out of the rest of the
/// app.
///
/// Desired retention can vary per card (interview-critical material is retained
/// harder — see [Priority]); since FSRS holds desired retention on the Scheduler,
/// we cache one underlying scheduler per retention value (a handful at most).
class SrsScheduler {
  SrsScheduler({fsrs.Scheduler? scheduler}) {
    if (scheduler != null) _cache[_defaultRetention] = scheduler;
  }

  static const _defaultRetention = 0.9;
  final _cache = <double, fsrs.Scheduler>{};

  fsrs.Scheduler _for(double retention) => _cache.putIfAbsent(
      retention, () => fsrs.Scheduler(desiredRetention: retention));

  /// Apply [grade] (1=Again … 4=Easy) to a section. Pass the section's current
  /// persisted state, or leave the state fields null for a section being
  /// reviewed for the first time. [reviewedAt] is coerced to UTC.
  /// [desiredRetention] shortens/lengthens intervals for higher/lower-priority
  /// material (default 0.9).
  ReviewOutcome review({
    required int grade,
    required DateTime reviewedAt,
    double desiredRetention = _defaultRetention,
    double? stability,
    double? difficulty,
    int? state,
    int? step,
    DateTime? due,
    DateTime? lastReview,
  }) {
    final now = reviewedAt.toUtc();
    final isNew = state == null;

    final card = isNew
        ? fsrs.Card(cardId: 0) // fresh: learning, step 0, no stability yet
        : fsrs.Card(
            cardId: 0,
            state: fsrs.State.fromValue(state),
            step: step,
            stability: stability,
            difficulty: difficulty,
            due: (due ?? now).toUtc(),
            lastReview: lastReview?.toUtc(),
          );

    final elapsedDays = lastReview == null
        ? 0.0
        : now.difference(lastReview.toUtc()).inSeconds / Duration.secondsPerDay;

    final result = _for(desiredRetention).reviewCard(
      card,
      fsrs.Rating.fromValue(grade),
      reviewDateTime: now,
    );
    final updated = result.card;

    return ReviewOutcome(
      stability: updated.stability ?? 0,
      difficulty: updated.difficulty ?? 0,
      state: updated.state.value,
      step: updated.step,
      due: updated.due,
      lastReview: updated.lastReview ?? now,
      elapsedDays: elapsedDays,
    );
  }
}
