import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/interview/applied_repository.dart';
import 'package:onyx/core/interview/assessment.dart';
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

    // Seed one graduated section (writes an activity_log 'learn' event), one
    // graded review, one applied attempt, plus a preference that must survive.
    await srs.seedState(cardId: 'a', sectionSlug: 's1', outcome: _outcome(at));
    await srs.recordReview(
        cardId: 'b', sectionSlug: 's2', grade: 3, outcome: _outcome(at));
    await AppliedRepository(db).record(
      cardId: 'b',
      domain: 'ds-a',
      source: 'interview-coach',
      occurredAt: at,
      assessment: const AppliedAssessment(appliedScore: 60),
    );
    await prefs.set('readiness_target', '{"level":"senior"}');

    expect((await db.select(db.srsStates).get()), isNotEmpty);
    expect((await db.select(db.reviews).get()), isNotEmpty);
    expect((await db.select(db.activityLog).get()), isNotEmpty);
    expect((await db.select(db.appliedAttempts).get()), isNotEmpty);

    await db.wipeStudyData();

    expect((await db.select(db.srsStates).get()), isEmpty);
    expect((await db.select(db.reviews).get()), isEmpty);
    expect((await db.select(db.activityLog).get()), isEmpty);
    expect((await db.select(db.appliedAttempts).get()), isEmpty);
    // Preferences (settings/target) are intentionally preserved.
    expect(await prefs.get('readiness_target'), '{"level":"senior"}');

    await db.close();
  });

  test('seedAllDueNow makes every section immediately due', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final srs = SrsRepository(db);

    await srs.seedAllDueNow([
      (cardId: 'a', sectionSlug: 's1'),
      (cardId: 'b', sectionSlug: 's2'),
    ]);

    final states = await srs.loadStates();
    expect(states.length, 2);
    final now = DateTime.now();
    for (final s in states.values) {
      expect(s.dueAt.isAfter(now), isFalse); // due now (not in the future)
    }

    // Idempotent: re-running just pulls dueAt forward, no duplicate rows.
    await srs.seedAllDueNow([(cardId: 'a', sectionSlug: 's1')]);
    expect((await srs.loadStates()).length, 2);

    await db.close();
  });
}
