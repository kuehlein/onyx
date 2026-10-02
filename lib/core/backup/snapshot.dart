import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../dev.dart';
import '../settings/device_id.dart';
import '../settings/preferences_repository.dart';
import '../srs/study_state.dart';
import '../vault/vault_source.dart';

/// Backs up study progress to the vault's config dir and restores it. The vault is
/// the durable store (it syncs via the folder-sync tool and survives app reinstalls),
/// so this is what lets you pick up where you left off if the local database is lost.
///
/// **Per-device files** (ADR-0019): each device writes only its own
/// `_onyx/state/<deviceId>.json`, so two devices sharing the folder never write the
/// *same* file — closing the same-file write race the single `onyx-state.json` had
/// (ADR-0001's deferred follow-up). Restore **glob-merges every** device's file (plus
/// the pre-#159 single file, read-only back-compat) into local progress.
///
/// Cross-device reconciliation is a **convergent merge** — last-review-wins on keyed
/// state, union on the event logs — so any set of devices that share the folder reach
/// the same result with no data loss, in any sync order. See [mergeSnapshots] and
/// ADR-0001 (`docs/adr/0001-progress-sync-merge.md`).
///
/// Snapshots `study_states` (your schedule — the unified recall + practice record,
/// ADR-0024), `reviews` (your history — for future stats / FSRS tuning), and
/// `applied_attempts` (the Phase B mock-interview evidence behind interview
/// readiness), so all of it follows you across devices. `activity_log` is excluded;
/// it is debug/analytics only and not needed to resume.
///
/// **Format v4** (ADR-0024 slice 5) exports one `studyStates[]` array. Older v≤3
/// files (separate `srsStates`/`recognitionStates`) are still read **indefinitely**
/// — [mergeSnapshots] folds them into the unified shape — so an un-upgraded device
/// in a shared folder never loses progress.
class SnapshotService {
  SnapshotService(this._db, this._source);

  final AppDatabase _db;
  final VaultSource _source;

  /// The per-device state dir under the config dir: `state/<deviceId>.json`.
  static const stateDir = 'state';

  /// This device's own state file (config-dir-relative). Dev builds use a `.dev.json`
  /// suffix so desktop experimenting never mixes with the real, synced snapshot.
  static String deviceFile(String deviceId) => isDevDataMode
      ? '$stateDir/$deviceId.dev.json'
      : '$stateDir/$deviceId.json';

  /// The pre-#159 single shared snapshot file. **Read-only** back-compat: merged in on
  /// restore, never written anymore (writing a shared file would reopen the write race).
  static String get legacyFileName =>
      isDevDataMode ? 'onyx-state.dev.json' : 'onyx-state.json';

  /// True if [name] (a config-dir-relative path) is a state file for the CURRENT data
  /// mode — dev reads only `.dev.json`, prod only plain `.json`.
  static bool _matchesMode(String name) =>
      name.endsWith('.json') && (name.endsWith('.dev.json') == isDevDataMode);

  Future<String> _deviceId() => resolveDeviceId(PreferencesRepository(_db));

  // Bumped as the shape changes (v2: appliedAttempts, v3: recognition, v4: the
  // unified studyStates record — ADR-0024). Older files restore fine: mergeSnapshots
  // folds v≤3 into the unified shape.
  static const _version = 4;

  Future<bool> isDbEmpty() async =>
      (await (_db.select(_db.studyStates)..limit(1)).get()).isEmpty;

  Future<bool> hasSnapshot() async {
    final stateFiles = await _source.listMeta(stateDir);
    if (stateFiles.any(_matchesMode)) return true;
    return (await _source.readMeta(legacyFileName)) != null;
  }

  /// The current DB progress as a snapshot payload — the same shape written to
  /// disk. The "local" side of the merge in both [export] and [restore].
  Future<Map<String, dynamic>> _localPayload() async {
    final study = await _db.select(_db.studyStates).get();
    final reviews = await _db.select(_db.reviews).get();
    final applied = await _db.select(_db.appliedAttempts).get();
    return {
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'studyStates': [for (final s in study) _studyToJson(s)],
      'reviews': [for (final r in reviews) _reviewToJson(r)],
      'appliedAttempts': [for (final a in applied) _appliedToJson(a)],
    };
  }

