import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/backup/snapshot.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
import 'package:onyx/core/vault/vault_ref.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/vault.dart';
import 'package:path/path.dart' as p;
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

ReviewOutcome _outcome(DateTime at) => ReviewOutcome(
      stability: 8,
      difficulty: 5,
      state: 2,
      step: null,
      due: at.add(const Duration(days: 3)),
      lastReview: at,
      elapsedDays: 0,
    );

/// Folder-switch data safety (docs/settings-ux.md §3): the local DB is a derived
/// cache of ONE folder at a time. Switching must preserve the outgoing folder's
/// progress in its own snapshot and NOT mix it into the incoming folder — so the
/// "your progress here isn't deleted" reassurance is literally true.
void main() {
  group('VaultRefController.choose — folder-switch data safety', () {
    late Directory a;
    late Directory b;
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      a = Directory.systemTemp.createTempSync('onyx_switch_a_');
      b = Directory.systemTemp.createTempSync('onyx_switch_b_');
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
      a.deleteSync(recursive: true);
      b.deleteSync(recursive: true);
    });

    VaultRef refFor(Directory d) => VaultRef(VaultRefKind.path, d.path);

    Future<void> study(String card) => SrsRepository(db).recordReview(
          cardId: card,
          sectionSlug: 's',
          grade: 3,
          outcome: _outcome(DateTime.utc(2026, 1, 1, 9)),
        );

    Future<Set<String>> cardsInDb() async =>
        (await db.select(db.srsStates).get()).map((s) => s.cardId).toSet();

    bool snapshotExists(Directory d) =>
        File(p.join(d.path, '_meta', SnapshotService.fileName)).existsSync();

    test('switching preserves the old folder and never mixes it into the new',
        () async {
      final ctl = container.read(vaultRefControllerProvider.notifier);

      // 1. Choose folder A (first-run, no switch) and study card 'a' there.
      await ctl.choose(refFor(a));
      await study('a');
      expect(await cardsInDb(), {'a'});

      // 2. Switch to folder B: A's progress is exported to A's own snapshot, and
      //    the cache is scoped to B (which has no progress yet).
      await ctl.choose(refFor(b));
      expect(snapshotExists(a), isTrue,
          reason:
              "the outgoing folder's progress is persisted to its snapshot");
      expect(await cardsInDb(), isEmpty,
          reason: "B starts fresh — A's progress is not mixed in");

      // 3. Study 'b' in folder B, then switch back to A.
      await study('b');
      await ctl.choose(refFor(a));

      // 4. A resumes its OWN progress ('a'); 'b' went to B's snapshot, not A's.
      expect(await cardsInDb(), {'a'});
      expect(snapshotExists(b), isTrue);
    }, skip: _sqliteAvailable ? false : 'host libsqlite3 unavailable');

    test('re-choosing the SAME folder is a no-op switch (progress kept)',
        () async {
      final ctl = container.read(vaultRefControllerProvider.notifier);
      await ctl.choose(refFor(a));
      await study('a');

      // Same ref again → not a switch → no export/clear, progress stays put.
      await ctl.choose(refFor(a));
      expect(await cardsInDb(), {'a'});
    }, skip: _sqliteAvailable ? false : 'host libsqlite3 unavailable');
  });
}
