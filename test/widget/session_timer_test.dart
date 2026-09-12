import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/widgets/session_timer.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('SessionTimer count-up (stopwatch)', () {
    testWidgets('starts, counts up, then pauses and resumes (keeps elapsed)',
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
      expect(find.text('tap to pause'), findsOneWidget);

      // Tap pauses: elapsed is kept, ticker stops.
      await tester.tap(find.byType(SessionTimer));
      await tester.pump();
      expect(find.text('2s'), findsOneWidget);
      expect(find.text('tap to resume'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('2s'), findsOneWidget); // didn't advance while paused

      // Tap resumes from where it left off.
      await tester.tap(find.byType(SessionTimer));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('3s'), findsOneWidget);

      // Clean up the running ticker.
      await tester.tap(find.byType(SessionTimer));
      await tester.pump();
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
