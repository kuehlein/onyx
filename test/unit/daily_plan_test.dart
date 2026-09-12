import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/daily_plan.dart';
import 'package:onyx/core/plan/practice_plan.dart';

TrackAvailability _avail(TrackId t, List<double> mins,
        {bool unlocked = true}) =>
    TrackAvailability(
      track: t,
      unlocked: unlocked,
      units: [
        for (var i = 0; i < mins.length; i++)
          PracticeUnit(
              track: t,
              id: '${t.name}-$i',
              label: '${t.name} $i',
              estMinutes: mins[i]),
      ],
    );

PlannedTrack? _track(DailyPlan p, TrackId t) {
  for (final pt in p.tracks) {
    if (pt.track == t) return pt;
  }
  return null;
}

void main() {
  test('empty availability or zero budget yields an empty plan', () {
    expect(buildDailyPlan(availabilities: const [], budgetMinutes: 60).isEmpty,
        isTrue);
    expect(
        buildDailyPlan(
          availabilities: [
            _avail(TrackId.review, [1, 1])
          ],
          budgetMinutes: 0,
        ).isEmpty,
        isTrue);
  });

  test('schedules everything when the budget is ample', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(TrackId.review, [1, 1, 1])
      ],
      budgetMinutes: 60,
    );
    final r = _track(p, TrackId.review)!;
    expect(r.units.length, 3);
    expect(r.deferred, 0);
    expect(p.plannedMinutes, 3);
  });

  test('dispenses only a subset that fits, deferring the rest', () {
    final p = buildDailyPlan(
      availabilities: [_avail(TrackId.review, List.filled(10, 1))],
      budgetMinutes: 4,
    );
    final r = _track(p, TrackId.review)!;
    expect(r.units.length, 4);
    expect(r.deferred, 6);
    expect(p.plannedMinutes, lessThanOrEqualTo(4));
  });

  test('skips an oversized top unit for a smaller one, deferring the big one',
      () {
    // 40-min "knapsack" won't fit a 15-min budget; the 10-min "isPalindrome" does.
    final p = buildDailyPlan(
      availabilities: [
        _avail(TrackId.algorithms, [40, 10]),
      ],
      budgetMinutes: 15,
    );
    final a = _track(p, TrackId.algorithms)!;
    expect(a.units.length, 1);
    expect(a.units.single.estMinutes, 10);
    expect(a.deferred, 1); // the 40-min problem rolls over (rises next day)
  });

  test('locked tracks are excluded from the plan but surfaced separately', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(TrackId.review, [1]),
        _avail(TrackId.systemDesign, [40], unlocked: false),
      ],
      budgetMinutes: 60,
    );
    expect(_track(p, TrackId.systemDesign), isNull);
    expect(p.locked.map((a) => a.track), contains(TrackId.systemDesign));
    expect(_track(p, TrackId.review), isNotNull);
  });

  test('a reserved track gets its unit even when a rival outweighs it', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(TrackId.review, [5]),
        _avail(TrackId.algorithms, [5, 5, 5]),
      ],
      budgetMinutes: 5, // only room for one 5-min unit
      ctx: const PlanContext(
        baseWeight: {TrackId.review: 0.1, TrackId.algorithms: 0.9},
        reserved: {TrackId.review},
      ),
    );
    // Review is reserved, so it claims the single slot despite lower weight.
    expect(_track(p, TrackId.review)!.units.length, 1);
    expect(_track(p, TrackId.algorithms), isNull);
  });

  test('recency down-weights a track (variety): the neglected one gets more',
      () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(TrackId.learn, List.filled(10, 1)),
        _avail(TrackId.algorithms, List.filled(10, 1)),
      ],
      budgetMinutes: 6,
      ctx: const PlanContext(
        baseWeight: {TrackId.learn: 0.5, TrackId.algorithms: 0.5},
        recencyLoad: {TrackId.learn: 1.0}, // learn done a lot lately
      ),
    );
    final learn = _track(p, TrackId.learn)!;
    final algo = _track(p, TrackId.algorithms)!;
    expect(algo.units.length, greaterThan(learn.units.length));
    expect(p.plannedMinutes, 6);
  });

  test('balances across equally-weighted tracks', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(TrackId.review, List.filled(10, 1)),
        _avail(TrackId.algorithms, List.filled(10, 1)),
      ],
      budgetMinutes: 4,
      ctx: const PlanContext(
        baseWeight: {TrackId.review: 0.5, TrackId.algorithms: 0.5},
      ),
    );
    expect(_track(p, TrackId.review)!.units.length, 2);
    expect(_track(p, TrackId.algorithms)!.units.length, 2);
  });

  group('rampedBudgetMinutes', () {
    test('starts at the ease-in and reaches the target after ~a week', () {
      expect(rampedBudgetMinutes(recentActiveDays: 0), 90);
      expect(rampedBudgetMinutes(recentActiveDays: 7), 150);
      expect(rampedBudgetMinutes(recentActiveDays: 30), 150); // capped
      final mid = rampedBudgetMinutes(recentActiveDays: 3);
      expect(mid, greaterThan(90));
      expect(mid, lessThan(150));
    });
  });

  group('learnTaperFactor', () {
    test('is full far out and eases to the floor by interview day', () {
      expect(learnTaperFactor(daysUntilInterview: null), 1);
      expect(learnTaperFactor(daysUntilInterview: 30), 1);
      expect(learnTaperFactor(daysUntilInterview: 7), closeTo(0.5, 1e-9));
      expect(learnTaperFactor(daysUntilInterview: 0), 0.2); // floor
      expect(learnTaperFactor(daysUntilInterview: 1), 0.2); // floored
    });
  });

  test('marks the top-priority track non-negotiable when none reserved', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(TrackId.review, [1]),
        _avail(TrackId.algorithms, [1]),
      ],
      budgetMinutes: 60,
      ctx: const PlanContext(
        baseWeight: {TrackId.review: 0.5, TrackId.algorithms: 0.9},
      ),
    );
    expect(_track(p, TrackId.algorithms)!.nonNegotiable, isTrue);
    expect(_track(p, TrackId.review)!.nonNegotiable, isFalse);
    // Highest priority first in the list.
    expect(p.tracks.first.track, TrackId.algorithms);
  });
}
