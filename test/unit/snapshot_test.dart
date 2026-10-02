import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/backup/snapshot.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/interview/applied_repository.dart';
import 'package:onyx/core/interview/assessment.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
import 'package:onyx/core/srs/study_state.dart';
import 'package:onyx/core/srs/study_state_repository.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
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

ReviewOutcome _outcome(DateTime at, double stability) => ReviewOutcome(
      stability: stability,
      difficulty: 5,
      state: 2,
      step: null,
      due: at.add(const Duration(days: 3)),
      lastReview: at,
      elapsedDays: 0,
    );

void main() {
  group('SnapshotService', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('onyx_snap_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('export then restore round-trips srs_state and reviews', () async {
      final at = DateTime.utc(2026, 1, 1, 9);
      final source = DesktopVaultSource(root.path);

      // Source DB with two reviewed sections.
      final db1 = AppDatabase.withExecutor(NativeDatabase.memory());
      final repo = SrsRepository(db1);
      await repo.recordReview(
          cardId: 'a', sectionSlug: 's1', grade: 3, outcome: _outcome(at, 8));
      await repo.recordReview(
          cardId: 'b', sectionSlug: 's2', grade: 4, outcome: _outcome(at, 20));
      await SnapshotService(db1, source).export();
      await db1.close();

      // A per-device state file landed under _onyx/state/ (ADR-0019).
      final stateDir =
          Directory(p.join(root.path, '_onyx', SnapshotService.stateDir));
      expect(
        stateDir.existsSync() &&
            stateDir
                .listSync()
                .whereType<File>()
                .any((f) => f.path.endsWith('.json')),
        isTrue,
      );

      // A fresh DB restores it.
      final db2 = AppDatabase.withExecutor(NativeDatabase.memory());
      final restored = await SnapshotService(db2, source).restore();
      expect(restored, 2);

      final states = await SrsRepository(db2).loadStates();
      expect(states.values.map((s) => s.cardId).toSet(), {'a', 'b'});
      final a = states['a::s1']!;
      expect(a.sectionSlug, 's1');
      expect(a.stability, 8);
      expect(a.reviewCount, 1);

      final reviews = await db2.select(db2.reviews).get();
      expect(reviews.length, 2);
      await db2.close();
    });

    test('export/restore round-trips applied_attempts', () async {
      final at = DateTime.utc(2026, 2, 1, 9);
      final source = DesktopVaultSource(root.path);

      final db1 = AppDatabase.withExecutor(NativeDatabase.memory());
      final applied = AppliedRepository(db1);
      final id = await applied.record(
        cardId: 'a',
        sectionSlug: 's1',
        domain: 'ds-a',
        source: 'interview-coach',
        occurredAt: at,
        assessment: const AppliedAssessment(
          appliedScore: 72,
          rubric: {'correctness': 4},
          novel: true,
          hintLevel: 1,
        ),
      );
      await applied.recordVerdict(
          attemptId: id, verifierScore: 60, verified: true);
      await SnapshotService(db1, source).export();
      await db1.close();

      final db2 = AppDatabase.withExecutor(NativeDatabase.memory());
      await SnapshotService(db2, source).restore();
      final rows = await AppliedRepository(db2).attempts();
      expect(rows.length, 1);
      final a = rows.single;
      expect(a.cardId, 'a');
      expect(a.domain, 'ds-a');
      expect(a.appliedScore, 72);
      expect(a.novel, isTrue);
      expect(a.hintLevel, 1);
      expect(AppliedAssessment.decodeRubric(a.rubric), {'correctness': 4});
      expect(a.verifierScore, 60);
      expect(a.verified, isTrue);
      await db2.close();
    });

    test('restore rebuilds the unified study_states mirror (ADR-0024 S4)',
        () async {
      final at = DateTime.utc(2026, 1, 1, 9);
      final source = DesktopVaultSource(root.path);

      final db1 = AppDatabase.withExecutor(NativeDatabase.memory());
      await SrsRepository(db1).recordReview(
          cardId: 'a', sectionSlug: 's1', grade: 3, outcome: _outcome(at, 8));
      await SnapshotService(db1, source).export();
      await db1.close();

      // A fresh DB restores: the legacy clocks AND the unified mirror must land,
      // so a reader turned on later (slice 5) sees the restored schedule.
      final db2 = AppDatabase.withExecutor(NativeDatabase.memory());
      await SnapshotService(db2, source).restore();
      final unified = await StudyStateRepository(db2).loadStates();
      expect(unified['a::s1'], isNotNull,
          reason: 'restore rebuilt the unified recall datum');
      expect(unified['a::s1']!.kind, StudyKind.recall.wire);
      expect(unified['a::s1']!.stability, 8);
      await db2.close();
    });

    test('clearProgress wipes the unified study_states mirror (ADR-0024 S4)',
        () async {
      final at = DateTime.utc(2026, 1, 1, 9);
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      await SrsRepository(db).recordReview(
          cardId: 'a', sectionSlug: 's1', grade: 3, outcome: _outcome(at, 8));
      expect((await StudyStateRepository(db).loadStates()), isNotEmpty);
      await SnapshotService.clearProgress(db);
      expect((await StudyStateRepository(db).loadStates()), isEmpty,
          reason:
              'vault switch must not bleed unified rows into the next vault');
      await db.close();
    });

    test('restore is a no-op when no snapshot exists', () async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final restored =
          await SnapshotService(db, DesktopVaultSource(root.path)).restore();
      expect(restored, 0);
      await db.close();
    });

    test('isDbEmpty reflects srs_state presence', () async {
      final at = DateTime.utc(2026, 1, 1, 9);
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final service = SnapshotService(db, DesktopVaultSource(root.path));
      expect(await service.isDbEmpty(), isTrue);
      await SrsRepository(db).recordReview(
          cardId: 'a', sectionSlug: 's1', grade: 3, outcome: _outcome(at, 8));
      expect(await service.isDbEmpty(), isFalse);
      await db.close();
    });

    test("two devices converge without losing either's progress", () async {
      final at1 = DateTime.utc(2026, 3, 1, 9);
      final at2 = DateTime.utc(2026, 3, 2, 9);
      final source = DesktopVaultSource(root.path); // one shared folder

      // Device 1 studies card X and exports.
      final d1 = AppDatabase.withExecutor(NativeDatabase.memory());
      await SrsRepository(d1).recordReview(
          cardId: 'X', sectionSlug: 's1', grade: 3, outcome: _outcome(at1, 8));
      await SnapshotService(d1, source).export();

      // Device 2 studies card Y (its DB is non-empty), then merges the folder.
      final d2 = AppDatabase.withExecutor(NativeDatabase.memory());
      await SrsRepository(d2).recordReview(
          cardId: 'Y', sectionSlug: 's2', grade: 4, outcome: _outcome(at2, 20));
      await SnapshotService(d2, source).restore(); // merge, non-destructive

      // Device 2 now has BOTH X and Y (old blob-LWW would have dropped one).
      expect(
          (await SrsRepository(d2).loadStates())
              .values
              .map((s) => s.cardId)
              .toSet(),
          {'X', 'Y'});

      // Device 2 exports to ITS OWN file (containing X + Y, since its DB has both).
      await SnapshotService(d2, source).export();

      // Device 1 glob-merges every device's file and also converges to X + Y.
      await SnapshotService(d1, source).restore();
      expect(
          (await SrsRepository(d1).loadStates())
              .values
              .map((s) => s.cardId)
              .toSet(),
          {'X', 'Y'});
      // Both review events survived on both devices.
      expect((await d1.select(d1.reviews).get()).length, 2);
      expect((await d2.select(d2.reviews).get()).length, 2);

      await d1.close();
      await d2.close();
    });

    test('each device writes its OWN file (no shared-file write race)',
        () async {
      final source = DesktopVaultSource(root.path);
      final d1 = AppDatabase.withExecutor(NativeDatabase.memory());
      final d2 = AppDatabase.withExecutor(NativeDatabase.memory());
      await SrsRepository(d1).recordReview(
          cardId: 'X',
          sectionSlug: 's',
          grade: 3,
          outcome: _outcome(DateTime.utc(2026, 5, 1, 9), 8));
      await SrsRepository(d2).recordReview(
          cardId: 'Y',
          sectionSlug: 's',
          grade: 3,
          outcome: _outcome(DateTime.utc(2026, 5, 2, 9), 8));
      await SnapshotService(d1, source).export();
      await SnapshotService(d2, source).export();

      // Two devices → two distinct files under state/; neither wrote the other's
      // (nor a shared file), so a folder-syncer has nothing to conflict on.
      final files =
          Directory(p.join(root.path, '_onyx', SnapshotService.stateDir))
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList();
      expect(files.length, 2);
      await d1.close();
      await d2.close();
    });

    test('restores a pre-#159 legacy single file (read-only back-compat)',
        () async {
      final at = DateTime.utc(2026, 6, 1, 9);
      final source = DesktopVaultSource(root.path);

      // Build a valid snapshot payload by exporting, then MOVE it to the legacy
      // single-file path — simulating a vault written before #159.
      final seed = AppDatabase.withExecutor(NativeDatabase.memory());
      await SrsRepository(seed).recordReview(
          cardId: 'L', sectionSlug: 's', grade: 3, outcome: _outcome(at, 8));
      await SnapshotService(seed, source).export();
      await seed.close();
      final stateDir =
          Directory(p.join(root.path, '_onyx', SnapshotService.stateDir));
      final deviceFile = stateDir.listSync().whereType<File>().first;
      final payload = deviceFile.readAsStringSync();
      stateDir.deleteSync(recursive: true); // no per-device files remain
      File(p.join(root.path, '_onyx', SnapshotService.legacyFileName))
        ..createSync(recursive: true)
        ..writeAsStringSync(payload);

      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final svc = SnapshotService(db, source);
      expect(await svc.hasSnapshot(), isTrue, reason: 'the legacy file counts');
      expect(await svc.restore(), 1);
      expect((await SrsRepository(db).loadStates()).values.single.cardId, 'L');
      await db.close();
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
