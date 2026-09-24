import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/deck/deck_store.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/active_template.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/core/vault/vault_source.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/vault.dart';

class _FakeSource implements VaultSource {
  _FakeSource([Map<String, String>? meta]) : meta = meta ?? {};
  final Map<String, String> meta;
  @override
  String get rootLabel => 'fake';
  @override
  Future<List<String>> listCardPaths() async => const [];
  @override
  Future<List<String>> listAllPaths() => listCardPaths();
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
  @override
  Future<void> deleteFile(String path) async {}
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
      final goal = Deck(
        id: 'debate',
        name: 'Saints debate',
        templateId: 'orthodoxy',
        membership: TagMembership('intercession'),
        budgetWeight: 0.4,
        state: DeckState.paused,
        // Post-S5 the target lives on the aim, not deck slots.
        aims: [
          Aim(
              id: 'jury',
              companyName: 'Diocesan jury',
              levelId: 'deep',
              rounds: [
                InterviewRound(
                    id: 'jury-r1', number: 1, date: DateTime(2026, 3, 1)),
              ]),
        ],
      );
      expect(Deck.fromJson(goal.toJson()).toJson(), goal.toJson());
    });
  });

  group('DeckStore', () {
    test('save then load round-trips; empty/malformed → none', () async {
      final src = _FakeSource();
      final store = DeckStore(src);
      expect(await store.load(), isEmpty);

      final goals = [
        Deck(
            id: 'korean',
            name: 'Korean',
            templateId: 'korean',
            membership: FolderMembership('korean')),
      ];
      await store.save(goals);
      final back = await store.load();
      expect(back.single.id, 'korean');
      expect(back.single.membership, isA<FolderMembership>());

      src.meta[DeckStore.fileName] = '{not json';
      expect(await store.load(), isEmpty);
    });
  });

  group('decksProvider', () {
    tearDown(() {
      activeTemplate = softwareInterviewsTemplate;
      activeRegistry = TemplateRegistry.single(softwareInterviewsTemplate);
    });

    test('no stored goals → just the synthesized default', () async {
      final c = ProviderContainer(overrides: [
        vaultSourceProvider.overrideWithValue(_FakeSource()),
      ]);
      addTearDown(c.dispose);
      final goals = await c.read(decksProvider.future);
      expect(goals.map((g) => g.id), [defaultDeckId]);
    });

    test('stored goals replace the default (which is only a fallback)',
        () async {
      final stored = Deck(
        id: 'korean',
        name: 'Korean',
        templateId: 'korean',
        membership: FolderMembership('korean'),
      );
      final src = _FakeSource({
        DeckStore.fileName: jsonEncode([
          stored.toJson(),
          // A stored goal colliding with the default id must be dropped.
          {'id': defaultDeckId, 'name': 'x', 'templateId': 'y'},
        ]),
      });
      final c = ProviderContainer(
        overrides: [vaultSourceProvider.overrideWithValue(src)],
      );
      addTearDown(c.dispose);

      final goals = await c.read(decksProvider.future);
      // The whole-vault default steps aside once explicit goals exist.
      expect(goals.map((g) => g.id), ['korean']);
    });

    test('all-graduated stored goals fall back to the default', () async {
      final grad = Deck(
        id: 'korean',
        name: 'Korean',
        templateId: 'korean',
        membership: FolderMembership('korean'),
        state: DeckState.graduated,
      );
      final src = _FakeSource({
        DeckStore.fileName: jsonEncode([grad.toJson()])
      });
      final c = ProviderContainer(
          overrides: [vaultSourceProvider.overrideWithValue(src)]);
      addTearDown(c.dispose);

      // No non-graduated goal → degrade to the whole-vault default, not run off
      // an archived goal.
      final goals = await c.read(decksProvider.future);
      expect(goals.map((g) => g.id), [defaultDeckId]);
    });
  });
}
