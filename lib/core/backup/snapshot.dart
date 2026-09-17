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
/// Cross-device reconciliation is a **convergent merge** — last-review-wins on
/// keyed state, union on the event logs — so two devices that share the folder
/// never clobber each other's progress. See [mergeSnapshots] and ADR-0001
/// (`docs/adr/0001-progress-sync-merge.md`).
///
/// Snapshots `srs_state` (your schedule — the essential thing), `reviews` (your
/// history — for future stats / FSRS tuning), `applied_attempts` (the Phase B
/// mock-interview evidence behind interview readiness), and `recognition_state`
/// (the algorithm track's explain clock), so all of it follows you across
/// devices. `activity_log` is excluded; it is debug/analytics only and not
/// needed to resume.
class SnapshotService {
  SnapshotService(this._db, this._source);

  final AppDatabase _db;
  final VaultSource _source;

  /// Dev builds read/write a separate file so desktop experimenting never
  /// overwrites the real, synced snapshot.
  static String get fileName =>
      isDevDataMode ? 'onyx-state.dev.json' : 'onyx-state.json';
  // Bumped as tables join the snapshot (v2: appliedAttempts, v3: recognition).
  // Older snapshots restore fine — a missing key just restores nothing for it.
  static const _version = 3;

  Future<bool> isDbEmpty() async =>
      (await (_db.select(_db.srsStates)..limit(1)).get()).isEmpty;

  Future<bool> hasSnapshot() async =>
      (await _source.readMeta(fileName)) != null;

  /// The current DB progress as a snapshot payload — the same shape written to
  /// disk. The "local" side of the merge in both [export] and [restore].
  Future<Map<String, dynamic>> _localPayload() async {
    final states = await _db.select(_db.srsStates).get();
    final reviews = await _db.select(_db.reviews).get();
    final applied = await _db.select(_db.appliedAttempts).get();
    final recognition = await _db.select(_db.recognitionStates).get();
    return {
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'srsStates': [for (final s in states) _srsToJson(s)],
      'reviews': [for (final r in reviews) _reviewToJson(r)],
      'appliedAttempts': [for (final a in applied) _appliedToJson(a)],
      'recognitionStates': [for (final r in recognition) _recognitionToJson(r)],
    };
  }

