import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/goal/study_goal.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/analytics.dart';
import 'package:onyx/shared/providers/daily_plan.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/study_goals.dart';
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
    c.listen(goalReadinessProvider('alpha'), (_, __) {});
    c.listen(goalReadinessProvider('beta'), (_, __) {});

    // Discovery: the two stored goals replace the whole-vault default.
    final goals = await c.read(studyGoalsProvider.future);
    expect(goals.map((g) => g.id).toSet(), {'alpha', 'beta'});

    // Per-goal readiness is scoped to each lens's cards (different domains).
    final rAlpha = await c.read(goalReadinessProvider('alpha').future);
    final rBeta = await c.read(goalReadinessProvider('beta').future);
    expect(rAlpha.domains.map((d) => d.domain), ['algebra']);
    expect(rBeta.domains.map((d) => d.domain), ['biology']);

    // Shared budget splits 3:1 by weight; both active goals get a slice.
    final budgets = await c.read(goalBudgetsProvider.future);
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
        await c.read(goalMemberCardIdsProvider('alpha').future), {'a1', 'a2'});
    expect(await c.read(goalMemberCardIdsProvider('beta').future), {'b1'});

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

    c.listen(goalRetentionByDomainProvider('alpha'), (_, __) {});
    c.listen(goalRetentionByDomainProvider('beta'), (_, __) {});

    // Retention is scoped: alpha sees only algebra, beta only biology — never the
    // other lane's data (the "per-goal lie" this refactor fixes).
    final retAlpha =
        await c.read(goalRetentionByDomainProvider('alpha').future);
    final retBeta = await c.read(goalRetentionByDomainProvider('beta').future);
    expect(retAlpha.map((d) => d.domain), ['algebra']);
    expect(retBeta.map((d) => d.domain), ['biology']);
  });

  test('pause redistributes the budget; remove degrades to one goal', () async {
    if (!_sqliteAvailable) return;
    final c = make();
    addTearDown(c.dispose);
    // Keep the goal + budget graph alive across mutations (like a mounted UI).
    c.listen(studyGoalsProvider, (_, __) {});
    c.listen(goalBudgetsProvider, (_, __) {});

    final goals = await c.read(studyGoalsProvider.future);
    final total = await c.read(dailyBudgetMinutesProvider.future);

    // Pause beta → it drops out and its share redistributes to alpha.
    await c
        .read(studyGoalsProvider.notifier)
        .upsert(goals.firstWhere((g) => g.id == 'beta').copyWith(
              state: GoalState.paused,
            ));
    final afterPause = await c.read(goalBudgetsProvider.future);
    expect(afterPause.containsKey('beta'), isFalse);
    expect(afterPause['alpha'], closeTo(total, 1e-9));

    // Degrade: remove beta → a single goal remains (the hub falls back to
    // today's single-goal Home).
    await c.read(studyGoalsProvider.notifier).remove('beta');
    final one = await c.read(studyGoalsProvider.future);
    expect(one.map((g) => g.id), ['alpha']);
  });
}
