import 'package:drift/drift.dart';

import '../database/database.dart';
import 'recognition.dart';

/// Reads and writes the recognition ("explain") clock — the algorithm track's
/// second clock. Kept entirely separate from [SrsRepository]: explaining never
/// touches the solve schedule.
class RecognitionRepository {
  RecognitionRepository(this._db);

  final AppDatabase _db;

  static String keyFor(String cardId, String sectionSlug) =>
      '$cardId::$sectionSlug';

  /// All recognition states, keyed `"cardId::sectionSlug"`.
  Future<Map<String, RecognitionState>> loadStates() async {
    final rows = await _db.select(_db.recognitionStates).get();
    return {for (final r in rows) keyFor(r.cardId, r.sectionSlug): r};
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
    return result;
  }
}
