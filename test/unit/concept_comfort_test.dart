import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/concept_comfort.dart';

Card _card(
  String id,
  String type, {
  String? path,
  List<CardSection> sections = const [],
}) =>
    Card(
      id: id,
      type: type,
      title: id,
      overview: '',
      tags: const [],
      tiers: const {},
      sections: sections,
      wikilinks: const [],
      filePath: path ?? '$id.md',
    );

CardSection _sec(String slug, {bool quizzable = true}) =>
    CardSection(heading: slug, slug: slug, content: 'x', quizzable: quizzable);

void main() {
  test('comfort = studied fraction of a flashcard\'s quizzable sections', () {
    final cards = [
      _card('a', 'flashcard',
          sections: [_sec('s1'), _sec('s2'), _sec('ref', quizzable: false)]),
    ];
    final cc =
        buildConceptComfort(cards, {'a::s1'}); // 1 of 2 quizzable studied
    expect(cc.comfort['a'], 0.5);
    expect(cc.label['a'], 'a');
    expect(cc.of('a'), 0.5);
  });

  test('a dependency named by filename resolves to the card id', () {
    final cards = [
      _card('id-123', 'flashcard',
          path: 'binary-search.md', sections: [_sec('s')]),
    ];
    final cc = buildConceptComfort(cards, {'id-123::s'});
    expect(cc.of('binary-search'), 1.0); // by filename slug
    expect(cc.of('id-123'), 1.0); // by id
    expect(cc.labelOf('binary-search'), 'id-123');
    expect(cc.of('unknown'), 0.0);
  });

  test('non-flashcard cards are excluded (today\'s concept predicate)', () {
    final cards = [
      _card('x', 'algorithm', sections: [_sec('s')]),
      _card('y', 'system-design', sections: [_sec('s')]),
    ];
    expect(buildConceptComfort(cards, {'x::s', 'y::s'}).comfort, isEmpty);
  });
}
