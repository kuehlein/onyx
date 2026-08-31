import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/interview/applied_repository.dart';
import 'package:onyx/core/interview/assessment.dart';
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

void main() {
  group('AppliedAssessment rubric', () {
    test('encodes and decodes round-trip', () {
      const a = AppliedAssessment(
        appliedScore: 72,
        rubric: {'correctness': 4, 'communication': 3},
        novel: true,
        hintLevel: 1,
      );
      expect(AppliedAssessment.decodeRubric(a.encodeRubric()),
          {'correctness': 4, 'communication': 3});
    });

    test('malformed rubric decodes to empty', () {
      expect(AppliedAssessment.decodeRubric('not json'), isEmpty);
      expect(AppliedAssessment.decodeRubric(null), isEmpty);
      expect(AppliedAssessment.decodeRubric(''), isEmpty);
    });
  });

  group('AppliedRepository', () {
    test('records attempts, queries by domain, and attaches a verdict',
        () async {
      if (!_sqliteAvailable) return;
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final repo = AppliedRepository(db);
      final t0 = DateTime.utc(2026, 9, 1, 9);

      final id = await repo.record(
        cardId: 'A',
        sectionSlug: 's1',
        domain: 'ds-a',
        source: 'interview-coach',
        occurredAt: t0,
        assessment: const AppliedAssessment(
          appliedScore: 70,
          rubric: {'correctness': 4},
          novel: true,
        ),
      );
      await repo.record(
        cardId: 'B',
        domain: 'system-design',
        source: 'interview-coach',
        occurredAt: t0.add(const Duration(hours: 1)),
        assessment: const AppliedAssessment(appliedScore: 40),
      );

      final all = await repo.attempts();
      expect(all.length, 2);
      // Most recent first.
      expect(all.first.domain, 'system-design');

      final dsa = await repo.attempts(domain: 'ds-a');
      expect(dsa.length, 1);
      expect(dsa.single.appliedScore, 70);
      expect(dsa.single.novel, isTrue);
      expect(AppliedAssessment.decodeRubric(dsa.single.rubric),
          {'correctness': 4});
      expect(dsa.single.verified, isNull);

      await repo.recordVerdict(
          attemptId: id, verifierScore: 65, verified: true);
      final after = await repo.attempts(domain: 'ds-a');
      expect(after.single.verified, isTrue);
      expect(after.single.verifierScore, 65);

      // `since` filters by time.
      final recent =
          await repo.attempts(since: t0.add(const Duration(minutes: 30)));
      expect(recent.map((a) => a.cardId), ['B']);

      await db.close();
    });
  });
}
