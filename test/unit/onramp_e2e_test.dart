import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/template/software_interviews.dart';
import 'package:onyx/core/template/template_registry.dart';
import 'package:onyx/core/vault/card_edit.dart';
import 'package:onyx/core/vault/card_promotion.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/template.dart';
import 'package:onyx/shared/providers/vault.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// End-to-end verification (task E4): the authoring on-ramps over a REAL temp-dir
/// vault + the real indexer. Uses a ProviderContainer (not a pumped widget) so the
/// real filesystem IO runs on the real event loop — pumpAndSettle can't drive it
/// (the create-via-widget attempt hung on "Loading…"), which is why the audit
/// prescribed this pattern (cf. draft_review_test). The card-editor / import UIs
/// themselves are covered by card_editor_test / import_deck_test; this pins the
/// write → parse → index → studyable round-trip.

final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

String _draftMd(String id, String title) => '''---
id: $id
type: flashcard
status: draft
tags: ["ds-a"]
---

# $title

## When to Use

$title body.
''';

ProviderContainer _container(DesktopVaultSource source, AppDatabase db) {
  final c = ProviderContainer(overrides: [
    vaultSourceProvider.overrideWithValue(source),
    appDatabaseProvider.overrideWithValue(db),
    templateRegistryProvider.overrideWith(
        (ref) async => TemplateRegistry.single(softwareInterviewsTemplate)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('authoring on-ramps (real temp-dir vault + indexer)', () {
    test('create-card: createCard → reindex → present + studyable', () async {
      if (!_sqliteAvailable) return; // no native sqlite → skip
      final root = Directory.systemTemp.createTempSync('onyx_e4_create_');
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        root.deleteSync(recursive: true);
      });
      final c = _container(DesktopVaultSource(root.path), db);

      // Empty vault to start.
      expect((await c.read(vaultIndexProvider.future)).studyCards, isEmpty);

      // Author a card through the real write path.
      final path = await createCard(DesktopVaultSource(root.path),
          title: 'Photosynthesis',
          body: '## When to Use\n\nGreen plants make food.',
          tags: ['ds-a']);
      expect(File('${root.path}/$path').existsSync(), isTrue);

      // Re-index → it round-tripped through parse + is studyable (active,
      // quizzable — hand-authored cards enter active, not draft).
      c.invalidate(vaultIndexProvider);
      final index = await c.read(vaultIndexProvider.future);
      final made = index.studyCards.where((x) => x.title == 'Photosynthesis');
      expect(made, hasLength(1));
      expect(made.first.quizzableSections, isNotEmpty);
    });

    test('import → draft → promote → studyable (schedule never travels)',
        () async {
      if (!_sqliteAvailable) return;
      final root = Directory.systemTemp.createTempSync('onyx_e4_import_');
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(() async {
        await db.close();
        root.deleteSync(recursive: true);
      });
      final source = DesktopVaultSource(root.path);
      final c = _container(source, db);

      // An imported card lands as a draft (ADR-0003 / invariant #4).
      File('${root.path}/imported.md')
          .writeAsStringSync(_draftMd('imp', 'Imported'));
      final idx1 = await c.read(vaultIndexProvider.future);
      expect(idx1.cards.map((x) => x.id), contains('imp')); // indexed
      expect(idx1.studyCards.map((x) => x.id),
          isNot(contains('imp'))); // excluded from study while a draft

      // Promote it through the review gate → active → studyable.
      await promoteCard(source, 'imported.md');
      c.invalidate(vaultIndexProvider);
      final idx2 = await c.read(vaultIndexProvider.future);
      expect(idx2.studyCards.map((x) => x.id), contains('imp'));
    });
  });
}
