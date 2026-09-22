import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/goal/study_goal.dart';
import 'package:onyx/features/interview/upcoming_interviews_screen.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/study_goals.dart';
import 'package:onyx/shared/providers/vault.dart';

/// A fake study-goals notifier holding one default goal whose [interviews] are
/// the interviews under test (Phase B — the interview cluster reads the active
/// goal's interviews).
class _FakeGoals extends StudyGoals {
  _FakeGoals(this._interviews);
  final List<Aim> _interviews;
  @override
  Future<List<StudyGoal>> build() async => [
        StudyGoal(
          id: defaultGoalId,
          name: 'default',
          templateId: 'software-interviews',
          interviews: _interviews,
        ),
      ];
}

Widget _app(List<Aim> interviews) => ProviderScope(
      overrides: [
        studyGoalsProvider.overrideWith(() => _FakeGoals(interviews)),
        clockProvider.overrideWith((ref) async => Clock.real),
        // templateRegistry uses the built-in SWE config when the source is null.
        vaultSourceProvider.overrideWithValue(null),
        // The card's pace chip depends on a heavy forecast; stub it out.
        readinessForecastForProvider.overrideWith((ref, dims) async => null),
      ],
      child: const MaterialApp(home: UpcomingInterviewsScreen()),
    );

Aim _aim(String id, String company, {DateTime? date}) => Aim(
      id: id,
      companyName: company,
      rounds: date == null
          ? const []
          : [InterviewRound(id: '$id-r1', number: 1, date: date)],
    );

void main() {
  testWidgets('lists active interviews soonest-first; undated last',
      (tester) async {
    final interviews = [
      // Undated (should sort last despite being first in the list).
      _aim('g2', 'Amazon'),
      _aim('g1', 'Google', date: DateTime(2099, 1, 1)),
    ];
    await tester.pumpWidget(_app(interviews));
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
      const Aim(
        id: 'g1',
        companyName: 'Google',
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
