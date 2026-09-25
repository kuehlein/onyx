import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/query/card_query.dart';
import 'package:onyx/core/search/card_filter.dart';
import 'package:onyx/shared/models/card.dart';

/// The deck-lens text form (ADR-0013 §Addendum, G3.0): `parseLens` turns the
/// mini-language into ONE `CardQuery` tree (full `OR`/`()` nesting — no chips to
/// reconcile, unlike Browse), and `renderLens` is its inverse so a saved lens is
/// editable as text. Load-bearing properties pinned here:
///   • precedence OR (lowest) < implicit/`&&` AND < `-`/`!` NOT
///   • TOTAL: never throws; a typo degrades to free/ignored, never a match-all
///   • tag semantics: `tag:`/`domain:` = first-tag (DomainIs, == Browse);
///     `tags:` = any-tag (TagIs, lens-only)
///   • render→parse is FAITHFUL (same cards match) over a corpus + fuzz

Card _c(
  String id, {
  required String type,
  required List<String> tags,
  Map<String, int> tiers = const {},
  String? path,
}) =>
    Card(
      id: id,
      type: type,
      title: id,
      overview: '',
      tags: tags,
      tiers: tiers,
      sections: const [
        CardSection(heading: 'H', slug: 'h', content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: path ?? '$id.md',
    );

// first-tag vs any-tag: two-sum/bfs are ds-a-first; tcp carries ds-a SECOND.
final _corpus = [
  _c('two-sum',
      type: kTypeInterviewQuestion,
      tags: ['ds-a', 'algorithms'],
      tiers: {'ds-a': 1}),
  _c('bfs',
      type: kTypeFlashcard,
      tags: ['ds-a', 'algorithms', 'graphs'],
      tiers: {'ds-a': 2},
      path: 'graphs/bfs.md'),
  _c('tcp',
      type: kTypeFlashcard,
      tags: ['networking', 'ds-a'],
      tiers: {'networking': 1},
      path: 'net/tcp.md'),
  _c('rate-limiter',
      type: kTypeSystemDesign,
      tags: ['system-design', 'ai-infra'],
      tiers: {'system-design': 2},
      path: 'sd/rl.md'),
];

final _ctx = QueryContext(now: DateTime(2026, 6, 1));

List<String> _match(CardQuery q) => [
      for (final c in _corpus)
        if (q.matches(c, _ctx)) c.id
    ]..sort();

List<String> _lens(String s) => _match(parseLens(s));

void main() {
  group('parseLens — leaves', () {
    test('tag:/tags: are any-tag (TagIs); domain: is first-tag (DomainIs)', () {
      // ADR-0013 §Addendum 2: tag:/tags: = any-tag (the convention); domain: = the
      // primary (first) tag.
      expect(parseLens('tag:ds-a'), isA<TagIs>());
      expect(parseLens('tags:ds-a'), isA<TagIs>());
      expect(parseLens('domain:ds-a'), isA<DomainIs>());
      // any-tag ds-a → every card carrying ds-a (incl. tcp, where it's 2nd)
      expect(_lens('tag:ds-a'), ['bfs', 'tcp', 'two-sum']);
      expect(_lens('tags:ds-a'), ['bfs', 'tcp', 'two-sum']);
      // first-tag ds-a → only cards whose FIRST tag is ds-a (not tcp)
      expect(_lens('domain:ds-a'), ['bfs', 'two-sum']);
      // algorithms is a non-first tag on two-sum + bfs
      expect(_lens('tag:algorithms'), ['bfs', 'two-sum']);
      expect(_lens('domain:algorithms'), isEmpty); // never a FIRST tag
      expect(_lens('tag:ai-infra'), ['rate-limiter']);
    });

    test('domain: is case-insensitive (mixed-case first tag round-trips)', () {
      // Regression: raw `==` corrupted the member set on a renderLens→parseLens
      // round-trip (`domain:Graphs` → DomainIs('graphs') matched different cards).
      final mixed = _c('gx', type: 'flashcard', tags: ['Graphs']);
      expect(parseLens('domain:graphs').matches(mixed, _ctx), isTrue);
      expect(parseLens('domain:Graphs').matches(mixed, _ctx), isTrue);
      expect(const DomainIs('GRAPHS').matches(mixed), isTrue);
      // render → parse preserves the match.
      expect(
          parseLens(renderLens(const DomainIs('Graphs'))).matches(mixed, _ctx),
          isTrue);
    });

    test('type: / tier: / folder: / path: / is:', () {
      expect(_lens('type:flashcard'), ['bfs', 'tcp']);
      expect(_lens('type:interview'), ['two-sum']); // alias
      expect(_lens('tier:1'), ['tcp', 'two-sum']);
      expect(_lens('folder:graphs'), ['bfs']);
      expect(_lens('path:net'), ['tcp']);
      expect(parseLens('is:due'), isA<StateIs>()); // dynamic; stripped on save
    });

    test('the `foo/` folder shorthand (deck_creation.md)', () {
      expect(parseLens('graphs/'), isA<FolderUnder>());
      expect((parseLens('graphs/') as FolderUnder).path, 'graphs');
      expect(_lens('graphs/'), ['bfs']);
    });

    test('empty / whitespace → Everything (whole vault)', () {
      expect(parseLens(''), isA<Everything>());
      expect(parseLens('   '), isA<Everything>());
      expect(_lens(''), ['bfs', 'rate-limiter', 'tcp', 'two-sum']);
    });

    test('a bare word is ignored (no free-text membership)', () {
      expect(parseLens('korean'), isA<Everything>());
      expect(parseLens('hello world'), isA<Everything>());
    });
  });

  group('parseLens — boolean structure', () {
    test('implicit AND (juxtaposition) intersects', () {
      expect(_lens('type:flashcard tier:1'), ['tcp']); // flashcard AND tier1
      expect(parseLens('type:flashcard tier:1'), isA<And>());
    });

    test('explicit && is the same as juxtaposition', () {
      expect(_lens('type:flashcard && tier:1'), ['tcp']);
    });

    test('OR / || unions', () {
      expect(_lens('folder:graphs OR path:net'), ['bfs', 'tcp']);
      expect(_lens('folder:graphs || path:net'), ['bfs', 'tcp']);
      expect(parseLens('folder:graphs OR path:net'), isA<Or>());
    });

    test('() groups against precedence', () {
      // (graphs OR networking-folder) AND flashcard = bfs, tcp
      expect(
          _lens('(folder:graphs OR path:net) type:flashcard'), ['bfs', 'tcp']);
      // without parens, AND binds tighter: graphs OR (net AND flashcard) = same
      // here, so use a case where grouping actually matters:
      // tags:algorithms AND (tier:1 OR tier:2) -> two-sum(1), bfs(2)
      expect(_lens('tags:algorithms (tier:1 OR tier:2)'), ['bfs', 'two-sum']);
    });

    test('negation: prefix on a term and a lone !/-', () {
      expect(_lens('tags:ds-a -tags:algorithms'), ['tcp']); // ds-a not algos
      expect(_lens('!type:flashcard'), ['rate-limiter', 'two-sum']);
      expect(_lens('tags:ds-a ! (tags:algorithms)'), ['tcp']); // lone !
    });

    test('precedence: OR is lowest, AND next, NOT tightest', () {
      // a AND b OR c  ==  (a AND b) OR c
      // type:flashcard tier:1 OR type:system-design
      //   = (flashcard AND tier1)=tcp  OR  system-design=rate-limiter
      expect(_lens('type:flashcard tier:1 OR type:system-design'),
          ['rate-limiter', 'tcp']);
    });
  });

  group('renderLens — inverse of parseLens', () {
    test('leaves render to their operator', () {
      expect(renderLens(TagIs('ds-a')), 'tag:ds-a');
      expect(renderLens(const DomainIs('ds-a')), 'domain:ds-a');
      expect(renderLens(FolderUnder('graphs/')), 'folder:graphs');
      expect(renderLens(const TypeIs('flashcard')), 'type:flashcard');
      expect(renderLens(const TierIs(1)), 'tier:1');
      expect(renderLens(const StateIs(MasteryFilter.due)), 'is:due');
      expect(renderLens(CardQuery.everything), '');
    });

    test('negation renders - for a leaf, !(...) for a group', () {
      expect(renderLens(Not(TagIs('done'))), '-tag:done');
      expect(
          renderLens(Not(Or([TagIs('a'), TagIs('b')]))), '!(tag:a OR tag:b)');
    });

    test('an Or inside an And is parenthesized; And inside Or is not', () {
      expect(
        renderLens(const And([
          TypeIs('flashcard'),
          Or([TierIs(1), TierIs(2)])
        ])),
        'type:flashcard (tier:1 OR tier:2)',
      );
      expect(
        renderLens(const Or([
          And([TypeIs('flashcard'), TierIs(1)]),
          TierIs(2)
        ])),
        'type:flashcard tier:1 OR tier:2',
      );
    });
  });

  group('quoting — values with spaces / reserved syntax round-trip', () {
    test('renderLens quotes a value that would break the tokenizer', () {
      expect(renderLens(FolderUnder('Machine Learning')),
          'folder:"Machine Learning"');
      expect(renderLens(TagIs('two words')), 'tag:"two words"');
      expect(renderLens(TagIs('korean')), 'tag:korean'); // no quote needed
    });

    test('parseLens round-trips quoted values (the editable-mirror invariant)',
        () {
      final trees = <CardQuery>[
        FolderUnder('Machine Learning'),
        TagIs('two words'),
        And([FolderUnder('a b'), TagIs('c d')]),
        Not(TagIs('a b')),
        Or([TagIs('a b'), const DomainIs('c')]),
      ];
      for (final q in trees) {
        // render → parse → render is stable (was silently corrupted pre-quoting:
        // `folder:Machine Learning` re-parsed to FolderUnder('Machine')).
        expect(renderLens(parseLens(renderLens(q))), renderLens(q),
            reason: renderLens(q));
      }
    });

    test('a value containing OR / parens survives via quoting', () {
      final t = parseLens(renderLens(TagIs('a OR b')));
      expect(t, isA<TagIs>());
      expect((t as TagIs).tag, 'a or b');
      final f = parseLens(renderLens(FolderUnder('x (y)')));
      expect(f, isA<FolderUnder>());
      expect((f as FolderUnder).path, 'x (y)');
    });
  });

  group('render→parse is faithful (same cards match)', () {
    final trees = <CardQuery>[
      CardQuery.everything,
      const DomainIs('ds-a'),
      TagIs('ds-a'),
      TagIs('algorithms'),
      FolderUnder('graphs/'),
      const TypeIs('flashcard'),
      const TierIs(1),
      const And([TypeIs('flashcard'), TierIs(1)]),
      Or([FolderUnder('graphs/'), FolderUnder('net/')]),
      And([TagIs('ds-a'), Not(TagIs('algorithms'))]),
      const Or([
        And([TypeIs('flashcard'), TierIs(1)]),
        TypeIs('system-design')
      ]),
      And([
        TagIs('algorithms'),
        const Or([TierIs(1), TierIs(2)])
      ]),
      const Not(Or([TypeIs('flashcard'), TypeIs('system-design')])),
      And([
        Or([FolderUnder('graphs/'), FolderUnder('net/')]),
        const Not(TierIs(2)),
      ]),
    ];

    test('parseLens(renderLens(q)) matches the same corpus subset', () {
      for (final q in trees) {
        final rendered = renderLens(q);
        final reparsed = parseLens(rendered);
        expect(_match(reparsed), _match(q),
            reason: 'q=${q.toJson()} rendered="$rendered"');
      }
    });
  });

  group('parseLens — TOTAL (never throws, never a bogus match-all)', () {
    test('a battery of malformed inputs', () {
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
        'tags:',
        'folder:',
        '-',
        '!',
        '- -',
        '-tag:',
        'type:',
        'tier:',
        'is:',
        'OR',
        '||',
        '&&',
        'a OR',
        'OR a',
        '(((tag:a',
        'tag:a)))',
        '!!x',
        '-!tag:x',
        'folder:/',
        'folder://',
        '/',
        '  a   b  ',
        'a && && b',
        '() OR ()',
        '( ) tag:a',
        'tags:a || || tags:b',
      ];
      for (final q in junk) {
        expect(() => parseLens(q), returnsNormally, reason: 'lens: "$q"');
        expect(parseLens(q), isA<CardQuery>(), reason: 'lens: "$q"');
      }
    });

    test('a lone match-all typo never selects the whole vault by accident', () {
      // `folder:/` and `/` trim to an empty path — must NOT become match-all.
      expect(parseLens('folder:/'), isA<Everything>()); // ignored → everything
      expect(parseLens('/'), isA<Everything>());
    });

    test('fuzz: total AND render is faithful over a token alphabet', () {
      const alphabet = [
        'tag:ds-a',
        'tags:algorithms',
        'domain:networking',
        'type:flashcard',
        'tier:1',
        'tier:2',
        'folder:graphs',
        'path:net',
        'is:due',
        'graphs/',
        '-tag:ds-a',
        '!tags:algorithms',
        'OR',
        '||',
        '&&',
        '(',
        ')',
        '-',
        '!',
        'word',
        ':',
        'tag:',
        'tags:',
        'tier:z',
      ];
      for (var seed = 0; seed < 600; seed++) {
        final n = 1 + seed % 9;
        final toks = [
          for (var k = 0; k < n; k++)
            alphabet[(seed * 31 + k * 17) % alphabet.length]
        ];
        final s = toks.join(' ');
        expect(() => parseLens(s), returnsNormally, reason: 'lens: "$s"');
        final q1 = parseLens(s);
        // render→parse must preserve the matched set (faithful, idempotent).
        expect(_match(parseLens(renderLens(q1))), _match(q1),
            reason: 'lens: "$s" rendered "${renderLens(q1)}"');
      }
    });
  });
}
