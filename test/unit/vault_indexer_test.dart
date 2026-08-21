import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
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

    test('parses cards and counts non-cards / id-less files', () async {
      final result = await indexer.reindex();
      expect(result.cardCount, 2);
      expect(result.idless, 1); // no-id.md
      expect(result.skipped, 1); // note.md (has no frontmatter)
      expect(result.malformed, 0);
    });

    test('populates card_cache with parsed metadata', () async {
      await indexer.reindex();
      final rows = await db.select(db.cardCache).get();
      expect(rows.map((r) => r.cardId).toSet(), {
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
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
      expect((await db.select(db.cardCache).get()).length, 2);
      expect((await db.select(db.cardLinks).get()).length, 1);
    });
  },
      skip: _sqliteAvailable
          ? false
          : 'libsqlite3 unavailable — run inside the nix dev shell');
}
