import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/study_goal.dart';
import 'package:onyx/core/readiness/readiness.dart';
import 'package:onyx/features/home/lanes_hub.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/study_goals.dart';

class _FixedGoals extends StudyGoals {
  _FixedGoals(this._goals);
  final List<StudyGoal> _goals;
  @override
  Future<List<StudyGoal>> build() async => _goals;
}

Readiness _emptyReadiness() =>
    computeReadiness(cards: const [], stabilityByKey: const {});

void main() {
  final korean = StudyGoal(
    id: 'korean',
    name: 'Korean',
    templateId: 'korean',
    membership: TagMembership('korean'),
  );
  const cs = StudyGoal(id: 'cs', name: 'CS interview', templateId: 'swe');

  ProviderScope harness({
    required List<StudyGoal> goals,
    required void Function(String) onEnter,
  }) =>
      ProviderScope(
        overrides: [
          studyGoalsProvider.overrideWith(() => _FixedGoals(goals)),
          goalBudgetsProvider
              .overrideWith((ref) async => {'korean': 60.0, 'cs': 40.0}),
          for (final g in goals)
            goalReadinessProvider(g.id)
                .overrideWith((ref) async => _emptyReadiness()),
        ],
        child: MaterialApp(
          home: Scaffold(body: LanesHub(onEnter: onEnter)),
        ),
      );

  testWidgets('renders a lane per active goal with its budget slice',
      (tester) async {
    await tester.pumpWidget(harness(goals: [korean, cs], onEnter: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Korean'), findsOneWidget);
    expect(find.text('CS interview'), findsOneWidget);
    expect(find.text('~60m'), findsOneWidget);
    expect(find.text('~40m'), findsOneWidget);
  });

  testWidgets('tapping a lane enters that goal', (tester) async {
    String? entered;
    await tester.pumpWidget(
        harness(goals: [korean, cs], onEnter: (id) => entered = id));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CS interview'));
    expect(entered, 'cs');
  });

  testWidgets('a paused goal shows a resume row, not a lane', (tester) async {
    final pausedCs = cs.copyWith(state: GoalState.paused);
    await tester
        .pumpWidget(harness(goals: [korean, pausedCs], onEnter: (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('CS interview · paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });
}
