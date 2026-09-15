import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/database/database.dart';
import 'package:onyx/core/goal/study_goal.dart';
import 'package:onyx/core/interview/assessment.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/vault/vault_indexer.dart';
import 'package:onyx/shared/models/card.dart';
import 'package:onyx/shared/providers/database.dart';
import 'package:onyx/shared/providers/interview.dart';
import 'package:onyx/shared/providers/readiness.dart';
import 'package:onyx/shared/providers/srs.dart';
import 'package:onyx/shared/providers/study_goals.dart';
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
      type: 'flashcard',
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

/// A prep-goals notifier with no goals, so readiness reflects only the base
/// target — decoupled from whatever is saved in the real dev vault.
class _NoGoals extends PrepGoals {
  @override
  Future<List<PrepGoal>> build() async => const [];
}

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

  ProviderContainer make(AppDatabase db, {StudyGoal? goal}) =>
      ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultIndexProvider.overrideWith((ref) async => index),
        srsStatesProvider.overrideWith((ref) async => states),
        // Isolate from any real on-disk prep goals in the dev vault — otherwise
        // an active goal's domain weights would override the base target's
        // level-weighting this test is asserting on.
        prepGoalsProvider.overrideWith(_NoGoals.new),
        // Pin the active study goal (whole-vault by default) so readiness doesn't
        // scan the real dev vault to discover subjects (task #30d, G2).
        studyGoalsProvider.overrideWith((ref) async => [
              goal ??
                  const StudyGoal(
                      id: 'default', name: 'All', templateId: 'swe'),
            ]),
      ]);

  test('level does not move readiness on a foundational deck; track does',
      () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    final c = make(db);
    addTearDown(c.dispose);
    // Keep the autodispose readiness graph alive across reads (a target change
    // invalidates it in between), the way the Home panel's ref.watch does.
    c.listen(readinessProvider, (_, __) {});

    Future<double> read(SeniorityLevel level, Track track) async {
      await c.read(readinessTargetControllerProvider.notifier).save(
          ReadinessTarget.of(
              level: level, company: CompanyTier.faang, track: track));
      return (await c.read(readinessProvider.future)).overall;
    }

    // Both cards are tier-1 → seniority (which now acts only through tier depth)
    // must NOT move the overall. The anti-inversion guarantee: a harder level
    // can no longer read as "closer".
    final newGrad = await read(SeniorityLevel.newGrad, Track.general);
    final staff = await read(SeniorityLevel.staff, Track.general);
    expect(staff, closeTo(newGrad, 1e-9));

    // Track still shifts emphasis: backend up-weights the weak system-design
    // domain → lower overall.
    final backend = await read(SeniorityLevel.senior, Track.backend);
    expect(backend, lessThan(newGrad));
    await db.close();
  });

  test('readiness scopes to the active goal\'s membership', () async {
    if (!_sqliteAvailable) return;
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    // A cross-cutting tag goal that selects only the DS&A card — system design is
    // a different lens and must drop out of this goal's readiness entirely.
    final c = make(db,
        goal: StudyGoal(
          id: 'dsa',
          name: 'DSA',
          templateId: 'swe',
          membership: TagMembership('ds-a'),
        ));
    addTearDown(c.dispose);
    c.listen(readinessProvider, (_, __) {});

    final r = await c.read(readinessProvider.future);
    expect(r.domains.map((d) => d.domain), ['ds-a']);
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
