import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/card_links_repository.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// Reading the card→card graph the indexer caches in `card_links` — the
/// second-brain surface (task #50, S1).
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

void main() {
  group('CardLinksRepository', () {
    late AppDatabase db;
    late CardLinksRepository repo;

    setUp(() {
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      repo = CardLinksRepository(db);
    });
    tearDown(() => db.close());

    Future<void> link(String from, String to) => db
        .into(db.cardLinks)
        .insert(CardLinksCompanion.insert(fromCard: from, toCard: to));

    test('outbound + backlinks read the edge graph both directions', () async {
      // a → b, a → c, d → a
      await link('a', 'b');
      await link('a', 'c');
      await link('d', 'a');

      expect((await repo.outbound('a')).toSet(), {'b', 'c'});
      expect(await repo.backlinks('a'), ['d']);
      // A leaf with no edges is empty both ways.
      expect(await repo.outbound('b'), isEmpty);
      expect(await repo.backlinks('d'), isEmpty);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
