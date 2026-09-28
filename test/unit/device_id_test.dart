import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/settings/device_id.dart';
import 'package:onyx/core/settings/preferences_repository.dart';
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

void main() {
  group('resolveDeviceId', () {
    test('generates once, then is stable within a device (DB)', () async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final prefs = PreferencesRepository(db);
      final first = await resolveDeviceId(prefs);
      final second = await resolveDeviceId(prefs);
      expect(first, second, reason: 'stable across calls');
      expect(await prefs.get(kDeviceIdKey), first, reason: 'persisted');
      expect(first, matches(RegExp(r'^[0-9a-f]{32}$')),
          reason: 'filename-safe lowercase hex');
      await db.close();
    });

    test('two devices (separate DBs) get distinct ids', () async {
      final a = AppDatabase.withExecutor(NativeDatabase.memory());
      final b = AppDatabase.withExecutor(NativeDatabase.memory());
      final idA = await resolveDeviceId(PreferencesRepository(a));
      final idB = await resolveDeviceId(PreferencesRepository(b));
      expect(idA, isNot(idB));
      await a.close();
      await b.close();
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
