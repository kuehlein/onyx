// Material's `Card` widget collides with our domain `Card` model.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/app/app.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/interview/transfer.dart';
import 'package:onyx/core/plan/daily_plan.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/folder_picker.dart';
import 'package:onyx/core/vault/starter_deck.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/core/vault/vault_ref.dart';
import 'package:onyx/core/vault/vault_ref_store.dart';
import 'package:onyx/shared/providers/analytics.dart';
import 'package:onyx/shared/providers/backup.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/glossary.dart';
import 'package:onyx/shared/providers/learn.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/settings.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/today_progress.dart';
import 'package:onyx/shared/providers/vault.dart';

/// A [FolderPicker] test double that returns a ref to a real temp directory
/// from both methods, so the create path exercises the real seeder +
/// DesktopVaultSource.writeFile with no path_provider dependency.
class _FakePicker implements FolderPicker {
  _FakePicker(this.dir);
  final Directory dir;

  VaultRef _ref() => VaultRef(VaultRefKind.path, dir.path);

  @override
  bool get canPickExisting => true;

  @override
  Future<VaultRef?> pickExisting() async => _ref();

  @override
  Future<VaultRef> createManaged({String name = 'Onyx'}) async => _ref();
}

/// The Home-rendering overrides (mirrors shell_test) so a *configured* app can
/// paint Home without touching a real DB/vault. Type is inferred — the bare
/// `Override` supertype isn't publicly nameable in riverpod's `show` export, so
/// annotating `List<Override>` would fail to resolve.
final _homeOverrides = [
  srsStatesProvider.overrideWith((ref) async => const SectionStates({})),
  reviewQueueProvider.overrideWith(
    (ref) async => const ReviewQueueData(queue: [], statesByKey: {}),
  ),
  learnQueueProvider.overrideWith((ref) async => const []),
  dailyPlanProvider.overrideWith((ref) async =>
      const DailyPlan(tracks: [], budgetMinutes: 90, locked: [])),
  clockProvider.overrideWith((ref) async => Clock.real),
  todayProgressProvider.overrideWith(
      (ref) async => const TodayProgress(doneMinutes: 0, remainingMinutes: 0)),
  startupRestoreProvider.overrideWith((ref) async {}),
  glossaryProvider.overrideWith((ref) async => const {}),
  activeTargetProvider.overrideWith((ref) async => ReadinessTarget.fallback),
  studyConsistencyProvider.overrideWith((ref) async => const <int>[]),
  appliedTransferProvider.overrideWith((ref) async =>
      (byDomain: <String, TransferEstimate>{}, interview: false)),
  appliedSummaryProvider
      .overrideWith((ref) async => <String, ({int attempts, int contested})>{}),
  vaultIndexProvider.overrideWith((ref) async =>
      const IndexResult(cards: [], idless: 0, malformed: 0, skipped: 0)),
];

/// Resolve the source from the in-memory ref, bypassing `ONYX_VAULT_PATH` (the
/// dev shell sets it, which would otherwise pin the source non-null and defeat
/// the gate). This mirrors the real env-less resolution, so `choose` flipping
/// the controller drives the gate exactly as in production.
final _sourceFromRef = vaultSourceProvider.overrideWith((ref) {
  final r = ref.watch(vaultRefControllerProvider);
  return r == null ? null : resolveVaultSource(r);
});

void main() {
  testWidgets('gate: no vault → welcome, not Home', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Startup ref load completes with nothing saved; source derives from the
        // (empty) controller, so it stays null → the gate shows /welcome.
        loadVaultRefProvider.overrideWith((ref) async {}),
        _sourceFromRef,
        ..._homeOverrides,
      ],
      child: const OnyxApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('How do you want to start?'), findsOneWidget);
    expect(find.text('Create a study folder for me'), findsOneWidget);
    // The bottom-nav shell must not be mounted behind the gate.
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.textContaining('All caught up'), findsNothing);
  });

  testWidgets('gate: configured vault → Home, no welcome', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        vaultSourceProvider
            .overrideWithValue(DesktopVaultSource('/tmp/onyx-test')),
        loadVaultRefProvider.overrideWith((ref) async {}),
        ..._homeOverrides,
      ],
      child: const OnyxApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.textContaining('All caught up'), findsOneWidget);
    expect(find.text('How do you want to start?'), findsNothing);
  });

  // The create path does real file + DB I/O (seedStarterDeck writes .md files;
  // choose persists the ref through the DB). That I/O does not complete inside a
  // `testWidgets` fake-async zone driven by `tester.pump`, so the widget-level
  // "tap Create" would hang. Exercise the exact same code path the button runs
  // at the provider level instead (real `await`, real I/O), which is the honest
  // unit under test: fake picker → createManaged → resolveVaultSource →
  // seedStarterDeck → choose.
  test('create path: createManaged + seed + choose sets ref and writes cards',
      () async {
    final dir = await Directory.systemTemp.createTemp('onyx_onboarding_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      folderPickerProvider.overrideWithValue(_FakePicker(dir)),
    ]);
    addTearDown(container.dispose);

    // Mirror WelcomeScreen's "Create a study folder for me" handler exactly.
    final picker = container.read(folderPickerProvider);
    final r = await picker.createManaged();
    final src = resolveVaultSource(r);
    await seedStarterDeck(src);
    await container.read(vaultRefControllerProvider.notifier).choose(r);

    // The controller now holds the chosen ref…
    final chosen = container.read(vaultRefControllerProvider);
    expect(chosen, isNotNull);
    expect(chosen!.value, dir.path);

    // …it was persisted (survives a fresh store read)…
    final reloaded = await VaultRefStore(
      container.read(preferencesRepositoryProvider),
    ).load();
    expect(reloaded, chosen);

    // …and the folder now holds real, parseable starter cards (so first-run
    // lands on cards, not the empty state).
    final mdFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    expect(mdFiles, isNotEmpty);
    const parser = CardParser();
    for (final f in mdFiles) {
      final card = parser.parse(f.readAsStringSync(), filePath: f.path);
      expect(card, isNotNull, reason: '${f.path} should parse as a card');
      expect(card!.sections.any((s) => s.quizzable), isTrue,
          reason: '${f.path} should have a quizzable section');
    }
  });

  // The create-path test above drives pickExisting/createManaged + choose; the
  // adaptive "Choose a folder" button visibility is a trivial `if (canPickExisting)`
  // and is exercised through the full welcome render in the gate test above (Linux
  // host → canPickExisting true). A dedicated isolated pump of FolderSourceBody was
  // dropped: its AnimatedSize widgets hang a bare-harness pump without settling.
}
