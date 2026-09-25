import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/query/card_query.dart';
import 'package:onyx/core/search/card_filter.dart';
import 'package:onyx/core/search/card_search.dart';
import 'package:onyx/shared/models/card.dart';

/// G2b.0 — the Browse pipeline differential harness (ADR-0013 §Addendum).
///
/// Pins the CURRENT Browse filter+search behavior over a MULTI-TAG corpus with
/// explicit expected results, so wiring Browse onto the CardQuery IR (G2b.1/.2)
/// can be proven byte-identical. [_run] reproduces `browse_screen._body` exactly:
///   parseSearchQuery -> chip.merge -> matchesFilter(cardMastery) -> searchCards|sort
/// The load-bearing pins: the DOMAIN facet is FIRST-TAG only (a card tagged
/// [networking, ds-a] is NOT a ds-a domain match; `domain:algorithms` matches
/// nothing) — the exact case where mapping domain->any-tag would silently widen —
/// and same-field values UNION while distinct fields AND.

Card _c(
  String id,
  String title, {
  required String type,
  required List<String> tags,
  Map<String, int> tiers = const {},
  String overview = '',
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
      filePath: '$id.md',
    );

// A corpus that stresses the multi-tag / first-tag distinction:
//  - tcp's SECOND tag is ds-a (first-tag networking) — any-tag would wrongly pull
//    it into a ds-a domain filter.
//  - two-sum/bfs carry `algorithms` as a NON-first tag — `domain:algorithms`
//    (first-tag) matches nothing; any-tag would match both.
final _corpus = [
  _c('two-sum', 'Two Sum',
      type: kTypeInterviewQuestion,
      tags: ['ds-a', 'algorithms'],
      tiers: {'ds-a': 1}),
  _c('bfs', 'BFS',
      type: kTypeFlashcard,
      tags: ['ds-a', 'algorithms', 'graphs', 'traversal'],
      tiers: {'ds-a': 2}),
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

/// Reproduces `browse_screen._body`'s combine over [_corpus]; returns result ids
/// in the exact order Browse would render.
List<String> _run({
  CardFilter chip = const CardFilter(),
  String query = '',
  Map<String, DateTime> dueByKey = const {},
  DateTime? now,
}) {
  final t = now ?? DateTime(2026, 6, 1);
  final parsed = parseSearchQuery(query.trim());
  final effective = chip.merge(parsed.filter);
  final filtered = [
    for (final c in _corpus)
      if (matchesFilter(c, effective, cardMastery(c, dueByKey, t))) c,
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

/// The NEW IR path (G2b.1): same combine, but chips+operators project through
/// `CardFilter.toQuery()` and evaluate via `CardQuery.matches`. Free-text ranking
/// stays the identical `searchCards` stage. Must equal [_run] byte-for-byte.
List<String> _runIR({
  CardFilter chip = const CardFilter(),
  String query = '',
  Map<String, DateTime> dueByKey = const {},
  DateTime? now,
}) {
  final t = now ?? DateTime(2026, 6, 1);
  final parsed = parseSearchQuery(query.trim());
  final q = chip.merge(parsed.filter).toQuery();
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

  group('DOMAIN is first-tag only (the anti-any-tag guard)', () {
    test('domain chip ds-a excludes tcp (ds-a is only its SECOND tag)', () {
      final r = _run(chip: const CardFilter(domains: {'ds-a'}));
      expect(r, ['bfs', 'binary-search', 'two-sum']);
      expect(r, isNot(contains('tcp')),
          reason: 'tcp domain = networking (tags.first)');
    });

    test('tag:ds-a operator matches identically (first-tag), NOT any-tag', () {
      expect(_run(query: 'tag:ds-a'), ['bfs', 'binary-search', 'two-sum']);
    });

    test('domain:algorithms matches NOTHING — algorithms is never a first tag',
        () {
      // The exact divergence: any-tag TagIs("algorithms") would match two-sum+bfs.
      expect(_run(query: 'domain:algorithms'), isEmpty);
      expect(_run(query: 'tag:algorithms'), isEmpty);
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
      // "tag:" with nothing after is NOT an operator; it becomes free text, which
      // matches no card — it must NEVER behave like a whole-vault match.
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
  });

  group('free-text (ranked stage)', () {
    test('body-only term', () {
      expect(_run(query: 'sorted'), ['binary-search']);
    });

    test('title term', () {
      expect(_run(query: 'binary'), ['binary-search']);
    });

    test('free-text runs WITHIN the filtered survivors', () {
      // type:flashcard filters to {bfs, binary-search, tcp}, then "binary" ranks.
      expect(_run(query: 'type:flashcard binary'), ['binary-search']);
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

  // G2b.1 gate: the IR path (CardFilter.toQuery -> CardQuery.matches) is
  // byte-identical to the legacy matchesFilter path across the whole matrix.
  group('IR path is byte-identical to the legacy pipeline', () {
    final due = {'two-sum::when-to-use': DateTime(2026, 5, 1)};
    final cases = <({CardFilter chip, String query, Map<String, DateTime> d})>[
      (chip: const CardFilter(), query: '', d: const {}),
      (chip: const CardFilter(types: {kTypeFlashcard}), query: '', d: const {}),
      (chip: const CardFilter(tiers: {1}), query: '', d: const {}),
      (chip: const CardFilter(domains: {'ds-a'}), query: '', d: const {}),
      (chip: const CardFilter(mastery: {MasteryFilter.due}), query: '', d: due),
      (chip: const CardFilter(), query: 'tag:ds-a', d: const {}),
      (chip: const CardFilter(), query: 'domain:algorithms', d: const {}),
      (chip: const CardFilter(), query: 'tag:algorithms', d: const {}),
      (chip: const CardFilter(), query: 'type:flashcard', d: const {}),
      (chip: const CardFilter(), query: 'type:interview', d: const {}),
      (chip: const CardFilter(), query: 'tier:1', d: const {}),
      (chip: const CardFilter(), query: 'tag:', d: const {}),
      (chip: const CardFilter(), query: 'is:due', d: due),
      (
        chip: const CardFilter(types: {kTypeFlashcard}),
        query: 'type:interview',
        d: const {}
      ),
      (
        chip: const CardFilter(types: {kTypeFlashcard}),
        query: 'tier:1',
        d: const {}
      ),
      (chip: const CardFilter(), query: 'sorted', d: const {}),
      (chip: const CardFilter(), query: 'binary', d: const {}),
      (chip: const CardFilter(), query: 'type:flashcard binary', d: const {}),
    ];
    for (final c in cases) {
      test('chip=${c.chip.activeFacetCount} facets, query="${c.query}"', () {
        expect(
          _runIR(chip: c.chip, query: c.query, dueByKey: c.d),
          _run(chip: c.chip, query: c.query, dueByKey: c.d),
        );
      });
    }
  });
}
