import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../dev.dart';
import '../vault/vault_source.dart';

/// Backs up study progress to a single JSON file in the vault's `_meta/` folder,
/// and restores it. The vault is the durable store (it syncs via Obsidian and
/// survives app reinstalls), so this is what lets you pick up where you left off
/// if the local database is lost.
///
/// Snapshots `srs_state` (your schedule — the essential thing) and `reviews`
/// (your history — for future stats / FSRS tuning). `activity_log` is excluded;
/// it is debug/analytics only and not needed to resume.
class SnapshotService {
  SnapshotService(this._db, this._source);

  final AppDatabase _db;
  final VaultSource _source;

  /// Dev builds read/write a separate file so desktop experimenting never
  /// overwrites the real, synced snapshot.
  static String get fileName =>
      isDevDataMode ? 'onyx-state.dev.json' : 'onyx-state.json';
  static const _version = 1;

  Future<bool> isDbEmpty() async =>
      (await (_db.select(_db.srsStates)..limit(1)).get()).isEmpty;

  Future<bool> hasSnapshot() async =>
      (await _source.readMeta(fileName)) != null;

  /// Write the current progress to the vault snapshot (atomically).
  Future<void> export() async {
    final states = await _db.select(_db.srsStates).get();
    final reviews = await _db.select(_db.reviews).get();
    final json = jsonEncode({
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'srsStates': [for (final s in states) _srsToJson(s)],
      'reviews': [for (final r in reviews) _reviewToJson(r)],
    });
    await _source.writeMeta(fileName, json);
  }

  /// Replace local progress with the vault snapshot. Returns the number of
  /// restored sections, or 0 if there is no snapshot. Destructive: clears the
  /// existing `srs_state` / `reviews` first.
  Future<int> restore() async {
    final raw = await _source.readMeta(fileName);
    if (raw == null) return 0;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final states =
        (data['srsStates'] as List? ?? const []).cast<Map<String, dynamic>>();
    final reviews =
        (data['reviews'] as List? ?? const []).cast<Map<String, dynamic>>();

    await _db.transaction(() async {
      await _db.delete(_db.srsStates).go();
      await _db.delete(_db.reviews).go();
      await _db.batch((b) {
        b.insertAll(_db.srsStates, [for (final s in states) _srsFromJson(s)]);
        b.insertAll(_db.reviews, [for (final r in reviews) _reviewFromJson(r)]);
      });
    });
    return states.length;
  }

  Map<String, dynamic> _srsToJson(SrsState s) => {
        'cardId': s.cardId,
        'sectionSlug': s.sectionSlug,
        'stability': s.stability,
        'difficulty': s.difficulty,
        'state': s.state,
        'step': s.step,
        'dueAt': s.dueAt.toUtc().toIso8601String(),
        'lastReview': s.lastReview?.toUtc().toIso8601String(),
        'reviewCount': s.reviewCount,
      };

  SrsStatesCompanion _srsFromJson(Map<String, dynamic> m) =>
      SrsStatesCompanion.insert(
        cardId: m['cardId'] as String,
        sectionSlug: m['sectionSlug'] as String,
        stability: Value((m['stability'] as num).toDouble()),
        difficulty: Value((m['difficulty'] as num).toDouble()),
        state: Value(m['state'] as int),
        step: Value(m['step'] as int?),
        dueAt: DateTime.parse(m['dueAt'] as String),
        lastReview: Value(m['lastReview'] == null
            ? null
            : DateTime.parse(m['lastReview'] as String)),
        reviewCount: Value(m['reviewCount'] as int),
      );

  Map<String, dynamic> _reviewToJson(Review r) => {
        'cardId': r.cardId,
        'sectionSlug': r.sectionSlug,
        'reviewedAt': r.reviewedAt.toUtc().toIso8601String(),
        'grade': r.grade,
        'stability': r.stability,
        'difficulty': r.difficulty,
        'elapsedDays': r.elapsedDays,
      };

  ReviewsCompanion _reviewFromJson(Map<String, dynamic> m) =>
      ReviewsCompanion.insert(
        cardId: m['cardId'] as String,
        sectionSlug: m['sectionSlug'] as String,
        reviewedAt: DateTime.parse(m['reviewedAt'] as String),
        grade: m['grade'] as int,
        stability: (m['stability'] as num).toDouble(),
        difficulty: (m['difficulty'] as num).toDouble(),
        elapsedDays: (m['elapsedDays'] as num).toDouble(),
      );
}
