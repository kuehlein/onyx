import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/budget.dart';
import 'package:onyx/core/goal/study_goal.dart';

StudyGoal _g(String id,
        {double weight = 1.0, GoalState state = GoalState.active}) =>
    StudyGoal(
      id: id,
      name: id,
      templateId: 't',
      budgetWeight: weight,
      state: state,
    );

void main() {
  group('allocateBudget', () {
    test('a single active goal gets the whole budget', () {
      expect(allocateBudget(goals: [_g('a')], totalMinutes: 150), {'a': 150.0});
    });

    test('equal weights split evenly', () {
      final b = allocateBudget(goals: [_g('a'), _g('b')], totalMinutes: 150);
      expect(b, {'a': 75.0, 'b': 75.0});
    });

    test('splits in proportion to weight', () {
      final b = allocateBudget(
          goals: [_g('a', weight: 3), _g('b', weight: 1)], totalMinutes: 160);
      expect(b, {'a': 120.0, 'b': 40.0});
    });

    test('a paused goal drops out and its share redistributes', () {
      final b = allocateBudget(
        goals: [_g('a'), _g('b', state: GoalState.paused), _g('c')],
        totalMinutes: 120,
      );
      expect(b.containsKey('b'), isFalse);
      expect(b, {'a': 60.0, 'c': 60.0});
    });

    test('graduated and non-positive-weight goals are excluded', () {
      final b = allocateBudget(
        goals: [
          _g('a'),
          _g('grad', state: GoalState.graduated),
          _g('zero', weight: 0),
        ],
        totalMinutes: 100,
      );
      expect(b, {'a': 100.0});
    });

    test('no active goals → empty', () {
      expect(
        allocateBudget(
          goals: [_g('a', state: GoalState.paused)],
          totalMinutes: 100,
        ),
        isEmpty,
      );
    });
  });
}
