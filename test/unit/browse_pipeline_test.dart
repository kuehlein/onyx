import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/query/card_query.dart';
import 'package:onyx/core/search/card_filter.dart';
import 'package:onyx/core/search/card_search.dart';
import 'package:onyx/shared/models/card.dart';

/// The Browse pipeline golden (ADR-0013 §Addendum). Pins Browse's filter+search
/// behavior over a MULTI-TAG corpus with explicit expected results. [_run] mirrors
/// `browse_screen._body` on the unified IR:
///   parseQuery -> chip.merge(facets).toQuery() AND extra -> matches -> searchCards|sort
/// These expected values were pinned against the legacy `parseSearchQuery ->
/// matchesFilter` path at G2b.0 and proven byte-identical to the IR path at G2b.1
/// (differential harness); G2b.2 swaps [_run] onto the new parser and the same
/// values must hold. Load-bearing pins: DOMAIN is FIRST-TAG only (any-tag would
/// silently widen), same-field values UNION, folder:/negation AND on.

Card _c(
  String id,
  String title, {
  required String type,
  required List<String> tags,
  Map<String, int> tiers = const {},
  String overview = '',
  String? path,
}) =>
    Card(
      id: id,
      type: type,
      title: title,
      overview: overview,
      tags: tags,
      tiers: tiers,
      sections: const [
        CardSection(
            heading: 'When to Use',
            slug: 'when-to-use',
            content: 'body',
            quizzable: true),
      ],
      wikilinks: const [],
      filePath: path ?? '$id.md',
    );

// Stresses the multi-tag / first-tag distinction (tcp's SECOND tag is ds-a;
// two-sum/bfs carry `algorithms` as a NON-first tag). bfs lives under graphs/ to
// exercise folder:.
final _corpus = [
  _c('two-sum', 'Two Sum',
      type: kTypeInterviewQuestion,
      tags: ['ds-a', 'algorithms'],
      tiers: {'ds-a': 1}),
  _c('bfs', 'BFS',
      type: kTypeFlashcard,
      tags: ['ds-a', 'algorithms', 'graphs', 'traversal'],
      tiers: {'ds-a': 2},
      path: 'graphs/bfs.md'),
  _c('rate-limiter', 'Rate Limiter',
      type: kTypeSystemDesign,
      tags: ['system-design', 'ai-infra'],
      tiers: {'system-design': 2}),
  _c('tcp', 'TCP',
      type: kTypeFlashcard,
      tags: ['networking', 'ds-a'],
      tiers: {'networking': 1}),
  _c('binary-search', 'Binary Search',
      type: kTypeFlashcard,
      tags: ['ds-a'],
      tiers: {'ds-a': 1},
      overview: 'divide a sorted array'),
];

/// AND two queries, dropping an [Everything] operand (mirrors browse_screen).
CardQuery _and2(CardQuery a, CardQuery b) =>
    a is Everything ? b : (b is Everything ? a : And([a, b]));

/// Mirrors `browse_screen._body` on the unified IR; returns result ids in render
/// order.
List<String> _run({
  CardFilter chip = const CardFilter(),
  String query = '',
  Map<String, DateTime> dueByKey = const {},
  DateTime? now,
}) {
  final t = now ?? DateTime(2026, 6, 1);
  final parsed = parseQuery(query.trim());
  final q = _and2(chip.merge(parsed.facets).toQuery(), parsed.extra);
  final ctx = QueryContext(dueByKey: dueByKey, now: t);
  final filtered = [
    for (final c in _corpus)
      if (q.matches(c, ctx)) c,
  ];
  final List<Card> results;
  if (parsed.text.isEmpty) {
    results = [...filtered]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  } else {
    results = searchCards(filtered, parsed.text);
  }
  return [for (final c in results) c.id];
}

