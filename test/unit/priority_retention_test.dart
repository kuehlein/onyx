import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
import 'package:onyx/shared/models/card.dart';

void main() {
  group('Priority', () {
    test('maps to a modest desired-retention band, normal is the default', () {
      expect(Priority.high.desiredRetention, greaterThan(0.90));
      expect(Priority.normal.desiredRetention, 0.90);
      expect(Priority.low.desiredRetention, lessThan(0.90));
      // Band stays narrow (no review-count explosion).
      expect(Priority.high.desiredRetention, lessThanOrEqualTo(0.95));
      expect(Priority.fromString(null), isNull);
      expect(Priority.fromString('high'), Priority.high);
    });
  });

  group('SrsScheduler desired retention', () {
    test('higher retention schedules a sooner review than lower', () {
      final scheduler = SrsScheduler();
      final at = DateTime.utc(2026, 1, 1, 9);
      // Same Good grade on a fresh card, different retention targets.
      final high =
          scheduler.review(grade: 3, reviewedAt: at, desiredRetention: 0.93);
      final low =
          scheduler.review(grade: 3, reviewedAt: at, desiredRetention: 0.85);
      // A higher retention target means a shorter (or equal) interval.
      expect(high.due.isAfter(low.due), isFalse);
    });

    test('the Easy first interval shrinks as retention rises', () {
      final scheduler = SrsScheduler();
      final at = DateTime.utc(2026, 1, 1, 9);
      final easyLow = scheduler
          .review(grade: 4, reviewedAt: at, desiredRetention: 0.85)
          .due
          .difference(at);
      final easyHigh = scheduler
          .review(grade: 4, reviewedAt: at, desiredRetention: 0.93)
          .due
          .difference(at);
      expect(easyHigh, lessThan(easyLow));
    });
  });

  group('guarded Learn-Easy (newCardMaxEasyFactor, n0014)', () {
    // Fuzzing off so intervals are deterministic (a fair comparison of the cap vs
    // native; production keeps fuzz on, which only jitters the capped interval).
    final scheduler = SrsScheduler(enableFuzzing: false);
    final at = DateTime.utc(2026, 1, 1, 9);

    test('a new Easy is capped at factor × Good, but never shorter than Good',
        () {
      final good =
          scheduler.review(grade: 3, reviewedAt: at).due.difference(at);
      final easyNative =
          scheduler.review(grade: 4, reviewedAt: at).due.difference(at);
      final easyCapped = scheduler
          .review(grade: 4, reviewedAt: at, newCardMaxEasyFactor: 2.0)
          .due
          .difference(at);
      // Native Easy is well beyond 2× Good (the whole reason for the guard)…
      expect(easyNative, greaterThan(good * 2));
      // …and the guard reins it in to ≤ 2× Good, still ≥ Good and < native.
      expect(easyCapped.inSeconds, lessThanOrEqualTo((good * 2.0).inSeconds));
      expect(easyCapped, greaterThanOrEqualTo(good));
      expect(easyCapped, lessThan(easyNative));
    });

    test('the cap scales the seeded stability too (state stays consistent)',
        () {
      final native = scheduler.review(grade: 4, reviewedAt: at);
      final capped =
          scheduler.review(grade: 4, reviewedAt: at, newCardMaxEasyFactor: 2.0);
      // A shorter interval reflects a lower seeded stability — not a hacked due date.
      expect(capped.stability, lessThan(native.stability));
      expect(capped.stability, greaterThan(0));
    });

    test('Good/Hard/Again new-card outcomes are unaffected (byte-identical)',
        () {
      for (final g in [1, 2, 3]) {
        final without = scheduler.review(grade: g, reviewedAt: at);
        final withCap = scheduler.review(
            grade: g, reviewedAt: at, newCardMaxEasyFactor: 2.0);
        expect(withCap.due, without.due, reason: 'grade $g due');
        expect(withCap.stability, without.stability,
            reason: 'grade $g stability');
      }
    });

    test('the cap applies only to NEW cards — a review-state Easy is native',
        () {
      final seed = scheduler.review(grade: 3, reviewedAt: at);
      final later = at.add(const Duration(days: 20));
      ReviewOutcome easyAt({double? cap}) => scheduler.review(
            grade: 4,
            reviewedAt: later,
            newCardMaxEasyFactor: cap,
            stability: seed.stability,
            difficulty: seed.difficulty,
            state: seed.state,
            step: seed.step,
            due: seed.due,
            lastReview: at,
          );
      // isNew is false here, so the cap is ignored → identical to native.
      expect(easyAt(cap: 2.0).due, easyAt().due);
    });
  });
}
