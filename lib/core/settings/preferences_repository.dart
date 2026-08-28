import '../database/database.dart';

/// A thin typed accessor over the key/value `preferences` table — app settings
/// that live in SQLite (not the vault) and are not part of the study snapshot.
class PreferencesRepository {
  PreferencesRepository(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.preferences)
          ..where((p) => p.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) =>
      _db.into(_db.preferences).insertOnConflictUpdate(
            PreferencesCompanion.insert(key: key, value: value),
          );
}
