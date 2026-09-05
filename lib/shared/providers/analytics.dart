import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/analytics/insights.dart';
import '../../core/analytics/retention.dart';
import '../../core/interview/assessment.dart' show AppliedAssessment;
import '../../core/readiness/readiness.dart' show durability;
import '../models/card.dart';
import 'clock.dart';
import 'interview.dart';
import 'readiness.dart';
import 'srs.dart';
import 'vault.dart';

part 'analytics.g.dart';

/// The lookback window for retention analytics. Recall reflects recent
/// performance; stability is read from current FSRS state (not windowed).
const retentionWindow = Duration(days: 90);

/// Per-domain retention (task #27), computed from the review log + current FSRS
/// state, grouped by each card's domain via the vault index.
@riverpod
Future<List<DomainRetention>> retentionByDomain(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final since = clock.now().subtract(retentionWindow);
  final grades =
      await ref.watch(srsRepositoryProvider).reviewGradesSince(since);

  final domainByCard = <String, String>{
    for (final c in index.cards)
      if (c.domain != null) c.id: c.domain!,
  };
  final stabilities = [
    for (final s in states.byKey.values)
      (cardId: s.cardId, stability: s.stability),
  ];

  return computeRetention(
    reviews: grades,
    stabilities: stabilities,
    domainByCard: domainByCard,
  );
}

/// Averaged mock-interview performance + rubric breakdown. Recomputes when the
/// applied-transfer signal is invalidated (a new mock, or the simulator).
@riverpod
Future<MockSkills> mockSkills(Ref ref) async {
  await ref.watch(appliedTransferProvider.future); // refresh on new mocks
  final attempts = await ref.watch(appliedRepositoryProvider).attempts();
  return computeMockSkills([
    // Exclude self-reported solves (external + algo track) — this section is the
    // coach-mock rubric breakdown, and self-reports carry no rubric. They still
    // count as applied evidence toward readiness.
    for (final a in attempts)
      if (a.source != 'external' && a.source != 'algo')
        (
          appliedScore: a.appliedScore,
          hintLevel: a.hintLevel,
          novel: a.novel,
          rubric: AppliedAssessment.decodeRubric(a.rubric),
        ),
  ]);
}

/// Algorithms-track progress: problems picked up, clean-solve rate, momentum.
/// Recomputes when a solve is logged (which invalidates appliedTransfer).
@riverpod
Future<AlgoStats> algoStats(Ref ref) async {
  await ref.watch(appliedTransferProvider.future); // refresh on new solves
  final index = await ref.watch(vaultIndexProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final attempts = await ref.watch(appliedRepositoryProvider).attempts();
  final patternByCard = {for (final c in index.cards) c.id: c.title};
  return computeAlgoStats([
    for (final a in attempts)
      if (a.source == 'algo')
        (
          appliedScore: a.appliedScore,
          occurredAt: a.occurredAt,
          problem: '${a.cardId}::${a.sectionSlug}',
          pattern: patternByCard[a.cardId] ?? a.cardId,
        ),
  ], clock.now());
}

/// Per-pattern mastery for the Algorithms track — how much of each pattern you
/// can durably solve (execution clock). Recomputes after solves change FSRS.
@riverpod
Future<List<PatternMastery>> patternMastery(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final states = await ref.watch(srsStatesProvider.future);
  return computePatternMastery([
    for (final c in index.cards)
      if (c.type == CardType.algorithm)
        (
          pattern: c.title,
          strengths: [
            for (final s in c.quizzableSections)
              switch (states.byKey['${c.id}::${s.slug}']?.stability) {
                null => null,
                final stability => durability(stability),
              },
          ],
        ),
  ]);
}

/// How many cards come due on each of the next 14 days (from FSRS `dueAt`).
@riverpod
Future<List<int>> dueForecast(Ref ref) async {
  final states = await ref.watch(srsStatesProvider.future);
  final clock = await ref.watch(clockProvider.future);
  return computeDueForecast(
    dueDates: [for (final s in states.byKey.values) s.dueAt],
    today: clock.today(),
  );
}

/// The most-lapsed cards (leeches worth reformulating), most-failed first.
@riverpod
Future<List<StrugglingCard>> strugglingCards(Ref ref) async {
  ref.watch(srsStatesProvider); // refresh after reviews change
  final index = await ref.watch(vaultIndexProvider.future);
  final rows = await ref.watch(srsRepositoryProvider).lapsesByCard();
  final titleByCard = {for (final c in index.cards) c.id: c.title};
  return topStruggling(rows, titleByCard);
}

/// Study actions per day over the last 4 weeks (a compact activity strip).
@riverpod
Future<List<int>> studyConsistency(Ref ref) async {
  ref.watch(srsStatesProvider); // refresh after study
  final clock = await ref.watch(clockProvider.future);
  final today = clock.today();
  const days = 28;
  final events = await ref
      .watch(srsRepositoryProvider)
      .studyTimestamps(since: today.subtract(const Duration(days: days)));
  return computeConsistency(events: events, today: today, days: days);
}
