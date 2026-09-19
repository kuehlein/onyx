// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  final populated = testIndex([
    testCard('11111111-1111-4111-8111-111111111111', 'Binary Search'),
    testCard('22222222-2222-4222-8222-222222222222', 'Two Pointers',
        type: 'interview-question'),
  ]);

  Finder browseTab() => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byIcon(Icons.grid_view_outlined),
      );

  testWidgets('shell renders the four bottom-nav destinations', (tester) async {
    await pumpApp(tester, index: populated);

    expect(find.byType(NavigationBar), findsOneWidget);
    // Study sessions (Review/Learn/Algorithms) are Home actions, not tabs.
    for (final label in ['Home', 'Browse', 'Insights', 'Settings']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Study'), findsNothing);
    // Home shows the Today queue; with an empty plan it's the caught-up state.
    expect(find.textContaining('All caught up'), findsOneWidget);
  });

  testWidgets('Browse tab lists indexed cards by title', (tester) async {
    await pumpApp(tester, index: populated);

    await tester.tap(browseTab());
    await tester.pumpAndSettle();

    expect(find.text('Binary Search'), findsOneWidget);
    expect(find.text('Two Pointers'), findsOneWidget);
  });

  testWidgets('tapping a card opens its detail view', (tester) async {
    await pumpApp(tester, index: populated);

    await tester.tap(browseTab());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Binary Search'));
    await tester.pumpAndSettle();

    // Detail renders the section heading and a type meta-chip.
    expect(find.text('When to Use'), findsOneWidget);
    expect(find.text('Flashcard'), findsOneWidget);
  });

  testWidgets('Browse shows an empty-state prompt when no cards',
      (tester) async {
    await pumpApp(tester); // empty index by default

    await tester.tap(browseTab());
    await tester.pumpAndSettle();

    expect(find.textContaining('No cards indexed'), findsOneWidget);
  });
}
