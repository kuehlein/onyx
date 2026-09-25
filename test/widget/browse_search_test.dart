// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/features/browse/browse_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/template.dart';
import 'package:onyx/shared/providers/vault.dart';

class _EmptyDecks extends Decks {
  @override
  Future<List<Deck>> build() async => const [];
}

Card _card(
  String title, {
  List<String> tags = const ['ds-a'],
  String o = '',
  String type = 'flashcard',
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

Widget _app(IndexResult index, {Deck? deck}) => ProviderScope(
      overrides: [
        vaultIndexProvider.overrideWith((ref) async => index),
        srsStatesProvider.overrideWith((ref) async => const SectionStates({})),
        // Browse is deck-scoped; pin the active deck so tests don't touch the DB.
        // Default = a whole-vault lens (shows everything, as before).
        activeDeckProvider.overrideWith((ref) async =>
            deck ?? const Deck(id: 'default', name: 'All', templateId: 't')),
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
          tags: ['system-design'], type: 'interview-question'),
    ],
    idless: 0,
    malformed: 0,
    skipped: 0,
  );

  testWidgets("Browse is deck-scoped to the active deck's lens (1d)",
      (tester) async {
    // A tag-lens deck selects only the ds-a cards; the graph + system-design
    // cards belong to other lenses and drop out.
    await tester.pumpWidget(_app(index,
        deck: Deck(
            id: 'dsa',
            name: 'DSA',
            templateId: 't',
            membership: TagIs('ds-a'))));
    await tester.pumpAndSettle();

    expect(find.text('Binary Search'), findsOneWidget);
    expect(find.text('Two Pointers'), findsOneWidget);
    expect(find.text('Dijkstra'), findsNothing);
    expect(find.text('Design a URL shortener'), findsNothing);
  });

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

  // G0 (ADR-0013): pin the tag: operator through the real pipeline (parse →
  // filter → render) before G2 rebuilds it on the unified query engine.
  testWidgets('query operators filter (tag:graphs)', (tester) async {
    await tester.pumpWidget(_app(index));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'tag:graphs');
    await tester.pumpAndSettle();
    expect(find.text('Dijkstra'), findsOneWidget);
    expect(find.text('Binary Search'), findsNothing);
    expect(find.text('Two Pointers'), findsNothing);
    expect(find.text('Design a URL shortener'), findsNothing);
  });

  // ADR-0013 §Addendum 2 (adversarial review): "Save as deck" on an all-dynamic
  // filter (is:due) strips to nothing structural — the composed lens equals the
  // active deck's own lens (whole vault here), so it must warn, not silently open a
  // whole-vault clone. Exercises the untested _saveAsDeck composition + note.
  testWidgets('Save as deck warns when the filter adds nothing structural',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vaultIndexProvider.overrideWith((ref) async => index),
        srsStatesProvider.overrideWith((ref) async => const SectionStates({})),
        activeDeckProvider.overrideWith((ref) async =>
            const Deck(id: 'default', name: 'All', templateId: 't')),
        decksProvider.overrideWith(_EmptyDecks.new),
        templateRegistryProvider.overrideWith(
            (ref) async => TemplateRegistry.single(softwareInterviewsTemplate)),
      ],
      child: const MaterialApp(home: BrowseScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'is:due');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save as deck'));
    await tester.pumpAndSettle();

    // is:due strips to Everything == the whole-vault active deck → warn, no clone.
    expect(find.textContaining('whole vault'), findsOneWidget);
  });

  // The second no-op branch: the active deck is NOT the whole vault, and the
  // filter adds nothing structural, so the composed lens equals the deck's own
  // lens — a clone. The note distinguishes this from the whole-vault case.
  testWidgets('Save as deck warns it just re-creates a non-vault deck',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vaultIndexProvider.overrideWith((ref) async => index),
        srsStatesProvider.overrideWith((ref) async => const SectionStates({})),
        activeDeckProvider.overrideWith((ref) async => Deck(
            id: 'algo',
            name: 'Algo',
            templateId: 't',
            membership: TagIs('ds-a'))),
        decksProvider.overrideWith(_EmptyDecks.new),
        templateRegistryProvider.overrideWith(
            (ref) async => TemplateRegistry.single(softwareInterviewsTemplate)),
      ],
      child: const MaterialApp(home: BrowseScreen()),
    ));
    await tester.pumpAndSettle();

    // is:due strips to nothing → composed lens == the ds-a deck's lens (a clone).
    await tester.enterText(find.byType(TextField), 'is:due');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save as deck'));
    await tester.pumpAndSettle();

    expect(find.textContaining('re-creates the current deck'), findsOneWidget);
    expect(find.textContaining('whole vault'), findsNothing);
  });

  // The non-no-op branch WITH free text: a real structural filter is added (so it
  // isn't a clone), but the ranked free-text term can't live in a lens — the note
  // says so rather than silently dropping it.
  testWidgets('Save as deck notes that free text is not saved', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vaultIndexProvider.overrideWith((ref) async => index),
        srsStatesProvider.overrideWith((ref) async => const SectionStates({})),
        activeDeckProvider.overrideWith((ref) async =>
            const Deck(id: 'default', name: 'All', templateId: 't')),
        decksProvider.overrideWith(_EmptyDecks.new),
        templateRegistryProvider.overrideWith(
            (ref) async => TemplateRegistry.single(softwareInterviewsTemplate)),
      ],
      child: const MaterialApp(home: BrowseScreen()),
    ));
    await tester.pumpAndSettle();

    // type:flashcard = a real structural filter; "dijkstra" = ranked free text.
    await tester.enterText(find.byType(TextField), 'type:flashcard dijkstra');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save as deck'));
    await tester.pumpAndSettle();

    // Assert on note-unique text ("dijkstra" alone also matches the search field).
    expect(find.textContaining("text search \"dijkstra\" isn't saved"),
        findsOneWidget);
    expect(find.textContaining('whole vault'), findsNothing);
  });
}
