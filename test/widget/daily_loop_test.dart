import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/features/home/today_flows.dart';

import 'support/harness.dart';

/// End-to-end verification (task E2): the daily loop over a live in-memory DB —
/// Home renders the day's plan, a study session grades, and the grade persists +
/// recomputes. Built on [pumpLiveApp] (E1). Guarded on sqlite availability.

void main() {
  testWidgets('live harness renders Home past the gate (seeded deck)',
      (tester) async {
    final db = await pumpLiveApp(tester, cards: [
      testCard('a', 'Alpha'),
      testCard('b', 'Beta'),
    ]);
    if (db == null) {
      markTestSkipped('no native sqlite'); // visible skip, not a silent pass
      return;
    }
    addTearDown(db.close);

    // A full live render (real DB + derived study providers) threw nothing.
    expect(tester.takeException(), isNull);
    // We're on Home, not redirected to the /welcome first-run gate.
    expect(find.text('Choose a folder'), findsNothing);
    // The Home shell rendered (the main nav bar) — the enabler for E2's flow.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
      'daily loop: learn two new cards → graded, persisted, Home clears',
      (tester) async {
    final db = await pumpLiveApp(tester, cards: [
      testCard('a', 'Alpha'),
      testCard('b', 'Beta'),
    ]);
    if (db == null) {
      markTestSkipped('no native sqlite'); // visible skip, not a silent pass
      return;
    }
    addTearDown(db.close);

    // Home derived a "learn" flow from the two fresh cards (plan → TodayFlows).
    final flowButton = find.descendant(
        of: find.byType(TodayFlows), matching: find.byType(FilledButton));
    expect(flowButton, findsWidgets);

    // Enter the study session.
    await tester.tap(flowButton.first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Learn'), findsOneWidget);

    // Dismiss the one-time "Before you start" learn intro.
    final startLearning = find.text('Start learning');
    if (startLearning.evaluate().isNotEmpty) {
      await tester.tap(startLearning);
      await tester.pumpAndSettle();
    }

    // Reveal (pretest sections) + grade Good, for each of the two sections.
    for (var i = 0; i < 2; i++) {
      final reveal = find.widgetWithText(FilledButton, 'Reveal');
      if (reveal.evaluate().isNotEmpty) {
        await tester.tap(reveal);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Good'));
      await tester.pumpAndSettle();
    }

    // Session complete.
    expect(find.text('Nice work'), findsOneWidget);

    // grade → PERSIST: both sections now carry FSRS state in the real DB.
    final states = await SrsRepository(db).loadStates();
    expect(
        states.keys, containsAll(<String>['a::when-to-use', 'b::when-to-use']));

    // → RECOMPUTE: back on Home, the learn flow is gone (both cards scheduled,
    // none due today) — the loop closed end-to-end.
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(TodayFlows), matching: find.byType(FilledButton)),
        findsNothing);
  });
}
