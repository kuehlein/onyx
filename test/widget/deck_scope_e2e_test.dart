import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/software_interviews.dart';

import 'support/harness.dart';

/// End-to-end verification (task E5): deck-scoped surfaces on the live app.
/// Browse and Insights act on the ACTIVE deck's members (not the whole vault),
/// and an aim on the deck flows through to the readiness surface. Built on the
/// live in-memory-DB harness (E1). Guarded on sqlite availability.

Finder _navDest(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets('Browse + Insights are scoped to the active deck',
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
      // A single deck scoped to ds-a → Home directly; Browse/Insights follow it.
      decks: [
        Deck(
            id: 'algo',
            name: 'Algorithms',
            templateId: tpl.id,
            membership: TagIs('ds-a')),
      ],
    );
    if (db == null) {
      markTestSkipped('no native sqlite'); // visible skip, not a silent pass
      return;
    }
    addTearDown(db.close);

    // Browse → only the deck's member (ds-a); the networking card is out of scope.
    await tester.tap(_navDest('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha Card'), findsOneWidget);
    expect(find.text('Beta Card'), findsNothing);

    // Insights → renders scoped to the deck, no exception (the analytics chain
    // resolves live over the deck's members).
    await tester.tap(_navDest('Insights'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an aim on the deck surfaces on Home as its readiness target',
      (tester) async {
    const tpl = softwareInterviewsTemplate;
    final db = await pumpLiveApp(
      tester,
      cards: [
        testCard('ca', 'Alpha Card',
            tags: const ['ds-a'], tiers: const {'ds-a': 2}),
      ],
      decks: [
        Deck(
          id: 'algo',
          name: 'Algorithms',
          templateId: tpl.id,
          membership: TagIs('ds-a'),
          // A deck WITH an aim → its target drives the Home readiness surface.
          aims: const [
            Aim(
                id: 'a1',
                companyName: 'Google',
                levelId: 'senior',
                contextId: 'faang',
                trackId: 'backend'),
          ],
        ),
      ],
    );
    if (db == null) {
      markTestSkipped('no native sqlite'); // visible skip, not a silent pass
      return;
    }
    addTearDown(db.close);

    // The deck's aim resolves into a set target → Home shows "Your target",
    // not the unset "Set your …" prompt (aim → readiness-surface wiring).
    expect(find.text('Your target'), findsOneWidget);
    expect(find.textContaining('Set your'), findsNothing);
  });
}
