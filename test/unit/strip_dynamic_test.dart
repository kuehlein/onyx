import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart'; // re-exports core/query/card_query
import 'package:onyx/shared/models/card.dart';

/// `stripDynamic` (ADR-0013 §Addendum, G3.1): a persisted deck lens must be
/// STRUCTURAL — `Deck.select` evaluates membership with no `QueryContext`, so a
/// persisted `StateIs` would match nothing and silently empty the deck. Stripping
/// drops the dynamic constraint (widening) and never leaves a `StateIs` behind;
/// an all-dynamic query degrades to the whole vault, never the empty set.

Card _c(String id, {String type = 'flashcard', int tier = 1}) => Card(
      id: id,
      type: type,
      title: id,
      overview: '',
      tags: ['ds-a'],
      tiers: {'ds-a': tier},
      sections: const [
        CardSection(heading: 'H', slug: 'h', content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

final _corpus = [
  _c('a', type: 'flashcard', tier: 1),
  _c('b', type: 'flashcard', tier: 2),
  _c('c', type: 'interview-question', tier: 1),
];

/// True if any StateIs survives anywhere in the tree.
bool _hasState(CardQuery q) => switch (q) {
      StateIs() => true,
      And(:final of) => of.any(_hasState),
      Or(:final of) => of.any(_hasState),
      Not(:final q) => _hasState(q),
      _ => false,
    };

// Deck membership is evaluated with NO context (like Deck.select).
List<String> _members(CardQuery q) => [
      for (final c in _corpus)
        if (q.matches(c)) c.id
    ]..sort();

void main() {
  group('stripDynamic', () {
    test('a lone StateIs → the whole vault (never empty)', () {
      expect(stripDynamic(const StateIs(MasteryFilter.due)), isA<Everything>());
      expect(_members(stripDynamic(const StateIs(MasteryFilter.due))),
          ['a', 'b', 'c']);
    });

    test('a purely structural query is preserved (matches identically)', () {
      final queries = <CardQuery>[
        CardQuery.everything,
        const TypeIs('flashcard'),
        const TierIs(1),
        const And([TypeIs('flashcard'), TierIs(1)]),
        const Or([TierIs(1), TypeIs('interview-question')]),
        const Not(TypeIs('flashcard')),
      ];
      for (final q in queries) {
        expect(_members(stripDynamic(q)), _members(q), reason: '${q.toJson()}');
        expect(_hasState(stripDynamic(q)), isFalse);
      }
    });

    test('And drops a StateIs conjunct, keeping the structural rest', () {
      const q = And([TypeIs('flashcard'), StateIs(MasteryFilter.due)]);
      expect(_members(stripDynamic(q)), _members(const TypeIs('flashcard')));
      expect(_hasState(stripDynamic(q)), isFalse);
    });

    test('a mastery facet (Or of StateIs) AND-ed on is dropped whole', () {
      // What a Browse "is:due OR is:strong" chip compiles to, AND-ed with a type.
      const q = And([
        TypeIs('flashcard'),
        Or([StateIs(MasteryFilter.due), StateIs(MasteryFilter.strong)]),
      ]);
      expect(_members(stripDynamic(q)), ['a', 'b']); // both flashcards
      expect(_hasState(stripDynamic(q)), isFalse);
    });

    test('Or drops only the dynamic branch (narrowing)', () {
      const q = Or([TypeIs('interview-question'), StateIs(MasteryFilter.due)]);
      expect(_members(stripDynamic(q)), ['c']); // just the structural branch
      expect(_hasState(stripDynamic(q)), isFalse);
    });

    test('a negated study state (-is:due) → no constraint', () {
      expect(stripDynamic(const Not(StateIs(MasteryFilter.due))),
          isA<Everything>());
    });

    test('Not over a subtree with StateIs is DROPPED (widens, never narrows)',
        () {
      // Not(And([type, is:due])) must NOT reduce to Not(type) — that would exclude
      // the not-due type cards the original kept (a narrowing). Drop the whole Not.
      const q = Not(And([TypeIs('flashcard'), StateIs(MasteryFilter.due)]));
      expect(stripDynamic(q), isA<Everything>());
      expect(_hasState(stripDynamic(q)), isFalse);
      // a Not with a purely-structural subtree is preserved
      expect(stripDynamic(const Not(TypeIs('flashcard'))), isA<Not>());
    });

    test(
        'a Not INSIDE an Or drops just that dynamic disjunct (keeps structural)',
        () {
      // `-is:due OR type:flashcard` typed into the Advanced field. The dynamic
      // disjunct can't be evaluated by a lens, so it's dropped and the STRUCTURAL
      // disjunct kept — a faithful, non-empty degradation (deliberately NOT widened
      // to the whole vault, NOT emptied). Pins the chosen semantics for a mixed Or
      // (an unpinned edge the review flagged; the structural-remnant choice is more
      // faithful to what the user typed than collapsing the Or to Everything).
      const q = Or([Not(StateIs(MasteryFilter.due)), TypeIs('flashcard')]);
      expect(_members(stripDynamic(q)), _members(const TypeIs('flashcard')));
      expect(_hasState(stripDynamic(q)), isFalse);
    });

    test('a Not OVER a dynamic Or is dropped whole (widens to everything)', () {
      // `!(is:due OR is:strong)` — the entire negation is dropped (widens), never
      // reduced to a narrowing structural remnant.
      const q =
          Not(Or([StateIs(MasteryFilter.due), StateIs(MasteryFilter.strong)]));
      expect(stripDynamic(q), isA<Everything>());
      expect(_hasState(stripDynamic(q)), isFalse);
    });

    test('Deck.fromJson strips a persisted StateIs on LOAD (defense-in-depth)',
        () {
      // A StateIs that reached the file would otherwise empty the deck (Deck.select
      // has no context). fromJson must strip it too, not just save.
      final deck = Deck.fromJson({
        'id': 'd',
        'name': 'D',
        'templateId': '',
        'membership': {
          'kind': 'and',
          'of': [
            {'kind': 'folder', 'value': 'korean'},
            {'kind': 'state', 'value': 'due'},
          ],
        },
      });
      expect(_hasState(deck.membership), isFalse);
      expect(
          deck.membership, isA<FolderUnder>()); // just the structural conjunct
    });

    test('nested: structural survives, all dynamic collapses to everything',
        () {
      expect(
        stripDynamic(const And([
          Or([StateIs(MasteryFilter.due)]),
          Not(StateIs(MasteryFilter.strong)),
        ])),
        isA<Everything>(),
      );
      const mixed = And([
        Or([TierIs(1), TierIs(2)]),
        StateIs(MasteryFilter.fresh),
      ]);
      expect(
          _members(stripDynamic(mixed)), ['a', 'b', 'c']); // tier 1 or 2 = all
      expect(_hasState(stripDynamic(mixed)), isFalse);
    });
  });
}
