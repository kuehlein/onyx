import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/features/interview/upcoming_interviews_screen.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/readiness.dart';

class _FakeGoals extends PrepGoals {
  _FakeGoals(this._goals);
  final List<PrepGoal> _goals;
  @override
  Future<List<PrepGoal>> build() async => _goals;
}

Widget _app(List<PrepGoal> goals) => ProviderScope(
      overrides: [
        prepGoalsProvider.overrideWith(() => _FakeGoals(goals)),
        clockProvider.overrideWith((ref) async => Clock.real),
      ],
      child: const MaterialApp(home: UpcomingInterviewsScreen()),
    );

void main() {
  testWidgets('lists goals soonest-first with a countdown; undated last',
      (tester) async {
    final goals = [
      // Undated (should sort last despite being first in the list).
      const PrepGoal(
          id: 'g2',
          companyName: 'Amazon',
          tier: CompanyTier.faang,
          level: SeniorityLevel.mid,
          track: Track.backend),
      PrepGoal(
          id: 'g1',
          companyName: 'Google',
          tier: CompanyTier.faang,
          level: SeniorityLevel.senior,
          track: Track.backend,
          date: DateTime(2099, 1, 1)),
    ];
    await tester.pumpWidget(_app(goals));
    await tester.pumpAndSettle();

    expect(find.text('Google · Senior · Backend'), findsOneWidget);
    expect(find.text('Amazon · Mid · Backend'), findsOneWidget);
    // Google has a future date → a countdown; Amazon shows no date.
    expect(find.textContaining('in '), findsWidgets);
    expect(find.textContaining('No date set'), findsOneWidget);
    // Dated goal sorts above the undated one.
    expect(tester.getTopLeft(find.text('Google · Senior · Backend')).dy,
        lessThan(tester.getTopLeft(find.text('Amazon · Mid · Backend')).dy));
    // A toggle per goal.
    expect(find.byType(Switch), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state prompts planning one', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('No interviews planned yet'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('a decided goal shows its outcome', (tester) async {
    await tester.pumpWidget(_app([
      const PrepGoal(
        id: 'g1',
        companyName: 'Google',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
        outcome: GoalOutcome.failed,
      ),
    ]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Didn'), findsOneWidget); // "Didn’t pass"
  });
}
