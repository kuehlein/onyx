import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/daily_plan.dart';
import 'package:onyx/core/plan/practice_plan.dart';
import 'package:onyx/features/home/today_plan.dart';
import 'package:onyx/shared/providers/daily_plan.dart';

PracticeUnit _u(TrackId t, String id, double m) =>
    PracticeUnit(track: t, id: id, label: id, estMinutes: m);

Widget _harness(DailyPlan plan) => ProviderScope(
      overrides: [dailyPlanProvider.overrideWith((ref) async => plan)],
      child: const MaterialApp(home: Scaffold(body: TodayPlan())),
    );

void main() {
  testWidgets('renders a row per planned track with count, time and total',
      (tester) async {
    final plan = DailyPlan(
      budgetMinutes: 90,
      locked: const [],
      tracks: [
        PlannedTrack(
          track: TrackId.review,
          units: [_u(TrackId.review, 'a', 1.5), _u(TrackId.review, 'b', 1.5)],
          deferred: 0,
          nonNegotiable: true,
        ),
        PlannedTrack(
          track: TrackId.algorithms,
          units: [_u(TrackId.algorithms, 'two-sum', 25)],
          deferred: 3,
          nonNegotiable: false,
        ),
      ],
    );

    await tester.pumpWidget(_harness(plan));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('~28 min'), findsOneWidget); // 3 + 25 total planned
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Algorithms'), findsOneWidget);
    expect(find.textContaining('2 due'), findsOneWidget);
    expect(find.textContaining('1 problem'), findsOneWidget);
    expect(find.textContaining('+3 later'), findsOneWidget);
    // The reserved track is starred; the "short on time" hint appears.
    expect(find.textContaining('Short on time?'), findsOneWidget);
  });

  testWidgets('shows an all-caught-up message when the plan is empty',
      (tester) async {
    await tester.pumpWidget(
        _harness(const DailyPlan(tracks: [], budgetMinutes: 90, locked: [])));
    await tester.pumpAndSettle();
    expect(find.textContaining('All caught up'), findsOneWidget);
  });

  testWidgets('surfaces a locked track with its gate reason', (tester) async {
    const plan = DailyPlan(
      budgetMinutes: 90,
      tracks: [],
      locked: [
        TrackAvailability(
          track: TrackId.systemDesign,
          units: [],
          unlocked: false,
          gateReason: 'Unlocks as you get comfortable with rate limiting',
        ),
      ],
    );
    await tester.pumpWidget(_harness(plan));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Unlocks as you get comfortable'), findsOneWidget);
  });
}
