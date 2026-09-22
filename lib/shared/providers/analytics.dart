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
import 'decks.dart';
import 'vault.dart';

part 'analytics.g.dart';

/// The lookback window for retention analytics. Recall reflects recent
/// performance; stability is read from current FSRS state (not windowed).
const retentionWindow = Duration(days: 90);

/// Per-domain retention (task #27) for a SPECIFIC goal — its member cards' review
/// log + current FSRS state, grouped by domain. Scoped to `deckMemberCardIds` so
/// a lane shows only its own recall; the whole-vault default goal includes every
/// card, so single-goal numbers are unchanged.
@riverpod
Future<List<DomainRetention>> deckRetentionByDomain(
    Ref ref, String deckId) async {
  // Register deps before the first await (disposal hazard — a goal edit rebuilds
  // decks/memberIds and would invalidate this instance mid-await).
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
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

/// Per-domain retention for the ACTIVE goal — see [deckRetentionByDomain].
@riverpod
Future<List<DomainRetention>> retentionByDomain(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckRetentionByDomainProvider(goal.id).future);
}

/// Per-TAG retention for a SPECIFIC goal (task #27): like [deckRetentionByDomain]
/// but each member card counts toward EVERY tag it carries, not just its domain
/// (first tag). So a cross-cutting tag (e.g. `caching`, `sharding`) gets its own
/// recall across domains — a finer lens than the domain rollup.
@riverpod
Future<List<DomainRetention>> deckRetentionByTag(Ref ref, String deckId) async {
  // Register deps before the first await (disposal hazard).
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final statesF = ref.watch(srsStatesProvider.future);
  final clockF = ref.watch(clockProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final memberIds = await memberIdsF;
  final index = await indexF;
  final states = await statesF;
  final since = (await clockF).now().subtract(retentionWindow);
  final grades = await repo.reviewGradesSince(since);

  final tagsByCard = <String, List<String>>{
    for (final c in index.cards)
      if (c.tags.isNotEmpty && memberIds.contains(c.id)) c.id: c.tags,
  };
  final stabilities = [
    for (final s in states.byKey.values)
      if (memberIds.contains(s.cardId))
        (cardId: s.cardId, stability: s.stability),
  ];

  return computeRetentionByTag(
    reviews: [
      for (final g in grades)
        if (memberIds.contains(g.cardId)) g,
    ],
    stabilities: stabilities,
    tagsByCard: tagsByCard,
  );
}

/// Per-tag retention for the ACTIVE goal — see [deckRetentionByTag].
@riverpod
Future<List<DomainRetention>> retentionByTag(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckRetentionByTagProvider(goal.id).future);
}

/// Averaged mock-interview performance + rubric breakdown for a SPECIFIC goal —
/// mocks on its member cards. The whole-vault default goal includes all, so
/// single-goal numbers are unchanged. Recomputes on a new mock.
@riverpod
Future<MockSkills> deckMockSkills(Ref ref, String deckId) async {
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
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

/// Mock skills for the ACTIVE goal — see [deckMockSkills].
@riverpod
Future<MockSkills> mockSkills(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckMockSkillsProvider(goal.id).future);
}

/// System-design mock performance + rubric breakdown for a goal (its own rubric,
/// distinct from the coding mock skills). Recomputes on a new mock.
@riverpod
Future<MockSkills> deckSystemDesignSkills(Ref ref, String deckId) async {
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
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

/// System-design skills for the ACTIVE goal — see [deckSystemDesignSkills].
@riverpod
Future<MockSkills> systemDesignSkills(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckSystemDesignSkillsProvider(goal.id).future);
}

/// Behavioral mock performance + STAR+L rubric breakdown for a goal (its own
/// rubric). Its own Insights section so it doesn't mix with coding/SD mocks.
@riverpod
Future<MockSkills> deckBehavioralSkills(Ref ref, String deckId) async {
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
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

/// Behavioral skills for the ACTIVE goal — see [deckBehavioralSkills].
@riverpod
Future<MockSkills> behavioralSkills(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckBehavioralSkillsProvider(goal.id).future);
}

/// Algorithms-track progress for a goal: problems picked up, clean-solve rate,
/// momentum. Recomputes when a solve is logged (invalidates appliedTransfer).
@riverpod
Future<AlgoStats> deckAlgoStats(Ref ref, String deckId) async {
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
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

/// Algorithms progress for the ACTIVE goal — see [deckAlgoStats].
@riverpod
Future<AlgoStats> algoStats(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckAlgoStatsProvider(goal.id).future);
}

/// Per-pattern mastery for the Algorithms track within a goal — how much of each
/// pattern you can durably solve (execution clock). Recomputes after solves.
@riverpod
Future<List<PatternMastery>> deckPatternMastery(Ref ref, String deckId) async {
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
  final indexF = ref.watch(vaultIndexProvider.future);
  final statesF = ref.watch(srsStatesProvider.future);
  final memberIds = await memberIdsF;
  final index = await indexF;
  final states = await statesF;
  return computePatternMastery([
    for (final c in index.cards)
      // Pattern mastery is the built-in Algorithms two-clock analytic; folding it
      // to a config predicate needs the concept-vs-applied-recall call (#87/#32).
      // ignore: no_card_type_branch
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

/// Pattern mastery for the ACTIVE goal — see [deckPatternMastery].
@riverpod
Future<List<PatternMastery>> patternMastery(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckPatternMasteryProvider(goal.id).future);
}

/// How many of a goal's cards come due on each of the next 14 days (FSRS `dueAt`).
@riverpod
Future<List<int>> deckDueForecast(Ref ref, String deckId) async {
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
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

/// Due forecast for the ACTIVE goal — see [deckDueForecast].
@riverpod
Future<List<int>> dueForecast(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckDueForecastProvider(goal.id).future);
}

/// A goal's most-lapsed cards (leeches worth reformulating), most-failed first.
@riverpod
Future<List<StrugglingCard>> deckStrugglingCards(Ref ref, String deckId) async {
  final memberIdsF = ref.watch(deckMemberCardIdsProvider(deckId).future);
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

/// Struggling cards for the ACTIVE goal — see [deckStrugglingCards].
@riverpod
Future<List<StrugglingCard>> strugglingCards(Ref ref) async {
  final goal = await ref.watch(activeDeckProvider.future);
  return ref.watch(deckStrugglingCardsProvider(goal.id).future);
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
