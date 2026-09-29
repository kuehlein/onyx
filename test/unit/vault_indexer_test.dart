import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/core/vault/vault_source.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// See database_test.dart — skip when host libsqlite3 is unavailable.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

const _cardA = '''
---
id: aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa
type: flashcard
tags: [ds-a, binary-search]
tiers:
  ds-a: 1
created: 2026-08-19
---

# Card A

Overview.

## When to Use

Use it.

## Related

- [[card-b]]
- [[nonexistent]]
''';

const _cardB = '''
---
id: bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb
type: flashcard
tags: [ds-a]
tiers:
  ds-a: 2
created: 2026-08-19
---

# Card B

Overview.

## When to Use

Use it.
''';

void main() {
  group('VaultIndexer', () {
    late Directory root;
    late AppDatabase db;
    late VaultIndexer indexer;

    void write(String relative, String content) {
      final file = File(p.join(root.path, relative));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
    }

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_index_');
      write('card-a.md', _cardA);
      write('card-b.md', _cardB);
      write('_meta/tags.md', '# Tags\n'); // excluded before parsing
      write('no-id.md',
          '---\ntype: flashcard\n---\n\n# No Id\n\n## When to Use\n\nx\n');
      write('note.md', '# Just a note\n\nNo frontmatter.\n'); // non-card
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      indexer = VaultIndexer(DesktopVaultSource(root.path), db);
    });

    tearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });

    test('parses cards (id-less file → filename-slug card) and skips non-cards',
        () async {
      final result = await indexer.reindex();
      // no-id.md has no id: → cardId is its filename slug (ADR-0022), so it's a
      // real card now (3 total: card-a, card-b, no-id), not an id-less reject.
      expect(result.cardCount, 3);
      expect(result.skipped, 1); // note.md (has no frontmatter)
      expect(result.malformed, 0);
    });

    test('counts a malformed card (type, but no H1 title)', () async {
      // A recognized card that fails structural parse lands in the `malformed`
      // bucket (which drives the Settings "fix your vault" surface) — distinct
      // from skipped (not a card at all). Indexing must bucket it, not crash the
      // whole reindex.
      write(
        'malformed.md',
        '---\nid: cccccccc-cccc-4ccc-8ccc-cccccccccccc\ntype: flashcard\n'
            '---\n\nNo H1 title here.\n\n## When to Use\n\nx\n',
      );
      final result = await indexer.reindex();
      expect(result.malformed, 1);
      expect(result.cardCount, 3, reason: 'card-a, card-b, no-id still index');
      expect(result.skipped, 1);
      // The malformed file is not cached.
      expect((await db.select(db.cardCache).get()).length, 3);
    });

    test('populates card_cache with parsed metadata', () async {
      await indexer.reindex();
      final rows = await db.select(db.cardCache).get();
      expect(rows.map((r) => r.cardId).toSet(), {
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'no-id', // no id: → cardId is the filename slug (ADR-0022)
      });
      final cardA = rows.firstWhere((r) => r.title == 'Card A');
      expect(cardA.cardType, 'flashcard');
      expect(cardA.tags, contains('binary-search')); // stored as JSON
      expect(cardA.filePath, 'card-a.md');
    });

    test('builds resolved wikilink edges, dropping unresolved links', () async {
      await indexer.reindex();
      final links = await db.select(db.cardLinks).get();
      // card-a links to [[card-b]] (resolves) and [[nonexistent]] (dropped).
      expect(links.length, 1);
      expect(links.single.fromCard, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      expect(links.single.toCard, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
    });

    test('reindex is idempotent (caches rebuilt, not duplicated)', () async {
      await indexer.reindex();
      await indexer.reindex();
      expect((await db.select(db.cardCache).get()).length, 3); // +no-id
      expect((await db.select(db.cardLinks).get()).length, 1);
    });

    test('skips + reports folder-syncer conflict copies (no duplicate id)',
        () async {
      // A conflict copy carries card-a's frontmatter (same id) VERBATIM — parsing
      // it would duplicate the id and corrupt the index. It must be skipped +
      // reported, never parsed (ADR-0019/0021).
      write('card-a.sync-conflict-20260101-ABCDEF.md', _cardA);
      write('card-a (conflicted copy).md', _cardA);
      final result = await indexer.reindex();
      expect(result.cardCount, 3, reason: 'conflict copies are not parsed');
      expect(result.conflictCopies.length, 2);
      // The three real cards cache once each — no duplicate id leaked from a copy.
      expect((await db.select(db.cardCache).get()).length, 3);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');

  // Pure — no DB, so it runs regardless of libsqlite3 availability.
  group('isConflictCopy', () {
    test('detects unambiguous folder-syncer patterns (case-insensitive)', () {
      expect(
          isConflictCopy('card.sync-conflict-20260101-ABCDEF-GHI.md'), isTrue);
      expect(isConflictCopy('deep/nested/note.sync-conflict-x.md'), isTrue);
      expect(isConflictCopy('array (conflicted copy).md'), isTrue);
      expect(isConflictCopy("array (John's conflicted copy 2026-01-01).md"),
          isTrue);
      expect(isConflictCopy('ARRAY (Conflicted Copy).md'), isTrue);
    });

    test('never flags legitimate filenames (incl. numbered suffixes)', () {
      expect(isConflictCopy('array.md'), isFalse);
      expect(
          isConflictCopy('chapter 2.md'), isFalse); // numbered ≠ conflict copy
      expect(isConflictCopy('notes-2.md'), isFalse);
      expect(isConflictCopy('sync-notes.md'), isFalse); // "sync-" ≠ the pattern
    });
  });
}
