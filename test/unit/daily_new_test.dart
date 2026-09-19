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

/// A frozen clock so "today" is deterministic. The default [Clock] is offset-
/// based (its now() still reads the wall clock), which let a midnight boundary
/// between capturing `now` and the provider reading the clock flake the test.
class _FixedClock extends Clock {
  _FixedClock(this._fixed);
  final DateTime _fixed;
  @override
  DateTime now() => _fixed;
}

// A safe midday instant, well away from any midnight boundary.
final _fixedNow = DateTime(2026, 6, 15, 12);

void main() {
  test('dailyNewRemaining subtracts sections learned today', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final srs = SrsRepository(db);
    final scheduler = SrsScheduler();
    final now = _fixedNow;

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // Freeze the clock so "today" is deterministic (no midnight race).
      clockProvider.overrideWith((ref) async => _FixedClock(_fixedNow)),
    ]);
    addTearDown(container.dispose);

    // Limit defaults to 8; nothing learned yet → full allowance.
    expect(await container.read(dailyNewRemainingProvider.future), 8);

    // Learn 3 sections today (each writes an activity_log 'learn' event).
    for (var i = 0; i < 3; i++) {
      await srs.seedState(
        cardId: 'c$i',
        sectionSlug: 's1',
        outcome: scheduler.review(grade: 3, reviewedAt: now),
      );
    }
    container.invalidate(dailyNewRemainingProvider);
    expect(await container.read(dailyNewRemainingProvider.future), 5);

    await db.close();
  });

  test('a forward clock offset resets the daily allowance (new day)', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final srs = SrsRepository(db);
    final scheduler = SrsScheduler();

    // Learn 5 sections "yesterday".
    final yesterday = _fixedNow.subtract(const Duration(days: 1));
    for (var i = 0; i < 5; i++) {
      await srs.seedState(
        cardId: 'c$i',
        sectionSlug: 's1',
        outcome: scheduler.review(grade: 3, reviewedAt: yesterday),
      );
    }

    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      // "Today" is the fixed day; yesterday's learns don't count against it.
      clockProvider.overrideWith((ref) async => _FixedClock(_fixedNow)),
    ]);
    addTearDown(container.dispose);

    // Yesterday's 5 don't reduce today's allowance.
    expect(await container.read(dailyNewRemainingProvider.future), 8);

    await db.close();
  });
}