void main() {
  // Alphabetical-by-title order (no free-text): bfs, binary-search, rate-limiter,
  // tcp, two-sum.
  group('no refinement / single facet', () {
    test('empty → whole corpus, title-sorted', () {
      expect(
          _run(), ['bfs', 'binary-search', 'rate-limiter', 'tcp', 'two-sum']);
    });

    test('chip type=flashcard → the three flashcards', () {
      expect(_run(chip: const CardFilter(types: {kTypeFlashcard})),
          ['bfs', 'binary-search', 'tcp']);
    });

    test('chip tier=1 → tier-1 cards', () {
      expect(_run(chip: const CardFilter(tiers: {1})),
          ['binary-search', 'tcp', 'two-sum']);
    });
  });

  group('DOMAIN chip + domain: are first-tag; tag:/tags: are any-tag', () {
    test('domain chip ds-a excludes tcp (ds-a is only its SECOND tag)', () {
      final r = _run(chip: const CardFilter(domains: {'ds-a'}));
      expect(r, ['bfs', 'binary-search', 'two-sum']);
      expect(r, isNot(contains('tcp')),
          reason: 'tcp domain = networking (tags.first)');
    });

    test('domain:ds-a operator == the chip (first-tag)', () {
      expect(_run(query: 'domain:ds-a'), ['bfs', 'binary-search', 'two-sum']);
    });

    test('tag:/tags:ds-a are ANY-tag → include tcp (ADR-0013 §Addendum 2)', () {
      // The convention-aligned semantics: any card carrying ds-a, incl. tcp
      // (where it's the 2nd tag).
      expect(
          _run(query: 'tag:ds-a'), ['bfs', 'binary-search', 'tcp', 'two-sum']);
      expect(
          _run(query: 'tags:ds-a'), ['bfs', 'binary-search', 'tcp', 'two-sum']);
    });

    test('domain:algorithms matches NOTHING; tag:algorithms is any-tag', () {
      expect(_run(query: 'domain:algorithms'), isEmpty); // never a FIRST tag
      expect(_run(query: 'tag:algorithms'), ['bfs', 'two-sum']); // any-tag
    });
  });

  group('operators', () {
    test('type:flashcard', () {
      expect(_run(query: 'type:flashcard'), ['bfs', 'binary-search', 'tcp']);
    });

    test('type:interview (alias → interview-question)', () {
      expect(_run(query: 'type:interview'), ['two-sum']);
    });

    test('tier:1', () {
      expect(_run(query: 'tier:1'), ['binary-search', 'tcp', 'two-sum']);
    });

    test(
        'a lone trailing-colon operator falls through to free-text (no match-all)',
        () {
      expect(_run(query: 'tag:'), isEmpty);
    });
  });

  group('same-field UNION, distinct-field AND', () {
    test('chip type=flashcard + typed type:interview → UNION (either)', () {
      expect(
          _run(
              chip: const CardFilter(types: {kTypeFlashcard}),
              query: 'type:interview'),
          ['bfs', 'binary-search', 'tcp', 'two-sum']);
    });

    test('chip type=flashcard + typed tier:1 → AND across facets', () {
      expect(
          _run(
              chip: const CardFilter(types: {kTypeFlashcard}), query: 'tier:1'),
          ['binary-search', 'tcp']);
    });

    test('two same-field operators UNION (tier:1 tier:2)', () {
      // Every card is tier 1 or 2, so the UNION matches all five; an AND
      // (intersection) would be empty — proving same-field pools to OR.
      expect(_run(query: 'tier:1 tier:2'),
          ['bfs', 'binary-search', 'rate-limiter', 'tcp', 'two-sum']);
    });
  });

  group('folder: and negation (G2b.2 additions)', () {
    test('folder: scopes to a subtree', () {
      expect(_run(query: 'folder:graphs'), ['bfs']);
    });

    test('negating a facet excludes its matches', () {
      expect(_run(query: '-type:flashcard'), ['rate-limiter', 'two-sum']);
    });

    test('negating a folder excludes the subtree', () {
      expect(_run(query: '-folder:graphs'),
          ['binary-search', 'rate-limiter', 'tcp', 'two-sum']);
    });

    test('positive facet AND a negation', () {
      expect(_run(query: 'type:flashcard -tier:1'), ['bfs']);
    });
  });

  group('free-text (ranked stage)', () {
    test('body-only term', () {
      expect(_run(query: 'sorted'), ['binary-search']);
    });

    test('title term', () {
      expect(_run(query: 'binary'), ['binary-search']);
    });

    test('free-text runs WITHIN the filtered survivors', () {
      expect(_run(query: 'type:flashcard binary'), ['binary-search']);
    });

    test('"or" is a free word, not a boolean operator (OR deferred to G3)', () {
      // If OR were an operator, "two OR binary" would match Two Sum OR Binary
      // Search; as free words it's an AND of [two, or, binary] — which no card
      // satisfies — so the empty result proves "or" is just a search term.
      expect(_run(query: 'two or binary'), isEmpty);
    });
  });

  group('study state (dynamic; needs due dates)', () {
    test('is:due matches only the card with a due section', () {
      expect(
          _run(
              query: 'is:due',
              dueByKey: {'two-sum::when-to-use': DateTime(2026, 5, 1)}),
          ['two-sum']);
    });
  });
}
