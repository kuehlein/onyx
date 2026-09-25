import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/deck_template.dart';
import 'package:onyx/shared/models/card.dart';

Card _card(String id, {List<String> tags = const [], String? path}) => Card(
      id: id,
      type: 'flashcard',
      title: id,
      overview: '',
      tags: tags,
      tiers: const {},
      sections: const [],
      wikilinks: const [],
      filePath: path ?? '$id.md',
    );

const _template = DeckTemplate(
  id: 'demo',
  target: TargetSpec(
    levels: [
      LevelValue(id: 'l', label: 'L', tierCurve: [1.0])
    ],
    contexts: [ContextValue(id: 'c', label: 'C', stabilityTargetDays: 30)],
    tracks: [TrackValue(id: 't', label: 'T')],
    families: [],
    fallbackLevelId: 'l',
    fallbackContextId: 'c',
    fallbackTrackId: 't',
  ),
);

void main() {
  final cards = [
    _card('a', tags: ['scripture'], path: 'Bible/john.md'),
    _card('b', tags: ['#History'], path: 'History/nicaea.md'),
    _card('c', tags: ['scripture', 'theology'], path: 'Theology/saints.md'),
    _card('d', path: 'Math/Calculus/101/limits.md'),
  ];

  group('CardQuery', () {
    test('Everything selects everything', () {
      expect(const Everything().matches(cards.first), isTrue);
    });

    test('TagIs is cross-cutting and case/# insensitive', () {
      final q = TagIs('#Scripture');
      final members = cards.where(q.matches).map((c) => c.id).toList();
      // Gathers scattered cards across folders, ignoring structure.
      expect(members, ['a', 'c']);
      expect(TagIs('history').matches(cards[1]), isTrue);
    });

    test('FolderUnder scopes to a subtree', () {
      expect(FolderUnder('Math/Calculus').matches(cards[3]), isTrue);
      expect(FolderUnder('Math/Calculus/101').matches(cards[3]), isTrue);
      expect(FolderUnder('Bible').matches(cards[3]), isFalse);
      // A folder prefix must be a path boundary, not a substring.
      expect(FolderUnder('Math/Calc').matches(cards[3]), isFalse);
      // Empty path matches all.
      expect(FolderUnder('').matches(cards[3]), isTrue);
    });
  });

  group('Deck', () {
    test('select applies the membership query', () {
      final goal = Deck(
        id: 'debate',
        name: 'Saints debate',
        templateId: 'demo',
        membership: TagIs('scripture'),
      );
      expect(goal.select(cards).map((c) => c.id), ['a', 'c']);
      expect(goal.isActive, isTrue);
    });

    test('the implicit default goal is the whole vault', () {
      final goal = defaultDeckFor(_template);
      expect(goal.id, defaultDeckId);
      expect(goal.templateId, 'demo');
      expect(goal.membership, isA<Everything>());
      expect(goal.select(cards).length, cards.length);
    });

    test('copyWith updates fields but keeps id', () {
      final g = defaultDeckFor(_template)
          .copyWith(state: DeckState.paused, budgetWeight: 0.3);
      expect(g.id, defaultDeckId);
      expect(g.state, DeckState.paused);
      expect(g.budgetWeight, 0.3);
      expect(g.isActive, isFalse);
    });

    test(
        'the interview facet round-trips through JSON + rounds logic (Phase B)',
        () {
      final aim = Aim(
        companyName: 'Acme',
        rounds: [
          InterviewRound(
              id: 'r1',
              number: 1,
              type: InterviewRoundType.screen,
              date: DateTime(2026, 4, 1),
              outcome: AimOutcome.passed),
          InterviewRound(
              id: 'r2',
              number: 2,
              type: InterviewRoundType.onsite,
              date: DateTime(2026, 5, 1)),
        ],
        domainWeights: {'arrays': 1.5},
      );
      const deckId = 'acme';
      final goal = Deck(
        id: deckId,
        name: 'Acme',
        templateId: 'demo',
        aims: [aim],
      );

      final back = Deck.fromJson(goal.toJson());
      expect(back.aims.length, 1);
      final iv = back.aims.single;
      expect(iv.companyName, 'Acme');
      expect(iv.rounds.length, 2);
      expect(iv.domainWeights['arrays'], 1.5);

      // The upcoming round is the first pending one; the passed one is history.
      expect(iv.currentRound()?.id, 'r2');
      expect(iv.pastRounds().map((r) => r.id), ['r1']);

      // A plain study goal has no interviews.
      expect(defaultDeckFor(_template).aims, isEmpty);
    });

    test('fromJson coerces empty-string / wrong-type slots to null', () {
      // A hand-edited/corrupted _meta file: '' and a number must not leak junk
      // slot ids into the folded target aim (they'd mis-resolve readiness).
      final g = Deck.fromJson({
        'id': 'd',
        'name': 'D',
        'templateId': 't',
        'levelId': '',
        'contextId': 42,
        'trackId': 'senior',
      });
      final a = g.aims.single; // only the real 'senior' slot folds
      expect(a.levelId, isNull); // '' ignored
      expect(a.contextId, isNull); // 42 ignored
      expect(a.trackId, 'senior');
    });

    test('fromJson throws on a missing/blank id (so the store skips just it)',
        () {
      expect(() => Deck.fromJson({'name': 'x', 'templateId': 't'}),
          throwsFormatException);
      expect(
          () => Deck.fromJson({'id': '', 'name': 'x'}), throwsFormatException);
    });

    test('soonestAimDate is the soonest live-aim round; skips paused/ended',
        () {
      final today = DateTime(2026, 1, 1);
      Deck deck(List<Aim> aims) =>
          Deck(id: 'd', name: 'D', templateId: 't', aims: aims);
      InterviewRound r(String id, DateTime date) =>
          InterviewRound(id: id, number: 1, date: date);

      // Soonest across two active aims.
      expect(
        deck([
          Aim(id: 'a', rounds: [r('a1', DateTime(2026, 5, 1))]),
          Aim(id: 'b', rounds: [r('b1', DateTime(2026, 3, 1))]),
        ]).soonestAimDate(today),
        DateTime(2026, 3, 1),
      );
      // Paused + ended aims are skipped (their earlier dates don't win).
      expect(
        deck([
          Aim(id: 'p', active: false, rounds: [r('p1', DateTime(2026, 2, 1))]),
          Aim(
              id: 'e',
              status: InterviewStatus.rejected,
              rounds: [r('e1', DateTime(2026, 2, 15))]),
          Aim(id: 'a', rounds: [r('a1', DateTime(2026, 4, 1))]),
        ]).soonestAimDate(today),
        DateTime(2026, 4, 1),
      );
      // No live dated aim → null (open-ended / 0-aim).
      expect(deck([const Aim(id: 'x')]).soonestAimDate(today), isNull);
    });
  });

  group('Aim.isScheduledInterview', () {
    InterviewRound r(String id,
            {InterviewRoundType type = InterviewRoundType.other,
            AimOutcome outcome = AimOutcome.pending}) =>
        InterviewRound(id: id, number: 1, type: type, outcome: outcome);

    test('a bare target (no company, <=1 untyped pending round) is not one',
        () {
      expect(const Aim(id: 'a').isScheduledInterview, isFalse); // no rounds
      expect(Aim(id: 'a', rounds: [r('a1')]).isScheduledInterview,
          isFalse); // one untyped date-holder
    });

    test('company / typed round / resolved round / >1 round makes it one', () {
      expect(const Aim(id: 'a', companyName: 'Google').isScheduledInterview,
          isTrue);
      expect(
          Aim(id: 'a', rounds: [r('a1', type: InterviewRoundType.onsite)])
              .isScheduledInterview,
          isTrue);
      expect(
          Aim(id: 'a', rounds: [r('a1', outcome: AimOutcome.passed)])
              .isScheduledInterview,
          isTrue);
      expect(Aim(id: 'a', rounds: [r('a1'), r('a2')]).isScheduledInterview,
          isTrue);
    });
  });
}
