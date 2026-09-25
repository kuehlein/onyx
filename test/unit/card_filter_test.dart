import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/query/card_query.dart';
import 'package:onyx/core/search/card_filter.dart';
import 'package:onyx/shared/models/card.dart';

/// The Browse query surface (ADR-0013 G2b): `parseQuery` splits a raw query into
/// pooled `facets` (byte-identical to the legacy parser) + an `extra` CardQuery
/// (folder:/negation) + free `text`; `CardFilter.toQuery()` projects the chips to
/// the IR. The parser must be TOTAL — never throw, never build a match-all leaf
/// from a typo.

Card _card(
  String id, {
  String type = 'flashcard',
  String domain = 'ds-a',
  int tier = 2,
  List<String> slugs = const ['s1'],
}) =>
    Card(
      id: id,
      type: type,
      title: id,
      overview: '',
      tags: [domain],
      tiers: {domain: tier},
      sections: [
        for (final s in slugs)
          CardSection(heading: s, slug: s, content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  group('parseQuery — facet pooling (byte-identical to the legacy parser)', () {
    test('pools tag/type/tier/is operators and keeps free text', () {
      final r = parseQuery('trees tag:ds-a is:due tier:1 type:interview');
      expect(r.text, 'trees');
      expect(r.facets.domains, {'ds-a'});
      expect(r.facets.mastery, {MasteryFilter.due});
      expect(r.facets.tiers, {1});
      expect(r.facets.types, {'interview-question'});
      expect(r.extra, isA<Everything>());
    });

    test('domain: is an alias for tag:', () {
      expect(parseQuery('domain:graphs').facets.domains, {'graphs'});
    });

    test('same-field operators pool (union), values lowercased', () {
      expect(parseQuery('tier:1 tier:2').facets.tiers, {1, 2});
      expect(parseQuery('tag:DS-A').facets.domains, {'ds-a'});
    });

    test('unrecognized operator → free text', () {
      final r = parseQuery('foo:bar hello');
      expect(r.text, 'foo:bar hello');
      expect(r.facets.isEmpty, isTrue);
    });

    test('type: with an unconfigured value → free text', () {
      final r = parseQuery('type:zzz hello');
      expect(r.facets.types, isEmpty);
      expect(r.text, 'type:zzz hello');
    });

    test('empty query → empty facets, Everything extra, empty text', () {
      final r = parseQuery('   ');
      expect(r.facets.isEmpty, isTrue);
      expect(r.extra, isA<Everything>());
      expect(r.text, '');
    });
  });

  group('parseQuery — extra (folder: + negation)', () {
    test('folder:/path: → a FolderUnder leaf in extra, case PRESERVED', () {
      final r = parseQuery('folder:Korean/Vocab');
      expect(r.facets.isEmpty, isTrue);
      expect(r.extra, isA<FolderUnder>());
      expect((r.extra as FolderUnder).path, 'Korean/Vocab');
      expect(parseQuery('path:a/b').extra, isA<FolderUnder>());
    });

    test('a negated operator → Not(leaf) in extra, never a facet', () {
      final r = parseQuery('-tag:done');
      expect(r.facets.isEmpty, isTrue);
      expect(r.extra, isA<Not>());
      final inner = (r.extra as Not).q;
      expect(inner, isA<DomainIs>());
      expect((inner as DomainIs).domain, 'done');
      expect(parseQuery('!type:flashcard').extra, isA<Not>());
    });

    test('a negated NON-operator stays free text (with its prefix)', () {
      final r = parseQuery('-hello');
      expect(r.extra, isA<Everything>());
      expect(r.text, '-hello');
    });

    test('multiple extra leaves AND together', () {
      final r = parseQuery('folder:a -tier:1');
      expect(r.extra, isA<And>());
      expect((r.extra as And).of.length, 2);
    });

    test('a trailing-colon operator is free text — NEVER a match-all leaf', () {
      for (final q in ['tag:', 'folder:', 'type:', '-tag:']) {
        final r = parseQuery(q);
        expect(r.facets.isEmpty, isTrue, reason: q);
        expect(r.extra, isA<Everything>(), reason: q);
        expect(r.text, q, reason: q);
      }
    });
  });

  group('parseQuery — TOTAL (never throws, never a bogus match-all)', () {
    test('handles a battery of malformed inputs without throwing', () {
      const junk = [
        '',
        '   ',
        '(',
        ')',
        '()',
        '(  )',
        ':',
        '::',
        'tag::a',
        'tag:',
        'folder:',
        '-',
        '!',
        '- -',
        '-tag:',
        'type:',
        'tier:',
        'is:',
        'http://example.com',
        'tag:a.*',
        r'\',
        '[',
        ']',
        '((((tag:a',
        'tag:a))))',
        'OR',
        '||',
        'a OR',
        'tier:99999999999999999999999',
        '  tag:a   tag:b  ',
        '-!tag:x',
        '!!x',
      ];
      for (final q in junk) {
        expect(() => parseQuery(q), returnsNormally, reason: 'query: "$q"');
        final r = parseQuery(q);
        expect(r.extra, isA<CardQuery>(), reason: 'query: "$q"');
      }
    });

    test('is total over a generated token alphabet (deterministic)', () {
      const alphabet = [
        'tag:a',
        'type:x',
        'tier:1',
        'is:due',
        'folder:f',
        '-tag:b',
        '!type:y',
        '(',
        ')',
        'OR',
        '||',
        'word',
        ':',
        'tag:',
        '-',
        '!',
        '-word',
        'tier:z',
      ];
      for (var seed = 0; seed < 400; seed++) {
        final n = 1 + seed % 7;
        final toks = [
          for (var k = 0; k < n; k++)
            alphabet[(seed * 31 + k * 17) % alphabet.length]
        ];
        final q = toks.join(' ');
        expect(() => parseQuery(q), returnsNormally, reason: 'query: "$q"');
      }
    });
  });

  group('CardFilter.toQuery', () {
    test('empty filter → Everything', () {
      expect(const CardFilter().toQuery(), isA<Everything>());
    });

    test('a single-value facet → a single leaf (never Or of one)', () {
      expect(const CardFilter(types: {'flashcard'}).toQuery(), isA<TypeIs>());
    });

    test('a multi-value facet → an Or of leaves', () {
      expect(const CardFilter(tiers: {1, 2}).toQuery(), isA<Or>());
    });

    test('multiple facets → an And of groups', () {
      expect(const CardFilter(types: {'flashcard'}, tiers: {1}).toQuery(),
          isA<And>());
    });
  });

  group('cardMastery', () {
    final now = DateTime(2026, 9, 1, 12);
    final card = _card('A', slugs: ['a', 'b', 'c']);

    test('classifies sections as fresh / due / strong', () {
      final due = {
        'A::a': now.subtract(const Duration(days: 1)), // due
        'A::c': now.add(const Duration(days: 5)), // strong
        // A::b absent → fresh
      };
      final m = cardMastery(card, due, now);
      expect(m, {MasteryFilter.due, MasteryFilter.strong, MasteryFilter.fresh});
    });

    test('all unstudied → fresh only', () {
      expect(cardMastery(card, const {}, now), {MasteryFilter.fresh});
    });
  });
}
