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

String _capital(String id, String title, String capital, {String? status}) =>
    '---\nid: $id\ntype: flashcard\ntags: [geography, capitals]\n'
    '${status == null ? '' : 'status: $status\n'}---\n\n'
    '# $title\n\n## Capital\n\n$capital\n';

/// A deck as a file tree with NESTED paths — so the round-trip proves the
/// exporter's folder structure survives the transfer. `japan.md` carries a
/// `status: active` that import must override to `draft`.
final _manifest = DeckManifest(
  deckId: 'world-capitals',
  name: 'World Capitals',
  author: 'Onyx Samples',
  license: 'CC0-1.0',
  files: [
    DeckFile(
        path: 'europe/france.md',
        content: _capital('capitals-france', 'France', 'Paris.')),
    DeckFile(
        path: 'asia/japan.md',
        content:
            _capital('capitals-japan', 'Japan', 'Tokyo.', status: 'active')),
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

    test('writes the file tree under <deckSlug>/, preserving structure',
        () async {
      final count = await importDeck(source, _manifest);
      expect(count, 2);
      // Nested paths survive — the deck arrives as one directory with its layout.
      expect(File('${root.path}/world-capitals/europe/france.md').existsSync(),
          isTrue);
      expect(File('${root.path}/world-capitals/asia/japan.md').existsSync(),
          isTrue);
    });

    test('every card enters as a draft with the deckId set (status forced)',
        () async {
      await importDeck(source, _manifest);
      for (final path in await source.listCardPaths()) {
        final card = _parser.parse(await source.readCard(path), filePath: path);
        expect(card, isNotNull, reason: '$path should parse as a card');
        expect(card!.isDraft, isTrue,
            reason: 'scheduling never travels — even japan.md said active');
        expect(card.status, CardStatus.draft);
        expect(card.deckId, 'world-capitals');
      }
    });

    test('preserves content verbatim (title, tags, section body)', () async {
      await importDeck(source, _manifest);
      const p = 'world-capitals/europe/france.md';
      final france = _parser.parse(await source.readCard(p), filePath: p)!;
      expect(france.id, 'capitals-france');
      expect(france.title, 'France');
      expect(france.tags, ['geography', 'capitals']);
      expect(france.sections.single.heading, 'Capital');
      expect(france.sections.single.content, 'Paris.');
    });

    test('slugifies the deck folder but keeps original id/deck in frontmatter',
        () async {
      final messy = DeckManifest(
        deckId: 'Fancy Deck! v2',
        name: 'Fancy',
        author: 'x',
        files: [
          DeckFile(
              path: 'intro.md', content: _capital('intro-card', 'Intro', 'x.'))
        ],
      );
      await importDeck(source, messy);
      final path = (await source.listCardPaths()).single;
      expect(path, 'fancy-deck-v2/intro.md'); // deck folder slugified
      final card = _parser.parse(await source.readCard(path), filePath: path)!;
      expect(card.id, 'intro-card'); // original id (from content) preserved
      expect(card.deckId, 'Fancy Deck! v2'); // original deck value preserved
    });

    test('a path-escaping segment (..) cannot write outside the deck folder',
        () async {
      final evil = DeckManifest(
        deckId: 'd',
        name: 'D',
        author: 'x',
        files: [
          DeckFile(path: '../../escape.md', content: _capital('e', 'E', 'x.')),
        ],
      );
      await importDeck(source, evil);
      expect(File('${root.path}/escape.md').existsSync(), isFalse);
      expect((await source.listCardPaths()).single, 'd/escape.md');
    });

    test('a file without frontmatter rides along verbatim (a note, not a card)',
        () async {
      const note = 'Just a plain note. No frontmatter, so not a card.\n';
      const withNote = DeckManifest(
        deckId: 'd',
        name: 'D',
        author: 'x',
        files: [DeckFile(path: 'notes/readme.md', content: note)],
      );
      await importDeck(source, withNote);
      final onDisk = File('${root.path}/d/notes/readme.md');
      expect(onDisk.existsSync(), isTrue);
      expect(onDisk.readAsStringSync(), note); // copied verbatim, un-stamped
    });
  });

  group('DeckManifest / DeckFile (scheduling never travels)', () {
    test('the payload types carry no SRS/review data — structural', () {
      final json = _manifest.toJson();
      expect(json.containsKey('srs_state'), isFalse);
      expect(json.containsKey('reviews'), isFalse);
      final fileJson = _manifest.files.first.toJson();
      expect(fileJson.keys, unorderedEquals(['path', 'content']));
      // Round-trips through JSON without losing content or structure.
      final back = DeckManifest.fromJson(json);
      expect(back.deckId, _manifest.deckId);
      expect(back.files.length, _manifest.files.length);
      expect(back.files.first.path, _manifest.files.first.path);
      expect(back.files.first.content, _manifest.files.first.content);
    });
  });

  group('FakeRegistryClient', () {
    test('listDecks returns two decks; getDeck files parse once imported',
        () async {
      final client = FakeRegistryClient();
      final summaries = await client.listDecks();
      expect(summaries.length, 2);

      for (final summary in summaries) {
        final manifest = await client.getDeck(summary.deckId);
        expect(manifest.deckId, summary.deckId);
        expect(manifest.files, isNotEmpty);
        expect(manifest.files.length, summary.cardCount);
        // Each fake file must parse as a draft once stamped by import.
        for (final f in manifest.files) {
          final parsed = _parser.parse(_stamp(manifest.deckId, f.content),
              filePath: f.path);
          expect(parsed, isNotNull, reason: '${f.path} must parse');
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
      expect(result.cards.length, written);
      expect(result.cards.every((c) => c.isDraft), isTrue);
      expect(result.studyCards, isEmpty);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}

/// Mirrors importDeck's frontmatter stamp for the parse-check above.
String _stamp(String deckId, String content) =>
    content.replaceFirst('---\n', '---\ndeck: "$deckId"\nstatus: draft\n');
