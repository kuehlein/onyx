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
}
