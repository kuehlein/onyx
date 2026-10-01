import 'package:drift/drift.dart';

import '../database/database.dart';
import 'recognition.dart';
import 'study_state.dart';

/// Reads and writes the recognition ("explain") clock — the algorithm track's
/// second clock. Kept entirely separate from [SrsRepository]: explaining never
/// touches the solve schedule.
class RecognitionRepository {
  RecognitionRepository(this._db);

  final AppDatabase _db;

  static String keyFor(String cardId, String sectionSlug) =>
      '$cardId::$sectionSlug';

  /// All recognition states, keyed `"cardId::sectionSlug"`.
  ///
  /// Reads the unified `study_states` record (ADR-0024 slice 5) and reconstructs
  /// the legacy [RecognitionState] shape. The practice `dataSlug` is namespaced
  /// (`recognize:<aspect>`), so [studyAspect] strips it back to the section slug —
  /// keeping the keys byte-identical to the old ones. `recognition_states` is still
  /// dual-written (until slice 5c) but no longer read here.
  Future<Map<String, RecognitionState>> loadStates() async {
    final rows = await (_db.select(_db.studyStates)
          ..where((t) => t.kind.equals(StudyKind.practice.wire)))
        .get();
    return {
      for (final r in rows)
        keyFor(r.cardId, studyAspect(r.dataSlug)): RecognitionState(
          cardId: r.cardId,
          sectionSlug: studyAspect(r.dataSlug),
          lastExplainedAt: r.lastActivityAt ?? r.dueAt,
          dueAt: r.dueAt,
          intervalDays: r.intervalDays ?? 0,
          streak: r.activityCount,
        ),
    };
  }

  /// Record how an explanation went: run the pure scheduler over the prior
  /// streak and upsert the new state. Returns the applied result.
  Future<RecognitionResult> recordExplain({
    required String cardId,
    required String sectionSlug,
    required ExplainOutcome outcome,
    required DateTime now,
  }) async {
    final key = keyFor(cardId, sectionSlug);
    final existing = (await loadStates())[key];
    final result = scheduleRecognition(
      outcome: outcome,
      now: now,
      priorStreak: existing?.streak ?? 0,
    );
    await _db.transaction(() async {
      await _db.into(_db.recognitionStates).insertOnConflictUpdate(
            RecognitionStatesCompanion.insert(
              cardId: cardId,
              sectionSlug: sectionSlug,
              lastExplainedAt: now,
              dueAt: result.dueAt,
              intervalDays: result.intervalDays,
              streak: Value(result.streak),
            ),
          );
      // Dual-write the unified practice datum (ADR-0024 slice 4). The practice
      // dataSlug is namespaced ('recognize:<aspect>') so it never collides with
      // the same section's recall (solve) datum; the streak is the activityCount.
      await _db.into(_db.studyStates).insertOnConflictUpdate(
            StudyStatesCompanion.insert(
              cardId: cardId,
              dataSlug: studyDataSlug(sectionSlug, StudyKind.practice),
              kind: StudyKind.practice.wire,
              dueAt: result.dueAt,
              lastActivityAt: Value(now),
              activityCount: Value(result.streak),
              intervalDays: Value(result.intervalDays),
            ),
          );
    });
    return result;
  }
}
