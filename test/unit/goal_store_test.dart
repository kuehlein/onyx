import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/goal_store.dart';
import 'package:onyx/core/goal/study_goal.dart';
import 'package:onyx/core/subject/active_subject.dart';
import 'package:onyx/core/subject/software_interviews.dart';
import 'package:onyx/core/subject/subject_registry.dart';
import 'package:onyx/core/vault/vault_source.dart';
import 'package:onyx/shared/providers/study_goals.dart';
import 'package:onyx/shared/providers/vault.dart';

class _FakeSource implements VaultSource {
  _FakeSource([Map<String, String>? meta]) : meta = meta ?? {};
  final Map<String, String> meta;
  @override
  String get rootLabel => 'fake';
  @override
  Future<List<String>> listCardPaths() async => const [];
  @override
  Future<List<String>> listConfigPaths() async => const [];
  @override
  Future<String> readCard(String path) async => '';
  @override
  Future<String?> readMeta(String name) async => meta[name];
  @override
  Future<void> writeMeta(String name, String content) async =>
      meta[name] = content;
  @override
  Future<void> writeFile(String path, String content) async {}
}

void main() {
  group('serialization round-trip', () {
    test('membership queries survive JSON', () {
      for (final q in <MembershipQuery>[
        const AllCards(),
        TagMembership('#Scripture'),
        FolderMembership('Math/Calculus/101'),
      ]) {
        final back = MembershipQuery.fromJson(q.toJson());
        expect(back.toJson(), q.toJson());
      }
      // Unknown kind is a safe AllCards.
      expect(MembershipQuery.fromJson({'kind': 'zzz'}), isA<AllCards>());
    });

    test('a full study goal survives JSON', () {
      final goal = StudyGoal(
        id: 'debate',
        name: 'Saints debate',
        templateId: 'orthodoxy',
        membership: TagMembership('intercession'),
        levelId: 'deep',
        deadline: DateTime(2026, 3, 1),
        budgetWeight: 0.4,
        state: GoalState.paused,
      );
      expect(StudyGoal.fromJson(goal.toJson()).toJson(), goal.toJson());
    });
  });

  group('GoalStore', () {
    test('save then load round-trips; empty/malformed → none', () async {
      final src = _FakeSource();
      final store = GoalStore(src);
      expect(await store.load(), isEmpty);

      final goals = [
        StudyGoal(
            id: 'korean',
            name: 'Korean',
            templateId: 'korean',
            membership: FolderMembership('korean')),
      ];
      await store.save(goals);
      final back = await store.load();
      expect(back.single.id, 'korean');
      expect(back.single.membership, isA<FolderMembership>());

      src.meta[GoalStore.fileName] = '{not json';
      expect(await store.load(), isEmpty);
    });
  });

  group('studyGoalsProvider', () {
    tearDown(() {
      activeSubject = softwareInterviewsConfig;
      activeRegistry = SubjectRegistry.single(softwareInterviewsConfig);
    });

    test('leads with the default goal, then stored goals', () async {
      final stored = StudyGoal(
        id: 'korean',
        name: 'Korean',
        templateId: 'korean',
        membership: FolderMembership('korean'),
      );
      final src = _FakeSource({
        GoalStore.fileName: jsonEncode([
          stored.toJson(),
          // A stored goal colliding with the default id must be dropped.
          {'id': defaultGoalId, 'name': 'x', 'templateId': 'y'},
        ]),
      });
      final c = ProviderContainer(
        overrides: [vaultSourceProvider.overrideWithValue(src)],
      );
      addTearDown(c.dispose);

      final goals = await c.read(studyGoalsProvider.future);
      expect(goals.first.id, defaultGoalId);
      expect(goals.map((g) => g.id), ['default', 'korean']);
    });
  });
}
