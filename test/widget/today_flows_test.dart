import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/plan/daily_plan.dart';
import 'package:onyx/core/plan/practice_plan.dart';
import 'package:onyx/features/home/today_flows.dart';
import 'package:onyx/shared/providers/daily_plan.dart';

PracticeUnit _u(String t, String id, double m) =>
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
          track: kTrackSystemDesign,
          label: 'System design',
          units: [],
          unlocked: false,
          gateReason: 'Unlocks as you get comfortable with graphs',
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
          deferred: 2,
          nonNegotiable: false,
        ),
        PlannedTrack(
          track: kTrackLearn,
          label: 'Learn',
          units: [_u(kTrackLearn, 'x', 3)],
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

  testWidgets('offers optional extra practice when the plan is empty',
      (tester) async {
    await tester.pumpWidget(
        _harness(const DailyPlan(tracks: [], budgetMinutes: 90, locked: [])));
    await tester.pumpAndSettle();
    expect(find.textContaining('clear for today'), findsOneWidget);
  });
}
