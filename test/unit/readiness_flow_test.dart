import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/interview/assessment.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/interview.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/srs.dart';
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

Card _card(String id, String domain) => Card(
      id: id,
      type: CardType.flashcard,
      title: id,
      overview: '',
      tags: [domain],
      tiers: {domain: 1},
      sections: [
        const CardSection(
            heading: 's1', slug: 's1', content: 'x', quizzable: true),
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  // Strong DS&A, weak system design — the case where re-weighting between levels
  // should visibly move the overall roll-up.
  final index = IndexResult(
    cards: [_card('A', 'ds-a'), _card('B', 'system-design')],
    idless: 0,
    malformed: 0,
    skipped: 0,
  );
  SrsState srs(String card, double stability) => SrsState(
        cardId: card,
        sectionSlug: 's1',
        stability: stability,
        difficulty: 5,
        state: 2,
        dueAt: DateTime(2026),
        reviewCount: 1,
      );
  final states = SectionStates({
    'A::s1': srs('A', 200), // strong DS&A
    'B::s1': srs('B', 5), // weak system design
  });

  ProviderContainer make(AppDatabase db) => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultIndexProvider.overrideWith((ref) async => index),
        srsStatesProvider.overrideWith((ref) async => states),
      ]);

  test('changing the target level moves the overall readiness', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final c = make(db);
    addTearDown(c.dispose);

    // New-grad weights DS&A (strong) heavily → higher overall.
    await c.read(readinessTargetControllerProvider.notifier).save(
        const ReadinessTarget(
            level: SeniorityLevel.newGrad,
            company: CompanyTier.faang,
            track: Track.general));
    final newGrad = (await c.read(readinessProvider.future)).overall;

    // Senior weights system design (weak) heavily → lower overall.
    await c.read(readinessTargetControllerProvider.notifier).save(
        const ReadinessTarget(
            level: SeniorityLevel.senior,
            company: CompanyTier.faang,
            track: Track.general));
    final senior = (await c.read(readinessProvider.future)).overall;

    expect(senior, lessThan(newGrad),
        reason: 'senior should weight the weak system-design domain more');
    await db.close();
  });

  test('seeding applied attempts graduates readiness to interview mode',
      () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final c = make(db);
    addTearDown(c.dispose);
    // Keep readiness alive the way the Home panel's ref.watch does, so the
    // autodispose provider doesn't tear down between reads.
    c.listen(readinessProvider, (_, __) {});
    c.listen(appliedTransferProvider, (_, __) {});

    expect((await c.read(readinessProvider.future)).interview, isFalse);

    // Seed a mock attempt (as the dev action / coach does).
    await c.read(appliedRepositoryProvider).record(
          cardId: 'A',
          domain: 'ds-a',
          source: 'dev-seed',
          occurredAt: DateTime.now(),
          assessment: const AppliedAssessment(appliedScore: 70, novel: true),
        );
    c.invalidate(appliedTransferProvider);

    final r = await c.read(readinessProvider.future);
    expect(r.interview, isTrue,
        reason: 'attempts should graduate the headline');
    // ds-a now has transfer evidence.
    final dsa = r.domains.firstWhere((d) => d.domain == 'ds-a');
    expect(dsa.appliedN, greaterThan(0));
    await db.close();
  });
}
