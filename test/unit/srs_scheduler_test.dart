import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:onyx/core/srs/srs_scheduler.dart';

void main() {
  // Disable fuzzing so intervals are deterministic under test.
  SrsScheduler build() =>
      SrsScheduler(scheduler: fsrs.Scheduler(enableFuzzing: false));

  final reviewedAt = DateTime.utc(2026, 1, 1, 12);

  group('SrsScheduler', () {
    test('a first review initializes state and schedules into the future', () {
      final out = build().review(grade: 3, reviewedAt: reviewedAt); // Good

      expect(out.stability, greaterThan(0));
      expect(out.difficulty, greaterThan(0));
      expect(out.due.isAfter(reviewedAt), isTrue);
      expect(out.lastReview, reviewedAt);
      expect(out.elapsedDays, 0.0); // no prior review
      expect(out.state, anyOf(1, 2)); // learning or review
    });

    test('a better grade schedules further out than a worse one', () {
      final again = build().review(grade: 1, reviewedAt: reviewedAt);
      final easy = build().review(grade: 4, reviewedAt: reviewedAt);

      expect(easy.due.isAfter(again.due), isTrue);
    });

    test('elapsedDays reflects the gap since the last review', () {
      final out = build().review(
        grade: 3,
        reviewedAt: reviewedAt,
        // A card already in review, last seen 3 days ago.
        state: 2,
        stability: 5,
        difficulty: 5,
        due: reviewedAt.subtract(const Duration(days: 1)),
        lastReview: reviewedAt.subtract(const Duration(days: 3)),
      );

      expect(out.elapsedDays, closeTo(3.0, 0.01));
      expect(out.due.isAfter(reviewedAt), isTrue);
    });

    test('reviewing a matured card keeps it in the review state', () {
      final out = build().review(
        grade: 3,
        reviewedAt: reviewedAt,
        state: 2,
        stability: 40,
        difficulty: 5,
        due: reviewedAt,
        lastReview: reviewedAt.subtract(const Duration(days: 30)),
      );

      expect(out.state, 2); // still review
      expect(out.due.difference(reviewedAt).inDays, greaterThan(30));
    });

    test('a lapse (Again on a review card) drops to relearning, due soon', () {
      final out = build().review(
        grade: 1, // Again
        reviewedAt: reviewedAt,
        state: 2, // review
        stability: 40,
        difficulty: 5,
        due: reviewedAt,
        lastReview: reviewedAt.subtract(const Duration(days: 30)),
      );
      expect(out.state, 3, reason: 'Again in review → relearning');
      // Relearning steps stay on, so it returns soon (minutes), not in weeks.
      expect(out.due.difference(reviewedAt).inDays, lessThan(1));
      expect(out.stability, lessThan(40), reason: 'stability drops on a lapse');
    });

    test('higher desiredRetention schedules a shorter interval (priority)', () {
      // Both retentions must be non-fuzzing to compare deterministically, so
      // build WITHOUT an injected (0.9-only) scheduler — every _for(retention)
      // it creates is then non-fuzzing.
      final sched = SrsScheduler(enableFuzzing: false);
      ReviewOutcome at(double retention) => sched.review(
            grade: 3, // Good
            reviewedAt: reviewedAt,
            desiredRetention: retention,
            state: 2,
            stability: 20,
            difficulty: 5,
            due: reviewedAt,
            lastReview: reviewedAt.subtract(const Duration(days: 10)),
          );
      final normal = at(0.90);
      final critical = at(0.97); // interview-critical material retains harder
      expect(
        critical.due.difference(reviewedAt) < normal.due.difference(reviewedAt),
        isTrue,
        reason: 'retaining harder (higher target) = reviewing sooner',
      );
    });

    test('cram learningSteps re-test a new card same-day; default spaces it',
        () {
      final crammed = SrsScheduler(
        enableFuzzing: false,
        learningSteps: const [Duration(minutes: 1), Duration(minutes: 10)],
      ).review(grade: 3, reviewedAt: reviewedAt); // Good on a NEW card
      final durable = SrsScheduler(enableFuzzing: false)
          .review(grade: 3, reviewedAt: reviewedAt);

      // Cram keeps it same-day via a short step (state stays learning); the
      // durable default graduates straight to a multi-day spaced interval.
      expect(crammed.due.difference(reviewedAt).inHours, lessThan(1));
      expect(crammed.state, 1, reason: 'still learning (a cram step)');
      expect(
          durable.due.difference(reviewedAt).inHours, greaterThanOrEqualTo(24));
      expect(durable.state, 2, reason: 'graduated to review');
    });
  });
}
