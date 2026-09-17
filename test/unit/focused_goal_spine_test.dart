import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/providers/study_goals.dart';

/// The one focused-goal spine (ADR-0005). The integration (readiness scopes to the
/// focused lens) lives in readiness_flow_test; here we pin the primitive itself.

void main() {
  group('FocusedGoal spine', () {
    test('defaults to null (the hub altitude); focus + clear round-trip', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(focusedGoalProvider), isNull);

      c.read(focusedGoalProvider.notifier).focus('algorithms');
      expect(c.read(focusedGoalProvider), 'algorithms');

      c.read(focusedGoalProvider.notifier).focus('korean');
      expect(c.read(focusedGoalProvider), 'korean');

      c.read(focusedGoalProvider.notifier).focus(null);
      expect(c.read(focusedGoalProvider), isNull);
    });
  });
}
