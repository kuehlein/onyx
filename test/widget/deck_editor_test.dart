// Material's Card widget collides with the domain Card model used to build a test
// vault index; we don't use the widget here, so hide it.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/search/card_filter.dart' show renderLens;
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/core/vault/vault_indexer.dart' show IndexResult;
import 'package:onyx/features/home/deck_editor_sheet.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/template.dart';
import 'package:onyx/shared/providers/vault.dart';

Card _card(String id,
        {required String folder,
        required List<String> tags,
        bool draft = false}) =>
    Card(
      id: id,
      type: 'flashcard',
      title: id,
      overview: '',
      tags: tags,
      tiers: const {},
      sections: const [
        CardSection(heading: 'H', slug: 'h', content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$folder/$id.md',
      status: draft ? CardStatus.draft : CardStatus.active,
    );

class _CapturingGoals extends Decks {
  _CapturingGoals([this._initial = const []]);
  final List<Deck> _initial;
  Deck? upserted;
  @override
  Future<List<Deck>> build() async => _initial;
  @override
  Future<void> upsert(Deck goal) async => upserted = goal;
}

Future<void> _open(
  WidgetTester tester,
  _CapturingGoals cap,
  void Function(BuildContext) onOpen, {
  IndexResult? index,
}) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          decksProvider.overrideWith(() => cap),
          templateRegistryProvider.overrideWith((ref) async =>
              TemplateRegistry.single(softwareInterviewsTemplate)),
          if (index != null)
            vaultIndexProvider.overrideWith((ref) async => index),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => onOpen(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('creating a goal from the editor upserts it', (tester) async {
    final cap = _CapturingGoals();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decksProvider.overrideWith(() => cap),
          templateRegistryProvider.overrideWith((ref) async =>
              TemplateRegistry.single(softwareInterviewsTemplate)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDeckEditor(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Create is disabled until the goal has a name.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).first, 'Korean');
    await tester.pump();

    // Scope to a tag lens.
    await tester.tap(find.text('Tag'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'korean');
    await tester.pump();

    await tester.tap(find.text('Create deck'));
    await tester.pumpAndSettle();

    expect(cap.upserted, isNotNull);
    expect(cap.upserted!.name, 'Korean');
    expect(cap.upserted!.id, 'korean');
    expect(cap.upserted!.membership, isA<TagIs>());
  });

  testWidgets('editing a deck preserves its aims + knobs (no data loss)',
      (tester) async {
    final cap = _CapturingGoals();
    const existing = Deck(
      id: 'd',
      name: 'Old name',
      templateId: 'software-interviews',
      // Post-S5 the target knobs live on the aim, not deck slots.
      aims: [
        Aim(
            id: 'a1',
            companyName: 'Google',
            levelId: 'senior',
            contextId: 'faang',
            trackId: 'backend')
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          decksProvider.overrideWith(() => cap),
          templateRegistryProvider.overrideWith((ref) async =>
              TemplateRegistry.single(softwareInterviewsTemplate)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDeckEditor(ctx, goal: existing),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'New name');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = cap.upserted!;
    expect(saved.id, 'd'); // same deck
    expect(saved.name, 'New name'); // edit applied
    // The bug rebuilt Deck() from scratch, wiping the aims (which now carry the
    // target knobs):
    final a1 = saved.aims.single;
    expect(a1.id, 'a1');
    expect(
        [a1.levelId, a1.contextId, a1.trackId], ['senior', 'faang', 'backend']);
  });

  testWidgets(
      'a complex initialMembership opens Advanced, pre-filled + saves it',
      (tester) async {
    final cap = _CapturingGoals();
    final membership = And([TagIs('korean'), const TypeIs('flashcard')]);
    await _open(tester, cap,
        (ctx) => showDeckEditor(ctx, initialMembership: membership));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The lens the radio can't express opens in the Advanced text field, filled
    // with its rendered query (name field is .first, the Query field is .last).
    final advanced = tester.widget<TextField>(find.byType(TextField).last);
    expect(advanced.controller!.text, 'tags:korean type:flashcard');

    await tester.enterText(find.byType(TextField).first, 'Korean flashcards');
    await tester.pump();
    await tester.tap(find.text('Create deck'));
    await tester.pumpAndSettle();

    // Round-trips through parseLens on save (structurally identical).
    expect(cap.upserted, isNotNull);
    expect(renderLens(cap.upserted!.membership), 'tags:korean type:flashcard');
  });

  testWidgets('a StateIs in the lens is stripped on save (structural only)',
      (tester) async {
    final cap = _CapturingGoals();
    // A dynamic study-state leaf must never persist — Deck.select has no context.
    const membership = And([TypeIs('flashcard'), StateIs(MasteryFilter.due)]);
    await _open(tester, cap,
        (ctx) => showDeckEditor(ctx, initialMembership: membership));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'X');
    await tester.pump();
    await tester.tap(find.text('Create deck'));
    await tester.pumpAndSettle();

    // And([TypeIs, StateIs]) → TypeIs (the dynamic conjunct dropped).
    expect(cap.upserted!.membership, isA<TypeIs>());
  });

  testWidgets('a colliding deck-name slug auto-suffixes the id',
      (tester) async {
    final cap = _CapturingGoals(
        [const Deck(id: 'korean', name: 'Korean', templateId: 's')]);
    await _open(tester, cap, (ctx) => showDeckEditor(ctx));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Korean');
    await tester.pump();
    await tester.tap(find.text('Create deck'));
    await tester.pumpAndSettle();

    // `upsert` keys by id — a second "korean" must not overwrite the first.
    expect(cap.upserted!.id, 'korean-2');
  });

  testWidgets('the lens preview shows a live count + tap-to-add suggestions',
      (tester) async {
    final cap = _CapturingGoals();
    final index = IndexResult(
      cards: [
        _card('a', folder: 'korean', tags: ['vocab']),
        _card('b', folder: 'korean', tags: ['vocab', 'grammar']),
        _card('c', folder: 'spanish', tags: ['vocab']),
        _card('d', folder: 'korean', tags: ['vocab'], draft: true),
      ],
      idless: 0,
      malformed: 0,
      skipped: 0,
    );
    await _open(tester, cap, (ctx) => showDeckEditor(ctx), index: index);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Whole vault: 3 study cards match; the 1 draft is surfaced separately.
    expect(find.textContaining('3 of 3 cards'), findsOneWidget);
    expect(find.textContaining('+1 draft'), findsOneWidget);
    // Suggestions from vault commonalities (folder + tag), with counts.
    expect(find.textContaining('#vocab'), findsOneWidget);
    expect(find.textContaining('korean/'), findsOneWidget);

    // Tapping a folder suggestion narrows the lens (and its live count).
    await tester.tap(find.textContaining('korean/'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 of 3 cards'), findsOneWidget);
  });
}
