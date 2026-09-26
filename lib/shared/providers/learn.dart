import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/ai/coach.dart' show CoachKind;
import '../../core/clock.dart';
import '../../core/plan/practice_plan.dart';
import '../../core/srs/learn_queue.dart';
import '../../core/srs/srs_scheduler.dart' show learnEasyMaxIntervalFactor;
import '../../core/template/study_policy.dart'
    show retentionDefault, retentionForPriority;
import '../models/card.dart';
import 'clock.dart';
import 'coach.dart';
import 'daily_plan.dart';
import 'database.dart';
import 'readiness.dart';
import 'settings.dart';
import 'srs.dart';
import 'decks.dart';
import 'vault.dart';

part 'learn.g.dart';

/// The engine-DERIVED daily new-material allowance (task #114 Phase B · ADR-0016):
/// [sustainableNewCount] over the active deck's budget slice and today's due-review
/// load. This replaces the old fixed `newCardLimit` guardrail — the user sets the
/// day's SIZE (the vault budget + each deck's proportion, ADR-0010); the engine
/// derives how much of it is new, capped so novelty can't out-run the review it
/// creates. Reviews are sized in the SAME state-aware est-minutes the daily-plan
/// packer uses (#133), computed here from the review queue directly (NOT via
/// practiceAvailability, which would cycle back through the learn queue).
@riverpod
Future<int> dailyNewAllowance(Ref ref) async {
  // Register every dependency synchronously (before the first await) so a mid-flight
  // invalidation can't leave this using a disposed ref. None of these transitively
  // read the learn queue, so there is no dependency cycle.
  final deckF = ref.watch(activeDeckProvider.future);
  final budgetsF = ref.watch(deckBudgetsProvider.future);
  final reviewF = ref.watch(reviewQueueProvider.future);
  final srsF = ref.watch(srsStatesProvider.future);
  final goal = await deckF;
  final budgets = await budgetsF;
  final reviewData = await reviewF;
  final srs = await srsF;

  final budget = budgets[goal.id] ?? 0;
  if (budget <= 0) return 0;

  // Today's due-review load in minutes, state-aware (#133) — mirrors the review
  // track's `_est` in practice_plan.dart so the derived count reflects the time
  // reviews will actually take (a mature-heavy backlog leaves more room for new).
  var dueReviewMinutes = 0.0;
  for (final it in reviewData.queue) {
    final t0 = it.card.estMinutes ?? kReviewMinutes;
    final st = srs[it.key];
    dueReviewMinutes += st == null
        ? t0
        : scaleEstMinutes(t0,
            stability: st.stability, fsrsState: st.state, floor: kReviewFloor);
  }

  return sustainableNewCount(
    budgetMinutes: budget,
    dueReviewMinutes: dueReviewMinutes,
  );
}

