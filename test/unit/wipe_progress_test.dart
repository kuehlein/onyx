import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/settings/preferences_repository.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
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
      stability: 10,
      difficulty: 5,
      state: 2,
      step: null,
      due: at.add(const Duration(days: 3)),
      lastReview: at,
      elapsedDays: 0,
    );

void main() {
  test('wipeStudyData clears progress but keeps preferences', () async {
    if (!_sqliteAvailable) return;
    final at = DateTime.utc(2026, 1, 1, 9);
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final srs = SrsRepository(db);
    final prefs = PreferencesRepository(db);

    // Seed one graduated section (writes an activity_log 'learn' event) and one
    // graded review, plus a preference that should survive the wipe.
    await srs.seedState(cardId: 'a', sectionSlug: 's1', outcome: _outcome(at));
    await srs.recordReview(
        cardId: 'b', sectionSlug: 's2', grade: 3, outcome: _outcome(at));
    await prefs.set('readiness_target', '{"level":"senior"}');

    expect((await db.select(db.srsStates).get()), isNotEmpty);
    expect((await db.select(db.reviews).get()), isNotEmpty);
    expect((await db.select(db.activityLog).get()), isNotEmpty);

    await db.wipeStudyData();

    expect((await db.select(db.srsStates).get()), isEmpty);
    expect((await db.select(db.reviews).get()), isEmpty);
    expect((await db.select(db.activityLog).get()), isEmpty);
    // Preferences (settings/target) are intentionally preserved.
    expect(await prefs.get('readiness_target'), '{"level":"senior"}');

    await db.close();
  });
}
