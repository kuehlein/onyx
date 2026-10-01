import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/srs/recognition.dart';
import 'package:onyx/core/srs/recognition_repository.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
import 'package:onyx/core/srs/study_state.dart';
import 'package:onyx/core/srs/study_state_repository.dart';
import 'package:path/path.dart' as p;
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

ReviewOutcome _outcome(DateTime at, {double stability = 3}) => ReviewOutcome(
      stability: stability,
      difficulty: 5,
      state: 2,
      step: null,
      due: at.add(const Duration(days: 1)),
      lastReview: at,
      elapsedDays: 0,
    );

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

  group('dual-write keeps the unified record live (slice 4)', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.withExecutor(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('recordReview mirrors the recall datum into study_states', () async {
      final at = DateTime.utc(2026, 3, 1, 9);
      await SrsRepository(db).recordReview(
          cardId: 'c',
          sectionSlug: 's',
          grade: 3,
          outcome: _outcome(at, stability: 8));
      final unified = (await StudyStateRepository(db).loadStates())['c::s']!;
      expect(unified.kind, StudyKind.recall.wire);
      expect(unified.stability, 8);
      expect(unified.difficulty, 5);
      expect(unified.fsrsState, 2);
      expect(unified.activityCount, 1, reason: 'reviewCount mirrored');
      expect(unified.dueAt.toUtc(), at.add(const Duration(days: 1)));
    });

    test('advance-anywhere: two lenses grading one card share ONE row',
        () async {
      // Two decks surfacing the same card both grade it through the same datum.
      final repo = SrsRepository(db);
      final at = DateTime.utc(2026, 3, 1, 9);
      await repo.recordReview(
          cardId: 'shared',
          sectionSlug: 's',
          grade: 3,
          outcome: _outcome(at, stability: 3));
      await repo.recordReview(
          cardId: 'shared',
          sectionSlug: 's',
          grade: 4,
          outcome: _outcome(at.add(const Duration(days: 1)), stability: 12));
      final rows = await StudyStateRepository(db).loadByKind(StudyKind.recall);
      expect(rows.length, 1, reason: 'one shared trace, not one per lens');
      expect(rows['shared::s']!.activityCount, 2);
      expect(rows['shared::s']!.stability, 12);
    });

    test('the algo two-clock stays two independent LIVE rows', () async {
      final at = DateTime.utc(2026, 3, 2, 9);
      await SrsRepository(db).recordReview(
          cardId: 'algo',
          sectionSlug: 'approach',
          grade: 3,
          outcome: _outcome(at, stability: 10));
      await RecognitionRepository(db).recordExplain(
          cardId: 'algo',
          sectionSlug: 'approach',
          outcome: ExplainOutcome.solid,
          now: at);
      final all = await StudyStateRepository(db).loadStates();
      expect(all.keys.toSet(), {'algo::approach', 'algo::recognize:approach'});
      expect(all['algo::approach']!.kind, StudyKind.recall.wire);
      expect(all['algo::approach']!.stability, 10);
      final practice = all['algo::recognize:approach']!;
      expect(practice.kind, StudyKind.practice.wire);
      expect(practice.intervalDays, 3, reason: 'first solid explanation → 3d');
      expect(practice.activityCount, 1, reason: 'streak 1 → activityCount');
    });

    test('rename + drop keep the unified recall row in sync', () async {
      final repo = SrsRepository(db);
      final at = DateTime.utc(2026, 3, 3, 9);
      await repo.recordReview(
          cardId: 'c', sectionSlug: 'old', grade: 3, outcome: _outcome(at));
      await repo.renameSection(cardId: 'c', oldSlug: 'old', newSlug: 'new');
      var rows = await StudyStateRepository(db).loadStates();
      expect(rows.containsKey('c::new'), isTrue);
      expect(rows.containsKey('c::old'), isFalse);
      await repo.dropSection(cardId: 'c', slug: 'new');
      rows = await StudyStateRepository(db).loadStates();
      expect(rows.containsKey('c::new'), isFalse);
    });

    test('dev seeds (seedStudied / seedAllDueNow) mirror to unified', () async {
      final repo = SrsRepository(db);
      final at = DateTime.utc(2026, 4, 1, 9);
      await repo.seedStudied([(cardId: 'c1', sectionSlug: 's', stability: 9.0)],
          at: at);
      await repo.seedAllDueNow([(cardId: 'c2', sectionSlug: 's')]);
      final rows = await StudyStateRepository(db).loadByKind(StudyKind.recall);
      expect(rows['c1::s']!.stability, 9);
      expect(rows['c1::s']!.activityCount, 2);
      expect(rows.containsKey('c2::s'), isTrue);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');

  // Exercises the ACTUAL v2→v3 onUpgrade invocation (not just backfillStudyStates
  // called directly): createTable(study_states) + the backfill, on a file-backed
  // DB rolled back to user_version 2. There is no drift schema-replay tooling, so
  // we simulate a v2 DB by dropping the table + resetting the version.
  group('v2→v3 upgrade path (onUpgrade)', () {
    test('onUpgrade creates + backfills study_states from the legacy clocks',
        () async {
      final dir = Directory.systemTemp.createTempSync('onyx_mig_');
      final file = File(p.join(dir.path, 'test.sqlite'));
      try {
        // Open at the current schema (v3) so onCreate builds every table, then
        // seed the two legacy clocks (incl. the algo two-clock on one section).
        var db = AppDatabase.withExecutor(NativeDatabase(file));
        await db.into(db.srsStates).insert(SrsStatesCompanion.insert(
              cardId: 'algo',
              sectionSlug: 'approach',
              stability: const Value(10),
              difficulty: const Value(6),
              state: const Value(2),
              step: const Value(null),
              dueAt: DateTime.utc(2026, 5, 1, 9),
              lastReview: Value(DateTime.utc(2026, 4, 20, 9)),
              reviewCount: const Value(3),
            ));
        await db.into(db.recognitionStates).insert(
              RecognitionStatesCompanion.insert(
                cardId: 'algo',
                sectionSlug: 'approach',
                lastExplainedAt: DateTime.utc(2026, 4, 18, 9),
                dueAt: DateTime.utc(2026, 4, 25, 9),
                intervalDays: 7,
                streak: const Value(2),
              ),
            );
        // Simulate a real v2 DB: study_states did not exist, user_version == 2.
        await db.customStatement('DROP TABLE study_states');
        await db.customStatement('PRAGMA user_version = 2');
        await db.close();

        // Reopen → drift sees user_version 2 < schemaVersion 3 → runs onUpgrade,
        // which must createTable(study_states) + backfillStudyStates().
        db = AppDatabase.withExecutor(NativeDatabase(file));
        final states = await StudyStateRepository(db).loadStates();
        expect(states.keys.toSet(),
            {'algo::approach', 'algo::recognize:approach'});
        expect(states['algo::approach']!.kind, StudyKind.recall.wire);
        expect(states['algo::approach']!.stability, 10);
        expect(states['algo::approach']!.activityCount, 3);
        final practice = states['algo::recognize:approach']!;
        expect(practice.kind, StudyKind.practice.wire);
        expect(practice.intervalDays, 7);
        expect(practice.activityCount, 2);
        await db.close();
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
