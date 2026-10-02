import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/backup/snapshot.dart';

/// Pure properties of [mergeSnapshots] (ADR-0001, now over the unified v4 shape —
/// ADR-0024). No DB / sqlite — this proves the convergent-merge core is
/// commutative, idempotent, and loss-free, and that it still folds older v≤3 files.

Map<String, dynamic> _study(
  String card,
  String slug, {
  String? lastActivityAt,
  int activityCount = 1,
  double stability = 5,
  String kind = 'recall',
}) =>
    {
      'cardId': card,
      'dataSlug': slug,
      'kind': kind,
      'dueAt': '2026-01-10T00:00:00.000Z',
      'lastActivityAt': lastActivityAt,
      'activityCount': activityCount,
      'stability': stability,
      'difficulty': 5.0,
      'fsrsState': 2,
      'step': null,
      'intervalDays': null,
    };

Map<String, dynamic> _review(String card, String sec, String at) => {
      'cardId': card,
      'sectionSlug': sec,
      'reviewedAt': at,
      'grade': 3,
      'stability': 5.0,
      'difficulty': 5.0,
      'elapsedDays': 0.0,
    };

Map<String, dynamic> _payload({
  List<Map<String, dynamic>> study = const [],
  List<Map<String, dynamic>> reviews = const [],
  String exportedAt = '2026-01-01T00:00:00.000Z',
  int version = 4,
}) =>
    {
      'version': version,
      'exportedAt': exportedAt,
      'studyStates': study,
      'reviews': reviews,
      'appliedAttempts': <Map<String, dynamic>>[],
    };

List<Map<String, dynamic>> _studyRows(Map<String, dynamic> m) =>
    (m['studyStates'] as List).cast<Map<String, dynamic>>();
List<Map<String, dynamic>> _reviewRows(Map<String, dynamic> m) =>
    (m['reviews'] as List).cast<Map<String, dynamic>>();

String _rk(Map<String, dynamic> r) =>
    '${r['cardId']}/${r['sectionSlug']}/${r['reviewedAt']}';
Set<String> _reviewKeys(Map<String, dynamic> m) =>
    _reviewRows(m).map(_rk).toSet();

