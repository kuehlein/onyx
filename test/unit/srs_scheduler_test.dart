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
  });
}