  /// One on-disk snapshot file, decoded, or null if absent/unparseable.
  Future<Map<String, dynamic>?> _readOne(String name) async {
    final raw = await _source.readMeta(name);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null; // a corrupt/half-synced file is skipped, not fatal
    }
  }

  /// Every on-disk snapshot merged into one payload: all per-device state files (for
  /// the current data mode) plus the pre-#159 single file (read-only back-compat).
  /// Null if none exist. The merge is convergent, so file order doesn't matter.
  Future<Map<String, dynamic>?> _readAllSnapshots() async {
    final names = [
      for (final n in await _source.listMeta(stateDir))
        if (_matchesMode(n)) n,
      legacyFileName,
    ];
    Map<String, dynamic>? acc;
    for (final n in names) {
      final one = await _readOne(n);
      if (one == null) continue;
      acc = acc == null ? one : mergeSnapshots(acc, one);
    }
    return acc;
  }

  /// Write current progress to **this device's own** state file, merged with its own
  /// prior contents so a transiently-empty DB can never shrink it (union-only). Only
  /// this device ever writes this file, so a folder-syncer never sees two devices
  /// write the same file — the write race the single shared file had. Other devices'
  /// files (and the legacy one) are untouched. See [mergeSnapshots] + ADR-0001/0019.
  Future<void> export() async {
    final name = deviceFile(await _deviceId());
    final local = await _localPayload();
    final own = await _readOne(name);
    final merged = own == null ? local : mergeSnapshots(own, local);
    await _source.writeMeta(name, jsonEncode(merged));
  }

  /// Merge every device's snapshot into local progress. Returns the number of sections
  /// after the merge, or 0 if there are none. **Non-destructive:** the DB is rewritten
  /// to the *union* of local + all snapshots, so no review or attempt is lost and
  /// per-section state resolves to the most recently reviewed side. (The `DELETE`+insert
  /// is safe because the merged set is a superset of local — the property the old
  /// destructive restore lacked.) See [mergeSnapshots] + ADR-0001.
  Future<int> restore() async {
    final incoming = await _readAllSnapshots();
    if (incoming == null) return 0;
    final local = await _localPayload();
    final merged = mergeSnapshots(local, incoming);
    await _applyPayload(merged);
    return (merged['studyStates'] as List).length;
  }

  /// Wipe the local progress tables (the derived cache) — used when SWITCHING
  /// content folders, *after* the outgoing folder's snapshot has been exported.
  /// Each folder's `_onyx/state/` snapshot stays the durable copy (ADR-0001/0002), so
  /// switching away and back loses nothing. Table set kept in sync with
  /// [_applyPayload].
  static Future<void> clearProgress(AppDatabase db) async {
    await db.transaction(() async {
      await db.delete(db.srsStates).go();
      await db.delete(db.reviews).go();
      await db.delete(db.appliedAttempts).go();
      await db.delete(db.recognitionStates).go();
      // The unified mirror (ADR-0024) is derived from the two legacy clocks, so
      // it is wiped alongside them — else a vault switch would bleed the outgoing
      // vault's unified rows into the next (invisible until slice 5 reads them).
      await db.delete(db.studyStates).go();
    });
  }

  /// Replace the DB tables with [data] (the merged union, already v4-shaped by
  /// [mergeSnapshots]). Private: callers pass a payload that already folds in the
  /// local rows (see [restore]). Writes the unified `study_states` directly; the
  /// legacy state tables are cleared but not written — they're no longer read
  /// (ADR-0024 slice 5a) and are dropped in slice 7.
  Future<void> _applyPayload(Map<String, dynamic> data) async {
    List<Map<String, dynamic>> rows(String key) =>
        (data[key] as List? ?? const []).cast<Map<String, dynamic>>();
    final study = rows('studyStates');
    final reviews = rows('reviews');
    final applied = rows('appliedAttempts');

    await _db.transaction(() async {
      await _db.delete(_db.srsStates).go();
      await _db.delete(_db.recognitionStates).go();
      await _db.delete(_db.studyStates).go();
      await _db.delete(_db.reviews).go();
      await _db.delete(_db.appliedAttempts).go();
      await _db.batch((b) {
        b.insertAll(
            _db.studyStates, [for (final s in study) _studyFromJson(s)]);
        b.insertAll(_db.reviews, [for (final r in reviews) _reviewFromJson(r)]);
        b.insertAll(_db.appliedAttempts,
            [for (final a in applied) _appliedFromJson(a)]);
      });
    });
  }

  Map<String, dynamic> _studyToJson(StudyState s) => {
        'cardId': s.cardId,
        'dataSlug': s.dataSlug,
        'kind': s.kind,
        'dueAt': s.dueAt.toUtc().toIso8601String(),
        'lastActivityAt': s.lastActivityAt?.toUtc().toIso8601String(),
        'activityCount': s.activityCount,
        'stability': s.stability,
        'difficulty': s.difficulty,
        'fsrsState': s.fsrsState,
        'step': s.step,
        'intervalDays': s.intervalDays,
      };

  StudyStatesCompanion _studyFromJson(Map<String, dynamic> m) =>
      StudyStatesCompanion.insert(
        cardId: m['cardId'] as String,
        dataSlug: m['dataSlug'] as String,
        kind: m['kind'] as String,
        dueAt: DateTime.parse(m['dueAt'] as String),
        lastActivityAt: Value(m['lastActivityAt'] == null
            ? null
            : DateTime.parse(m['lastActivityAt'] as String)),
        activityCount: Value(m['activityCount'] as int? ?? 0),
        stability: Value((m['stability'] as num?)?.toDouble()),
        difficulty: Value((m['difficulty'] as num?)?.toDouble()),
        fsrsState: Value(m['fsrsState'] as int?),
        step: Value(m['step'] as int?),
        intervalDays: Value(m['intervalDays'] as int?),
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
///  * **Keyed state** (`studyStates`) resolves per datum `(cardId, dataSlug)` to the
///    most recent side (last-activity-wins on `lastActivityAt`, tie-broken by the
///    higher `activityCount`).
///  * **Event logs** (`reviews`, `appliedAttempts`) are unioned by a natural event
///    key, so history is never dropped and re-merging is a no-op.
///
/// Either input may be an older v≤3 file (separate `srsStates`/`recognitionStates`);
/// [_foldLegacyToStudy] normalizes both sides to the unified v4 shape first, so an
/// un-upgraded device's file still merges without loss. Output row lists are sorted
/// by key so the serialized file is deterministic (less folder-sync churn).
Map<String, dynamic> mergeSnapshots(
    Map<String, dynamic> a, Map<String, dynamic> b) {
  final fa = _foldLegacyToStudy(a);
  final fb = _foldLegacyToStudy(b);
  String exportedAt(Map<String, dynamic> m) =>
      (m['exportedAt'] as String?) ?? '';
  final at = exportedAt(fa).compareTo(exportedAt(fb)) >= 0
      ? exportedAt(fa)
      : exportedAt(fb);
  return {
    'version': 4,
    if (at.isNotEmpty) 'exportedAt': at,
    'studyStates':
        _mergeStudyStates(_rows(fa, 'studyStates'), _rows(fb, 'studyStates')),
    'reviews':
        _mergeEvents(_rows(fa, 'reviews'), _rows(fb, 'reviews'), _reviewKey),
    'appliedAttempts': _mergeEvents(_rows(fa, 'appliedAttempts'),
        _rows(fb, 'appliedAttempts'), _appliedKey),
  };
}

/// Normalize a payload to the unified v4 shape: a v≤3 file's separate
/// `srsStates` / `recognitionStates` arrays fold into one `studyStates` array
/// (recall ← srs, practice ← recognition), using the same key mapping as the DB
/// migration ([studyDataSlug]). A v4 payload is returned unchanged. This is the
/// single place legacy-readability lives, so merge / restore / export downstream
/// only ever see the unified shape.
Map<String, dynamic> _foldLegacyToStudy(Map<String, dynamic> m) {
  if (((m['version'] as int?) ?? 0) >= 4) return m;
  final study = <Map<String, dynamic>>[
    for (final s in _rows(m, 'srsStates'))
      {
        'cardId': s['cardId'],
        'dataSlug': studyDataSlug(s['sectionSlug'] as String, StudyKind.recall),
        'kind': StudyKind.recall.wire,
        'dueAt': s['dueAt'],
        'lastActivityAt': s['lastReview'],
        'activityCount': s['reviewCount'],
        'stability': s['stability'],
        'difficulty': s['difficulty'],
        'fsrsState': s['state'],
        'step': s['step'],
        'intervalDays': null,
      },
    for (final r in _rows(m, 'recognitionStates'))
      {
        'cardId': r['cardId'],
        'dataSlug':
            studyDataSlug(r['sectionSlug'] as String, StudyKind.practice),
        'kind': StudyKind.practice.wire,
        'dueAt': r['dueAt'],
        'lastActivityAt': r['lastExplainedAt'],
        'activityCount': r['streak'],
        'stability': null,
        'difficulty': null,
        'fsrsState': null,
        'step': null,
        'intervalDays': r['intervalDays'],
      },
  ];
  return {
    'version': 4,
    if (m['exportedAt'] != null) 'exportedAt': m['exportedAt'],
    'studyStates': study,
    'reviews': m['reviews'] ?? const [],
    'appliedAttempts': m['appliedAttempts'] ?? const [],
  };
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> m, String key) =>
    (m[key] as List? ?? const []).cast<Map<String, dynamic>>();

String _dataKey(Map<String, dynamic> r) => '${r['cardId']} ${r['dataSlug']}';

/// Last-activity-wins per `(cardId, dataSlug)`, tie-broken by `activityCount`.
/// ISO-8601 UTC strings compare lexicographically as they order chronologically,
/// and a null/absent `lastActivityAt` (`''`) loses to any real one.
List<Map<String, dynamic>> _mergeStudyStates(
    List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final r in [...a, ...b]) {
    final k = _dataKey(r);
    final cur = byKey[k];
    if (cur == null || _studyNewer(r, cur)) byKey[k] = r;
  }
  return byKey.values.toList()
    ..sort((x, y) => _dataKey(x).compareTo(_dataKey(y)));
}

bool _studyNewer(Map<String, dynamic> cand, Map<String, dynamic> cur) {
  final cr = (cand['lastActivityAt'] as String?) ?? '';
  final ur = (cur['lastActivityAt'] as String?) ?? '';
  final cmp = cr.compareTo(ur);
  if (cmp != 0) return cmp > 0;
  return ((cand['activityCount'] as int?) ?? 0) >
      ((cur['activityCount'] as int?) ?? 0);
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
