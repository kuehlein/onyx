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
