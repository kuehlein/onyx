// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/features/browse/browse_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/vault.dart';

Card _card(
  String title, {
  List<String> tags = const ['ds-a'],
  String o = '',
  CardType type = CardType.flashcard,
}) =>
    Card(
      id: title,
      type: type,
      title: title,
      overview: o,
      tags: tags,
      tiers: {tags.first: 1},
      sections: const [],
      wikilinks: const [],
      filePath: '$title.md',
    );

Widget _app(IndexResult index) => ProviderScope(
      overrides: [
        vaultIndexProvider.overrideWith((ref) async => index),
        srsStatesProvider.overrideWith((ref) async => const SectionStates({})),
      ],
      child: const MaterialApp(home: BrowseScreen()),
    );

void main() {
  final index = IndexResult(
    cards: [
      _card('Binary Search', o: 'divide a sorted array'),
      _card('Two Pointers'),
      _card('Dijkstra', tags: ['graphs'], o: 'shortest path in a graph'),
      _card('Design a URL shortener',
          tags: ['system-design'], type: CardType.interviewQuestion),
    ],
    idless: 0,
    malformed: 0,
    skipped: 0,
  );

  testWidgets('lists all cards with no query, filters as you type',
      (tester) async {
    await tester.pumpWidget(_app(index));
    await tester.pumpAndSettle();

    // All present initially.
    expect(find.text('Binary Search'), findsOneWidget);
    expect(find.text('Two Pointers'), findsOneWidget);
    expect(find.text('Dijkstra'), findsOneWidget);

    // Title search narrows to one.
    await tester.enterText(find.byType(TextField), 'binary');
    await tester.pumpAndSettle();
    expect(find.text('Binary Search'), findsOneWidget);
    expect(find.text('Two Pointers'), findsNothing);
    expect(find.text('Dijkstra'), findsNothing);
    expect(find.text('1 of 4 cards'), findsOneWidget);
  });

  testWidgets('body-only match works and no-match shows a message',
      (tester) async {
    await tester.pumpWidget(_app(index));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'path');
    await tester.pumpAndSettle();
    expect(find.text('Dijkstra'), findsOneWidget);
    expect(find.text('Binary Search'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzznope');
    await tester.pumpAndSettle();
    expect(find.textContaining('No cards match'), findsOneWidget);
  });

  testWidgets('query operators filter (type:interview)', (tester) async {
    await tester.pumpWidget(_app(index));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'type:interview');
    await tester.pumpAndSettle();
    expect(find.text('Design a URL shortener'), findsOneWidget);
    expect(find.text('Binary Search'), findsNothing);
    expect(find.text('Dijkstra'), findsNothing);
  });
}
