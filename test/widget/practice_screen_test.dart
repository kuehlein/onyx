// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onyx/features/practice/practice_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/practice.dart';

Card _interview(String id) => Card(
      id: id,
      type: CardType.interviewQuestion,
      title: id,
      overview: 'Solve $id.',
      tags: const ['ds-a'],
      tiers: const {'ds-a': 1},
      sections: const [
        CardSection(
            heading: 'Approach',
            slug: 'approach',
            content: 'do it',
            quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

Widget _app(List<Card> set) {
  final router = GoRouter(routes: [
    GoRoute(
        path: '/', builder: (_, __) => const PracticeScreen(domain: 'ds-a')),
  ]);
  return ProviderScope(
    overrides: [
      practiceSetProvider('ds-a').overrideWith((ref) async => set),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('practice screen pages through cards and reveals answers',
      (tester) async {
    await tester.pumpWidget(_app([_interview('Q1'), _interview('Q2')]));
    await tester.pumpAndSettle();

    // First problem shown, applied-practice entry present, no grade buttons.
    expect(find.text('Practice · DS & A'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Answer the coach'), findsWidgets);
    expect(find.text('Again'), findsNothing); // never grades

    // Reveal → shows the answer section, then advance.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reveal'));
    await tester.pumpAndSettle();
    expect(find.text('Approach'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    // Last card finishes to the done screen.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reveal'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle();
    expect(find.textContaining('practised'), findsOneWidget);
    expect(find.textContaining('nothing recorded'), findsOneWidget);
  });

  testWidgets('empty set shows a graceful message', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('No practice material'), findsOneWidget);
  });
}
