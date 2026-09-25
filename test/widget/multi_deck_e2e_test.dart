import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/features/home/today_flows.dart';

import 'support/harness.dart';

/// End-to-end verification (task E3): the multi-deck journey — with ≥2 active
/// decks Home shows the "Today's mix" lanes hub; focusing a lane enters that
/// deck's own Home, and studying it is scoped to that deck's members. Built on the
/// live in-memory-DB harness (E1). Guarded on sqlite availability.

void main() {
  testWidgets('multi-deck: lanes hub → focus a deck → study scoped to it',
      (tester) async {
    const tpl = softwareInterviewsTemplate;
    final db = await pumpLiveApp(
      tester,
      cards: [
        testCard('ca', 'Alpha Card',
            tags: const ['ds-a'], tiers: const {'ds-a': 2}),
        testCard('cb', 'Beta Card',
            tags: const ['networking'], tiers: const {'networking': 2}),
      ],
      decks: [
        Deck(
            id: 'algo',
            name: 'Algorithms',
            templateId: tpl.id,
            membership: TagIs('ds-a')),
        Deck(
            id: 'net',
            name: 'Networking',
            templateId: tpl.id,
            membership: TagIs('networking')),
      ],
    );
    if (db == null) return; // sqlite unavailable — skip
    addTearDown(db.close);

    // Two active decks → the "Today's mix" lanes hub (the ≥2 degradation
    // boundary), one lane per deck.
    expect(find.text("Today's mix"), findsOneWidget);
    expect(find.text('Algorithms'), findsOneWidget);
    expect(find.text('Networking'), findsOneWidget);

    // Focus a deck → its own single-deck Home; the hub is gone.
    await tester.tap(find.text('Algorithms'));
    await tester.pumpAndSettle();
    expect(find.text("Today's mix"), findsNothing);

    // Study from the focused deck → scoped to ITS member only (ds-a → Alpha Card;
    // the Networking deck's Beta Card is not in this session).
    final flow = find.descendant(
        of: find.byType(TodayFlows), matching: find.byType(FilledButton));
    expect(flow, findsWidgets);
    await tester.tap(flow.first);
    await tester.pumpAndSettle();
    final start = find.text('Start learning');
    if (start.evaluate().isNotEmpty) {
      await tester.tap(start);
      await tester.pumpAndSettle();
    }
    expect(find.text('Alpha Card'), findsOneWidget);
    expect(find.text('Beta Card'), findsNothing);
  });
}