  /// The on-disk snapshot, decoded, or null if none exists.
  Future<Map<String, dynamic>?> _readSnapshot() async {
    final raw = await _source.readMeta(fileName);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Write current progress to the vault snapshot, **merged with whatever is
  /// already on disk** (read-merge-write). Merging on export preserves a snapshot
  /// that arrived from another device via folder-sync but has not been imported
  /// locally yet, instead of clobbering it. See [mergeSnapshots] + ADR-0001.
  Future<void> export() async {
    final local = await _localPayload();
    final existing = await _readSnapshot();
    final merged = existing == null ? local : mergeSnapshots(existing, local);
    await _source.writeMeta(fileName, jsonEncode(merged));
  }

  /// Merge the vault snapshot into local progress. Returns the number of sections
  /// after the merge, or 0 if there is no snapshot. **Non-destructive:** the DB is
  /// rewritten to the *union* of local + snapshot, so no review or attempt is lost
  /// and per-section state resolves to the most recently reviewed side. (The
  /// `DELETE`+insert is safe here because the merged set is a superset of local —
  /// the property the old destructive restore lacked.) See [mergeSnapshots] + ADR-0001.
  Future<int> restore() async {
    final incoming = await _readSnapshot();
    if (incoming == null) return 0;
    final local = await _localPayload();
    final merged = mergeSnapshots(local, incoming);
    await _applyPayload(merged);
    return (merged['srsStates'] as List).length;
  }

  /// Replace the DB tables with [data] (the merged union). Private: callers must
  /// pass a payload that already folds in the local rows (see [restore]).
  Future<void> _applyPayload(Map<String, dynamic> data) async {
    List<Map<String, dynamic>> rows(String key) =>
        (data[key] as List? ?? const []).cast<Map<String, dynamic>>();
    final states = rows('srsStates');
    final reviews = rows('reviews');
    final applied = rows('appliedAttempts');
    final recognition = rows('recognitionStates');

    await _db.transaction(() async {
      await _db.delete(_db.srsStates).go();
      await _db.delete(_db.reviews).go();
      await _db.delete(_db.appliedAttempts).go();
      await _db.delete(_db.recognitionStates).go();
      await _db.batch((b) {
        b.insertAll(_db.srsStates, [for (final s in states) _srsFromJson(s)]);
        b.insertAll(_db.reviews, [for (final r in reviews) _reviewFromJson(r)]);
        b.insertAll(_db.appliedAttempts,
            [for (final a in applied) _appliedFromJson(a)]);
        b.insertAll(_db.recognitionStates,
            [for (final r in recognition) _recognitionFromJson(r)]);
      });
    });
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

  Map<String, dynamic> _recognitionToJson(RecognitionState r) => {
        'cardId': r.cardId,
        'sectionSlug': r.sectionSlug,
        'lastExplainedAt': r.lastExplainedAt.toUtc().toIso8601String(),
        'dueAt': r.dueAt.toUtc().toIso8601String(),
        'intervalDays': r.intervalDays,
        'streak': r.streak,
      };

  RecognitionStatesCompanion _recognitionFromJson(Map<String, dynamic> m) =>
      RecognitionStatesCompanion.insert(
        cardId: m['cardId'] as String,
        sectionSlug: m['sectionSlug'] as String,
        lastExplainedAt: DateTime.parse(m['lastExplainedAt'] as String),
        dueAt: DateTime.parse(m['dueAt'] as String),
        intervalDays: m['intervalDays'] as int,
        streak: Value(m['streak'] as int? ?? 0),
      );

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

  Map<String, dynamic> _appliedToJson(AppliedAttempt a) => {
        'cardId': a.cardId,
        'sectionSlug': a.sectionSlug,
        'domain': a.domain,
        'occurredAt': a.occurredAt.toUtc().toIso8601String(),
        'appliedScore': a.appliedScore,
        'rubric': a.rubric,
        'novel': a.novel,
        'hintLevel': a.hintLevel,
        'source': a.source,
        'note': a.note,
        'verifierScore': a.verifierScore,
        'verified': a.verified,
      };

  AppliedAttemptsCompanion _appliedFromJson(Map<String, dynamic> m) =>
      AppliedAttemptsCompanion.insert(
        cardId: m['cardId'] as String,
        sectionSlug: Value(m['sectionSlug'] as String?),
        domain: Value(m['domain'] as String?),
        occurredAt: DateTime.parse(m['occurredAt'] as String),
        appliedScore: m['appliedScore'] as int,
        rubric: Value(m['rubric'] as String? ?? '{}'),
        novel: Value(m['novel'] as bool? ?? false),
        hintLevel: Value(m['hintLevel'] as int? ?? 0),
        source: m['source'] as String,
        note: Value(m['note'] as String?),
        verifierScore: Value(m['verifierScore'] as int?),
        verified: Value(m['verified'] as bool?),
      );
}

// ---------------------------------------------------------------------------
// Convergent snapshot merge (ADR-0001: docs/adr/0001-progress-sync-merge.md)
// ---------------------------------------------------------------------------

/// Merge two decoded snapshot payloads into their union — **commutative,
/// idempotent, and convergent** (a CRDT-style merge), so any two devices that
/// exchange snapshots (in any order, any number of times) reach the same result
/// with no data loss:
///
///  * **Keyed state** (`srsStates`, `recognitionStates`) resolves per section
///    `(cardId, sectionSlug)` to the most recently reviewed side (last-review-wins
///    on `lastReview` / `lastExplainedAt`, tie-broken by the higher `reviewCount`).
///  * **Event logs** (`reviews`, `appliedAttempts`) are unioned by a natural event
///    key, so history is never dropped and re-merging is a no-op.
///
/// Output row lists are sorted by key so the serialized file is deterministic
/// (stable across re-exports → less folder-sync churn). Replaces the old
/// last-write-wins-on-the-whole-blob behaviour that let the last device to export
/// clobber the other's progress.
Map<String, dynamic> mergeSnapshots(
    Map<String, dynamic> a, Map<String, dynamic> b) {
  int version(Map<String, dynamic> m) => (m['version'] as int?) ?? 0;
  String exportedAt(Map<String, dynamic> m) =>
      (m['exportedAt'] as String?) ?? '';
  final at = exportedAt(a).compareTo(exportedAt(b)) >= 0
      ? exportedAt(a)
      : exportedAt(b);
  return {
    'version': version(a) >= version(b) ? version(a) : version(b),
    if (at.isNotEmpty) 'exportedAt': at,
    'srsStates': _mergeKeyedState(
        _rows(a, 'srsStates'), _rows(b, 'srsStates'), 'lastReview'),
    'recognitionStates': _mergeKeyedState(_rows(a, 'recognitionStates'),
        _rows(b, 'recognitionStates'), 'lastExplainedAt'),
    'reviews':
        _mergeEvents(_rows(a, 'reviews'), _rows(b, 'reviews'), _reviewKey),
    'appliedAttempts': _mergeEvents(
        _rows(a, 'appliedAttempts'), _rows(b, 'appliedAttempts'), _appliedKey),
  };
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> m, String key) =>
    (m[key] as List? ?? const []).cast<Map<String, dynamic>>();

String _sectionKey(Map<String, dynamic> r) =>
    '${r['cardId']} ${r['sectionSlug']}';

/// Last-review-wins per `(cardId, sectionSlug)`, tie-broken by `reviewCount`.
/// [recencyField] is the ISO-8601 recency stamp for the table (`lastReview` /
/// `lastExplainedAt`); ISO-8601 UTC strings compare lexicographically as they
/// order chronologically, and a null/absent stamp (`''`) loses to any real one.
List<Map<String, dynamic>> _mergeKeyedState(List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b, String recencyField) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final r in [...a, ...b]) {
    final k = _sectionKey(r);
    final cur = byKey[k];
    if (cur == null || _stateNewer(r, cur, recencyField)) byKey[k] = r;
  }
  return byKey.values.toList()
    ..sort((x, y) => _sectionKey(x).compareTo(_sectionKey(y)));
}

bool _stateNewer(
    Map<String, dynamic> cand, Map<String, dynamic> cur, String recencyField) {
  final cr = (cand[recencyField] as String?) ?? '';
  final ur = (cur[recencyField] as String?) ?? '';
  final cmp = cr.compareTo(ur);
  if (cmp != 0) return cmp > 0;
  return ((cand['reviewCount'] as int?) ?? 0) >
      ((cur['reviewCount'] as int?) ?? 0);
}

/// Union of event rows, deduped by [keyOf], sorted by key for determinism.
List<Map<String, dynamic>> _mergeEvents(List<Map<String, dynamic>> a,
    List<Map<String, dynamic>> b, String Function(Map<String, dynamic>) keyOf) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final r in [...a, ...b]) {
    byKey.putIfAbsent(keyOf(r), () => r);
  }
  return byKey.values.toList()..sort((x, y) => keyOf(x).compareTo(keyOf(y)));
}

String _reviewKey(Map<String, dynamic> r) =>
    '${r['cardId']} ${r['sectionSlug']} ${r['reviewedAt']}';

String _appliedKey(Map<String, dynamic> r) =>
    '${r['cardId']} ${r['sectionSlug']} ${r['occurredAt']} ${r['source']}';
