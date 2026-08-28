import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/settings/preferences_repository.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/settings.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.withExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('PreferencesRepository', () {
    test('set then get round-trips; missing key is null; set upserts',
        () async {
      final repo = PreferencesRepository(db);
      expect(await repo.get('k'), isNull);
      await repo.set('k', 'v');
      expect(await repo.get('k'), 'v');
      await repo.set('k', 'v2');
      expect(await repo.get('k'), 'v2');
    });
  });

  group('NewCardLimit', () {
    ProviderContainer container() => ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)]);

    test('defaults when unset', () async {
      final c = container();
      addTearDown(c.dispose);
      expect(
          await c.read(newCardLimitProvider.future), NewCardLimit.defaultValue);
    });

    test('set persists (survives a fresh container) and clamps to range',
        () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(newCardLimitProvider.future);
      await c.read(newCardLimitProvider.notifier).set(35);
      expect(await c.read(newCardLimitProvider.future), 35);

      await c.read(newCardLimitProvider.notifier).set(999); // over max
      expect(await c.read(newCardLimitProvider.future), NewCardLimit.max);

      final c2 = container();
      addTearDown(c2.dispose);
      expect(await c2.read(newCardLimitProvider.future), NewCardLimit.max);
    });
  });
}
