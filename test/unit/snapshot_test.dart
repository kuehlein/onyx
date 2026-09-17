import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/backup/snapshot.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/interview/applied_repository.dart';
import 'package:onyx/core/interview/assessment.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
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

      // The snapshot file landed in _meta/.
      expect(
        File(p.join(root.path, '_meta', SnapshotService.fileName)).existsSync(),
        isTrue,
      );

      // A fresh DB restores it.
      final db2 = AppDatabase.withExecutor(NativeDatabase.memory());
      final restored = await SnapshotService(db2, source).restore();
      expect(restored, 2);

      final states = await db2.select(db2.srsStates).get();
      expect(states.map((s) => s.cardId).toSet(), {'a', 'b'});
      final a = states.firstWhere((s) => s.cardId == 'a');
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
      expect((await d2.select(d2.srsStates).get()).map((s) => s.cardId).toSet(),
          {'X', 'Y'});

      // Device 2 exports; the file must still contain X (read-merge-write).
      await SnapshotService(d2, source).export();

      // Device 1 merges and also converges to X + Y.
      await SnapshotService(d1, source).restore();
      expect((await d1.select(d1.srsStates).get()).map((s) => s.cardId).toSet(),
          {'X', 'Y'});
      // Both review events survived on both devices.
      expect((await d1.select(d1.reviews).get()).length, 2);
      expect((await d2.select(d2.reviews).get()).length, 2);

      await d1.close();
      await d2.close();
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
