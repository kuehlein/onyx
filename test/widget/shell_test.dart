// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/app.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/vault.dart';

CardSection _section(String heading, {bool quizzable = true}) => CardSection(
      heading: heading,
      slug: heading.toLowerCase().replaceAll(' ', '-'),
      content: 'body',
      quizzable: quizzable,
    );

Card _card(String id, String title, {CardType type = CardType.flashcard}) =>
    Card(
      id: id,
      type: type,
      title: title,
      overview: 'overview',
      tags: const ['ds-a'],
      tiers: const {'ds-a': 2},
      sections: [_section('When to Use')],
      wikilinks: const [],
      filePath: '$title.md',
    );

void main() {
  Widget app(IndexResult index) => ProviderScope(
        overrides: [
          vaultIndexProvider.overrideWith((ref) async => index),
        ],
        child: const OnyxApp(),
      );

  final populated = IndexResult(
    cards: [
      _card('11111111-1111-4111-8111-111111111111', 'Binary Search'),
      _card('22222222-2222-4222-8222-222222222222', 'Two Pointers',
          type: CardType.interviewQuestion),
    ],
    idless: 0,
    malformed: 0,
    skipped: 0,
  );

  testWidgets('shell renders the four bottom-nav destinations', (tester) async {
    await tester.pumpWidget(app(populated));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'Browse', 'Study', 'Settings']) {
      expect(find.text(label), findsOneWidget);
    }
    // Home tab shows the index count.
    expect(find.text('2 cards indexed'), findsOneWidget);
  });

  testWidgets('Browse tab lists indexed cards by title', (tester) async {
    await tester.pumpWidget(app(populated));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(Icons.grid_view_outlined),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Binary Search'), findsOneWidget);
    expect(find.text('Two Pointers'), findsOneWidget);
  });

  testWidgets('tapping a card opens its detail view', (tester) async {
    await tester.pumpWidget(app(populated));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(Icons.grid_view_outlined),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Binary Search'));
    await tester.pumpAndSettle();

    // Detail renders the section heading and a type meta-chip.
    expect(find.text('When to Use'), findsOneWidget);
    expect(find.text('Flashcard'), findsOneWidget);
  });

  testWidgets('Browse shows an empty-state prompt when no cards',
      (tester) async {
    await tester.pumpWidget(app(const IndexResult(
      cards: [],
      idless: 0,
      malformed: 0,
      skipped: 0,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.byIcon(Icons.grid_view_outlined),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No cards indexed'), findsOneWidget);
  });
}
