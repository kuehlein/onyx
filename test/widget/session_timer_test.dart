import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/widgets/session_timer.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('SessionTimer count-up (stopwatch)', () {
    testWidgets('starts on tap, counts up, and reports elapsed via onTick',
        (tester) async {
      final ticks = <int>[];
      await tester.pumpWidget(_wrap(
        SessionTimer(
          mode: TimerMode.countUp,
          idleLabel: 'Timer',
          onTick: ticks.add,
        ),
      ));

      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('tap to start'), findsOneWidget);

      await tester.tap(find.byType(SessionTimer));
      await tester.pump(); // enter running state
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(ticks, [1, 2]);
      expect(find.text('2s'), findsOneWidget);
      expect(find.text('tap to reset'), findsOneWidget);

      // Tap again resets to idle.
      await tester.tap(find.byType(SessionTimer));
      await tester.pump();
      expect(find.text('Timer'), findsOneWidget);
      expect(ticks.last, 0);
    });
  });

  group('SessionTimer count-down', () {
    testWidgets('counts down to the done label at zero', (tester) async {
      await tester.pumpWidget(_wrap(
        const SessionTimer(
          mode: TimerMode.countDown,
          durationSeconds: 2,
          idleLabel: 'Rest timer',
          doneLabel: 'Next set',
          doneIcon: Icons.fitness_center,
        ),
      ));

      expect(find.text('Rest timer'), findsOneWidget);
      await tester.tap(find.byType(SessionTimer));
      await tester.pump();
      expect(find.text('2s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Next set'), findsOneWidget);
    });
  });
}
