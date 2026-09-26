import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/practice_plan.dart';

/// State-aware est-minutes (task #133): a first-time cost T0 scales DOWN as FSRS
/// stability grows, floored per-flow by the incompressible fraction; a lapsed
/// item scales UP. Pure — sizes the daily plan, never schedules.
void main() {
  group('scaleEstMinutes', () {
    test('new / no stability yet → the full first-time cost', () {
      expect(scaleEstMinutes(1.5, stability: 0, fsrsState: 2), 1.5);
      expect(scaleEstMinutes(45, stability: 0, fsrsState: 1), 45);
    });

    test('well-spaced (stability ≥ mature) → the floor, and clamps beyond', () {
      // review floor 0.33: 1.5 → ~0.5
      expect(
          scaleEstMinutes(1.5,
              stability: 21, fsrsState: 2, floor: kReviewFloor),
          closeTo(0.495, 1e-9));
      // clamped — deeper maturity doesn't go below the floor
      expect(
          scaleEstMinutes(1.5,
              stability: 200, fsrsState: 2, floor: kReviewFloor),
          closeTo(0.495, 1e-9));
      // algo-solve floor 0.5: 40 → 20
      expect(
          scaleEstMinutes(40,
              stability: 60, fsrsState: 2, floor: kAlgoSolveFloor),
          closeTo(20, 1e-9));
    });

    test('settling (mid stability) interpolates between full and floor', () {
      // half-mature (10.5d) at review floor: factor = 1 - 0.67*0.5 = 0.665
      expect(
          scaleEstMinutes(1.5,
              stability: 10.5, fsrsState: 2, floor: kReviewFloor),
          closeTo(0.9975, 1e-9));
    });

    test('a lapsed (relearning) item costs MORE, regardless of stability', () {
      expect(
          scaleEstMinutes(1.5, stability: 2, fsrsState: kRelearningFsrsState),
          closeTo(1.8, 1e-9));
      // the relearning bump precedes the stability ramp
      expect(
          scaleEstMinutes(1.5, stability: 100, fsrsState: kRelearningFsrsState),
          closeTo(1.8, 1e-9));
    });

    test('the floor is per-flow — a solve compresses less than pure recall',
        () {
      final asRecall =
          scaleEstMinutes(40, stability: 30, fsrsState: 2, floor: kReviewFloor);
      final asSolve = scaleEstMinutes(40,
          stability: 30, fsrsState: 2, floor: kAlgoSolveFloor);
      expect(asSolve, greaterThan(asRecall));
      expect(
          kAlgoExplainFloor, inInclusiveRange(kReviewFloor, kAlgoSolveFloor));
    });
  });
}
