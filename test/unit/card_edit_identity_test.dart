import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/srs/srs_repository.dart';
import 'package:onyx/core/vault/card_edit.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

/// S2 (ADR-0012 edit-identity): editing a card must not orphan a studied
/// section's FSRS schedule. Pins the pure slug delta + the repo rekey/drop that
/// back the editor's keep-vs-reset — the fix for the heading-rename-orphans bug.

final bool _sqlite = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

final _past = DateTime(2000);

void main() {
  group('sectionSlugDelta', () {
    test('an unchanged slug set is empty (a cosmetic/body edit — silent keep)',
        () {
      final d = sectionSlugDelta(['a', 'b'], ['a', 'b']);
      expect(d.isEmpty, isTrue);
      expect(d.lost, isEmpty);
      expect(d.gained, isEmpty);
    });

    test('a heading rename pairs lost↔gained positionally', () {
      final d = sectionSlugDelta(
          ['when-to-use', 'impl'], ['when-you-need-it', 'impl']);
      expect(d.lost, ['when-to-use']);
      expect(d.gained, ['when-you-need-it']);
      expect(d.renames, [(from: 'when-to-use', to: 'when-you-need-it')]);
      expect(d.removed, isEmpty);
    });

    test('a removal (no counterpart) is a removed, not a rename', () {
      final d = sectionSlugDelta(['a', 'b'], ['a']);
      expect(d.lost, ['b']);
      expect(d.gained, isEmpty);
      expect(d.renames, isEmpty);
      expect(d.removed, ['b']);
    });

    test('a pure addition drops nothing (not material to studied sections)',
        () {
      final d = sectionSlugDelta(['a'], ['a', 'c']);
      expect(d.lost, isEmpty);
      expect(d.gained, ['c']);
      expect(d.isEmpty, isFalse); // gained, but nothing lost → no prompt
    });
  });

  group('SrsRepository edit-identity', () {
    test('renameSection moves the schedule — KEEP survives a heading rename',
        () async {
      if (!_sqlite) return;
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SrsRepository(db);
      await repo.seedStudied(
        [(cardId: 'C', sectionSlug: 'old', stability: 10)],
        at: _past,
      );

      await repo.renameSection(cardId: 'C', oldSlug: 'old', newSlug: 'new');

      final states = await repo.loadStates();
      expect(states.containsKey('C::old'), isFalse,
          reason: 'the old slug no longer schedules');
      expect(states.containsKey('C::new'), isTrue,
          reason: 'history followed the rename (not orphaned + re-newed)');
      expect(
          states['C::new']!.reviewCount, 2); // seedStudied plants reviewCount 2
    });

    test('dropSection clears the schedule — RESET / prune of a removed section',
        () async {
      if (!_sqlite) return;
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SrsRepository(db);
      await repo.seedStudied(
        [(cardId: 'C', sectionSlug: 'gone', stability: 10)],
        at: _past,
      );

      await repo.dropSection(cardId: 'C', slug: 'gone');

      expect((await repo.loadStates()).containsKey('C::gone'), isFalse);
    });
  });
}
