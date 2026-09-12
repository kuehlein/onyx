import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/daily_plan.dart';
import 'package:onyx/core/plan/practice_plan.dart';
import 'package:onyx/features/home/today_flows.dart';
import 'package:onyx/shared/providers/daily_plan.dart';

PracticeUnit _u(TrackId t, String id, double m) =>
    PracticeUnit(track: t, id: id, label: id, estMinutes: m);

Widget _harness(DailyPlan plan) => ProviderScope(
      overrides: [dailyPlanProvider.overrideWith((ref) async => plan)],
      child: const MaterialApp(home: Scaffold(body: TodayFlows())),
    );

void main() {
  testWidgets('renders flows with descending emphasis + a locked row',
      (tester) async {
    final plan = DailyPlan(
      budgetMinutes: 150,
      locked: const [
        TrackAvailability(
          track: TrackId.systemDesign,
          units: [],
          unlocked: false,
          gateReason: 'Unlocks as you get comfortable with graphs',
        ),
      ],
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
          deferred: 2,
          nonNegotiable: false,
        ),
        PlannedTrack(
          track: TrackId.learn,
          units: [_u(TrackId.learn, 'x', 3)],
          deferred: 0,
          nonNegotiable: false,
        ),
      ],
    );

    await tester.pumpWidget(_harness(plan));
    await tester.pumpAndSettle();

    // Primary + secondary are both FilledButton (tonal is a FilledButton
    // variant); tertiary is an OutlinedButton.
    expect(find.byType(FilledButton), findsNWidgets(2));
    expect(find.byType(OutlinedButton), findsOneWidget);

    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Algorithms'), findsOneWidget);
    expect(find.text('Learn'), findsOneWidget);
    expect(find.textContaining('2 due'), findsOneWidget);
    expect(find.textContaining('1 problem'), findsOneWidget);
    expect(find.textContaining('+2'), findsOneWidget); // deferred marker
    expect(
        find.textContaining('Unlocks as you get comfortable'), findsOneWidget);
  });

  testWidgets('shows a nothing-scheduled note when the plan is empty',
      (tester) async {
    await tester.pumpWidget(
        _harness(const DailyPlan(tracks: [], budgetMinutes: 90, locked: [])));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing scheduled'), findsOneWidget);
  });
}
