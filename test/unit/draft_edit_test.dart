import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/card_edit.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/drafts.dart';
import 'package:onyx/shared/providers/vault.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// The draft-review gate's Edit wiring (task #28): after the in-app editor
/// rewrites a draft's file, `DraftReview.refreshCurrent()` re-reads it into the
/// session's snapshotted queue so the reveal reflects the edit — and the card
/// stays a draft, so it's still promotable.

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
status: draft
tags: ["geography"]
---

# $title

## Capital

$title city.
''';

void main() {
  group('DraftReview.refreshCurrent', () {
    late Directory root;
    late DesktopVaultSource source;
    late AppDatabase db;

    setUp(() {
      root = Directory.systemTemp.createTempSync('onyx_draft_edit_');
      source = DesktopVaultSource(root.path);
      db = AppDatabase.withExecutor(NativeDatabase.memory());
      File('${root.path}/france.md')
          .writeAsStringSync(_draft('c-fr', 'France'));
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
      c.listen(draftReviewProvider, (_, __) {});
      return c;
    }

    test('re-reads an edited draft into the queue; stays a promotable draft',
        () async {
      if (!_sqliteAvailable) return;
      final c = makeContainer();
      final s0 = await c.read(draftReviewProvider.future);
      final before = s0.current!;
      expect(before.title, 'France');
      expect(before.isDraft, isTrue);

      // Simulate the in-app editor: rewrite the file (title changes; status is
      // preserved by the edit path).
      await saveCardEdit(
        source,
        before.filePath,
        title: 'French Republic',
        body: '## Capital\n\nParis.',
        tags: null,
      );

      // Refresh the snapshot; the current queue card now reflects the edit.
      await c.read(draftReviewProvider.notifier).refreshCurrent();
      final s1 = c.read(draftReviewProvider).requireValue;
      expect(s1.index, 0, reason: 'refresh does not advance');
      expect(s1.total, 1);
      expect(s1.current!.title, 'French Republic');
      expect(s1.current!.isDraft, isTrue,
          reason: 'edit preserves draft status');

      // Still promotable: keep() advances and the file becomes active.
      await c.read(draftReviewProvider.notifier).keep();
      final s2 = c.read(draftReviewProvider).requireValue;
      expect(s2.promoted, 1);
      final raw = await source.readCard(before.filePath);
      expect(raw.contains('status:'), isFalse, reason: 'promoted to active');
      expect(raw.contains('French Republic'), isTrue,
          reason: 'the edit persisted');
    });

    test('refreshCurrent is a safe no-op past the end of the queue', () async {
      if (!_sqliteAvailable) return;
      final c = makeContainer();
      await c.read(draftReviewProvider.future);
      final notifier = c.read(draftReviewProvider.notifier);
      notifier.skip(); // advance past the single draft → isDone
      expect(c.read(draftReviewProvider).requireValue.isDone, isTrue);
      // No current card → returns without throwing.
      await notifier.refreshCurrent();
      expect(c.read(draftReviewProvider).requireValue.index, 1);
    });
  });
}
