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

Finder _navDest(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

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
    if (db == null) {
      markTestSkipped('no native sqlite'); // visible skip, not a silent pass
      return;
    }
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

    // Focusing the lane scopes the whole app to that deck. Browse lists the FULL
    // member set (not one card at a time), so a scoping regression would surface
    // Beta here — a stronger proof than the single-card study queue below, whose
    // one-card view could hide a leak by accident.
    await tester.tap(_navDest('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha Card'), findsOneWidget);
    expect(find.text('Beta Card'), findsNothing);

    // Back to this deck's Home to study.
    await tester.tap(_navDest('Home'));
    await tester.pumpAndSettle();

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
