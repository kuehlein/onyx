import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/learn.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/vault.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

Card _card(String id, {required String path}) => Card(
      id: id,
      type: 'flashcard',
      title: id,
      overview: '',
      tags: const ['x'],
      tiers: const {},
      sections: [
        const CardSection(
            heading: 'Def', slug: 'def', content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: path,
    );

class _FixedGoals extends Decks {
  _FixedGoals(this._goals);
  final List<Deck> _goals;
  @override
  Future<List<Deck>> build() async => _goals;
}

void main() {
  // Two folder areas; the learn/review queues should surface only the active
  // goal's cards (task #30d in-lane scoping).
  final index = IndexResult(
    cards: [
      _card('a1', path: 'alpha/a1.md'),
      _card('a2', path: 'alpha/a2.md'),
      _card('b1', path: 'beta/b1.md'),
    ],
    idless: 0,
    malformed: 0,
    skipped: 0,
  );

  ProviderContainer make(Deck goal) => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase.withExecutor(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        vaultIndexProvider.overrideWith((ref) async => index),
        decksProvider.overrideWith(() => _FixedGoals([goal])),
      ]);

  test('learn queue scopes to the active goal', () async {
    if (!_sqliteAvailable) return;
    final c = make(Deck(
      id: 'alpha',
      name: 'Alpha',
      templateId: 'software-interviews',
      membership: FolderUnder('alpha'),
    ));
    addTearDown(c.dispose);
    c.listen(learnQueueProvider, (_, __) {});

    final learn = await c.read(learnQueueProvider.future);
    final ids = {for (final it in learn) it.card.id};
    expect(ids, {'a1', 'a2'});
    expect(ids.contains('b1'), isFalse);
  });

  test('a beta goal learns only beta cards', () async {
    if (!_sqliteAvailable) return;
    final c = make(Deck(
      id: 'beta',
      name: 'Beta',
      templateId: 'software-interviews',
      membership: FolderUnder('beta'),
    ));
    addTearDown(c.dispose);
    c.listen(learnQueueProvider, (_, __) {});

    final learn = await c.read(learnQueueProvider.future);
    expect({for (final it in learn) it.card.id}, {'b1'});
  });
}
