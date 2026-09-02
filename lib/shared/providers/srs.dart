import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../core/database/database.dart';
import '../../core/readiness/readiness.dart';
import '../../core/srs/review_queue.dart';
import '../../core/srs/srs_repository.dart';
import '../../core/srs/srs_scheduler.dart';
import 'clock.dart';
import 'coach.dart';
import 'database.dart';
import 'readiness.dart';
import 'vault.dart';

part 'srs.g.dart';

/// The FSRS scheduler — stateless config, shared for the process.
@Riverpod(keepAlive: true)
SrsScheduler srsScheduler(Ref ref) => SrsScheduler();

/// Reads/writes scheduling state and the review log.
@Riverpod(keepAlive: true)
SrsRepository srsRepository(Ref ref) =>
    SrsRepository(ref.watch(appDatabaseProvider));

/// All per-section scheduling state, keyed by `"$cardId::$sectionSlug"`.
///
/// Wrapped in a class rather than returned as a bare `Map<String, SrsState>`:
/// riverpod codegen would have to emit the drift `SrsState` type in the provider
/// signature, which fails during the build (it isn't generated yet at that
/// phase). Holding it in a field sidesteps that.
class SectionStates {
  const SectionStates(this.byKey);

  final Map<String, SrsState> byKey;

  SrsState? operator [](String key) => byKey[key];
}

/// Loads all scheduling state; used by the browse detail view to decide which
/// sections to open. Invalidated after each graded review so it stays fresh.
@riverpod
Future<SectionStates> srsStates(Ref ref) async {
  final repo = ref.watch(srsRepositoryProvider);
  return SectionStates(await repo.loadStates());
}

/// The built session queue plus the state snapshot it was built from (so the
/// session can grade without re-reading the DB).
class ReviewQueueData {
  const ReviewQueueData({required this.queue, required this.statesByKey});

  final List<ReviewItem> queue;
  final Map<String, SrsState> statesByKey;
}

/// Assembles the current review queue from the indexed cards + scheduling state.
@riverpod
Future<ReviewQueueData> reviewQueue(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final clock = await ref.watch(clockProvider.future);
  final states = await repo.loadStates();
  final dueByKey = {for (final e in states.entries) e.key: e.value.dueAt};
  final queue = buildReviewQueue(
    cards: index.cards,
    dueByKey: dueByKey,
    now: clock.now(),
  );
  return ReviewQueueData(queue: queue, statesByKey: states);
}

/// In-progress study session: the queue, the state snapshot, and a cursor.
class SessionState {
  const SessionState({
    required this.queue,
    required this.statesByKey,
    required this.index,
    this.readinessBefore,
    this.grades = const [],
  });

  final List<ReviewItem> queue;
  final Map<String, SrsState> statesByKey;
  final int index;

  /// Readiness snapshot captured at session start, so the completion screen can
  /// show the honest movement toward the user's goal. Null if it couldn't be
  /// computed (the summary then just omits the delta).
  final Readiness? readinessBefore;

  /// The grade given to each reviewed item so far, in order.
  final List<int> grades;

  bool get isDone => index >= queue.length;
  int get total => queue.length;
  ReviewItem? get current => isDone ? null : queue[index];

  SessionState copyWith({int? index, List<int>? grades}) => SessionState(
        queue: queue,
        statesByKey: statesByKey,
        index: index ?? this.index,
        readinessBefore: readinessBefore,
        grades: grades ?? this.grades,
      );
}

/// Drives a study session: presents items one at a time and, on each grade,
/// runs FSRS, persists the result, and advances. Kept alive across tab switches
/// (the shell is an indexed stack) so progress survives; invalidate
/// [reviewQueueProvider] to start a fresh session.
@riverpod
class StudySession extends _$StudySession {
  @override
  Future<SessionState> build() async {
    final data = await ref.watch(reviewQueueProvider.future);
    // A fresh session: drop any test-scoped coach conversations left over from
    // a previous session so they never resurface. Browse chats are untouched;
    // within a session, chats persist to the DB (survive close/reopen + tab
    // switches).
    await clearTestCoachConversations(ref.read(appDatabaseProvider));

    // Snapshot readiness before the session so the completion screen can show
    // how far this session moved the user toward their goal. Uses `read` (not
    // `watch`) so per-grade srs_state invalidations don't rebuild the session.
    Readiness? before;
    try {
      final index = await ref.read(vaultIndexProvider.future);
      final targeting = await ref.read(targetingProvider.future);
      final domains = <String>{
        for (final c in index.cards)
          if (c.domain != null) c.domain!,
      };
      // Match readinessProvider's weighting (targeting layer) so the before/
      // after delta on the completion screen stays consistent once prep goals
      // are active. Recall-only here (no transfer), same as the "after" base.
      before = computeReadiness(
        cards: index.cards,
        stabilityByKey: {
          for (final e in data.statesByKey.entries) e.key: e.value.stability,
        },
        stabilityTarget: targeting.stabilityTarget,
        domainWeights: {
          for (final d in domains) d: targeting.weightForDomain(d),
        },
      );
    } catch (_) {
      before = null; // summary just omits the delta
    }

    return SessionState(
      queue: data.queue,
      statesByKey: Map.of(data.statesByKey),
      index: 0,
      readinessBefore: before,
    );
  }

  /// Grade the current item (1=Again … 4=Easy): schedule it via FSRS, persist,
  /// and move to the next.
  Future<void> grade(int grade) async {
    final s = state.asData?.value;
    if (s == null || s.isDone) return;
    final item = s.current!;

    final scheduler = ref.read(srsSchedulerProvider);
    final repo = ref.read(srsRepositoryProvider);
    final clock = ref.read(clockProvider).asData?.value ?? Clock.real;
    final current = s.statesByKey[item.key];

    final outcome = scheduler.review(
      grade: grade,
      reviewedAt: clock.now(),
      desiredRetention: item.card.priority.desiredRetention,
      stability: current?.stability,
      difficulty: current?.difficulty,
      state: current?.state,
      step: current?.step,
      due: current?.dueAt,
      lastReview: current?.lastReview,
    );

    await repo.recordReview(
      cardId: item.card.id,
      sectionSlug: item.section.slug,
      grade: grade,
      outcome: outcome,
    );

    // Browse's mastery-driven collapse reads srsStates; refresh it.
    ref.invalidate(srsStatesProvider);
    state =
        AsyncData(s.copyWith(index: s.index + 1, grades: [...s.grades, grade]));
  }
}
