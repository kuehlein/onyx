import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/features/home/target_sheet.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/template.dart';
import 'package:onyx/shared/providers/vault.dart';

/// A decks notifier that records the writer path the aim editor takes — proving
/// Save flips to [upsertAim] (the aim) and never touches [upsert] (the old
/// deck-slot writer).
class _RecordingDecks extends Decks {
  _RecordingDecks(this._deck);
  final Deck _deck;
  String? upsertedDeckId;
  Aim? upsertedAim;
  Deck?
      upsertedDeck; // the deck-slot writer — must stay unused (S5e writer flip)

  @override
  Future<List<Deck>> build() async => [_deck];

  @override
  Future<void> upsertAim(String deckId, Aim aim) async {
    upsertedDeckId = deckId;
    upsertedAim = aim;
  }

  @override
  Future<void> upsert(Deck goal) async => upsertedDeck = goal;
}

Deck _deckWith(List<Aim> aims) => Deck(
      id: defaultDeckId,
      name: 'default',
      templateId: 'software-interviews',
      aims: aims,
    );

Widget _harness(Deck deck, void Function(_RecordingDecks) capture,
        {String? aimId}) =>
    ProviderScope(
      overrides: [
        decksProvider.overrideWith(() {
          final d = _RecordingDecks(deck);
          capture(d);
          return d;
        }),
        clockProvider.overrideWith((ref) async => Clock.real),
        vaultSourceProvider.overrideWithValue(null),
        // Pin the deck's template to SWE so the axis titles are the familiar
        // Level / Company / Track (a null source alone resolves to neutral).
        activeDeckTemplateProvider
            .overrideWith((ref) async => softwareInterviewsTemplate),
        // The forecast block + calendar zones are heavy; stub them out.
        readinessForecastForProvider.overrideWith((ref, dims) async => null),
      ],
      child: MaterialApp(
        theme: OnyxTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAimEditorSheet(context, aimId: aimId),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

Future<void> _openEditor(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

// The editor sheet is taller than the test viewport; scroll a control into view
// before tapping it.
Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('editing a knob saves the aim via upsertAim, not the deck slots',
      (tester) async {
    late _RecordingDecks rec;
    await tester.pumpWidget(_harness(
        _deckWith([const Aim(id: 'a1')]), (d) => rec = d,
        aimId: 'a1'));
    await _openEditor(tester);

    // SWE keeps its natural axis titles (the Vocabulary override), not the
    // neutral Difficulty / Durability / Emphasis defaults.
    expect(find.text('Level'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('Track'), findsOneWidget);

    await _tap(tester, 'Senior');
    await _tap(tester, 'Save');

    // The writer flip: the knob persists on the AIM (n006 — the deck is a pure
    // lens), and the legacy deck-slot writer is never called.
    expect(rec.upsertedDeckId, defaultDeckId);
    expect(rec.upsertedAim?.id, 'a1');
    expect(rec.upsertedAim?.levelId, 'senior');
    expect(rec.upsertedDeck, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new aim is minted and saved via upsertAim', (tester) async {
    late _RecordingDecks rec;
    // aimId null → the editor creates a fresh aim on the active deck.
    await tester.pumpWidget(_harness(_deckWith(const []), (d) => rec = d));
    await _openEditor(tester);

    await _tap(tester, 'Staff');
    await _tap(tester, 'Save');

    expect(rec.upsertedAim, isNotNull);
    expect(rec.upsertedAim!.id, startsWith('aim-'));
    expect(rec.upsertedAim!.levelId, 'staff');
    expect(rec.upsertedDeck, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing the date keeps a typed round (only clears its date)',
      (tester) async {
    late _RecordingDecks rec;
    final aim = Aim(id: 'a1', rounds: [
      InterviewRound(
          id: 'a1-r1',
          number: 1,
          type: InterviewRoundType.onsite,
          date: DateTime(2099, 6, 1)),
    ]);
    await tester
        .pumpWidget(_harness(_deckWith([aim]), (d) => rec = d, aimId: 'a1'));
    await _openEditor(tester);

    // A set date shows a Clear affordance; clearing must NOT drop the round (it
    // carries the "Onsite" type), only its date — the aim just goes open-ended.
    await _tap(tester, 'Clear');
    await _tap(tester, 'Save');

    final saved = rec.upsertedAim;
    expect(saved, isNotNull);
    expect(saved!.rounds.length, 1);
    expect(saved.rounds.single.type, InterviewRoundType.onsite);
    expect(saved.rounds.single.date, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing the date drops a bare synthetic date-holder round',
      (tester) async {
    late _RecordingDecks rec;
    // Default type (other) + no notes → a bare date-holder, safe to remove so a
    // target with no date carries no phantom round.
    final aim = Aim(id: 'a1', rounds: [
      InterviewRound(id: 'a1-r1', number: 1, date: DateTime(2099, 6, 1)),
    ]);
    await tester
        .pumpWidget(_harness(_deckWith([aim]), (d) => rec = d, aimId: 'a1'));
    await _openEditor(tester);
    await _tap(tester, 'Clear');
    await _tap(tester, 'Save');

    expect(rec.upsertedAim?.rounds, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
