import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/backup/snapshot.dart';

/// Pure properties of [mergeSnapshots] (ADR-0001). No DB / sqlite — this proves
/// the convergent-merge core is commutative, idempotent, and loss-free.

Map<String, dynamic> _srs(
  String card,
  String sec, {
  String? lastReview,
  int reviewCount = 1,
  double stability = 5,
}) =>
    {
      'cardId': card,
      'sectionSlug': sec,
      'stability': stability,
      'difficulty': 5.0,
      'state': 2,
      'step': null,
      'dueAt': '2026-01-10T00:00:00.000Z',
      'lastReview': lastReview,
      'reviewCount': reviewCount,
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
  List<Map<String, dynamic>> srs = const [],
  List<Map<String, dynamic>> reviews = const [],
  String exportedAt = '2026-01-01T00:00:00.000Z',
  int version = 3,
}) =>
    {
      'version': version,
      'exportedAt': exportedAt,
      'srsStates': srs,
      'reviews': reviews,
      'appliedAttempts': <Map<String, dynamic>>[],
      'recognitionStates': <Map<String, dynamic>>[],
    };

List<Map<String, dynamic>> _srsRows(Map<String, dynamic> m) =>
    (m['srsStates'] as List).cast<Map<String, dynamic>>();
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

    test('keyed state resolves last-review-wins', () {
      final older =
          _payload(srs: [_srs('a', 's1', lastReview: t1, stability: 5)]);
      final newer =
          _payload(srs: [_srs('a', 's1', lastReview: t2, stability: 9)]);
      final merged = mergeSnapshots(older, newer);
      expect(_srsRows(merged).length, 1);
      expect(_srsRows(merged).single['stability'], 9);
    });

    test('ties on recency break toward the higher reviewCount', () {
      final a = _payload(
          srs: [_srs('a', 's1', lastReview: t1, reviewCount: 1, stability: 5)]);
      final b = _payload(
          srs: [_srs('a', 's1', lastReview: t1, reviewCount: 3, stability: 9)]);
      expect(mergeSnapshots(a, b).let(_srsRows).single['reviewCount'], 3);
      // symmetric
      expect(mergeSnapshots(b, a).let(_srsRows).single['reviewCount'], 3);
    });

    test('a real recency stamp beats a null/absent one', () {
      final withNull =
          _payload(srs: [_srs('a', 's1', lastReview: null, stability: 5)]);
      final withReal =
          _payload(srs: [_srs('a', 's1', lastReview: t1, stability: 9)]);
      expect(
          mergeSnapshots(withNull, withReal).let(_srsRows).single['stability'],
          9);
      expect(
          mergeSnapshots(withReal, withNull).let(_srsRows).single['stability'],
          9);
    });

    test('is commutative (same result set either order)', () {
      final a = _payload(
        srs: [_srs('a', 's1', lastReview: t2, stability: 9)],
        reviews: [_review('a', 's1', t2)],
      );
      final b = _payload(
        srs: [
          _srs('a', 's1', lastReview: t1, stability: 5),
          _srs('b', 's2', lastReview: t1)
        ],
        reviews: [_review('b', 's2', t1)],
      );
      final ab = mergeSnapshots(a, b);
      final ba = mergeSnapshots(b, a);
      expect(_reviewKeys(ab), _reviewKeys(ba));
      expect(_srsRows(ab).length, _srsRows(ba).length);
      // the contested section resolves to the same (newer) winner either way
      double win(Map<String, dynamic> m) =>
          _srsRows(m).firstWhere((r) => r['cardId'] == 'a')['stability']
              as double;
      expect(win(ab), 9);
      expect(win(ba), 9);
    });

    test('is idempotent — re-merging changes nothing', () {
      final a = _payload(
        srs: [_srs('a', 's1', lastReview: t2, stability: 9)],
        reviews: [_review('a', 's1', t2)],
      );
      final b = _payload(
        srs: [_srs('b', 's2', lastReview: t1)],
        reviews: [_review('b', 's2', t1)],
      );
      final once = mergeSnapshots(a, b);
      expect(_reviewKeys(mergeSnapshots(once, once)), _reviewKeys(once));
      expect(_srsRows(mergeSnapshots(once, b)).length, _srsRows(once).length);
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
