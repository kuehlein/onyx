import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/ai/card_generation.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/card_parser.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/generated_cards.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// The indexer touches SQLite; skip that group when host libsqlite3 is missing
/// (write + parse needs no DB). Mirrors import_deck_test.dart.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

const _parser = CardParser();

const _batch = GeneratedBatch(
  name: 'TCP fundamentals',
  cards: [
    GeneratedCard(
      title: 'TCP handshake',
      tags: ['tcp', 'networking'],
      sections: [
        (heading: 'When to Use', content: 'When you need reliable delivery.'),
        (
          heading: 'vs UDP',
          content: 'TCP is reliable + ordered; UDP is fire-and-forget.'
        ),
      ],
    ),
    GeneratedCard(
      title: 'Flow control',
      tags: ['tcp'],
      sections: [
        (heading: 'Key idea', content: 'The receiver advertises a window.'),
      ],
    ),
  ],
);

void main() {
  group('writeGeneratedCards', () {
    late Directory root;
    late DesktopVaultSource source;

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_gen_');
      source = DesktopVaultSource(root.path);
    });

    tearDown(() => root.deleteSync(recursive: true));

    test('writes one file per card under <nameSlug>/ and returns the count',
        () async {
      final count = await writeGeneratedCards(source, _batch);
      expect(count, 2);
      final paths = await source.listCardPaths();
      expect(paths, contains('tcp-fundamentals/tcp-handshake.md'));
      expect(paths, contains('tcp-fundamentals/flow-control.md'));
    });

    test('each written file parses as a LOCAL draft (deckId empty)', () async {
      await writeGeneratedCards(source, _batch);
      for (final path in await source.listCardPaths()) {
        final card = _parser.parse(await source.readCard(path), filePath: path);
        expect(card, isNotNull, reason: '$path should parse');
        expect(card!.isDraft, isTrue,
            reason: 'generated cards enter as drafts');
        expect(card.status, CardStatus.draft);
        expect(card.deckId, '',
            reason: 'no deck: field — local content, not a pulled deck');
        expect(card.type, 'flashcard');
      }
    });

    test('preserves title, tags, and all sections', () async {
      await writeGeneratedCards(source, _batch);
      final card = _parser.parse(
        await source.readCard('tcp-fundamentals/tcp-handshake.md'),
        filePath: 'tcp-fundamentals/tcp-handshake.md',
      )!;
      expect(card.id, 'tcp-handshake');
      expect(card.title, 'TCP handshake');
      expect(card.tags, ['tcp', 'networking']);
      expect(card.sections.map((s) => s.heading), ['When to Use', 'vs UDP']);
      expect(card.sections.first.content, 'When you need reliable delivery.');
      expect(card.sections[1].content,
          'TCP is reliable + ordered; UDP is fire-and-forget.');
      // These generated sections are quizzable (not blocklisted).
      expect(card.quizzableSections, isNotEmpty);
    });

    test('de-dupes filename slugs within a batch (-2, -3 …)', () async {
      const dupes = GeneratedBatch(
        name: 'Dupes',
        cards: [
          GeneratedCard(
            title: 'Same Title',
            tags: [],
            sections: [(heading: 'A', content: 'first')],
          ),
          GeneratedCard(
            title: 'Same Title',
            tags: [],
            sections: [(heading: 'A', content: 'second')],
          ),
          GeneratedCard(
            title: 'Same Title',
            tags: [],
            sections: [(heading: 'A', content: 'third')],
          ),
        ],
      );
      final count = await writeGeneratedCards(source, dupes);
      expect(count, 3);
      final paths = (await source.listCardPaths()).toSet();
      expect(paths, contains('dupes/same-title.md'));
      expect(paths, contains('dupes/same-title-2.md'));
      expect(paths, contains('dupes/same-title-3.md'));
      // The deduped slug is also the card id, so ids stay unique.
      final ids = <String>{};
      for (final path in paths) {
        final card =
            _parser.parse(await source.readCard(path), filePath: path)!;
        expect(ids.add(card.id), isTrue, reason: 'ids must be unique');
      }
    });

    test('records a provenance comment that the parser ignores', () async {
      await writeGeneratedCards(source, _batch,
          sourceLabel: 'my pasted notes about TCP');
      const path = 'tcp-fundamentals/tcp-handshake.md';
      final raw = await source.readCard(path);
      expect(raw, contains('<!-- generated: my pasted notes about TCP -->'));
      // …and it still parses cleanly as a draft (comment is body text).
      final card = _parser.parse(raw, filePath: path)!;
      expect(card.isDraft, isTrue);
      expect(card.title, 'TCP handshake');
    });

    test('handles a title that slugifies to nothing', () async {
      const weird = GeneratedBatch(
        name: '!!!',
        cards: [
          GeneratedCard(
            title: '???',
            tags: [],
            sections: [(heading: 'H', content: 'C')],
          ),
        ],
      );
      final count = await writeGeneratedCards(source, weird);
      expect(count, 1);
      final path = (await source.listCardPaths()).single;
      // folder falls back to 'generated', filename to 'card'.
      expect(path, 'generated/card.md');
      final card = _parser.parse(await source.readCard(path), filePath: path)!;
      expect(card.isDraft, isTrue);
    });
  });

  group('generated drafts flow into the gate', () {
    late Directory root;
    late DesktopVaultSource source;
    late AppDatabase db;

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_gen_index_');
      source = DesktopVaultSource(root.path);
      db = AppDatabase.withExecutor(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });

    test('all generated cards appear in the index as drafts (the queue)',
        () async {
      final written = await writeGeneratedCards(source, _batch);
      final result = await VaultIndexer(source, db).reindex();
      expect(result.cards.length, written);
      // draftCardsProvider does index.cards.where(isDraft) — mirror that here.
      final drafts = result.cards.where((c) => c.isDraft).toList();
      expect(drafts.length, written);
      // …and none are studiable yet (excluded from scheduling + readiness).
      expect(result.studyCards, isEmpty);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