void main() {
  group('mergeSnapshots', () {
    const t1 = '2026-01-01T09:00:00.000Z';
    const t2 = '2026-01-02T09:00:00.000Z';

    test('unions event logs — no review is lost', () {
      final a = _payload(reviews: [_review('a', 's1', t1)]);
      final b = _payload(reviews: [_review('b', 's2', t2)]);
      final merged = mergeSnapshots(a, b);
      expect(_reviewRows(merged).length, 2);
      expect(_reviewKeys(merged), {'a/s1/$t1', 'b/s2/$t2'});
    });

    test('dedups identical events by natural key', () {
      final a = _payload(reviews: [_review('a', 's1', t1)]);
      final b = _payload(reviews: [_review('a', 's1', t1)]);
      expect(_reviewRows(mergeSnapshots(a, b)).length, 1);
    });

    test('keyed state resolves last-activity-wins', () {
      final older = _payload(
          study: [_study('a', 's1', lastActivityAt: t1, stability: 5)]);
      final newer = _payload(
          study: [_study('a', 's1', lastActivityAt: t2, stability: 9)]);
      final merged = mergeSnapshots(older, newer);
      expect(_studyRows(merged).length, 1);
      expect(_studyRows(merged).single['stability'], 9);
    });

    test('ties on recency break toward the higher activityCount', () {
      final a = _payload(study: [
        _study('a', 's1', lastActivityAt: t1, activityCount: 1, stability: 5)
      ]);
      final b = _payload(study: [
        _study('a', 's1', lastActivityAt: t1, activityCount: 3, stability: 9)
      ]);
      expect(mergeSnapshots(a, b).let(_studyRows).single['activityCount'], 3);
      expect(mergeSnapshots(b, a).let(_studyRows).single['activityCount'], 3);
    });

    test('a real recency stamp beats a null/absent one', () {
      final withNull = _payload(
          study: [_study('a', 's1', lastActivityAt: null, stability: 5)]);
      final withReal = _payload(
          study: [_study('a', 's1', lastActivityAt: t1, stability: 9)]);
      expect(
          mergeSnapshots(withNull, withReal)
              .let(_studyRows)
              .single['stability'],
          9);
      expect(
          mergeSnapshots(withReal, withNull)
              .let(_studyRows)
              .single['stability'],
          9);
    });

    test('recall and practice on one section stay distinct (dataSlug keys)',
        () {
      final merged = mergeSnapshots(
        _payload(study: [_study('a', 's1', lastActivityAt: t1)]),
        _payload(study: [
          _study('a', 'recognize:s1', lastActivityAt: t1, kind: 'practice')
        ]),
      );
      expect(_studyRows(merged).map((r) => r['dataSlug']).toSet(),
          {'s1', 'recognize:s1'});
    });

    test('folds an older v≤3 payload into the unified shape (no loss)', () {
      final v3 = {
        'version': 3,
        'exportedAt': '2026-01-01T00:00:00.000Z',
        'srsStates': [
          {
            'cardId': 'a',
            'sectionSlug': 's1',
            'stability': 9.0,
            'difficulty': 5.0,
            'state': 2,
            'step': null,
            'dueAt': '2026-01-10T00:00:00.000Z',
            'lastReview': t1,
            'reviewCount': 2,
          }
        ],
        'recognitionStates': [
          {
            'cardId': 'a',
            'sectionSlug': 's1',
            'lastExplainedAt': t1,
            'dueAt': '2026-01-08T00:00:00.000Z',
            'intervalDays': 7,
            'streak': 3,
          }
        ],
        'reviews': <Map<String, dynamic>>[],
        'appliedAttempts': <Map<String, dynamic>>[],
      };
      final merged = mergeSnapshots(v3, <String, dynamic>{});
      final rows = _studyRows(merged);
      expect(rows.length, 2, reason: 'recall + practice, no collision');
      final recall = rows.firstWhere((r) => r['kind'] == 'recall');
      expect(recall['dataSlug'], 's1');
      expect(recall['stability'], 9.0);
      expect(recall['activityCount'], 2); // reviewCount → activityCount
      final practice = rows.firstWhere((r) => r['kind'] == 'practice');
      expect(practice['dataSlug'], 'recognize:s1');
      expect(practice['intervalDays'], 7);
      expect(practice['activityCount'], 3); // streak → activityCount
    });

    test('is commutative (same result set either order)', () {
      final a = _payload(
        study: [_study('a', 's1', lastActivityAt: t2, stability: 9)],
        reviews: [_review('a', 's1', t2)],
      );
      final b = _payload(
        study: [
          _study('a', 's1', lastActivityAt: t1, stability: 5),
          _study('b', 's2', lastActivityAt: t1)
        ],
        reviews: [_review('b', 's2', t1)],
      );
      final ab = mergeSnapshots(a, b);
      final ba = mergeSnapshots(b, a);
      expect(_reviewKeys(ab), _reviewKeys(ba));
      expect(_studyRows(ab).length, _studyRows(ba).length);
      double win(Map<String, dynamic> m) =>
          _studyRows(m).firstWhere((r) => r['cardId'] == 'a')['stability']
              as double;
      expect(win(ab), 9);
      expect(win(ba), 9);
    });

    test('is idempotent — re-merging changes nothing', () {
      final a = _payload(
        study: [_study('a', 's1', lastActivityAt: t2, stability: 9)],
        reviews: [_review('a', 's1', t2)],
      );
      final b = _payload(
        study: [_study('b', 's2', lastActivityAt: t1)],
        reviews: [_review('b', 's2', t1)],
      );
      final once = mergeSnapshots(a, b);
      expect(_reviewKeys(mergeSnapshots(once, once)), _reviewKeys(once));
      expect(
          _studyRows(mergeSnapshots(once, b)).length, _studyRows(once).length);
      expect(_reviewKeys(mergeSnapshots(once, b)), _reviewKeys(once));
    });

    test('output is sorted by key (deterministic file, low sync churn)', () {
      final a =
          _payload(reviews: [_review('b', 's2', t2), _review('a', 's1', t1)]);
      final merged = mergeSnapshots(a, _payload());
      final keys = _reviewRows(merged).map(_rk).toList();
      expect(keys, List.of(keys)..sort());
    });

    test('handles empty / missing keys', () {
      expect(
          _reviewRows(mergeSnapshots(<String, dynamic>{}, <String, dynamic>{})),
          isEmpty);
      final merged = mergeSnapshots(
          <String, dynamic>{}, _payload(reviews: [_review('a', 's1', t1)]));
      expect(_reviewRows(merged).length, 1);
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
