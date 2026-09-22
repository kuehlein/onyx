import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/deck/deck.dart';
import 'package:onyx/core/template/deck_template.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/decks.dart';
import 'package:onyx/shared/providers/template.dart';
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

DeckTemplate _template(String id, double stabilityDays) => DeckTemplate(
      id: id,
      target: TargetSpec(
        levels: const [
          LevelValue(id: 'l', label: 'L', tierCurve: [1.0])
        ],
        contexts: [
          ContextValue(id: 'c', label: 'C', stabilityTargetDays: stabilityDays)
        ],
        tracks: const [TrackValue(id: 't', label: 'T')],
        families: const [],
        fallbackLevelId: 'l',
        fallbackContextId: 'c',
        fallbackTrackId: 't',
      ),
    );

class _FixedGoals extends Decks {
  _FixedGoals(this._goals);
  final List<Deck> _goals;
  @override
  Future<List<Deck>> build() async => _goals;
}

void main() {
  // Two templates with very different durability bars; one goal on each.
  final registry = TemplateRegistry(entries: [
    TemplateEntry(rootDir: '', config: _template('short', 20)),
    TemplateEntry(rootDir: 'x', config: _template('long', 200)),
  ], primaryId: 'short');

  const index = IndexResult(
    cards: [
      Card(
        id: 'a',
        type: 'flashcard',
        title: 'A',
        overview: '',
        tags: ['x'],
        tiers: {},
        sections: [
          CardSection(
              heading: 'Def', slug: 'def', content: 'x', quizzable: true),
        ],
        wikilinks: [],
        filePath: 'a.md',
      ),
    ],
    idless: 0,
    malformed: 0,
    skipped: 0,
  );
  final states = SectionStates({
    'a::def': SrsState(
      cardId: 'a',
      sectionSlug: 'def',
      stability: 60,
      difficulty: 5,
      state: 2,
      dueAt: DateTime(2026),
      reviewCount: 1,
    ),
  });

  test('a goal is scored against its own template durability bar', () async {
    if (!_sqliteAvailable) return;
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase.withExecutor(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      vaultIndexProvider.overrideWith((ref) async => index),
      srsStatesProvider.overrideWith((ref) async => states),
      templateRegistryProvider.overrideWith((ref) async => registry),
      decksProvider.overrideWith(() => _FixedGoals(const [
            Deck(id: 'g-short', name: 'S', templateId: 'short'),
            Deck(id: 'g-long', name: 'L', templateId: 'long'),
          ])),
    ]);
    addTearDown(c.dispose);
    c.listen(deckReadinessProvider('g-short'), (_, __) {});
    c.listen(deckReadinessProvider('g-long'), (_, __) {});

    final short = await c.read(deckReadinessProvider('g-short').future);
    final long = await c.read(deckReadinessProvider('g-long').future);

    // Same card + stability (60), but the short-durability template counts it as
    // fully learned while the long-durability one still sees it as maturing → the
    // short goal reads more ready. (Proves per-goal template scoring, not global.)
    expect(short.overall, greaterThan(long.overall));
  });
}
