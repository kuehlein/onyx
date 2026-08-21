import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Whether the native sqlite3 library can be loaded here. On-device this is
/// provided by `sqlite3_flutter_libs`; for host `flutter test` the nix dev shell
/// puts libsqlite3 on the loader path (see flake.nix). When absent we skip
/// rather than fail, with a clear reason.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

void main() {
  group('AppDatabase', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.withExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('schema opens and preferences round-trip', () async {
      await db.into(db.preferences).insert(
            PreferencesCompanion.insert(
              key: 'vault_path',
              value: '/vault/Flashcards',
            ),
          );
      final row = await (db.select(db.preferences)
            ..where((t) => t.key.equals('vault_path')))
          .getSingle();
      expect(row.value, '/vault/Flashcards');
    });

    test('srs_state applies column defaults and composite key', () async {
      await db.into(db.srsStates).insert(
            SrsStatesCompanion.insert(
              cardId: 'card-1',
              sectionSlug: 'when-to-use',
              dueAt: DateTime.utc(2026, 1, 1),
            ),
          );
      final state = await db.select(db.srsStates).getSingle();
      expect(state.stability, 0.0);
      expect(state.difficulty, 5.0); // FSRS default difficulty
      expect(state.reviewCount, 0);
      expect(state.lastReview, isNull);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell (flake provides sqlite)');
}
