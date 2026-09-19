import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/drafts.dart';
import 'package:onyx/shared/providers/vault.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// The indexer touches SQLite; skip when the host libsqlite3 is unavailable.
final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

String _draft(String id, String title) => '''---
id: $id
type: flashcard
deck: world-capitals
status: draft
tags: ["geography"]
---

# $title

## Capital

$title city.
''';

String _active(String id, String title) => '''---
id: $id
type: flashcard
tags: ["geography"]
---

# $title

## Capital

$title city.
''';

void main() {
  group('DraftReview session', () {
    late Directory root;
    late DesktopVaultSource source;
    late AppDatabase db;

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_draft_review_');
      source = DesktopVaultSource(root.path);
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      // 3 drafts + 1 already-active card.
      File('${root.path}/france.md')
          .writeAsStringSync(_draft('c-fr', 'France'));
      File('${root.path}/japan.md').writeAsStringSync(_draft('c-jp', 'Japan'));
      File('${root.path}/spain.md').writeAsStringSync(_draft('c-es', 'Spain'));
      File('${root.path}/italy.md').writeAsStringSync(_active('c-it', 'Italy'));
    });

    tearDown(() async {
      await db.close();
      root.deleteSync(recursive: true);
    });

    ProviderContainer makeContainer() {
      final c = ProviderContainer(overrides: [
        vaultSourceProvider.overrideWithValue(source),
        appDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(c.dispose);
      // Keep the (autoDispose) session alive across mutations so its state
      // survives between reads — mirrors a live screen listening to it.
      c.listen(draftReviewProvider, (_, __) {});
      return c;
    }

    test('draftCards sees only the 3 drafts (not the active card)', () async {
      if (!_sqliteAvailable) return;
      final c = makeContainer();
      final drafts = await c.read(draftCardsProvider.future);
      expect(drafts.length, 3);
      expect(drafts.every((d) => d.isDraft), isTrue);
    });

    test('keep promotes the current draft; queue advances; counts right',
        () async {
      if (!_sqliteAvailable) return;
      final c = makeContainer();
      final s0 = await c.read(draftReviewProvider.future);
      expect(s0.total, 3);
      expect(s0.index, 0);
      final first = s0.current!;

      await c.read(draftReviewProvider.notifier).keep();

      final s1 = c.read(draftReviewProvider).requireValue;
      expect(s1.index, 1);
      expect(s1.promoted, 1);
      expect(s1.discarded, 0);
      expect(s1.skipped, 0);

      // The kept card's file is now active (status: draft line gone).
      final raw = await source.readCard(first.filePath);
      expect(raw.contains('status:'), isFalse);

      // A FRESH index (post-invalidation) shows it in studyCards now.
      final index = await c.read(vaultIndexProvider.future);
      expect(index.studyCards.map((x) => x.id), contains(first.id));
      // …and it's no longer a draft.
      expect(index.cards.where((x) => x.isDraft).length, 2);
    });

    test('discard deletes the current draft file; advances', () async {
      if (!_sqliteAvailable) return;
      final c = makeContainer();
      final s0 = await c.read(draftReviewProvider.future);
      final first = s0.current!;

      await c.read(draftReviewProvider.notifier).discard();

      final s1 = c.read(draftReviewProvider).requireValue;
      expect(s1.index, 1);
      expect(s1.discarded, 1);
      expect(File('${root.path}/${first.filePath}').existsSync(), isFalse);

      // The index no longer knows the card at all.
      final index = await c.read(vaultIndexProvider.future);
      expect(index.cards.map((x) => x.id), isNot(contains(first.id)));
    });

    test('skip advances without writing; the file stays a draft', () async {
      if (!_sqliteAvailable) return;
      final c = makeContainer();
      final s0 = await c.read(draftReviewProvider.future);
      final first = s0.current!;

      c.read(draftReviewProvider.notifier).skip();

      final s1 = c.read(draftReviewProvider).requireValue;
      expect(s1.index, 1);
      expect(s1.skipped, 1);
      // Untouched: still a draft on disk.
      expect(await source.readCard(first.filePath), contains('status: draft'));
    });

    test('walking the whole queue reaches isDone with honest counts', () async {
      if (!_sqliteAvailable) return;
      final c = makeContainer();
      await c.read(draftReviewProvider.future);
      final notifier = c.read(draftReviewProvider.notifier);

      await notifier.keep(); // France → active
      await notifier.discard(); // Japan → deleted
      notifier.skip(); // Spain → left draft

      final s = c.read(draftReviewProvider).requireValue;
      expect(s.isDone, isTrue);
      expect(s.current, isNull);
      expect(s.promoted, 1);
      expect(s.discarded, 1);
      expect(s.skipped, 1);

      // Calling actions past the end is a safe no-op.
      await notifier.keep();
      expect(c.read(draftReviewProvider).requireValue.index, 3);
    });

    test(
        'the queue is a snapshot — an index invalidation mid-session does not '
        'reshuffle it', () async {
      if (!_sqliteAvailable) return;
      final c = makeContainer();
      final s0 = await c.read(draftReviewProvider.future);
      expect(s0.total, 3);

      // keep() invalidates vaultIndexProvider; the session must keep its queue
      // (still 3 total, just advanced) rather than rebuild down to 2.
      await c.read(draftReviewProvider.notifier).keep();
      final s1 = c.read(draftReviewProvider).requireValue;
      expect(s1.total, 3);
      expect(s1.index, 1);
    });
  });

  group('DraftReview with no vault source', () {
    test('empty session, no crash', () async {
      if (!_sqliteAvailable) return;
      // vaultIndex constructs the DB before the null-source short-circuit, so
      // provide an in-memory one to keep the test hermetic.
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final c = ProviderContainer(overrides: [
        vaultSourceProvider.overrideWithValue(null),
        appDatabaseProvider.overrideWithValue(db),
      ]);
      addTearDown(c.dispose);
      c.listen(draftReviewProvider, (_, __) {});
      final s = await c.read(draftReviewProvider.future);
      expect(s.total, 0);
      expect(s.isDone, isTrue);
      // Actions are guarded no-ops.
      await c.read(draftReviewProvider.notifier).keep();
      expect(c.read(draftReviewProvider).requireValue.total, 0);
    });
  });
}
