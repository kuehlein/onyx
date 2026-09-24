import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/features/home/deck_settings_sheet.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/template.dart';
import 'package:onyx/shared/providers/vault.dart';

/// A decks notifier pinned to a fixed list (no DB); the active deck derives from it.
class _FixedDecks extends Decks {
  _FixedDecks(this._decks);
  final List<Deck> _decks;
  @override
  Future<List<Deck>> build() async => _decks;
}

Widget _app({required List<Deck> decks, required double budget}) =>
    ProviderScope(
      overrides: [
        decksProvider.overrideWith(() => _FixedDecks(decks)),
        vaultSourceProvider.overrideWithValue(null),
        dailyBudgetMinutesProvider.overrideWith((ref) async => budget),
        // SWE declares a system-design flow (a ~40-min session) → hasLongSessions.
        activeDeckTemplateProvider
            .overrideWith((ref) async => softwareInterviewsTemplate),
      ],
      child: MaterialApp(
        theme: OnyxTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDeckSettingsSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'deck settings warns when a deck gets too little time for a session',
      (tester) async {
    // One deck, a 30-min budget → the whole budget is 30 min, under the 40-min
    // system-design session → the too-little-time warning (deck_selection.md).
    await tester.pumpWidget(_app(
      decks: const [Deck(id: 'default', name: 'CS', templateId: 'swe')],
      budget: 30,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('This deck only'), findsOneWidget);
    expect(find.textContaining("won't fit"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a comfortable budget shows no warning', (tester) async {
    await tester.pumpWidget(_app(
      decks: const [Deck(id: 'default', name: 'CS', templateId: 'swe')],
      budget: 120,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('This deck only'), findsOneWidget);
    expect(find.textContaining("won't fit"), findsNothing);
    expect(find.textContaining('very little'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
