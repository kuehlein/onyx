// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onyx/app/app.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/interview/transfer.dart';
import 'package:onyx/core/plan/daily_plan.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/analytics.dart';
import 'package:onyx/shared/providers/backup.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/glossary.dart';
import 'package:onyx/shared/providers/learn.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/today_progress.dart';
import 'package:onyx/shared/providers/vault.dart';

/// Shared widget-test harness (task #51 tail). Consolidates the Card factories
/// and the ~15-provider override block that screen tests used to hand-roll: the
/// overrides keep the tree off a real DB/vault and satisfy the first-run gate so
/// [OnyxApp] renders Home instead of redirecting to /welcome.
///
/// NB: the override list is built inline (its type is inferred) — riverpod's
/// bare `Override` supertype isn't in the public `show` export, so it can't be
/// named in a return type or parameter (see onboarding_test.dart's note).

/// A quizzable (by default) [CardSection] with a slug derived from [heading].
CardSection testSection(String heading, {bool quizzable = true}) => CardSection(
      heading: heading,
      slug: heading.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      content: 'body',
      quizzable: quizzable,
    );

/// A minimal valid [Card] for widget tests (one "When to Use" section).
Card testCard(
  String id,
  String title, {
  String type = 'flashcard',
  List<String> tags = const ['ds-a'],
  Map<String, int> tiers = const {'ds-a': 2},
  List<CardSection>? sections,
}) =>
    Card(
      id: id,
      type: type,
      title: title,
      overview: 'overview',
      tags: tags,
      tiers: tiers,
      sections: sections ?? [testSection('When to Use')],
      wikilinks: const [],
      filePath: '$title.md',
    );

/// An [IndexResult] wrapping [cards] with zero error buckets.
IndexResult testIndex(List<Card> cards) =>
    IndexResult(cards: cards, idless: 0, malformed: 0, skipped: 0);

/// Pumps the full [OnyxApp] off a real DB/vault and past the /welcome gate, then
/// settles. Every async provider has a calm default; pass the few a test varies.
/// Use for shell / navigation / Home tests.
Future<void> pumpApp(
  WidgetTester tester, {
  IndexResult? index,
  SectionStates? states,
  ReviewQueueData? reviewQueue,
  DailyPlan? plan,
  ReadinessTarget? target,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      vaultSourceProvider
          .overrideWithValue(DesktopVaultSource('/tmp/onyx-test')),
      loadVaultRefProvider.overrideWith((ref) async {}),
      vaultIndexProvider
          .overrideWith((ref) async => index ?? testIndex(const [])),
      srsStatesProvider
          .overrideWith((ref) async => states ?? const SectionStates({})),
      reviewQueueProvider.overrideWith((ref) async =>
          reviewQueue ?? const ReviewQueueData(queue: [], statesByKey: {})),
      learnQueueProvider.overrideWith((ref) async => const []),
      dailyPlanProvider.overrideWith((ref) async =>
          plan ?? const DailyPlan(tracks: [], budgetMinutes: 90, locked: [])),
      clockProvider.overrideWith((ref) async => Clock.real),
      todayProgressProvider.overrideWith((ref) async =>
          const TodayProgress(doneMinutes: 0, remainingMinutes: 0)),
      startupRestoreProvider.overrideWith((ref) async {}),
      glossaryProvider.overrideWith((ref) async => const {}),
      activeTargetProvider
          .overrideWith((ref) async => target ?? ReadinessTarget.fallback),
      studyConsistencyProvider.overrideWith((ref) async => const <int>[]),
      appliedTransferProvider.overrideWith((ref) async =>
          (byDomain: <String, TransferEstimate>{}, interview: false)),
      appliedSummaryProvider.overrideWith(
          (ref) async => <String, ({int attempts, int contested})>{}),
    ],
    child: const OnyxApp(),
  ));
  await tester.pumpAndSettle();
}

/// Pumps a single [screen] inside the app theme (which registers OnyxColors /
/// OnyxTokens — StatusPill and friends read them) plus a bare [ProviderScope].
/// Use for single-screen / sheet tests that don't need provider overrides; a
/// test that does can wrap its own ProviderScope.
Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(theme: OnyxTheme.dark(), home: screen),
  ));
  await tester.pump();
}
