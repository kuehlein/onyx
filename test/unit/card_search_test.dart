import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/search/card_search.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(
  String title, {
  List<String> tags = const ['ds-a'],
  String overview = '',
  List<CardSection> sections = const [],
  List<String> concepts = const [],
}) =>
    Card(
      id: title,
      type: CardType.flashcard,
      title: title,
      overview: overview,
      tags: tags,
      tiers: {if (tags.isNotEmpty) tags.first: 1},
      sections: sections,
      wikilinks: const [],
      filePath: '$title.md',
      concepts: concepts,
    );

void main() {
  final cards = [
    _card('Binary Search', overview: 'divide a sorted array and halve'),
    _card('Two Pointers', overview: 'converge from both ends'),
    _card('Dijkstra', tags: ['graphs'], overview: 'shortest path in a graph'),
    _card('Hash Maps', sections: const [
      CardSection(
          heading: 'Collisions',
          slug: 'collisions',
          content: 'chaining and open addressing',
          quizzable: true),
    ], concepts: const [
      'hashing'
    ]),
  ];

  group('searchCards', () {
    test('empty query returns all cards unchanged', () {
      expect(searchCards(cards, '').length, cards.length);
      expect(searchCards(cards, '   ').length, cards.length);
    });

    test('matches on title', () {
      final r = searchCards(cards, 'binary');
      expect(r.map((c) => c.title), ['Binary Search']);
    });

    test('matches on body/overview when not in the title', () {
      final r = searchCards(cards, 'path');
      expect(r.map((c) => c.title), ['Dijkstra']);
    });

    test('matches on section content and concepts', () {
      expect(searchCards(cards, 'chaining').map((c) => c.title), ['Hash Maps']);
      expect(searchCards(cards, 'hashing').map((c) => c.title), ['Hash Maps']);
    });

    test('is AND across terms', () {
      // "sorted" (body) + "search" (title) both in Binary Search only.
      expect(searchCards(cards, 'sorted search').map((c) => c.title),
          ['Binary Search']);
      // No card has both.
      expect(searchCards(cards, 'binary dijkstra'), isEmpty);
    });

    test('ranks a title hit above a body-only hit', () {
      final withGraph = [
        _card('Graph Traversal', overview: 'bfs and dfs'),
        _card('Dijkstra', tags: ['graphs'], overview: 'shortest path in graph'),
      ];
      final r = searchCards(withGraph, 'graph');
      // "Graph Traversal" (title) outranks "Dijkstra" (body/tag only).
      expect(r.first.title, 'Graph Traversal');
    });

    test('no match returns empty', () {
      expect(searchCards(cards, 'zzzznope'), isEmpty);
    });
  });
}
