import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/daily_plan.dart';
import 'package:onyx/core/plan/practice_plan.dart';

TrackAvailability _avail(String t, List<double> mins, {bool unlocked = true}) =>
    TrackAvailability(
      track: t,
      label: t,
      unlocked: unlocked,
      units: [
        for (var i = 0; i < mins.length; i++)
          PracticeUnit(
              track: t, id: '$t-$i', label: '$t $i', estMinutes: mins[i]),
      ],
    );

PracticeUnit _u(String t, String id, double m) =>
    PracticeUnit(track: t, id: id, label: id, estMinutes: m);

PlannedTrack? _track(DailyPlan p, String t) {
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
            _avail(kTrackReview, [1, 1])
          ],
          budgetMinutes: 0,
        ).isEmpty,
        isTrue);
  });

  test('schedules everything when the budget is ample', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(kTrackReview, [1, 1, 1])
      ],
      budgetMinutes: 60,
    );
    final r = _track(p, kTrackReview)!;
    expect(r.units.length, 3);
    expect(r.deferred, 0);
    expect(p.plannedMinutes, 3);
  });

  test('dispenses only a subset that fits, deferring the rest', () {
    final p = buildDailyPlan(
      availabilities: [_avail(kTrackReview, List.filled(10, 1))],
      budgetMinutes: 4,
    );
    final r = _track(p, kTrackReview)!;
    expect(r.units.length, 4);
    expect(r.deferred, 6);
    expect(p.plannedMinutes, lessThanOrEqualTo(4));
  });

  test('skips an oversized top unit for a smaller one, deferring the big one',
      () {
    // 40-min "knapsack" won't fit a 15-min budget; the 10-min "isPalindrome" does.
    final p = buildDailyPlan(
      availabilities: [
        _avail(kTrackAlgorithms, [40, 10]),
      ],
      budgetMinutes: 15,
    );
    final a = _track(p, kTrackAlgorithms)!;
    expect(a.units.length, 1);
    expect(a.units.single.estMinutes, 10);
    expect(a.deferred, 1); // the 40-min problem rolls over (rises next day)
  });

  test('locked tracks are excluded from the plan but surfaced separately', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(kTrackReview, [1]),
        _avail(kTrackSystemDesign, [40], unlocked: false),
      ],
      budgetMinutes: 60,
    );
    expect(_track(p, kTrackSystemDesign), isNull);
    expect(p.locked.map((a) => a.track), contains(kTrackSystemDesign));
    expect(_track(p, kTrackReview), isNotNull);
  });

  test('a reserved track gets its unit even when a rival outweighs it', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(kTrackReview, [5]),
        _avail(kTrackAlgorithms, [5, 5, 5]),
      ],
      budgetMinutes: 5, // only room for one 5-min unit
      ctx: const PlanContext(
        baseWeight: {kTrackReview: 0.1, kTrackAlgorithms: 0.9},
        reserved: {kTrackReview},
      ),
    );
    // Review is reserved, so it claims the single slot despite lower weight.
    expect(_track(p, kTrackReview)!.units.length, 1);
    expect(_track(p, kTrackAlgorithms), isNull);
  });

  test('recency down-weights a track (variety): the neglected one gets more',
      () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(kTrackLearn, List.filled(10, 1)),
        _avail(kTrackAlgorithms, List.filled(10, 1)),
      ],
      budgetMinutes: 6,
      ctx: const PlanContext(
        baseWeight: {kTrackLearn: 0.5, kTrackAlgorithms: 0.5},
        recencyLoad: {kTrackLearn: 1.0}, // learn done a lot lately
      ),
    );
    final learn = _track(p, kTrackLearn)!;
    final algo = _track(p, kTrackAlgorithms)!;
    expect(algo.units.length, greaterThan(learn.units.length));
    expect(p.plannedMinutes, 6);
  });

  test('balances across equally-weighted tracks', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(kTrackReview, List.filled(10, 1)),
        _avail(kTrackAlgorithms, List.filled(10, 1)),
      ],
      budgetMinutes: 4,
      ctx: const PlanContext(
        baseWeight: {kTrackReview: 0.5, kTrackAlgorithms: 0.5},
      ),
    );
    expect(_track(p, kTrackReview)!.units.length, 2);
    expect(_track(p, kTrackAlgorithms)!.units.length, 2);
  });

  group('retention floor (#106)', () {
    test('a floor track clears its due units first, beating a heavier rival',
        () {
      // Review is weighted far below Algorithms, but as the floor it clears before
      // anything competes: all 10 due reviews (10 min), then Algo takes what's left.
      final p = buildDailyPlan(
        availabilities: [
          _avail(kTrackReview, List.filled(10, 1)),
          _avail(kTrackAlgorithms, [5, 5, 5]),
        ],
        budgetMinutes: 20,
        ctx: const PlanContext(
          baseWeight: {kTrackReview: 0.1, kTrackAlgorithms: 0.9},
          floor: {kTrackReview}, // default cap 0.8 → 16 min, all 10 fit
        ),
      );
      expect(_track(p, kTrackReview)!.units.length, 10);
      expect(_track(p, kTrackAlgorithms)!.units.length, 2); // 10 min left / 5
    });

    test('the floor cap keeps a backlog from eating the whole day', () {
      // 20 due reviews but the cap is half the day; the rest goes to a track that
      // can use it, so reviews hold at the cap (never crowd practice out entirely).
      final p = buildDailyPlan(
        availabilities: [
          _avail(kTrackReview, List.filled(20, 1)),
          _avail(kTrackAlgorithms, List.filled(10, 1)),
        ],
        budgetMinutes: 10,
        ctx: const PlanContext(
          baseWeight: {kTrackReview: 0.9, kTrackAlgorithms: 0.1},
          floor: {kTrackReview},
          floorCap: 0.5, // 5 min for reviews
        ),
      );
      expect(_track(p, kTrackReview)!.units.length, 5); // capped
      expect(_track(p, kTrackAlgorithms)!.units.length, 5); // the other half
    });

    test('leftover no one else can use flows back to the floor (past the cap)',
        () {
      // Same cap, but the only rival has a single unit — the rest of the day would
      // be wasted, so reviews soak it up beyond the cap rather than idle.
      final p = buildDailyPlan(
        availabilities: [
          _avail(kTrackReview, List.filled(20, 1)),
          _avail(kTrackAlgorithms, [2]),
        ],
        budgetMinutes: 10,
        ctx: const PlanContext(
          floor: {kTrackReview},
          floorCap: 0.5, // 5 min cap, but…
        ),
      );
      expect(_track(p, kTrackAlgorithms)!.units.length, 1); // 2 min
      expect(_track(p, kTrackReview)!.units.length, 8); // 5 capped + 3 leftover
      expect(p.plannedMinutes, 10); // nothing wasted
    });

    test('a floor track is marked non-negotiable', () {
      final p = buildDailyPlan(
        availabilities: [
          _avail(kTrackReview, [1])
        ],
        budgetMinutes: 60,
        ctx: const PlanContext(floor: {kTrackReview}),
      );
      expect(_track(p, kTrackReview)!.nonNegotiable, isTrue);
    });
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

  group('budgetZone', () {
    test('classifies the daily budget into sustainability zones', () {
      expect(budgetZone(30), BudgetZone.light); // slider min
      expect(budgetZone(44), BudgetZone.light);
      expect(budgetZone(45), BudgetZone.sustainable);
      expect(budgetZone(90), BudgetZone.sustainable); // ease-in start
      expect(budgetZone(150), BudgetZone.sustainable); // default target
      expect(budgetZone(165), BudgetZone.sustainable);
      expect(budgetZone(180), BudgetZone.ambitious);
      expect(budgetZone(210), BudgetZone.ambitious);
      expect(budgetZone(211), BudgetZone.tooMuch);
      expect(budgetZone(240), BudgetZone.tooMuch); // slider max
    });
  });

  group('describeDailyPlan', () {
    test('summarizes tracks, budget, must-do, deferred and locked', () {
      final plan = DailyPlan(
        budgetMinutes: 90,
        locked: const [
          TrackAvailability(
            track: kTrackSystemDesign,
            label: 'System design',
            units: [],
            unlocked: false,
            gateReason: 'Unlocks as you get comfortable with rate limiting',
          ),
        ],
        tracks: [
          PlannedTrack(
            track: kTrackReview,
            label: 'Review',
            units: [_u(kTrackReview, 'a', 1.5), _u(kTrackReview, 'b', 1.5)],
            deferred: 0,
            nonNegotiable: true,
          ),
          PlannedTrack(
            track: kTrackAlgorithms,
            label: 'Algorithms',
            units: [_u(kTrackAlgorithms, 'two-sum', 25)],
            deferred: 3,
            nonNegotiable: false,
          ),
        ],
      );
      final s = describeDailyPlan(plan);
      expect(s, contains('~28 of 90 min'));
      expect(s, contains('Review: 2 items'));
      expect(s, contains('must-do'));
      expect(s, contains('Algorithms: 1 item'));
      expect(s, contains('+3 deferred'));
      expect(s, contains('System design: locked'));
      expect(s, contains('rate limiting'));
    });

    test('reports the caught-up state when nothing is scheduled', () {
      expect(
        describeDailyPlan(
            const DailyPlan(tracks: [], budgetMinutes: 90, locked: [])),
        contains('all caught up'),
      );
    });
  });

  test('marks the top-priority track non-negotiable when none reserved', () {
    final p = buildDailyPlan(
      availabilities: [
        _avail(kTrackReview, [1]),
        _avail(kTrackAlgorithms, [1]),
      ],
      budgetMinutes: 60,
      ctx: const PlanContext(
        baseWeight: {kTrackReview: 0.5, kTrackAlgorithms: 0.9},
      ),
    );
    expect(_track(p, kTrackAlgorithms)!.nonNegotiable, isTrue);
    expect(_track(p, kTrackReview)!.nonNegotiable, isFalse);
    // Highest priority first in the list.
    expect(p.tracks.first.track, kTrackAlgorithms);
  });
}