/// How many brand-new sections may still be started today: the derived daily
/// [dailyNewAllowanceProvider] minus what's already been learned today. A DAILY
/// allowance (not per-session) — once you've learned that many today, there's
/// nothing new until tomorrow, mirroring how reviews are time-gated. Learned-today
/// is counted from the activity log against the (dev-adjustable) clock's day.
@riverpod
Future<int> dailyNewRemaining(Ref ref) async {
  final allowanceF = ref.watch(dailyNewAllowanceProvider.future);
  final clockF = ref.watch(clockProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final allowance = await allowanceF;
  final clock = await clockF;
  final learnedToday = await repo.sectionsStartedSince(clock.today());
  return (allowance - learnedToday).clamp(0, allowance);
}

/// The "learn new material" queue: un-seeded quizzable sections grouped by
/// wikilink family, foundational-first, capped by the remaining daily allowance.
@riverpod
Future<List<LearnItem>> learnQueue(Ref ref) async {
  final deckF = ref.watch(activeDeckProvider.future); // register first
  final index = await ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final states = await repo.loadStates();
  final remaining = await ref.watch(dailyNewRemainingProvider.future);
  if (remaining <= 0) return const [];
  final targeting = await ref.watch(activeTargetingProvider.future);
  // Urgency-weighted per-domain emphasis (S3d): order new material by per-aim
  // urgency, not the blended base track. Byte-identical single-aim.
  final planWeights = await ref.watch(activePlanDomainWeightsProvider.future);
  final goal = await deckF;
  // Scope to the active goal's cards (task #30d, G5+) so a lane learns its own
  // material; the whole-vault default goal selects everything (unchanged).
  final scoped = goal.select(index.studyCards).toList();
  return buildLearnQueue(
    // Practice-track cards (Algorithms, System Design) are practiced on their
    // own tracks, not learned here.
    cards: [
      for (final c in scoped)
        if (!c.isPracticeTrack) c,
    ],
    seededKeys: states.keys.toSet(),
    adjacency: _buildAdjacency(scoped),
    newSectionLimit: remaining,
    // Bias new material toward the domains/concepts the active aims weight most,
    // now scaled by each aim's feasibility urgency (S3d) — a behind aim's domains
    // surface sooner (secondary to foundational-first).
    priorityOf: (c) => targeting.weightForCard(c, domainWeights: planWeights),
  );
}

/// Symmetric card→card adjacency from resolved wikilinks (by filename).
Map<String, Set<String>> _buildAdjacency(List<Card> cards) {
  final idByFilename = {
    for (final c in cards) _filenameKey(c.filePath): c.id,
  };
  final adjacency = <String, Set<String>>{};
  void link(String a, String b) {
    adjacency.putIfAbsent(a, () => {}).add(b);
    adjacency.putIfAbsent(b, () => {}).add(a);
  }

  for (final card in cards) {
    for (final target in card.wikilinks) {
      final toId = idByFilename[target];
      if (toId != null && toId != card.id) link(card.id, toId);
    }
  }
  return adjacency;
}

String _filenameKey(String path) {
  final base = path.split('/').last;
  return base.endsWith('.md') ? base.substring(0, base.length - 3) : base;
}

/// A Learn session: the remaining items to study (head is current) and a count
/// of how many have graduated. Graduating removes the head; a re-study moves the
/// head to the tail — so `graduated + queue.length` stays constant (a stable
/// progress denominator).
class LearnSessionState {
  const LearnSessionState({required this.queue, required this.graduated});

  final List<LearnItem> queue;
  final int graduated;

  LearnItem? get current => queue.isEmpty ? null : queue.first;
  bool get isDone => queue.isEmpty;
  int get total => graduated + queue.length;
}

/// Drives Learn mode: present un-seeded sections one at a time; a self-rating of
/// Good/Easy graduates the section (seeds FSRS state, enters the review queue),
/// while Again/Hard re-queues it for another pass this session. Learn never
/// writes a review-log row.
@riverpod
class LearnSession extends _$LearnSession {
  @override
  Future<LearnSessionState> build() async {
    // `read` (not `watch`): a learn session is a point-in-time snapshot. Grading
    // invalidates srs/review state (so Home refreshes after you learn), which now
    // cascades to the learn queue via the derived new-allowance (ADR-0016) —
    // *watching* it would reset the in-progress session mid-grade. Fresh sessions
    // come from autoDispose on nav (mirrors the review session's read-not-watch
    // note in srs.dart).
    final queue = await ref.read(learnQueueProvider.future);
    // Fresh session: clear stale per-section coach chats (symmetric with the
    // review session). Browse chats are untouched; within a session, chats
    // persist to the DB so they survive closing/reopening the coach.
    await clearTestCoachConversations(
        ref.read(appDatabaseProvider), CoachKind.tutor);
    return LearnSessionState(queue: queue, graduated: 0);
  }

  /// Grade the current section (1=Again … 4=Easy). Good/Easy graduate it; lower
  /// grades send it back for another pass.
  Future<void> grade(int grade) async {
    final s = state.asData?.value;
    if (s == null || s.isDone) return;
    final item = s.queue.first;

    if (grade >= 3) {
      final scheduler = ref.read(srsSchedulerProvider);
      final repo = ref.read(srsRepositoryProvider);
      final clock = ref.read(clockProvider).asData?.value ?? Clock.real;
      // A near-term interview raises target retention (scheduling only); the user's
      // global target-retention (n0014) sets the base otherwise. Seeds the initial
      // FSRS values for this fresh section.
      final base =
          ref.read(targetRetentionProvider).asData?.value ?? retentionDefault;
      final retention = ref
              .read(activeTargetingProvider)
              .asData
              ?.value
              .desiredRetentionForCard(item.card,
                  today: clock.today(), normalRetention: base) ??
          retentionForPriority(item.card.priority, base: base);
      final outcome = scheduler.review(
        grade: grade,
        reviewedAt: clock.now(),
        desiredRetention: retention,
        // Guard first-exposure Easy so an already-known card skips ahead without
        // FSRS's unearned ~15-day jump (n0014).
        newCardMaxEasyFactor: learnEasyMaxIntervalFactor,
      );
      await repo.seedState(
        cardId: item.card.id,
        sectionSlug: item.section.slug,
        outcome: outcome,
      );
      ref.invalidate(srsStatesProvider);
      ref.invalidate(reviewQueueProvider);
      state = AsyncData(LearnSessionState(
        queue: s.queue.sublist(1),
        graduated: s.graduated + 1,
      ));
    } else {
      state = AsyncData(LearnSessionState(
        queue: [...s.queue.sublist(1), item],
        graduated: s.graduated,
      ));
    }
  }
}
