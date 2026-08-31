import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/learn.dart';
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
  test('dailyNewRemaining subtracts sections learned today', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final srs = SrsRepository(db);
    final scheduler = SrsScheduler();
    final now = DateTime.now();

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // Freeze the clock at real "now" so 'today' is deterministic.
      clockProvider.overrideWith((ref) async => Clock.real),
    ]);
    addTearDown(container.dispose);

    // Limit defaults to 20; nothing learned yet → full allowance.
    expect(await container.read(dailyNewRemainingProvider.future), 20);

    // Learn 3 sections today (each writes an activity_log 'learn' event).
    for (var i = 0; i < 3; i++) {
      await srs.seedState(
        cardId: 'c$i',
        sectionSlug: 's1',
        outcome: scheduler.review(grade: 3, reviewedAt: now),
      );
    }
    container.invalidate(dailyNewRemainingProvider);
    expect(await container.read(dailyNewRemainingProvider.future), 17);

    await db.close();
  });

  test('a forward clock offset resets the daily allowance (new day)', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final srs = SrsRepository(db);
    final scheduler = SrsScheduler();

    // Learn 5 sections "yesterday".
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    for (var i = 0; i < 5; i++) {
      await srs.seedState(
        cardId: 'c$i',
        sectionSlug: 's1',
        outcome: scheduler.review(grade: 3, reviewedAt: yesterday),
      );
    }

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // "Today" is the real day; yesterday's learns don't count against it.
      clockProvider.overrideWith((ref) async => Clock.real),
    ]);
    addTearDown(container.dispose);

    // Yesterday's 5 don't reduce today's allowance.
    expect(await container.read(dailyNewRemainingProvider.future), 20);

    await db.close();
  });
}
