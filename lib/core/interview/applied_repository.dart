import 'package:drift/drift.dart';

import '../database/database.dart';
import 'assessment.dart';

/// Reads and writes applied / mock-interview attempts (the Phase B signal).
class AppliedRepository {
  AppliedRepository(this._db);

  final AppDatabase _db;

  /// Record one attempt from a structured [assessment].
  Future<int> record({
    required String cardId,
    String? sectionSlug,
    String? domain,
    required AppliedAssessment assessment,
    required String source,
    required DateTime occurredAt,
  }) {
    return _db.into(_db.appliedAttempts).insert(
          AppliedAttemptsCompanion.insert(
            cardId: cardId,
            sectionSlug: Value(sectionSlug),
            domain: Value(domain),
            occurredAt: occurredAt,
            appliedScore: assessment.appliedScore,
            rubric: Value(assessment.encodeRubric()),
            novel: Value(assessment.novel),
            hintLevel: Value(assessment.hintLevel),
            source: source,
            note: Value(assessment.note),
          ),
        );
  }

  /// Attach an adversarial second-opinion verdict to an attempt.
  Future<void> recordVerdict({
    required int attemptId,
    required int verifierScore,
    required bool verified,
  }) async {
    await (_db.update(_db.appliedAttempts)
          ..where((a) => a.id.equals(attemptId)))
        .write(AppliedAttemptsCompanion(
      verifierScore: Value(verifierScore),
      verified: Value(verified),
    ));
  }

  /// Attempts, most recent first, optionally scoped to a [domain] and/or a
  /// [since] cutoff.
  Future<List<AppliedAttempt>> attempts({String? domain, DateTime? since}) {
    final q = _db.select(_db.appliedAttempts)
      ..orderBy([(a) => OrderingTerm.desc(a.occurredAt)]);
    if (domain != null) q.where((a) => a.domain.equals(domain));
    if (since != null) q.where((a) => a.occurredAt.isBiggerOrEqualValue(since));
    return q.get();
  }
}
