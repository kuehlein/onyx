import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/query/card_query.dart';
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
      write('note.md',
          '# Just a note\n\nNo frontmatter.\n'); // zero-frontmatter card now
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      indexer = VaultIndexer(DesktopVaultSource(root.path), db);
    });

    tearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });

    test('parses cards incl. a zero-frontmatter note; nothing left to skip',
        () async {
      final result = await indexer.reindex();
      // Every well-formed note is a card now (ADR-0023 card-ness = the deck lens;
      // this direct indexer applies no lens gate → keep all): card-a, card-b, no-id
      // (ADR-0022 filename slug), and note.md — a plain `# Just a note` with NO
      // frontmatter (the zero-frontmatter vault). _meta/ is excluded before parsing.
      expect(result.cardCount, 4);
      expect(result.skipped, 0);
      expect(result.malformed, 0);
      final note = result.cards.firstWhere((c) => c.id == 'note');
      expect(note.type, 'flashcard'); // the subject's default flow
      expect(note.title, 'Just a note');
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
      expect(result.cardCount, 4,
          reason: 'card-a, card-b, no-id, note still index');
      expect(result.skipped, 0);
      // The malformed file is not cached.
      expect((await db.select(db.cardCache).get()).length, 4);
    });

    test('populates card_cache with parsed metadata', () async {
      await indexer.reindex();
      final rows = await db.select(db.cardCache).get();
      expect(rows.map((r) => r.cardId).toSet(), {
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        'no-id', // no id: → cardId is the filename slug (ADR-0022)
        'note', // plain `# Just a note`, no frontmatter → filename-slug card
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
      expect((await db.select(db.cardCache).get()).length, 4); // +no-id +note
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
      expect(result.cardCount, 4, reason: 'conflict copies are not parsed');
      expect(result.conflictCopies.length, 2);
      // The four real cards cache once each — no duplicate id leaked from a copy.
      expect((await db.select(db.cardCache).get()).length, 4);
    });

    test('cardId collision: first (sorted) wins, the rest skip + report',
        () async {
      // Two distinct files declare the same id: — indexing both would fuse their
      // FSRS schedules under one key. The sorted-first wins; the other is skipped +
      // reported, never merged (ADR-0022).
      write('aaa-first.md',
          '---\nid: dup\ntype: flashcard\n---\n\n# First\n\n## S\n\nx\n');
      write('zzz-second.md',
          '---\nid: dup\ntype: flashcard\n---\n\n# Second\n\n## S\n\ny\n');
      final result = await indexer.reindex();
      expect(result.collisions,
          ['zzz-second.md']); // aaa- sorts first, claims 'dup'
      final dup = result.cards.where((c) => c.id == 'dup');
      expect(dup.length, 1,
          reason: 'the two schedules never fuse under one id');
      expect(dup.single.title, 'First');
    });

    test('card-ness gate: only cards a deck lens claims are indexed (ADR-0023)',
        () async {
      // Two well-formed cards in different folders. A single deck lens over `algo/`
      // makes card-ness = "in that folder"; the rest parse fine but aren't cards.
      write('algo/two-sum.md',
          '---\nid: two-sum\ntype: flashcard\n---\n\n# Two Sum\n\n## S\n\nx\n');
      write('lang/verbs.md',
          '---\nid: verbs\ntype: flashcard\n---\n\n# Verbs\n\n## S\n\ny\n');

      final scoped = VaultIndexer(DesktopVaultSource(root.path), db,
          lenses: [FolderUnder('algo')]);
      final result = await scoped.reindex();
      expect(result.cards.map((c) => c.id).toSet(), {'two-sum'});
      expect(result.unlensed, greaterThan(0),
          reason: 'card-a/card-b/no-id/verbs are outside the lens');

      // No lenses (the fresh-vault / direct-parse default) = no gate → keep all.
      final all =
          await VaultIndexer(DesktopVaultSource(root.path), db).reindex();
      expect(all.unlensed, 0);
      expect(all.cards.map((c) => c.id),
          containsAll(<String>['two-sum', 'verbs', 'no-id']));
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
