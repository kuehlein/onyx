import 'dart:io';

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

    test('kind round-trips through wire; an unknown value degrades to null',
        () {
      for (final k in StudyKind.values) {
        expect(StudyKind.fromWire(k.wire), k);
      }
      expect(StudyKind.fromWire('bogus-forward-incompatible'), isNull);
    });
  });

  group('writers persist the unified record (slice 4/5c)', () {
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

    test('both clocks on one section land as two unified rows', () async {
      final at = DateTime.utc(2026, 5, 1, 9);
      await SrsRepository(db).recordReview(
          cardId: 'c',
          sectionSlug: 's',
          grade: 3,
          outcome: _outcome(at, stability: 8));
      await RecognitionRepository(db).recordExplain(
          cardId: 'c',
          sectionSlug: 's',
          outcome: ExplainOutcome.solid,
          now: at);
      // Both clocks land in the unified record as two independent rows.
      expect((await StudyStateRepository(db).loadStates()).length, 2);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');

  // Exercises the v3→v4 onUpgrade: the legacy clocks are dropped. `deleteTable` is
  // first-use in this repo, so this pins that a real reopen removes them. There is
  // no drift schema-replay tooling, so we simulate a v3 DB by hand-creating the two
  // legacy tables via raw SQL and rolling user_version back to 3.
  group('v3→v4 upgrade path (drops the legacy tables)', () {
    test('onUpgrade drops srs_states + recognition_states, keeps study_states',
        () async {
      final dir = Directory.systemTemp.createTempSync('onyx_mig4_');
      final file = File(p.join(dir.path, 'test.sqlite'));
      try {
        // Open at the current schema (v4), then hand-recreate the two legacy
        // tables and roll user_version back to 3 — a DB that upgraded through v3.
        var db = AppDatabase.withExecutor(NativeDatabase(file));
        await db.customStatement(
            'CREATE TABLE srs_states (card_id TEXT NOT NULL, section_slug TEXT NOT NULL)');
        await db.customStatement(
            'CREATE TABLE recognition_states (card_id TEXT NOT NULL, section_slug TEXT NOT NULL)');
        await db.customStatement('PRAGMA user_version = 3');
        await db.close();

        // Reopen → drift sees user_version 3 < schemaVersion 4 → runs the from<4
        // step, dropping both legacy tables (DROP TABLE IF EXISTS).
        db = AppDatabase.withExecutor(NativeDatabase(file));
        await StudyStateRepository(db)
            .loadStates(); // force the migration to run
        final names = (await db
                .customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table'")
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
        expect(names, isNot(contains('srs_states')));
        expect(names, isNot(contains('recognition_states')));
        expect(names, contains('study_states'),
            reason: 'the unified record survives the drop');
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
