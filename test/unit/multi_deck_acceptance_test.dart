import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/analytics.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/vault.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

String _card(String id, String domain) => '''
---
id: $id
type: flashcard
tags: [$domain]
---

# $id

## Definition

Body.
''';

/// Await a fire-and-forget side effect: poll [file] until it exists (bounded), so
/// a test can observe the B5 migration write-through (an `unawaited` save) without
/// racing it or teardown. Returns once present; throws on timeout.
Future<void> _awaitFile(File file,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!file.existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for ${file.path}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// End-to-end (#30d G7): two query-defined goals over one vault, exercised through
/// the real providers — discovery, per-goal readiness scoping, the shared-budget
/// split, pause→redistribute, and degradation back to a single goal.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('onyx_multigoal_');
    File(p.join(root.path, 'alpha', 'a1.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync(_card('a1', 'algebra'));
    File(p.join(root.path, 'alpha', 'a2.md'))
        .writeAsStringSync(_card('a2', 'algebra'));
    File(p.join(root.path, 'beta', 'b1.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync(_card('b1', 'biology'));
    // Two stored goals: folder lenses over the same vault, weighted 3:1.
    File(p.join(root.path, '_meta', 'study-goals.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
[
  {"id":"alpha","name":"Alpha","templateId":"software-interviews",
   "membership":{"kind":"folder","value":"alpha"},"budgetWeight":3.0,"state":"active"},
  {"id":"beta","name":"Beta","templateId":"software-interviews",
   "membership":{"kind":"folder","value":"beta"},"budgetWeight":1.0,"state":"active"}
]
''');
  });

  tearDown(() => root.deleteSync(recursive: true));

  ProviderContainer make() => ProviderContainer(overrides: [
        vaultSourceProvider.overrideWithValue(DesktopVaultSource(root.path)),
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase.withExecutor(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
      ]);

  test('discovery + per-goal readiness scoping + budget split', () async {
    if (!_sqliteAvailable) return;
    final c = make();
    addTearDown(c.dispose);
    // Keep the readiness subtree mounted (as a mounted UI would) so its async
    // deps don't autodispose between one-shot reads.
    c.listen(deckReadinessProvider('alpha'), (_, __) {});
    c.listen(deckReadinessProvider('beta'), (_, __) {});

    // Discovery: the two stored goals replace the whole-vault default.
    final goals = await c.read(decksProvider.future);
    expect(goals.map((g) => g.id).toSet(), {'alpha', 'beta'});

    // Per-goal readiness is scoped to each lens's cards (different domains).
    final rAlpha = await c.read(deckReadinessProvider('alpha').future);
    final rBeta = await c.read(deckReadinessProvider('beta').future);
    expect(rAlpha.domains.map((d) => d.domain), ['algebra']);
    expect(rBeta.domains.map((d) => d.domain), ['biology']);

    // Shared budget splits 3:1 by weight; both active goals get a slice.
    final budgets = await c.read(deckBudgetsProvider.future);
    expect(budgets.keys.toSet(), {'alpha', 'beta'});
    expect(budgets['alpha']! / budgets['beta']!, closeTo(3.0, 1e-9));
  });

  test('per-goal analytics scope to the goal\'s member cards (#30d honesty)',
      () async {
    if (!_sqliteAvailable) return;
    final c = make();
    addTearDown(c.dispose);

    // Membership is the one scoping key every per-goal analytic filters by.
    expect(
        await c.read(deckMemberCardIdsProvider('alpha').future), {'a1', 'a2'});
    expect(await c.read(deckMemberCardIdsProvider('beta').future), {'b1'});

    // Seed recall for one card in each lens (different domains). Do it before the
    // first retention read so the freshly-built srs_state picks the rows up.
    final now = DateTime.now();
    final repo = c.read(srsRepositoryProvider);
    await repo.seedStudied([
      (cardId: 'a1', sectionSlug: 'definition', stability: 12.0),
      (cardId: 'b1', sectionSlug: 'definition', stability: 12.0),
    ], at: now);
    await repo.seedReviews([
      (cardId: 'a1', sectionSlug: 'definition', grade: 3, stability: 12.0),
      (cardId: 'b1', sectionSlug: 'definition', grade: 3, stability: 12.0),
    ], at: now);

    c.listen(deckRetentionByDomainProvider('alpha'), (_, __) {});
    c.listen(deckRetentionByDomainProvider('beta'), (_, __) {});

    // Retention is scoped: alpha sees only algebra, beta only biology — never the
    // other lane's data (the "per-goal lie" this refactor fixes).
    final retAlpha =
        await c.read(deckRetentionByDomainProvider('alpha').future);
    final retBeta = await c.read(deckRetentionByDomainProvider('beta').future);
    expect(retAlpha.map((d) => d.domain), ['algebra']);
    expect(retBeta.map((d) => d.domain), ['biology']);
  });

  test('pause redistributes the budget; remove degrades to one goal', () async {
    if (!_sqliteAvailable) return;
    final c = make();
    addTearDown(c.dispose);
    // Keep the goal + budget graph alive across mutations (like a mounted UI).
    c.listen(decksProvider, (_, __) {});
    c.listen(deckBudgetsProvider, (_, __) {});

    final goals = await c.read(decksProvider.future);
    final total = await c.read(dailyBudgetMinutesProvider.future);

    // Pause beta → it drops out and its share redistributes to alpha.
    await c
        .read(decksProvider.notifier)
        .upsert(goals.firstWhere((g) => g.id == 'beta').copyWith(
              state: DeckState.paused,
            ));
    final afterPause = await c.read(deckBudgetsProvider.future);
    expect(afterPause.containsKey('beta'), isFalse);
    expect(afterPause['alpha'], closeTo(total, 1e-9));

    // Degrade: remove beta → a single goal remains (the hub falls back to
    // today's single-goal Home).
    await c.read(decksProvider.notifier).remove('beta');
    final one = await c.read(decksProvider.future);
    expect(one.map((g) => g.id), ['alpha']);
  });

  test('no study-goals.json → the default goal folds in the legacy aims (B2c)',
      () async {
    if (!_sqliteAvailable) return;
    // A pre-#30d vault: the legacy base target + interview goal, no study-goals.
    final legacy = Directory.systemTemp.createTempSync('onyx_legacy_');
    addTearDown(() => legacy.deleteSync(recursive: true));
    File(p.join(legacy.path, 'x1.md')).writeAsStringSync(_card('x1', 'ds-a'));
    File(p.join(legacy.path, '_meta', 'onyx-target.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync('{"level":"senior","company":"faang",'
          '"track":"backend","interviewDate":"2026-06-01"}');
    const goalsJson = '[{"id":"g1","companyName":"Google","tier":"faang",'
        '"level":"senior","track":"backend","date":"2026-05-15","active":true,'
        '"domainWeights":{"system-design":1.3},"status":"active"}]';
    // legacyInterviews reads the dev-isolated file under test (isDevDataMode);
    // write both so the fold is exercised regardless of the build's data mode.
    File(p.join(legacy.path, '_meta', 'onyx-goals.json'))
        .writeAsStringSync(goalsJson);
    File(p.join(legacy.path, '_meta', 'onyx-goals.dev.json'))
        .writeAsStringSync(goalsJson);

    final c = ProviderContainer(overrides: [
      vaultSourceProvider.overrideWithValue(DesktopVaultSource(legacy.path)),
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase.withExecutor(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
    ]);
    addTearDown(c.dispose);

    final goals = await c.read(decksProvider.future);
    expect(goals.length, 1);
    final g = goals.single;
    expect(g.id, defaultDeckId);
    expect([g.levelId, g.contextId, g.trackId], ['senior', 'faang', 'backend']);
    expect(g.deadline, DateTime(2026, 6, 1));
    expect(g.aims.single.companyName, 'Google');
    expect(g.aims.single.domainWeights['system-design'], 1.3);

    // B5 write-through: the migration durably persists the folded default so the
    // legacy files are no longer needed. Wait for the fire-and-forget save.
    await _awaitFile(File(p.join(legacy.path, '_meta', 'study-goals.json')));
  });

  test('editing the default goal\'s interviews persists it (B4a cutover)',
      () async {
    if (!_sqliteAvailable) return;
    final legacy = Directory.systemTemp.createTempSync('onyx_b4a_');
    addTearDown(() => legacy.deleteSync(recursive: true));
    File(p.join(legacy.path, 'x1.md')).writeAsStringSync(_card('x1', 'ds-a'));
    File(p.join(legacy.path, '_meta', 'onyx-target.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
          '{"level":"senior","company":"faang","track":"backend"}');
    const goalsJson = '[{"id":"g1","companyName":"Google","tier":"faang",'
        '"level":"senior","track":"backend","active":true,"status":"active"}]';
    File(p.join(legacy.path, '_meta', 'onyx-goals.json'))
        .writeAsStringSync(goalsJson);
    File(p.join(legacy.path, '_meta', 'onyx-goals.dev.json'))
        .writeAsStringSync(goalsJson);

    ProviderContainer container() => ProviderContainer(overrides: [
          vaultSourceProvider
              .overrideWithValue(DesktopVaultSource(legacy.path)),
          appDatabaseProvider.overrideWith((ref) {
            final db = AppDatabase.withExecutor(NativeDatabase.memory());
            ref.onDispose(db.close);
            return db;
          }),
        ]);
    final storeFile = File(p.join(legacy.path, '_meta', 'study-goals.json'));

    // First load: the migrated default with the one legacy interview (id kept).
    // B5 write-through persists it durably; wait for that fire-and-forget save.
    final c = container();
    addTearDown(c.dispose);
    c.listen(decksProvider, (_, __) {});
    final migrated = (await c.read(decksProvider.future)).single;
    expect(migrated.aims.single.id, 'g1');
    await _awaitFile(storeFile);

    // Add a second interview → the persisted default is updated.
    await c
        .read(decksProvider.notifier)
        .upsertAim(defaultDeckId, const Aim(id: 'amzn', companyName: 'Amazon'));
    expect(storeFile.existsSync(), isTrue);

    // A FRESH container reads the STORED default (both interviews) — the migration
    // is superseded (re-deriving from the legacy files alone would give just one).
    final c2 = container();
    addTearDown(c2.dispose);
    final stored = (await c2.read(decksProvider.future)).single;
    expect(stored.id, defaultDeckId);
    expect(stored.aims.map((iv) => iv.id).toSet(), {'g1', 'amzn'});
    // Slots survived the cutover too.
    expect([stored.levelId, stored.contextId, stored.trackId],
        ['senior', 'faang', 'backend']);
  });

  test('migration write-through preserves a graduated explicit goal (B5)',
      () async {
    if (!_sqliteAvailable) return;
    // A vault with legacy aims AND a stored-but-graduated explicit goal: the app
    // degrades to the whole-vault default, and the write-through must NOT erase the
    // graduated goal (a plain [migrated] save would).
    final legacy = Directory.systemTemp.createTempSync('onyx_b5_');
    addTearDown(() => legacy.deleteSync(recursive: true));
    File(p.join(legacy.path, 'x1.md')).writeAsStringSync(_card('x1', 'ds-a'));
    File(p.join(legacy.path, '_meta', 'onyx-target.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
          '{"level":"senior","company":"faang","track":"backend"}');
    final storeFile = File(p.join(legacy.path, '_meta', 'study-goals.json'))
      ..writeAsStringSync('[{"id":"old","name":"Old","templateId":"swe",'
          '"state":"graduated"}]');

    final c = ProviderContainer(overrides: [
      vaultSourceProvider.overrideWithValue(DesktopVaultSource(legacy.path)),
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase.withExecutor(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
    ]);
    addTearDown(c.dispose);
    c.listen(decksProvider, (_, __) {});

    // All explicit goals graduated → single-goal mode on the migrated default.
    final goals = await c.read(decksProvider.future);
    expect(goals.single.id, defaultDeckId);

    // The write-through rewrites the pre-existing file, so wait for the default to
    // appear (not mere existence), then assert the graduated goal wasn't dropped.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!storeFile.readAsStringSync().contains('"$defaultDeckId"')) {
      if (DateTime.now().isAfter(deadline)) {
        fail('write-through never persisted');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(storeFile.readAsStringSync().contains('"old"'), isTrue,
        reason: 'graduated goal preserved');
  });
}
