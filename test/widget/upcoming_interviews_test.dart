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
        // The card's pace chip depends on a heavy forecast; stub it out.
        readinessForecastForProvider.overrideWith((ref, dims) async => null),
      ],
      child: const MaterialApp(home: UpcomingInterviewsScreen()),
    );

void main() {
  testWidgets('lists active interviews soonest-first; undated last',
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

    // The card shows the company name.
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Amazon'), findsOneWidget);
    // Google has a future date → a countdown; Amazon has no upcoming round.
    expect(find.textContaining('in '), findsWidgets);
    expect(find.textContaining('No upcoming round'), findsOneWidget);
    // Dated interview sorts above the undated one.
    expect(tester.getTopLeft(find.text('Google')).dy,
        lessThan(tester.getTopLeft(find.text('Amazon')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state prompts planning one', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('No interviews planned yet'), findsOneWidget);
  });

  testWidgets('ended interviews live in a collapsible Past section',
      (tester) async {
    await tester.pumpWidget(_app([
      const PrepGoal(
        id: 'g1',
        companyName: 'Google',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
        status: InterviewStatus.rejected,
      ),
    ]));
    await tester.pumpAndSettle();
    // Collapsed by default: a "Past interviews (1)" toggle, no card yet.
    expect(find.textContaining('Past interviews (1)'), findsOneWidget);
    expect(find.text('Google'), findsNothing);
    // Expand → the card appears with its outcome.
    await tester.tap(find.textContaining('Past interviews (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Google'), findsOneWidget);
    expect(find.textContaining('Didn'), findsWidgets); // "Didn't pass"
  });
}
