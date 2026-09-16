import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/study_goal.dart';
import 'package:onyx/core/subject/subject_config.dart';
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

const _template = SubjectConfig(
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

  group('MembershipQuery', () {
    test('AllCards selects everything', () {
      expect(const AllCards().matches(cards.first), isTrue);
    });

    test('TagMembership is cross-cutting and case/# insensitive', () {
      final q = TagMembership('#Scripture');
      final members = cards.where(q.matches).map((c) => c.id).toList();
      // Gathers scattered cards across folders, ignoring structure.
      expect(members, ['a', 'c']);
      expect(TagMembership('history').matches(cards[1]), isTrue);
    });

    test('FolderMembership scopes to a subtree', () {
      expect(FolderMembership('Math/Calculus').matches(cards[3]), isTrue);
      expect(FolderMembership('Math/Calculus/101').matches(cards[3]), isTrue);
      expect(FolderMembership('Bible').matches(cards[3]), isFalse);
      // A folder prefix must be a path boundary, not a substring.
      expect(FolderMembership('Math/Calc').matches(cards[3]), isFalse);
      // Empty path matches all.
      expect(FolderMembership('').matches(cards[3]), isTrue);
    });
  });

  group('StudyGoal', () {
    test('select applies the membership query', () {
      final goal = StudyGoal(
        id: 'debate',
        name: 'Saints debate',
        templateId: 'demo',
        membership: TagMembership('scripture'),
      );
      expect(goal.select(cards).map((c) => c.id), ['a', 'c']);
      expect(goal.isActive, isTrue);
    });

    test('the implicit default goal is the whole vault', () {
      final goal = defaultGoalFor(_template);
      expect(goal.id, defaultGoalId);
      expect(goal.templateId, 'demo');
      expect(goal.membership, isA<AllCards>());
      expect(goal.select(cards).length, cards.length);
    });

    test('toTarget resolves null slots to the template fallbacks + deadline',
        () {
      // A deadline with a time-of-day is coerced to date-only midnight.
      final deadline = DateTime(2026, 3, 1, 20, 30);
      // Null slots → template fallbacks.
      final bare = defaultGoalFor(_template).copyWith(deadline: deadline);
      final t1 = bare.toTarget(_template);
      expect([t1.levelId, t1.contextId, t1.trackId], ['l', 'c', 't']);
      expect(t1.interviewDate, DateTime(2026, 3, 1));

      // Empty-string slots also fall back to the template (not kept as '').
      final empty = defaultGoalFor(_template)
          .copyWith(levelId: '', contextId: '', trackId: '');
      final te = empty.toTarget(_template);
      expect([te.levelId, te.contextId, te.trackId], ['l', 'c', 't']);

      // Explicit slots win.
      const chosen = StudyGoal(
        id: 'g',
        name: 'G',
        templateId: 'demo',
        levelId: 'sr',
        contextId: 'exam',
        trackId: 'read',
      );
      final t2 = chosen.toTarget(_template);
      expect([t2.levelId, t2.contextId, t2.trackId], ['sr', 'exam', 'read']);
    });

    test('copyWith updates fields but keeps id', () {
      final g = defaultGoalFor(_template)
          .copyWith(state: GoalState.paused, budgetWeight: 0.3);
      expect(g.id, defaultGoalId);
      expect(g.state, GoalState.paused);
      expect(g.budgetWeight, 0.3);
      expect(g.isActive, isFalse);
    });

    test('copyWith can clear a nullable field back to null', () {
      final dated =
          defaultGoalFor(_template).copyWith(deadline: DateTime(2026));
      expect(dated.deadline, isNotNull);
      // Omitting deadline keeps it; passing null clears it.
      expect(dated.copyWith(budgetWeight: 0.5).deadline, isNotNull);
      expect(dated.copyWith(deadline: null).deadline, isNull);
    });
  });
}
