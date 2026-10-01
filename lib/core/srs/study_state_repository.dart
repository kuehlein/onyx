import '../database/database.dart';
import 'study_state.dart';

/// Reader for the unified study-state record (ADR-0024 — #155).
///
/// **Readers-first (slice 3):** this exposes the unified `(cardId, dataSlug)` rows
/// that the migration backfills; the live write paths + the `SrsRepository` /
/// `RecognitionRepository` adapters flip onto it in later slices. Keeping it
/// read-only for now means the old clocks stay the source of truth while the
/// unified shape is proven byte-identical against them.
class StudyStateRepository {
  StudyStateRepository(this._db);

  final AppDatabase _db;

  /// Every unified row, keyed `"$cardId::$dataSlug"` ([studyKey]). For recall rows
  /// `dataSlug == sectionSlug`, so these keys match the legacy `SrsRepository`
  /// keys exactly; practice rows carry the namespaced slug.
  Future<Map<String, StudyState>> loadStates() async {
    final rows = await _db.select(_db.studyStates).get();
    return {for (final r in rows) studyKey(r.cardId, r.dataSlug): r};
  }

  /// The unified rows for one scheduling [kind], keyed as in [loadStates] — the
  /// seam the two legacy repositories will read through once they become adapters.
  Future<Map<String, StudyState>> loadByKind(StudyKind kind) async {
    final rows = await (_db.select(_db.studyStates)
          ..where((t) => t.kind.equals(kind.wire)))
        .get();
    return {for (final r in rows) studyKey(r.cardId, r.dataSlug): r};
  }
}
