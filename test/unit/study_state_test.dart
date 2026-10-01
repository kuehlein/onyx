import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/srs/study_state.dart';
import 'package:onyx/core/srs/study_state_repository.dart';
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

void main() {
  group('study-state key vocabulary (ADR-0024)', () {
    test('recall is the bare aspect; practice is namespaced', () {
      expect(studyDataSlug('two-sum', StudyKind.recall), 'two-sum');
      expect(studyDataSlug('two-sum', StudyKind.practice), 'recognize:two-sum');
      expect(studyDataSlug('mock', StudyKind.practice), 'recognize:mock');
    });

    test('studyAspect inverts studyDataSlug for both kinds', () {
      for (final aspect in ['two-sum', 'mock', 'when-to-use']) {
        expect(studyAspect(studyDataSlug(aspect, StudyKind.recall)), aspect);
        expect(studyAspect(studyDataSlug(aspect, StudyKind.practice)), aspect);
      }
    });

    test('a practice datum can never collide with a recall datum', () {
      // The whole point of the namespace: same card, same aspect, two clocks.
      final recall = studyDataSlug('approach', StudyKind.recall);
      final practice = studyDataSlug('approach', StudyKind.practice);
      expect(recall, isNot(practice));
    });

    test('kind round-trips through its wire value', () {
      for (final k in StudyKind.values) {
        expect(StudyKind.fromWire(k.wire), k);
      }
    });
  });

  group('backfillStudyStates (v2→v3 migration mapping)', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.withExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    // A relearning recall row with a null lastReview edge case, a plain recall
    // row, a mock practice row, AND the algorithm two-clock case: the SAME
    // (cardId, sectionSlug) living in BOTH legacy tables.
    Future<void> seedLegacy() async {
      await db.into(db.srsStates).insert(SrsStatesCompanion.insert(
            cardId: 'algo-x',
            sectionSlug: 'approach',
            stability: const Value(12.5),
            difficulty: const Value(6.25),
            state: const Value(2),
            step: const Value(null),
            dueAt: DateTime.utc(2026, 2, 15, 9),
            lastReview: Value(DateTime.utc(2026, 2, 3, 9)),
            reviewCount: const Value(4),
          ));
      await db.into(db.srsStates).insert(SrsStatesCompanion.insert(
            cardId: 'concept-y',
            sectionSlug: 'when-to-use',
            stability: const Value(2),
            difficulty: const Value(7.1),
            state: const Value(3), // relearning
            step: const Value(1),
            dueAt: DateTime.utc(2026, 2, 4, 9, 10),
            lastReview: const Value(null),
            reviewCount: const Value(2),
          ));
      // Same (cardId, sectionSlug) as the recall row above → MUST NOT collide.
      await db.into(db.recognitionStates).insert(
            RecognitionStatesCompanion.insert(
              cardId: 'algo-x',
              sectionSlug: 'approach',
              lastExplainedAt: DateTime.utc(2026, 2, 1, 9),
              dueAt: DateTime.utc(2026, 2, 8, 9),
              intervalDays: 7,
              streak: const Value(2),
            ),
          );
      await db.into(db.recognitionStates).insert(
            RecognitionStatesCompanion.insert(
              cardId: 'sd-z',
              sectionSlug: 'mock',
              lastExplainedAt: DateTime.utc(2026, 1, 20, 9),
              dueAt: DateTime.utc(2026, 1, 27, 9),
              intervalDays: 7,
              streak: const Value(3),
            ),
          );
    }

    test('maps both clocks byte-exact, with no PK collision', () async {
      await seedLegacy();
      await db.backfillStudyStates();

      final states = await StudyStateRepository(db).loadStates();
      // 2 recall + 2 practice = 4 rows; the algo card contributes one of each.
      expect(states.length, 4);

      // --- recall (FSRS) payload verbatim; bare slug; counters remapped. ---
      final recall = states['algo-x::approach']!;
      expect(recall.kind, StudyKind.recall.wire);
      expect(recall.stability, 12.5);
      expect(recall.difficulty, 6.25);
      expect(recall.fsrsState, 2);
      expect(recall.step, isNull);
      expect(recall.activityCount, 4, reason: 'reviewCount → activityCount');
      expect(recall.lastActivityAt?.toUtc(), DateTime.utc(2026, 2, 3, 9));
      expect(recall.dueAt.toUtc(), DateTime.utc(2026, 2, 15, 9));
      expect(recall.intervalDays, isNull,
          reason: 'recall has no practice payload');

      final relearn = states['concept-y::when-to-use']!;
      expect(relearn.fsrsState, 3);
      expect(relearn.step, 1);
      expect(relearn.lastActivityAt, isNull,
          reason: 'null lastReview preserved');

      // --- practice payload; namespaced slug; streak → activityCount. ---
      final practice = states['algo-x::recognize:approach']!;
      expect(practice.kind, StudyKind.practice.wire);
      expect(practice.intervalDays, 7);
      expect(practice.activityCount, 2, reason: 'streak → activityCount');
      expect(practice.lastActivityAt?.toUtc(), DateTime.utc(2026, 2, 1, 9));
      expect(practice.dueAt.toUtc(), DateTime.utc(2026, 2, 8, 9));
      expect(practice.stability, isNull,
          reason: 'practice has no FSRS payload');
      expect(practice.difficulty, isNull);
      expect(practice.fsrsState, isNull);

      final mock = states['sd-z::recognize:mock']!;
      expect(mock.kind, StudyKind.practice.wire);
      expect(mock.intervalDays, 7);
      expect(mock.activityCount, 3);
    });

    test('is idempotent (safe to re-run)', () async {
      await seedLegacy();
      await db.backfillStudyStates();
      await db.backfillStudyStates(); // insert-or-replace, no PK crash
      expect((await StudyStateRepository(db).loadStates()).length, 4);
    });

    test('loadByKind filters to one scheduling model', () async {
      await seedLegacy();
      await db.backfillStudyStates();
      final repo = StudyStateRepository(db);
      expect((await repo.loadByKind(StudyKind.recall)).keys.toSet(),
          {'algo-x::approach', 'concept-y::when-to-use'});
      expect((await repo.loadByKind(StudyKind.practice)).keys.toSet(),
          {'algo-x::recognize:approach', 'sd-z::recognize:mock'});
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
