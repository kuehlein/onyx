import 'package:fsrs/fsrs.dart' as fsrs;

/// Learn's guarded-Easy cap (n0014): a NEW card graded Easy is limited to this
/// multiple of what Good would seed the same fresh card. FSRS's native Easy seeds a
/// ~15-day first interval — unearned for a just-seen card — so an already-known card
/// skips ahead only "a bit longer than Good," not weeks. Review mode is uncapped.
const learnEasyMaxIntervalFactor = 2.0;

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
  SrsScheduler({
    fsrs.Scheduler? scheduler,
    this.enableFuzzing = true,
    this.learningSteps = const [],
  }) {
    if (scheduler != null) _cache[_defaultRetention] = scheduler;
  }

  /// FSRS interval fuzz. On in production (spreads due dates to avoid review
  /// pile-ups); the forward-simulation projection turns it OFF so a forecast is
  /// deterministic (a ready-date shouldn't jitter run-to-run).
  final bool enableFuzzing;

  /// Same-day learning steps (task #30c study-policy axis 2). Empty = Onyx's
  /// durable default: a graded-Good new card graduates straight to a spaced
  /// interval (Learn IS the first-exposure step). A non-empty list (cram profile)
  /// re-tests just-learned material the same day for a short-term boost.
  final List<Duration> learningSteps;

  static const _defaultRetention = 0.9;
  final _cache = <double, fsrs.Scheduler>{};

  // Learning steps default to empty: Onyx's Learn flow IS the first-exposure
  // step, so a graded-Good new card graduates straight to a spaced (multi-day)
  // interval rather than FSRS's default 1m/10m steps — which would make a
  // just-learned card reappear in Review the same day (churn, and the confusing
  // "Learn spawned Review" the daily plan showed). The cram study-policy profile
  // overrides this with same-day steps for a deliberate short-term boost.
  // Relearning steps stay on: a genuine lapse (Again in Review) should still
  // come back soon to re-cement.
  fsrs.Scheduler _for(double retention) => _cache.putIfAbsent(
      retention,
      () => fsrs.Scheduler(
            desiredRetention: retention,
            learningSteps: learningSteps,
            enableFuzzing: enableFuzzing,
          ));

  /// Apply [grade] (1=Again … 4=Easy) to a section. Pass the section's current
  /// persisted state, or leave the state fields null for a section being
  /// reviewed for the first time. [reviewedAt] is coerced to UTC.
  /// [desiredRetention] shortens/lengthens intervals for higher/lower-priority
  /// material (default 0.9).
  ///
  /// [newCardMaxEasyFactor] guards Learn's Easy (n0014): for a NEW card graded Easy
  /// it caps the first interval at that multiple of what Good would seed the same
  /// fresh card, by scaling the seeded stability (interval ∝ stability, so state
  /// stays self-consistent — no due-date hacking). Null (Review's default) = native
  /// FSRS. Good/Hard sit at or below their own value, so they're never clipped.
  ReviewOutcome review({
    required int grade,
    required DateTime reviewedAt,
    double desiredRetention = _defaultRetention,
    double? newCardMaxEasyFactor,
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

    var outcomeStability = updated.stability ?? 0;
    var outcomeDue = updated.due;
    // Guarded Learn-Easy (n0014): cap a NEW Easy first interval at the factor × what
    // Good would seed this same fresh card. interval ∝ stability, so scaling the
    // stability by the same ratio keeps stability and due mutually consistent.
    if (isNew && newCardMaxEasyFactor != null && grade >= 4) {
      final good = _for(desiredRetention)
          .reviewCard(fsrs.Card(cardId: 0), fsrs.Rating.good,
              reviewDateTime: now)
          .card;
      final cap = good.due.difference(now) * newCardMaxEasyFactor;
      final easyInterval = outcomeDue.difference(now);
      if (easyInterval > cap && easyInterval.inSeconds > 0) {
        outcomeStability =
            outcomeStability * (cap.inSeconds / easyInterval.inSeconds);
        outcomeDue = now.add(cap);
      }
    }

    return ReviewOutcome(
      stability: outcomeStability,
      difficulty: updated.difficulty ?? 0,
      state: updated.state.value,
      step: updated.step,
      due: outcomeDue,
      lastReview: updated.lastReview ?? now,
      elapsedDays: elapsedDays,
    );
  }
}
