import 'package:drift/drift.dart';

import '../database/database.dart';
import 'srs_scheduler.dart';

/// Reads and writes per-section FSRS state and the append-only review log.
class SrsRepository {
  SrsRepository(this._db);

  final AppDatabase _db;

  /// All scheduling state, keyed by `"$cardId::$sectionSlug"`.
  Future<Map<String, SrsState>> loadStates() async {
    final rows = await _db.select(_db.srsStates).get();
    return {for (final r in rows) '${r.cardId}::${r.sectionSlug}': r};
  }

  /// Graduate a section out of Learn mode: seed its initial FSRS state so it
  /// enters the review queue, WITHOUT writing a `reviews` row — the forgetting
  /// curve should be fit from the first real review (the next encounter), not
  /// this first-study event. Logged to `activity_log` instead. reviewCount stays
  /// 0 so the next review counts as the first.
  Future<void> seedState({
    required String cardId,
    required String sectionSlug,
    required ReviewOutcome outcome,
  }) async {
    await _db.transaction(() async {
      await _db.into(_db.srsStates).insertOnConflictUpdate(
            SrsStatesCompanion.insert(
              cardId: cardId,
              sectionSlug: sectionSlug,
              stability: Value(outcome.stability),
              difficulty: Value(outcome.difficulty),
              state: Value(outcome.state),
              step: Value(outcome.step),
              dueAt: outcome.due,
              lastReview: Value(outcome.lastReview),
              reviewCount: const Value(0),
            ),
          );
      await _db.into(_db.activityLog).insert(
            ActivityLogCompanion.insert(
              occurredAt: outcome.lastReview,
              eventType: 'learn',
              cardId: Value(cardId),
              sectionSlug: Value(sectionSlug),
            ),
          );
    });
  }

  /// How many brand-new sections were first studied (graduated out of Learn)
  /// since [since] — the `'learn'` events in the activity log. This is the
  /// coverage-pace signal for the readiness dashboard. Note: `activity_log` is
  /// device-local (not part of the synced snapshot), so on a freshly restored
  /// device this reads 0 until studying resumes.
  Future<int> sectionsStartedSince(DateTime since) async {
    final count = _db.activityLog.id.count();
    final row = await (_db.selectOnly(_db.activityLog)
          ..addColumns([count])
          ..where(_db.activityLog.eventType.equals('learn') &
              _db.activityLog.occurredAt.isBiggerOrEqualValue(since)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Timestamps of every study action since [since] — graded reviews plus
  /// newly learned sections (`'learn'` events). Used to compute the study
  /// streak. Reviews sync via the snapshot; `activity_log` is device-local, so
  /// a freshly restored device rebuilds the learn side as studying resumes.
  Future<List<DateTime>> studyTimestamps({required DateTime since}) async {
    final reviews = await (_db.select(_db.reviews)
          ..where((r) => r.reviewedAt.isBiggerOrEqualValue(since)))
        .get();
    final learns = await (_db.select(_db.activityLog)
          ..where((a) =>
              a.eventType.equals('learn') &
              a.occurredAt.isBiggerOrEqualValue(since)))
        .get();
    return [
      for (final r in reviews) r.reviewedAt,
      for (final l in learns) l.occurredAt,
    ];
  }

  /// DEV/E2E: make every given `(cardId, sectionSlug)` due right now, so the
  /// whole review queue is immediately exercisable. Seeds a default review state
  /// for un-studied sections and pulls existing ones forward to now — without
  /// writing review-log rows (this is a testing shortcut, not real history).
  Future<void> seedAllDueNow(
      Iterable<({String cardId, String sectionSlug})> keys) async {
    final now = DateTime.now();
    await _db.batch((b) {
      for (final k in keys) {
        b.insert(
          _db.srsStates,
          SrsStatesCompanion.insert(
            cardId: k.cardId,
            sectionSlug: k.sectionSlug,
            stability: const Value(1),
            difficulty: const Value(5),
            state: const Value(2), // review
            step: const Value(null),
            dueAt: now,
            lastReview: Value(now),
            reviewCount: const Value(0),
          ),
          onConflict: DoUpdate((_) => SrsStatesCompanion(dueAt: Value(now))),
        );
      }
    });
  }

  /// Persist a graded review: upsert the section's FSRS state and append a row
  /// to the immutable review log, in one transaction.
  Future<void> recordReview({
    required String cardId,
    required String sectionSlug,
    required int grade,
    required ReviewOutcome outcome,
  }) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.srsStates)
            ..where((t) =>
                t.cardId.equals(cardId) & t.sectionSlug.equals(sectionSlug)))
          .getSingleOrNull();

      await _db.into(_db.srsStates).insertOnConflictUpdate(
            SrsStatesCompanion.insert(
              cardId: cardId,
              sectionSlug: sectionSlug,
              stability: Value(outcome.stability),
              difficulty: Value(outcome.difficulty),
              state: Value(outcome.state),
              step: Value(outcome.step),
              dueAt: outcome.due,
              lastReview: Value(outcome.lastReview),
              reviewCount: Value((existing?.reviewCount ?? 0) + 1),
            ),
          );

      await _db.into(_db.reviews).insert(
            ReviewsCompanion.insert(
              cardId: cardId,
              sectionSlug: sectionSlug,
              reviewedAt: outcome.lastReview,
              grade: grade,
              stability: outcome.stability,
              difficulty: outcome.difficulty,
              elapsedDays: outcome.elapsedDays,
            ),
          );
    });
  }
}
