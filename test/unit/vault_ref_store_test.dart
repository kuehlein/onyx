import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/settings/preferences_repository.dart';
import 'package:onyx/core/vault/vault_ref.dart';
import 'package:onyx/core/vault/vault_ref_store.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// See database_test.dart — skip when host libsqlite3 is unavailable.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

void main() {
  group('VaultRefStore', () {
    test('save then load round-trips', () async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final store = VaultRefStore(PreferencesRepository(db));
      expect(await store.load(), isNull);
      const ref = VaultRef(VaultRefKind.appManaged, '/docs/Onyx');
      await store.save(ref);
      expect(await store.load(), ref);
      await db.close();
    });

    test('clear forgets the ref', () async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final store = VaultRefStore(PreferencesRepository(db));
      await store.save(const VaultRef(VaultRefKind.path, '/x'));
      await store.clear();
      expect(await store.load(), isNull);
      await db.close();
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
