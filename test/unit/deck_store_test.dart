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
  @override
  Future<List<String>> listMeta(String subdir) async =>
      meta.keys.where((k) => k.startsWith('$subdir/')).toList()..sort();
  @override
  Future<void> deleteMeta(String name) async {
    meta.remove(name);
    meta.removeWhere((k, _) => k.startsWith('$name/'));
  }
}

void main() {
  group('serialization round-trip', () {
    test('membership queries survive JSON', () {
      for (final q in <CardQuery>[
        const Everything(),
        TagIs('#Scripture'),
        FolderUnder('Math/Calculus/101'),
      ]) {
        final back = CardQuery.fromJson(q.toJson());
        expect(back.toJson(), q.toJson());
      }
      // Unknown kind is a safe Everything.
      expect(CardQuery.fromJson({'kind': 'zzz'}), isA<Everything>());
    });

    test('a full study goal survives JSON', () {
      final goal = Deck(
        id: 'debate',
        name: 'Saints debate',
        templateId: 'orthodoxy',
        membership: TagIs('intercession'),
        priority: PriorityTier.high,
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
    test('save writes per-deck clusters; load round-trips from them (ADR-0019)',
        () async {
      final src = _FakeSource();
      final store = DeckStore(src);
      expect(await store.load(), isEmpty);

      final goals = [
        Deck(
            id: 'korean',
            name: 'Korean',
            templateId: 'korean',
            membership: FolderUnder('korean')),
      ];
      await store.save(goals);
      // Physically laid out as a per-deck cluster under decks/<id>/.
      expect(src.meta.keys, contains('decks/korean/deck.json'));
      expect(src.meta.keys, contains('decks/korean/aims.json'));

      final back = await store.load();
      expect(back.single.id, 'korean');
      expect(back.single.membership, isA<FolderUnder>());
    });

    test('aims live in aims.json; deck.json carries no interviews', () async {
      final src = _FakeSource();
      final deck = Deck(
        id: 'debate',
        name: 'Debate',
        templateId: 't',
        membership: TagIs('intercession'),
        aims: [
          Aim(id: 'jury', companyName: 'Jury', levelId: 'deep', rounds: [
            InterviewRound(
                id: 'jury-r1', number: 1, date: DateTime(2026, 3, 1)),
          ]),
        ],
      );
      await DeckStore(src).save([deck]);
      // The lens/config file must not carry aims — they're split out so a puller's
      // aim overlay can sit apart from the authored lens (ADR-0021).
      expect(src.meta['decks/debate/deck.json'], isNot(contains('interviews')));
      expect(src.meta['decks/debate/aims.json'], contains('jury'));
      final back = await DeckStore(src).load();
      expect(back.single.aims.single.id, 'jury');
    });

    test('removing a deck deletes its cluster (no zombie re-read)', () async {
      final src = _FakeSource();
      final store = DeckStore(src);
      final a =
          Deck(id: 'a', name: 'A', templateId: 't', membership: TagIs('a'));
      final b =
          Deck(id: 'b', name: 'B', templateId: 't', membership: TagIs('b'));
      await store.save([a, b]);
      await store.save([a]); // b removed
      expect((await store.load()).map((g) => g.id), ['a']);
      expect(src.meta.keys.where((k) => k.startsWith('decks/b/')), isEmpty);
    });

    test('per-deck layout wins over a stale legacy blob; blob is retired',
        () async {
      final src = _FakeSource({
        // A leftover blob naming a different deck must be ignored once per-deck
        // dirs exist, and cleaned up on the next save.
        DeckStore.fileName: jsonEncode([
          {'id': 'from-blob', 'name': 'x', 'templateId': 't'}
        ]),
      });
      final store = DeckStore(src);
      await store.save(
          [Deck(id: 'a', name: 'A', templateId: 't', membership: TagIs('a'))]);
      expect(src.meta.keys, isNot(contains(DeckStore.fileName))); // retired
      expect((await store.load()).map((g) => g.id), ['a']);
    });

    test('blob is read as a fallback + migration source when no per-deck dirs',
        () async {
      final src = _FakeSource({
        DeckStore.fileName: jsonEncode([
          {
            'id': 'korean',
            'name': 'Korean',
            'templateId': 'k',
            'membership': {'kind': 'folder', 'value': 'korean'},
          },
        ]),
      });
      expect((await DeckStore(src).load()).single.id, 'korean');
      // A wholly unparseable blob → none (fall back to the synthesized default).
      src.meta[DeckStore.fileName] = '{not json';
      expect(await DeckStore(src).load(), isEmpty);
    });

    test('one malformed deck is skipped per-entry, not the whole file',
        () async {
      // Data-safety regression guard: a single bad/hand-edited row in a synced,
      // user-editable config file must NOT drop every deck (which the next save
      // would then persist as data loss). Holds for the legacy blob…
      final src = _FakeSource({
        DeckStore.fileName: jsonEncode([
          {
            'id': 'korean',
            'name': 'Korean',
            'templateId': 'k',
            'membership': {'kind': 'folder', 'value': 'korean'},
          },
          // Wrong-typed fields DEGRADE (don't throw): numeric levelId, bogus
          // priority → ignored/default.
          {
            'id': 'okbadfield',
            'name': 'OK',
            'templateId': 't',
            'levelId': 7,
            'priority': 'bogus',
          },
          {'name': 'no-usable-id'}, // throws in fromJson → this entry skipped
          'not-even-a-map', // skipped
        ]),
      });
      final back = await DeckStore(src).load();
      expect(back.map((g) => g.id), ['korean', 'okbadfield']);
      expect(back.firstWhere((g) => g.id == 'okbadfield').priority,
          PriorityTier.normal);
    });

    test('…and per-deck: one malformed cluster is skipped, the rest load',
        () async {
      final src = _FakeSource({
        'decks/good/deck.json': jsonEncode({
          'id': 'good',
          'name': 'Good',
          'templateId': 't',
          'membership': {'kind': 'folder', 'value': 'g'},
        }),
        'decks/bad/deck.json': '{ not json',
      });
      expect((await DeckStore(src).load()).map((g) => g.id), ['good']);
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
        membership: FolderUnder('korean'),
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

    test(
        'reading migrates a legacy blob to per-deck clusters (read-only, #161)',
        () async {
      final src = _FakeSource({
        DeckStore.fileName: jsonEncode([
          {
            'id': 'korean',
            'name': 'Korean',
            'templateId': 'korean',
            'membership': {'kind': 'folder', 'value': 'korean'},
          },
        ]),
      });
      final c = ProviderContainer(
          overrides: [vaultSourceProvider.overrideWithValue(src)]);
      addTearDown(c.dispose);

      // A read alone (no mutation) must migrate the blob off, so a read-only user
      // stops depending on it.
      expect((await c.read(decksProvider.future)).map((g) => g.id), ['korean']);
      expect(src.meta.keys, contains('decks/korean/deck.json'));
      expect(src.meta.keys, isNot(contains(DeckStore.fileName)));
    });

    test('all-graduated stored goals fall back to the default', () async {
      final grad = Deck(
        id: 'korean',
        name: 'Korean',
        templateId: 'korean',
        membership: FolderUnder('korean'),
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
