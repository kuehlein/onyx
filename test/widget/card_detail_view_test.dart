import 'package:drift/native.dart';
// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/theme.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/features/browse/card_detail_screen.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/settings.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/vault.dart';
import 'package:onyx/shared/widgets/card_section_panel.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'support/harness.dart';

/// S1 baseline (ADR-0012 / task 1f): pins the card VIEW's rendering contract as
/// it's rebuilt onto the shared component layer (CardMetaChip / CardSectionPanel /
/// CardLinks) — the config-driven flow label, the section panels + study-unit
/// indicator, and the expand-default policy — so the lift stays byte-identical.

final bool _sqlite = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

/// Forces the mastered-collapse off-switch off (the legacy due-date proxy).
class _MasteredOff extends MasteredCollapse {
  @override
  Future<bool> build() async => false;
}

/// A card with one mastered section (Alpha) and one due section (Beta).
Card _masteryCard() => testCard('M1', 'Mastery', sections: const [
      CardSection(
          heading: 'Alpha', slug: 'alpha', content: 'a', quizzable: true),
      CardSection(heading: 'Beta', slug: 'beta', content: 'b', quizzable: true),
    ]);

SectionStates _masteryStates() {
  final now = DateTime.now();
  SrsState st(String slug, {required Duration due, required Duration since}) =>
      SrsState(
        cardId: 'M1',
        sectionSlug: slug,
        stability: 40, // ≥ 21d spacing floor
        difficulty: 5,
        state: 2, // review
        dueAt: now.add(due),
        lastReview: now.subtract(since),
        reviewCount: 3,
      );
  return SectionStates({
    // Spaced, retained, not due → mastered.
    'M1::alpha': st('alpha',
        due: const Duration(days: 30), since: const Duration(days: 10)),
    // Overdue → never mastered (must stay shown).
    'M1::beta': st('beta',
        due: const Duration(days: -1), since: const Duration(days: 45)),
  });
}

Future<void> _pumpMastery(WidgetTester tester,
    {bool masteredOff = false}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase.withExecutor(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      vaultIndexProvider
          .overrideWith((ref) async => testIndex([_masteryCard()])),
      srsStatesProvider.overrideWith((ref) async => _masteryStates()),
      if (masteredOff) masteredCollapseProvider.overrideWith(_MasteredOff.new),
    ],
    child: MaterialApp(
        theme: OnyxTheme.dark(), home: const CardDetailScreen(cardId: 'M1')),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('VIEW: flow label + tier chip + section panels + expand policy',
      (tester) async {
    if (!_sqlite) return;
    final card = testCard('C1', 'Two Sum', sections: const [
      // Quizzable + unstudied → expands by default, shows the study-unit indicator.
      CardSection(
          heading: 'When to Use', slug: 'when', content: 'x', quizzable: true),
      // Non-quizzable supplementary → collapses, no indicator.
      CardSection(
          heading: 'Resources',
          slug: 'resources',
          content: 'y',
          quizzable: false),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase.withExecutor(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        vaultIndexProvider.overrideWith((ref) async => testIndex([card])),
        srsStatesProvider.overrideWith((ref) async => const SectionStates({})),
      ],
      child: MaterialApp(
          theme: OnyxTheme.dark(), home: const CardDetailScreen(cardId: 'C1')),
    ));
    await tester.pumpAndSettle();

    // The type chip is config-driven (byte-identical to the old hardcoded
    // 'Flashcard'), resolved from the flow — not a `card.type ==` branch.
    expect(find.text('Flashcard'), findsOneWidget);
    expect(find.text('ds-a · T2'), findsOneWidget); // tier chip

    // One section panel per section; both headings render.
    final panels =
        tester.widgetList<CardSectionPanel>(find.byType(CardSectionPanel));
    expect(panels.length, 2);
    expect(find.text('When to Use'), findsOneWidget);
    expect(find.text('Resources'), findsOneWidget);

    // The study-unit indicator marks the quizzable section only.
    expect(find.byTooltip('Scheduled for review'), findsOneWidget);

    // Expand-default policy: quizzable-unstudied opens; supplementary collapses.
    CardSectionPanel panel(String heading) =>
        panels.firstWhere((p) => p.section.heading == heading);
    expect(panel('When to Use').initiallyExpanded, isTrue);
    expect(panel('Resources').initiallyExpanded, isFalse);
  });

  // Before/after for the mastered auto-collapse (ADR-0012 #6, 1f.1).
  testWidgets('ON: mastered section collapses with a badge; due stays expanded',
      (tester) async {
    if (!_sqlite) return;
    await _pumpMastery(tester);
    final panels =
        tester.widgetList<CardSectionPanel>(find.byType(CardSectionPanel));
    CardSectionPanel panel(String h) =>
        panels.firstWhere((p) => p.section.heading == h);

    // Exactly the mastered section carries the badge + folds; the due one shows.
    expect(find.text('Mastered'), findsOneWidget);
    expect(panel('Alpha').mastered, isTrue);
    expect(panel('Alpha').initiallyExpanded, isFalse);
    expect(panel('Beta').mastered, isFalse);
    expect(panel('Beta').initiallyExpanded, isTrue);
  });

  testWidgets('OFF: legacy due-date proxy — no badge, not-due collapses',
      (tester) async {
    if (!_sqlite) return;
    await _pumpMastery(tester, masteredOff: true);
    final panels =
        tester.widgetList<CardSectionPanel>(find.byType(CardSectionPanel));
    CardSectionPanel panel(String h) =>
        panels.firstWhere((p) => p.section.heading == h);

    expect(find.text('Mastered'), findsNothing);
    expect(panel('Alpha').mastered, isFalse);
    expect(panel('Alpha').initiallyExpanded, isFalse); // not due → collapsed
    expect(panel('Beta').initiallyExpanded, isTrue); // due → expanded
  });
}
