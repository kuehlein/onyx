import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/urgency.dart';
import 'package:onyx/core/readiness/feasibility.dart';

/// S3: the feasibility → urgency mapping the daily plan allocates on (ADR-0007).
/// Status dominates proximity; only a BEHIND aim amplifies as its date nears.
void main() {
  final today = DateTime(2026, 1, 1);
  AimFeasibility fz(FeasibilityStatus s, {int? daysOut}) => AimFeasibility(
        status: s,
        date: daysOut == null ? null : today.add(Duration(days: daysOut)),
      );

  test('open-ended and unknown → the flat baseline', () {
    expect(aimUrgency(fz(FeasibilityStatus.openEnded), today: today),
        kBaselineUrgency);
    expect(aimUrgency(fz(FeasibilityStatus.unknown, daysOut: 10), today: today),
        kBaselineUrgency);
  });

  test('ready → 0 (no pull)', () {
    expect(
        aimUrgency(fz(FeasibilityStatus.ready, daysOut: 5), today: today), 0);
  });

  test('on-track is flat — proximity does NOT amplify it', () {
    final near =
        aimUrgency(fz(FeasibilityStatus.onTrack, daysOut: 1), today: today);
    final far =
        aimUrgency(fz(FeasibilityStatus.onTrack, daysOut: 120), today: today);
    expect(near, kOnTrackUrgency);
    expect(near, far);
  });

  test('behind ramps up as the date nears (monotonic)', () {
    final far =
        aimUrgency(fz(FeasibilityStatus.behind, daysOut: 60), today: today);
    final mid =
        aimUrgency(fz(FeasibilityStatus.behind, daysOut: 30), today: today);
    final near =
        aimUrgency(fz(FeasibilityStatus.behind, daysOut: 0), today: today);
    expect(far, kBehindUrgencyFloor); // at the window edge, the floor
    expect(near, 1.0); // on the date, maxed
    expect(mid, greaterThan(far));
    expect(near, greaterThan(mid));
  });

  test('status dominates proximity: behind-far outranks on-track-tomorrow', () {
    final behindFar =
        aimUrgency(fz(FeasibilityStatus.behind, daysOut: 60), today: today);
    final onTrackSoon =
        aimUrgency(fz(FeasibilityStatus.onTrack, daysOut: 1), today: today);
    expect(behindFar, greaterThan(onTrackSoon));
  });

  test('infeasible → max pull', () {
    expect(
        aimUrgency(fz(FeasibilityStatus.infeasible, daysOut: 3), today: today),
        1);
  });

  test('a past-due behind aim is maxed, and output stays within 0..1', () {
    final overdue =
        aimUrgency(fz(FeasibilityStatus.behind, daysOut: -5), today: today);
    expect(overdue, 1.0);
    for (final s in FeasibilityStatus.values) {
      final u = aimUrgency(fz(s, daysOut: 7), today: today);
      expect(u, inInclusiveRange(0.0, 1.0));
    }
  });
}
