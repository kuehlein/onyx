import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/clock.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/behavioral.dart';
import 'package:onyx/shared/providers/clock.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/vault.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show sqlite3;

final bool _sqliteAvailable = () {
  try {
    sqlite3.openInMemory().dispose();
    return true;
  } catch (_) {
    return false;
  }
}();

Card _behavioral(String id, {CardStatus status = CardStatus.active}) => Card(
      id: id,
      type: kTypeBehavioral,
      title: id,
      overview: '',
      tags: const ['behavioral'],
      tiers: const {},
      sections: const [],
      wikilinks: const [],
      filePath: '$id.md',
      status: status,
    );

void main() {
  // A draft behavioral competency (every imported card lands status:draft) must
  // NOT appear in the mock-practice list — the ADR-0003 exclusion the other four
  // tracks already honor via studyCards. Regression for the #89 draft leak.
  test('behavioralCompetencies excludes draft cards (ADR-0003)', () async {
    if (!_sqliteAvailable) return;
    final index = IndexResult(
      cards: [
        _behavioral('leadership'),
        _behavioral('conflict', status: CardStatus.draft),
      ],
      idless: 0,
      malformed: 0,
      skipped: 0,
    );
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase.withExecutor(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      vaultIndexProvider.overrideWith((ref) async => index),
      clockProvider.overrideWith((ref) async => Clock.real),
    ]);
    addTearDown(c.dispose);

    final competencies = await c.read(behavioralCompetenciesProvider.future);
    final ids = {for (final it in competencies) it.id};
    expect(ids, {'leadership'});
    expect(ids.contains('conflict'), isFalse, reason: 'draft must be excluded');
  });
}
