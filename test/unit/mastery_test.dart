import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/srs/mastery.dart';

/// The display-only "mastered" predicate (ADR-0012 #6, task 1f.1): a section is
/// mastered only when it has graduated to review, is not due, has grown to a
/// spaced interval (stability ≥ 21d), and is still retained (R ≥ 0.9). R comes
/// from the fsrs curve via core/srs — these tests pin the gates + the rationale.

SrsState _state({
  required int state,
  required double stability,
  DateTime? lastReview,
  required DateTime dueAt,
}) =>
    SrsState(
      cardId: 'c',
      sectionSlug: 's',
      stability: stability,
      difficulty: 5,
      state: state,
      dueAt: dueAt,
      lastReview: lastReview,
      reviewCount: 3,
    );

void main() {
  final now = DateTime.utc(2026, 6, 1);
  DateTime daysFromNow(int d) => now.add(Duration(days: d));
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  group('sectionRetrievability', () {
    test('is 0 when never reviewed or without stability', () {
      expect(
          sectionRetrievability(
              _state(
                  state: 2,
                  stability: 40,
                  lastReview: null,
                  dueAt: daysFromNow(30)),
              now),
          0);
      expect(
          sectionRetrievability(
              _state(
                  state: 2,
                  stability: 0,
                  lastReview: daysAgo(5),
                  dueAt: daysFromNow(1)),
              now),
          0);
    });

    test('is high early in a long interval, low far past it', () {
      final fresh = sectionRetrievability(
          _state(
              state: 2,
              stability: 40,
              lastReview: daysAgo(10),
              dueAt: daysFromNow(30)),
          now);
      final stale = sectionRetrievability(
          _state(
              state: 2,
              stability: 25,
              lastReview: daysAgo(200),
              dueAt: daysFromNow(365)),
          now);
      expect(fresh, greaterThan(0.9));
      expect(stale, lessThan(0.9));
    });
  });

  group('isSectionMastered', () {
    test('review + spaced + retained + not due → mastered', () {
      expect(
          isSectionMastered(
              _state(
                  state: 2,
                  stability: 40,
                  lastReview: daysAgo(10),
                  dueAt: daysFromNow(30)),
              now),
          isTrue);
    });

    test('just-learned (stability below the spacing floor) → not mastered', () {
      // Onyx graduates Learn straight into review with R≈1; the stability floor
      // is exactly what stops that from being flagged as mastered.
      expect(
          isSectionMastered(
              _state(
                  state: 2,
                  stability: 5,
                  lastReview: now,
                  dueAt: daysFromNow(5)),
              now),
          isFalse);
    });

    test('a due section is never mastered (never folds a due retrieval away)',
        () {
      expect(
          isSectionMastered(
              _state(
                  state: 2,
                  stability: 40,
                  lastReview: daysAgo(45),
                  dueAt: daysAgo(1)),
              now),
          isFalse);
    });

    test('spaced + not due but retrievability slipped below 0.9 → not mastered',
        () {
      // Artificial due date isolates the retrievability gate from the due gate.
      expect(
          isSectionMastered(
              _state(
                  state: 2,
                  stability: 25,
                  lastReview: daysAgo(200),
                  dueAt: daysFromNow(365)),
              now),
          isFalse);
    });

    test('never studied → not mastered', () {
      expect(isSectionMastered(null, now), isFalse);
    });

    test('learning / relearning (not graduated) → not mastered', () {
      for (final s in [1, 3]) {
        expect(
            isSectionMastered(
                _state(
                    state: s,
                    stability: 40,
                    lastReview: daysAgo(10),
                    dueAt: daysFromNow(30)),
                now),
            isFalse,
            reason: 'state $s is not the review state');
      }
    });
  });
}
