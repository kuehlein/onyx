// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/app.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/interview/transfer.dart';
import 'package:onyx/core/plan/daily_plan.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/today_progress.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/backup.dart';
import 'package:onyx/shared/providers/glossary.dart';
import 'package:onyx/shared/providers/learn.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/analytics.dart';
import 'package:onyx/shared/providers/vault.dart';

CardSection _section(String heading, {bool quizzable = true}) => CardSection(
      heading: heading,
      slug: heading.toLowerCase().replaceAll(' ', '-'),
      content: 'body',
      quizzable: quizzable,
    );

Card _card(String id, String title, {String type = 'flashcard'}) => Card(
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
  // Override the SRS providers so the widget tree never touches a real DB.
  Widget app(IndexResult index) => ProviderScope(
        overrides: [
          // A configured source + a settled load so the first-run gate lets the
          // shell render Home instead of redirecting to /welcome. The index is
          // already stubbed below, so this path never needs to exist.
          vaultSourceProvider
              .overrideWithValue(DesktopVaultSource('/tmp/onyx-test')),
          loadVaultRefProvider.overrideWith((ref) async {}),
          vaultIndexProvider.overrideWith((ref) async => index),
          srsStatesProvider
              .overrideWith((ref) async => const SectionStates({})),
          reviewQueueProvider.overrideWith(
            (ref) async => const ReviewQueueData(queue: [], statesByKey: {}),
          ),
          learnQueueProvider.overrideWith((ref) async => const []),
          dailyPlanProvider.overrideWith((ref) async =>
              const DailyPlan(tracks: [], budgetMinutes: 90, locked: [])),
          clockProvider.overrideWith((ref) async => Clock.real),
          todayProgressProvider.overrideWith((ref) async =>
              const TodayProgress(doneMinutes: 0, remainingMinutes: 0)),
          startupRestoreProvider.overrideWith((ref) async {}),
          glossaryProvider.overrideWith((ref) async => const {}),
          // Serve a fixed active target so the readiness panel renders without
          // reaching the preferences DB / vault in widget tests.
          activeTargetProvider
              .overrideWith((ref) async => ReadinessTarget.fallback),
          studyConsistencyProvider.overrideWith((ref) async => const <int>[]),
          appliedTransferProvider.overrideWith((ref) async =>
              (byDomain: <String, TransferEstimate>{}, interview: false)),
          appliedSummaryProvider.overrideWith(
              (ref) async => <String, ({int attempts, int contested})>{}),
        ],
        child: const OnyxApp(),
      );

  final populated = IndexResult(
    cards: [
      _card('11111111-1111-4111-8111-111111111111', 'Binary Search'),
      _card('22222222-2222-4222-8222-222222222222', 'Two Pointers',
          type: 'interview-question'),
    ],
    idless: 0,
    malformed: 0,
    skipped: 0,
  );

  testWidgets('shell renders the four bottom-nav destinations', (tester) async {
    await tester.pumpWidget(app(populated));
    await tester.pumpAndSettle();

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
