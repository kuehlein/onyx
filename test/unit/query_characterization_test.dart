import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/shared/models/card.dart';

/// G0 characterization for the query/lens unification (ADR-0013). Pins deck
/// membership at the level that MUST survive **G1** — which folds the internal
/// `MembershipQuery` classes into the new `core/query` IR. So this deliberately
/// asserts only against the PUBLIC surface: `Deck.fromJson`'s `membership` JSON +
/// `Deck.select`. It never names `TagMembership` / `FolderMembership` / `AllCards`
/// (those get deleted in G1), which is exactly why it stays a frozen golden:
/// after the fold, the same legacy `{all|tag|folder}` JSON must still deserialize
/// and select the same cards, byte-for-byte. `deckMemberCardIds` (and every
/// readiness/plan/analytics denominator that scopes through `Deck.select`) depends
/// on this being unchanged.

Card _card(String id, {List<String> tags = const [], required String path}) =>
    Card(
      id: id,
      type: 'flashcard',
      title: id,
      overview: '',
      tags: tags,
      tiers: const {},
      sections: const [],
      wikilinks: const [],
      filePath: path,
    );

/// A deck whose membership is [membership] (legacy JSON), built via the public API.
Deck _deckWith(Map<String, dynamic>? membership) => Deck.fromJson({
      'id': 'd',
      'name': 'D',
      'templateId': 't',
      if (membership != null) 'membership': membership,
    });

void main() {
  // A corpus spanning tags (incl. a `#`-prefixed, mixed-case one) and folders
  // (incl. a deep path and a sibling-prefix trap).
  final corpus = [
    _card('a', tags: ['scripture'], path: 'Bible/john.md'),
    _card('b', tags: ['#History'], path: 'History/nicaea.md'),
    _card('c', tags: ['scripture', 'theology'], path: 'Theology/saints.md'),
    _card('d', path: 'Math/Calculus/101/limits.md'),
    _card('e', path: 'Math/Calc/extra.md'), // sibling-prefix of Math/Calculus
  ];
  List<String> ids(Deck d) => d.select(corpus).map((c) => c.id).toList();

  group('deck lens golden — Deck.select via legacy JSON (survives the G1 fold)',
      () {
    test('all / absent membership → the whole corpus, order preserved', () {
      expect(ids(_deckWith({'kind': 'all'})), ['a', 'b', 'c', 'd', 'e']);
      expect(ids(_deckWith(null)), ['a', 'b', 'c', 'd', 'e'],
          reason: 'absent membership defaults to the whole vault');
    });

    test('tag → cross-cutting; case- and #-insensitive; empty on a miss', () {
      expect(ids(_deckWith({'kind': 'tag', 'value': 'scripture'})), ['a', 'c']);
      expect(ids(_deckWith({'kind': 'tag', 'value': '#History'})), ['b'],
          reason: 'tag normalized: lowercased, leading # dropped');
      expect(ids(_deckWith({'kind': 'tag', 'value': 'missing'})), isEmpty);
    });

    test('folder → subtree + exact file; a sibling-prefix folder is excluded',
        () {
      expect(
          ids(_deckWith({'kind': 'folder', 'value': 'Math/Calculus'})), ['d'],
          reason: 'deep child under the subtree matches; Math/Calc/ does NOT');
      expect(
          ids(_deckWith({'kind': 'folder', 'value': 'Bible/john.md'})), ['a'],
          reason: 'an exact file path matches itself');
      expect(ids(_deckWith({'kind': 'folder', 'value': ''})),
          ['a', 'b', 'c', 'd', 'e'],
          reason: 'an empty folder path matches everything');
    });

    test('unknown / malformed kind → whole corpus (never selects nothing)', () {
      expect(ids(_deckWith({'kind': 'bogus'})), ['a', 'b', 'c', 'd', 'e']);
      expect(ids(_deckWith(const {})), ['a', 'b', 'c', 'd', 'e']);
    });

    test('legacy membership JSON round-trips through Deck.toJson unchanged',
        () {
      for (final j in [
        {'kind': 'all'},
        {'kind': 'tag', 'value': 'scripture'},
        {'kind': 'folder', 'value': 'Math/Calculus'},
      ]) {
        final back = Deck.fromJson(_deckWith(j).toJson());
        expect(ids(back), ids(_deckWith(j)),
            reason: 'a persisted lens reloads to the same member set');
      }
    });
  });
}
