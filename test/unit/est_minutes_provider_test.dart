import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/plan/practice_plan.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/practice_plan.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/vault.dart';
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

String _card(String id) => '''
---
id: $id
type: flashcard
tags: [algebra]
---

# $id

## Definition

Body.
''';

/// End-to-end proof that the state-aware est-minutes (#133) reach the daily-plan
/// PROVIDER (the `_est`/`scaleEstMinutes` wiring on top of the pure-helper test):
/// two DUE reviews, identical but for FSRS stability, get different plan minutes —
/// the well-spaced one far cheaper. This is the "est-minutes fidelity" half of #106
/// verified through the real provider graph; flat `kReviewMinutes` would tie them.
void main() {
  test('a well-spaced review is sized cheaper than a settling one (#133/#106)',
      () async {
    if (!_sqliteAvailable) return;
    final root = Directory.systemTemp.createTempSync('onyx_estmin_');
    addTearDown(() => root.deleteSync(recursive: true));
    File(p.join(root.path, 'mature.md')).writeAsStringSync(_card('mature'));
    File(p.join(root.path, 'settling.md')).writeAsStringSync(_card('settling'));

    final c = ProviderContainer(overrides: [
      vaultSourceProvider.overrideWithValue(DesktopVaultSource(root.path)),
      appDatabaseProvider.overrideWith((ref) {
        final db = AppDatabase.withExecutor(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
    ]);
    addTearDown(c.dispose);

    // Seed both sections DUE (seedStudied sets dueAt = at + stability days, so a
    // far-past `at` → due now): one well-spaced (stability 60 ≥ the mature line),
    // one settling (stability 3). Seed BEFORE the provider first builds, so its
    // srsStates snapshot includes them (else it caches an empty snapshot → flat).
    final now = DateTime.now();
    final repo = c.read(srsRepositoryProvider);
    await repo.seedStudied(
      [(cardId: 'mature', sectionSlug: 'definition', stability: 60)],
      at: now.subtract(const Duration(days: 61)),
    );
    await repo.seedStudied(
      [(cardId: 'settling', sectionSlug: 'definition', stability: 3)],
      at: now.subtract(const Duration(days: 4)),
    );

    c.listen(practiceAvailabilityProvider, (_, __) {});
    final avail = await c.read(practiceAvailabilityProvider.future);
    final review = avail.firstWhere((a) => a.track == kTrackReview);
    double est(String id) =>
        review.units.firstWhere((u) => u.id == id).estMinutes;

    // Well-spaced → the review floor (~0.5); settling → still near the full cost.
    expect(est('mature::definition'), lessThan(est('settling::definition')));
    expect(est('mature::definition'),
        closeTo(kReviewMinutes * kReviewFloor, 0.05));
    expect(est('settling::definition'), greaterThan(kReviewMinutes * 0.8));
  });
}
