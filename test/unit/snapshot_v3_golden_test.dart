import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/backup/snapshot.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/interview/assessment.dart';
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

/// A LITERAL, hand-authored v3 snapshot — the exact on-disk shape real users
/// have in their vault `_onyx/state/` today (schema v3: srs + reviews + applied +
/// recognition). Deliberately exercises the edge cases the serializer must keep
/// honoring: a null `step` AND null `lastReview` on one srs row, a relearning
/// row (state 3, step 1), and an applied attempt with every nullable optional
/// absent (domain / note / verifierScore / verified = null) + the default-shaped
/// rubric string.
///
/// Raw string (`r'''`) so the escaped quotes inside the `rubric` JSON stay
/// byte-exact rather than being unescaped by Dart.
const _v3Snapshot = r'''
{
  "version": 3,
  "exportedAt": "2026-02-03T12:00:00.000Z",
  "srsStates": [
    {"cardId": "algo-two-sum", "sectionSlug": "approach", "stability": 12.5, "difficulty": 6.25, "state": 2, "step": null, "dueAt": "2026-02-15T09:00:00.000Z", "lastReview": "2026-02-03T09:00:00.000Z", "reviewCount": 4},
    {"cardId": "concept-btree", "sectionSlug": "when-to-use", "stability": 2.0, "difficulty": 7.1, "state": 3, "step": 1, "dueAt": "2026-02-04T09:10:00.000Z", "lastReview": null, "reviewCount": 2}
  ],
  "reviews": [
    {"cardId": "algo-two-sum", "sectionSlug": "approach", "reviewedAt": "2026-02-03T09:00:00.000Z", "grade": 3, "stability": 12.5, "difficulty": 6.25, "elapsedDays": 9.0}
  ],
  "appliedAttempts": [
    {"cardId": "algo-two-sum", "sectionSlug": null, "domain": null, "occurredAt": "2026-02-03T10:00:00.000Z", "appliedScore": 78, "rubric": "{\"correctness\":4,\"communication\":3}", "novel": true, "hintLevel": 0, "source": "interview-coach", "note": null, "verifierScore": null, "verified": null}
  ],
  "recognitionStates": [
    {"cardId": "algo-two-sum", "sectionSlug": "approach", "lastExplainedAt": "2026-02-01T09:00:00.000Z", "dueAt": "2026-02-08T09:00:00.000Z", "intervalDays": 7, "streak": 2}
  ]
}
''';

void main() {
  // GOLDEN: freezes the v3 on-disk snapshot contract. Unlike snapshot_test.dart
  // (which round-trips through the live serializer, so its fixtures move WITH any
  // format change), this feeds a literal v3 file through `restore()` and asserts
  // every field lands byte-exact. When Stream A changes the snapshot format
  // (ADR-0024, v3 → v4), THIS test must still pass unchanged — that is the proof
  // the new code stays legacy-readable and never orphans a real user's schedule.
  group('v3 snapshot golden (legacy-readable contract)', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('onyx_v3golden_'));
    tearDown(() => root.deleteSync(recursive: true));

    test('a literal v3 file restores every field byte-exact', () async {
      final source = DesktopVaultSource(root.path);
      // Write the literal fixture to a mode-correct per-device state file, exactly
      // where a synced vault would carry it (_onyx/state/<id>.json).
      final name = SnapshotService.deviceFile('golden');
      File(p.join(root.path, '_onyx', name))
        ..createSync(recursive: true)
        ..writeAsStringSync(_v3Snapshot);

      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      final svc = SnapshotService(db, source);
      expect(await svc.hasSnapshot(), isTrue);
      expect(await svc.restore(), 2, reason: 'two srs sections restored');

      // --- srs_state: both rows, every column, incl. the null edge cases. ---
      final srs = {
        for (final s in await db.select(db.srsStates).get()) s.cardId: s,
      };
      expect(srs.keys.toSet(), {'algo-two-sum', 'concept-btree'});

      final a = srs['algo-two-sum']!;
      expect(a.sectionSlug, 'approach');
      expect(a.stability, 12.5);
      expect(a.difficulty, 6.25);
      expect(a.state, 2);
      expect(a.step, isNull);
      expect(a.reviewCount, 4);
      expect(a.dueAt.toUtc(), DateTime.utc(2026, 2, 15, 9));
      expect(a.lastReview?.toUtc(), DateTime.utc(2026, 2, 3, 9));

      final b = srs['concept-btree']!;
      expect(b.sectionSlug, 'when-to-use');
      expect(b.stability, 2.0);
      expect(b.difficulty, 7.1);
      expect(b.state, 3, reason: 'relearning state preserved');
      expect(b.step, 1);
      expect(b.reviewCount, 2);
      expect(b.dueAt.toUtc(), DateTime.utc(2026, 2, 4, 9, 10));
      expect(b.lastReview, isNull,
          reason: 'null lastReview survives round-trip');

      // --- reviews: the append-only log row, exact doubles. ---
      final review = (await db.select(db.reviews).get()).single;
      expect(review.cardId, 'algo-two-sum');
      expect(review.sectionSlug, 'approach');
      expect(review.grade, 3);
      expect(review.stability, 12.5);
      expect(review.difficulty, 6.25);
      expect(review.elapsedDays, 9.0);
      expect(review.reviewedAt.toUtc(), DateTime.utc(2026, 2, 3, 9));

      // --- applied_attempts: all nullable optionals absent + rubric decodes. ---
      final applied = (await db.select(db.appliedAttempts).get()).single;
      expect(applied.cardId, 'algo-two-sum');
      expect(applied.sectionSlug, isNull);
      expect(applied.domain, isNull);
      expect(applied.appliedScore, 78);
      expect(applied.novel, isTrue);
      expect(applied.hintLevel, 0);
      expect(applied.source, 'interview-coach');
      expect(applied.note, isNull);
      expect(applied.verifierScore, isNull);
      expect(applied.verified, isNull);
      expect(applied.occurredAt.toUtc(), DateTime.utc(2026, 2, 3, 10));
      expect(AppliedAssessment.decodeRubric(applied.rubric),
          {'correctness': 4, 'communication': 3});

      // --- recognition_state: the explain clock, every column. ---
      final rec = (await db.select(db.recognitionStates).get()).single;
      expect(rec.cardId, 'algo-two-sum');
      expect(rec.sectionSlug, 'approach');
      expect(rec.intervalDays, 7);
      expect(rec.streak, 2);
      expect(rec.dueAt.toUtc(), DateTime.utc(2026, 2, 8, 9));
      expect(rec.lastExplainedAt.toUtc(), DateTime.utc(2026, 2, 1, 9));

      await db.close();
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
