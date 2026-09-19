import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/registry/deck.dart';
import 'package:onyx/core/registry/import_deck.dart';
import 'package:onyx/core/registry/registry_client.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// See vault_indexer_test.dart — the indexer touches SQLite, so skip that group
/// when the host libsqlite3 is unavailable (write+parse needs no DB).
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

const _parser = CardParser();

const _manifest = DeckManifest(
  deckId: 'world-capitals',
  name: 'World Capitals',
  author: 'Onyx Samples',
  license: 'CC0-1.0',
  cards: [
    DeckCard(
      id: 'capitals-france',
      type: 'flashcard',
      title: 'France',
      tags: ['geography', 'capitals'],
      body: '## Capital\n\nParis.',
    ),
    DeckCard(
      id: 'capitals-japan',
      type: 'flashcard',
      title: 'Japan',
      tags: ['geography', 'capitals'],
      body: '## Capital\n\nTokyo.',
    ),
  ],
);

void main() {
  group('importDeck', () {
    late Directory root;
    late DesktopVaultSource source;

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_import_');
      source = DesktopVaultSource(root.path);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('writes one file per card under <deckSlug>/', () async {
      final count = await importDeck(source, _manifest);
      expect(count, 2);

      expect(
        File('${root.path}/world-capitals/capitals-france.md').existsSync(),
        isTrue,
      );
      expect(
        File('${root.path}/world-capitals/capitals-japan.md').existsSync(),
        isTrue,
      );
    });

    test('each written file parses as a draft with the deckId set', () async {
      await importDeck(source, _manifest);

      for (final path in await source.listCardPaths()) {
        final card = _parser.parse(await source.readCard(path), filePath: path);
        expect(card, isNotNull, reason: '$path should parse as a card');
        expect(card!.isDraft, isTrue,
            reason:
                'imported cards enter as drafts (scheduling never travels)');
        expect(card.status, CardStatus.draft);
        expect(card.deckId, 'world-capitals');
      }
    });

    test('preserves title, tags and body sections', () async {
      await importDeck(source, _manifest);
      final france = _parser.parse(
        await source.readCard('world-capitals/capitals-france.md'),
        filePath: 'world-capitals/capitals-france.md',
      )!;
      expect(france.id, 'capitals-france');
      expect(france.type, 'flashcard');
      expect(france.title, 'France');
      expect(france.tags, ['geography', 'capitals']);
      expect(france.sections.map((s) => s.heading), contains('Capital'));
      expect(france.sections.single.content, 'Paris.');
    });

    test('slugifies non-filesystem-safe ids into safe paths', () async {
      const messy = DeckManifest(
        deckId: 'Fancy Deck! v2',
        name: 'Fancy',
        author: 'x',
        cards: [
          DeckCard(
            id: 'Card #1 (Intro)',
            type: 'flashcard',
            title: 'Intro',
            body: '## A\n\nb.',
          ),
        ],
      );
      await importDeck(source, messy);
      // deckId + cardId slugified: lowercase, non-alnum → single hyphen, trimmed.
      final path = (await source.listCardPaths()).single;
      expect(path, 'fancy-deck-v2/card-1-intro.md');
      // …but the frontmatter `id`/`deck` keep the ORIGINAL values.
      final card = _parser.parse(await source.readCard(path), filePath: path)!;
      expect(card.id, 'Card #1 (Intro)');
      expect(card.deckId, 'Fancy Deck! v2');
    });

    test('handles empty tags', () async {
      const noTags = DeckManifest(
        deckId: 'd',
        name: 'D',
        author: 'x',
        cards: [
          DeckCard(id: 'c', type: 'flashcard', title: 'C', body: '## A\n\nb.'),
        ],
      );
      await importDeck(source, noTags);
      final card = _parser.parse(
        await source.readCard('d/c.md'),
        filePath: 'd/c.md',
      )!;
      expect(card.tags, isEmpty);
    });

    test('flattens a newline in a card title so the H1 stays one line',
        () async {
      const messy = DeckManifest(
        deckId: 'd',
        name: 'D',
        author: 'x',
        cards: [
          DeckCard(
            id: 'c',
            type: 'flashcard',
            title: 'Title with\na newline',
            body: '## A\n\nb.',
          ),
        ],
      );
      await importDeck(source, messy);
      final card = _parser.parse(
        await source.readCard('d/c.md'),
        filePath: 'd/c.md',
      )!;
      expect(card.title, 'Title with a newline');
      expect(card.sections.map((s) => s.heading), contains('A'));
    });
  });

  group('DeckManifest / DeckCard (scheduling never travels)', () {
    test('the payload types carry no SRS/review data — structural', () {
      // A pulled manifest can only surface content. There is deliberately no
      // srs_state / reviews field to travel in (invariant S8 / T4).
      final json = _manifest.toJson();
      expect(json.containsKey('srs_state'), isFalse);
      expect(json.containsKey('reviews'), isFalse);
      final cardJson = _manifest.cards.first.toJson();
      expect(cardJson.containsKey('srs_state'), isFalse);
      expect(cardJson.containsKey('reviews'), isFalse);
      // Round-trips through JSON without losing content.
      final back = DeckManifest.fromJson(json);
      expect(back.deckId, _manifest.deckId);
      expect(back.cards.length, _manifest.cards.length);
      expect(back.cards.first.body, _manifest.cards.first.body);
    });
  });

  group('FakeRegistryClient', () {
    test('listDecks returns two decks; getDeck round-trips with parsing cards',
        () async {
      const client = FakeRegistryClient();
      final summaries = await client.listDecks();
      expect(summaries.length, 2);

      for (final summary in summaries) {
        final manifest = await client.getDeck(summary.deckId);
        expect(manifest.deckId, summary.deckId);
        expect(manifest.cards, isNotEmpty);
        expect(manifest.cards.length, summary.cardCount);
        // Every fake card must be a body that CardParser accepts once imported.
        for (final card in manifest.cards) {
          final md = '''
---
id: ${card.id}
type: ${card.type}
deck: ${manifest.deckId}
status: draft
---

# ${card.title}

${card.body}
''';
          final parsed = _parser.parse(md, filePath: '${card.id}.md');
          expect(parsed, isNotNull, reason: '${card.id} must parse');
          expect(parsed!.isDraft, isTrue);
        }
      }
    });
  });

  group('imported drafts in the index', () {
    late Directory root;
    late DesktopVaultSource source;
    late AppDatabase db;

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_import_index_');
      source = DesktopVaultSource(root.path);
      db = AppDatabase.withExecutor(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });

    test('cards includes the drafts; studyCards EXCLUDES them', () async {
      final written = await importDeck(source, _manifest);
      final result = await VaultIndexer(source, db).reindex();

      // All imported cards are present in the full index (Browse reads this)…
      expect(result.cards.length, written);
      expect(result.cards.every((c) => c.isDraft), isTrue);
      // …but none are studiable: scheduling never travels, so they're excluded
      // from the study set (schedulers + readiness read studyCards).
      expect(result.studyCards, isEmpty);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
