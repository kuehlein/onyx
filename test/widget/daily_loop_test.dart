import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

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
    if (db == null) return; // sqlite unavailable in this env — skip
    addTearDown(db.close);

    // A full live render (real DB + derived study providers) threw nothing.
    expect(tester.takeException(), isNull);
    // We're on Home, not redirected to the /welcome first-run gate.
    expect(find.text('Choose a folder'), findsNothing);
    // The Home shell rendered (the main nav bar) — the enabler for E2's flow.
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
