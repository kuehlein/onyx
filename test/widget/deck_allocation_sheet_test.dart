import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/features/home/deck_allocation_sheet.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/decks.dart';

/// Widget-level cover for the cross-deck allocation view (#137 slice 3b / ADR-0018):
/// it *reads out* the engine-derived split (minutes + deadline, never a % input) and
/// a tier tap flows straight to `Deck.priority`. The allocation math itself lives in
/// budget_test.dart; here we prove the sheet renders the split and wires the picker.

/// A decks notifier that serves a fixed list and records every [upsert] — so a tier
/// tap can be asserted without a real store / DB.
class _CapturingDecks extends Decks {
  _CapturingDecks(this._seed);
  final List<Deck> _seed;
  final List<Deck> upserts = [];
  @override
  Future<List<Deck>> build() async => _seed;
  @override
  Future<void> upsert(Deck goal) async => upserts.add(goal);
}

Future<void> _open(
  WidgetTester tester, {
  required _CapturingDecks decks,
  required Map<String, double> budgets,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      decksProvider.overrideWith(() => decks),
      deckBudgetsProvider.overrideWith((ref) async => budgets),
      dailyBudgetMinutesProvider.overrideWith((ref) async => 60.0),
      clockProvider.overrideWith((ref) async => Clock.real),
    ],
    child: MaterialApp(
      theme: OnyxTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showDeckAllocationSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  // Dates are relative to the same clock the sheet reads, so the "Nd left" caption
  // is deterministic regardless of the real wall-clock date.
  final today = Clock.real.today();

  testWidgets('reads out the split: minutes, proportion, deadline, tiers',
      (tester) async {
    final decks = _CapturingDecks([
      Deck(
        id: 'latin',
        name: 'Latin',
        templateId: 't',
        aims: [
          Aim(id: 'exam', rounds: [
            InterviewRound(
                id: 'r', number: 1, date: today.add(const Duration(days: 5))),
          ]),
        ],
      ),
      const Deck(id: 'chem', name: 'Chemistry', templateId: 't'),
    ]);

    await _open(tester, decks: decks, budgets: {'latin': 40, 'chem': 20});

    // Both decks, each with its engine-derived minutes (an OUTPUT, not an input).
    expect(find.text('Latin'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);
    expect(find.text('~40 min/day'), findsOneWidget);
    expect(find.text('~20 min/day'), findsOneWidget);

    // The deadline caption explains why a deck earns its share (Latin's aim is due).
    expect(find.text('soonest deadline · 5d left'), findsOneWidget);

    // A tier picker per deck (four coarse ranks each).
    expect(find.text('Highest'), findsNWidgets(2));
    expect(find.text('Low'), findsNWidgets(2));
  });

  testWidgets('a tier tap sets that deck\'s priority', (tester) async {
    final decks = _CapturingDecks([
      const Deck(id: 'latin', name: 'Latin', templateId: 't'),
      const Deck(id: 'chem', name: 'Chemistry', templateId: 't'),
    ]);

    // Latin gets the larger share, so its row sorts first.
    await _open(tester, decks: decks, budgets: {'latin': 45, 'chem': 15});

    // Tap "Highest" on the first row (Latin).
    await tester.tap(find.text('Highest').first);
    await tester.pumpAndSettle();

    expect(decks.upserts, hasLength(1));
    expect(decks.upserts.single.id, 'latin');
    expect(decks.upserts.single.priority, PriorityTier.highest);
  });
}
