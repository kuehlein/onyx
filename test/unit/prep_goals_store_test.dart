import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/readiness/goals_service.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/vault_source.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/vault.dart';
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

/// A VaultSource whose meta files live in memory.
class _FakeSource implements VaultSource {
  final Map<String, String> meta = {};
  @override
  String get rootLabel => 'fake';
  @override
  Future<List<String>> listCardPaths() async => const [];
  @override
  Future<String> readCard(String relativePath) async => '';
  @override
  Future<String?> readMeta(String name) async => meta[name];
  @override
  Future<void> writeMeta(String name, String content) async =>
      meta[name] = content;
}

PrepGoal _goal(String id, {String company = '', bool active = true}) =>
    PrepGoal(
      id: id,
      companyName: company,
      tier: CompanyTier.faang,
      level: SeniorityLevel.senior,
      track: Track.backend,
      active: active,
    );

void main() {
  test('GoalsService round-trips goals through the vault meta file', () async {
    final src = _FakeSource();
    final svc = GoalsService(src);
    expect(await svc.load(), isEmpty);
    await svc.save([_goal('a'), _goal('b', company: 'Amazon')]);
    expect(src.meta.containsKey(GoalsService.fileName), isTrue);
    final back = await svc.load();
    expect(back.map((g) => g.id), ['a', 'b']);
    expect(back[1].companyName, 'Amazon');
  });

  ProviderContainer make(AppDatabase db) => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultSourceProvider.overrideWithValue(null),
      ]);

  test('prepGoals: empty by default; upsert / setActive / remove mutate it',
      () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final c = make(db);
    addTearDown(c.dispose);

    expect(await c.read(prepGoalsProvider.future), isEmpty);

    await c.read(prepGoalsProvider.notifier).upsert(_goal('a'));
    expect((c.read(prepGoalsProvider).asData!.value).map((g) => g.id), ['a']);

    // upsert with the same id replaces, not appends.
    await c
        .read(prepGoalsProvider.notifier)
        .upsert(_goal('a', company: 'Google'));
    final one = c.read(prepGoalsProvider).asData!.value;
    expect(one, hasLength(1));
    expect(one.single.companyName, 'Google');

    await c.read(prepGoalsProvider.notifier).setActive('a', false);
    expect(c.read(prepGoalsProvider).asData!.value.single.active, isFalse);

    await c.read(prepGoalsProvider.notifier).remove('a');
    expect(c.read(prepGoalsProvider).asData!.value, isEmpty);
    await db.close();
  });

  test('prepGoals persist: a fresh container reads them back', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final c1 = make(db);
    await c1
        .read(prepGoalsProvider.notifier)
        .upsert(_goal('a', company: 'Meta'));
    c1.dispose();

    // Same DB (the preferences table persists) → a new container reloads.
    final c2 = make(db);
    addTearDown(c2.dispose);
    final reloaded = await c2.read(prepGoalsProvider.future);
    expect(reloaded.map((g) => g.id), ['a']);
    expect(reloaded.single.companyName, 'Meta');
    await db.close();
  });
}
