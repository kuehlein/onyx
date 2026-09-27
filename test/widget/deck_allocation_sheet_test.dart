import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/deck_template.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/features/home/deck_allocation_sheet.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/template.dart';

/// Widget-level cover for the cross-deck allocation view (#137 slice 3b / ADR-0018):
/// it *reads out* the engine-derived split (minutes + deadline, never a % input), a
/// tier tap flows straight to `Deck.priority`, and it **warns on too-little-time**
/// two ways (deck_selection.md). The allocation math itself lives in budget_test.dart.

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

/// A minimal template with **no flows** → no long practice sessions, so the
/// long-session warning stays off unless a test opts into a real (SWE) template.
const _noFlowTemplate = DeckTemplate(
  id: 'demo',
  target: TargetSpec(
    levels: [
      LevelValue(id: 'l', label: 'L', tierCurve: [1.0])
    ],
    contexts: [ContextValue(id: 'c', label: 'C', stabilityTargetDays: 30)],
    tracks: [TrackValue(id: 't', label: 'T')],
    families: [],
    fallbackLevelId: 'l',
    fallbackContextId: 'c',
    fallbackTrackId: 't',
  ),
);

Future<void> _open(
  WidgetTester tester, {
  required _CapturingDecks decks,
  required Map<String, double> budgets,
  double budget = 60.0,
  DeckTemplate template = _noFlowTemplate,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      decksProvider.overrideWith(() => decks),
      deckBudgetsProvider.overrideWith((ref) async => budgets),
      dailyBudgetMinutesProvider.overrideWith((ref) async => budget),
      clockProvider.overrideWith((ref) async => Clock.real),
      templateRegistryProvider
          .overrideWith((ref) async => TemplateRegistry.single(template)),
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

    // A comfortable 60-min day over 2 decks isn't over-subscribed, and a no-flow
    // template has no long sessions → no warnings.
    expect(find.textContaining('raise your daily budget'), findsNothing);
    expect(find.textContaining("won't fit"), findsNothing);
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

  testWidgets('warns once when the day can\'t cover every deck at the floor',
      (tester) async {
    final decks = _CapturingDecks([
      const Deck(id: 'latin', name: 'Latin', templateId: 't'),
      const Deck(id: 'chem', name: 'Chemistry', templateId: 't'),
    ]);

    // A 20-min day can't give 2 decks even the ~15-min floor each → over-subscribed.
    await _open(tester,
        decks: decks, budget: 20, budgets: {'latin': 10, 'chem': 10});

    expect(find.textContaining('raise your daily budget'), findsOneWidget);
  });

  testWidgets('warns per-deck when a long practice session can\'t fit',
      (tester) async {
    final id = softwareInterviewsTemplate.id;
    final decks = _CapturingDecks([
      Deck(id: 'sd', name: 'System Design', templateId: id),
      Deck(id: 'net', name: 'Networking', templateId: id),
    ]);

    // Not over-subscribed (2×15 < 60). System Design's 18-min slice can't fit a
    // ~40-min mock (warn); Networking's 42-min slice can (no warn).
    await _open(tester,
        decks: decks,
        budget: 60,
        budgets: {'sd': 18, 'net': 42},
        template: softwareInterviewsTemplate);

    expect(find.textContaining("won't fit"), findsOneWidget);
    // The heaviest-flow warning is deck-specific, not the vault over-subscription one.
    expect(find.textContaining('raise your daily budget'), findsNothing);
  });
}
