import 'package:drift/drift.dart';

import '../database/database.dart';
import 'recognition.dart';
import 'study_scheduler.dart';
import 'study_state.dart';
import 'study_state_model.dart';

/// Reads and writes the recognition ("explain") clock — the algorithm track's
/// second clock. Kept entirely separate from [SrsRepository]: explaining never
/// touches the solve schedule.
class RecognitionRepository {
  RecognitionRepository(this._db);

  final AppDatabase _db;

  static String keyFor(String cardId, String sectionSlug) =>
      '$cardId::$sectionSlug';

  /// All practice ("explain") scheduling state, keyed `"cardId::sectionSlug"`.
  ///
  /// Reads the unified `study_states` record (ADR-0024) and decodes each practice
  /// row into a [PracticeState] domain type (see `study_state_model.dart`). The
  /// practice `dataSlug` is namespaced (`recognize:<aspect>`), so [studyAspect]
  /// strips it back to the section slug — keeping the keys byte-identical to the
  /// pre-migration ones.
  Future<Map<String, PracticeState>> loadStates() async {
    final rows = await (_db.select(_db.studyStates)
          ..where((t) => t.kind.equals(StudyKind.practice.wire)))
        .get();
    return {
      for (final r in rows)
        keyFor(r.cardId, studyAspect(r.dataSlug)): PracticeState.fromRow(r),
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
    // Dispatch through the per-kind registry (ADR-0024 §3): practice → expanding.
    final result = const PracticeScheduler().schedule(
      outcome: outcome,
      now: now,
      priorStreak: existing?.activityCount ?? 0,
    );
    // Persist the unified practice datum (ADR-0024 slice 5c — the sole state
    // write). The practice dataSlug is namespaced ('recognize:<aspect>') so it
    // never collides with the same section's recall datum; streak = activityCount.
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
    return result;
  }
}
