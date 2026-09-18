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
import 'study_goals.dart';
import 'vault.dart';

part 'analytics.g.dart';

/// The lookback window for retention analytics. Recall reflects recent
/// performance; stability is read from current FSRS state (not windowed).
const retentionWindow = Duration(days: 90);

/// Per-domain retention (task #27) for a SPECIFIC goal — its member cards' review
/// log + current FSRS state, grouped by domain. Scoped to `goalMemberCardIds` so
/// a lane shows only its own recall; the whole-vault default goal includes every
/// card, so single-goal numbers are unchanged.
@riverpod
Future<List<DomainRetention>> goalRetentionByDomain(
    Ref ref, String goalId) async {
  // Register deps before the first await (disposal hazard — a goal edit rebuilds
  // studyGoals/memberIds and would invalidate this instance mid-await).
  final memberIdsF = ref.watch(goalMemberCardIdsProvider(goalId).future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final statesF = ref.watch(srsStatesProvider.future);
  final clockF = ref.watch(clockProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final memberIds = await memberIdsF;
  final index = await indexF;
  final states = await statesF;
  final since = (await clockF).now().subtract(retentionWindow);
  final grades = await repo.reviewGradesSince(since);

  final domainByCard = <String, String>{
    for (final c in index.cards)
      if (c.domain != null && memberIds.contains(c.id)) c.id: c.domain!,
  };
  final stabilities = [
    for (final s in states.byKey.values)
      if (memberIds.contains(s.cardId))
        (cardId: s.cardId, stability: s.stability),
  ];

  return computeRetention(
    reviews: [
      for (final g in grades)
        if (memberIds.contains(g.cardId)) g,
    ],
    stabilities: stabilities,
    domainByCard: domainByCard,
  );
}

/// Per-domain retention for the ACTIVE goal — see [goalRetentionByDomain].
@riverpod
Future<List<DomainRetention>> retentionByDomain(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  return ref.watch(goalRetentionByDomainProvider(goal.id).future);
}

/// Averaged mock-interview performance + rubric breakdown for a SPECIFIC goal —
/// mocks on its member cards. The whole-vault default goal includes all, so
/// single-goal numbers are unchanged. Recomputes on a new mock.
@riverpod
Future<MockSkills> goalMockSkills(Ref ref, String goalId) async {
  final memberIdsF = ref.watch(goalMemberCardIdsProvider(goalId).future);
  final transferF =
      ref.watch(appliedTransferProvider.future); // refresh on mocks
  final repo = ref.watch(appliedRepositoryProvider);
  await transferF;
  final memberIds = await memberIdsF;
  final attempts = await repo.attempts();
  return computeMockSkills([
    // Exclude self-reported solves (external + algo track) — this section is the
    // coach-mock rubric breakdown, and self-reports carry no rubric. Also exclude
    // system-design mocks: they use a different rubric and get their own section.
    // All still count as applied evidence toward readiness.
    for (final a in attempts)
      if (memberIds.contains(a.cardId) &&
          a.source != 'external' &&
          a.source != 'algo' &&
          a.source != 'sd-practice' &&
          a.source != 'behavioral')
        (
          appliedScore: a.appliedScore,
          hintLevel: a.hintLevel,
          novel: a.novel,
          rubric: AppliedAssessment.decodeRubric(a.rubric),
        ),
  ]);
}

/// Mock skills for the ACTIVE goal — see [goalMockSkills].
@riverpod
Future<MockSkills> mockSkills(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  return ref.watch(goalMockSkillsProvider(goal.id).future);
}

/// System-design mock performance + rubric breakdown for a goal (its own rubric,
/// distinct from the coding mock skills). Recomputes on a new mock.
@riverpod
Future<MockSkills> goalSystemDesignSkills(Ref ref, String goalId) async {
  final memberIdsF = ref.watch(goalMemberCardIdsProvider(goalId).future);
  final transferF =
      ref.watch(appliedTransferProvider.future); // refresh on mocks
  final repo = ref.watch(appliedRepositoryProvider);
  await transferF;
  final memberIds = await memberIdsF;
  final attempts = await repo.attempts();
  return computeMockSkills([
    for (final a in attempts)
      if (a.source == 'sd-practice' && memberIds.contains(a.cardId))
        (
          appliedScore: a.appliedScore,
          hintLevel: a.hintLevel,
          novel: a.novel,
          rubric: AppliedAssessment.decodeRubric(a.rubric),
        ),
  ]);
}

/// System-design skills for the ACTIVE goal — see [goalSystemDesignSkills].
@riverpod
Future<MockSkills> systemDesignSkills(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  return ref.watch(goalSystemDesignSkillsProvider(goal.id).future);
}

/// Behavioral mock performance + STAR+L rubric breakdown for a goal (its own
/// rubric). Its own Insights section so it doesn't mix with coding/SD mocks.
@riverpod
Future<MockSkills> goalBehavioralSkills(Ref ref, String goalId) async {
  final memberIdsF = ref.watch(goalMemberCardIdsProvider(goalId).future);
  final transferF =
      ref.watch(appliedTransferProvider.future); // refresh on mocks
  final repo = ref.watch(appliedRepositoryProvider);
  await transferF;
  final memberIds = await memberIdsF;
  final attempts = await repo.attempts();
  return computeMockSkills([
    for (final a in attempts)
      if (a.source == 'behavioral' && memberIds.contains(a.cardId))
        (
          appliedScore: a.appliedScore,
          hintLevel: a.hintLevel,
          novel: a.novel,
          rubric: AppliedAssessment.decodeRubric(a.rubric),
        ),
  ]);
}

/// Behavioral skills for the ACTIVE goal — see [goalBehavioralSkills].
@riverpod
Future<MockSkills> behavioralSkills(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  return ref.watch(goalBehavioralSkillsProvider(goal.id).future);
}

/// Algorithms-track progress for a goal: problems picked up, clean-solve rate,
/// momentum. Recomputes when a solve is logged (invalidates appliedTransfer).
@riverpod
Future<AlgoStats> goalAlgoStats(Ref ref, String goalId) async {
  final memberIdsF = ref.watch(goalMemberCardIdsProvider(goalId).future);
  final transferF =
      ref.watch(appliedTransferProvider.future); // refresh on solves
  final indexF = ref.watch(vaultIndexProvider.future);
  final clockF = ref.watch(clockProvider.future);
  final repo = ref.watch(appliedRepositoryProvider);
  await transferF;
  final memberIds = await memberIdsF;
  final index = await indexF;
  final clock = await clockF;
  final attempts = await repo.attempts();
  final patternByCard = {for (final c in index.cards) c.id: c.title};
  return computeAlgoStats([
    for (final a in attempts)
      if (a.source == 'algo' && memberIds.contains(a.cardId))
        (
          appliedScore: a.appliedScore,
          occurredAt: a.occurredAt,
          problem: '${a.cardId}::${a.sectionSlug}',
          pattern: patternByCard[a.cardId] ?? a.cardId,
        ),
  ], clock.now());
}

/// Algorithms progress for the ACTIVE goal — see [goalAlgoStats].
@riverpod
Future<AlgoStats> algoStats(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  return ref.watch(goalAlgoStatsProvider(goal.id).future);
}

/// Per-pattern mastery for the Algorithms track within a goal — how much of each
/// pattern you can durably solve (execution clock). Recomputes after solves.
@riverpod
Future<List<PatternMastery>> goalPatternMastery(Ref ref, String goalId) async {
  final memberIdsF = ref.watch(goalMemberCardIdsProvider(goalId).future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final statesF = ref.watch(srsStatesProvider.future);
  final memberIds = await memberIdsF;
  final index = await indexF;
  final states = await statesF;
  return computePatternMastery([
    for (final c in index.cards)
      if (c.type == kTypeAlgorithm && memberIds.contains(c.id))
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

/// Pattern mastery for the ACTIVE goal — see [goalPatternMastery].
@riverpod
Future<List<PatternMastery>> patternMastery(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  return ref.watch(goalPatternMasteryProvider(goal.id).future);
}

/// How many of a goal's cards come due on each of the next 14 days (FSRS `dueAt`).
@riverpod
Future<List<int>> goalDueForecast(Ref ref, String goalId) async {
  final memberIdsF = ref.watch(goalMemberCardIdsProvider(goalId).future);
  final statesF = ref.watch(srsStatesProvider.future);
  final clockF = ref.watch(clockProvider.future);
  final memberIds = await memberIdsF;
  final states = await statesF;
  final clock = await clockF;
  return computeDueForecast(
    dueDates: [
      for (final s in states.byKey.values)
        if (memberIds.contains(s.cardId)) s.dueAt,
    ],
    today: clock.today(),
  );
}

/// Due forecast for the ACTIVE goal — see [goalDueForecast].
@riverpod
Future<List<int>> dueForecast(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  return ref.watch(goalDueForecastProvider(goal.id).future);
}

/// A goal's most-lapsed cards (leeches worth reformulating), most-failed first.
@riverpod
Future<List<StrugglingCard>> goalStrugglingCards(Ref ref, String goalId) async {
  final memberIdsF = ref.watch(goalMemberCardIdsProvider(goalId).future);
  ref.watch(srsStatesProvider); // refresh after reviews change
  final indexF = ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final memberIds = await memberIdsF;
  final index = await indexF;
  final rows = await repo.lapsesByCard();
  final titleByCard = {for (final c in index.cards) c.id: c.title};
  return topStruggling(
    [
      for (final r in rows)
        if (memberIds.contains(r.cardId)) r,
    ],
    titleByCard,
  );
}

/// Struggling cards for the ACTIVE goal — see [goalStrugglingCards].
@riverpod
Future<List<StrugglingCard>> strugglingCards(Ref ref) async {
  final goal = await ref.watch(activeStudyGoalProvider.future);
  return ref.watch(goalStrugglingCardsProvider(goal.id).future);
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
