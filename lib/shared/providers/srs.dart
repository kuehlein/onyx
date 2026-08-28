import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/database.dart';
import '../../core/srs/review_queue.dart';
import '../../core/srs/srs_repository.dart';
import '../../core/srs/srs_scheduler.dart';
import 'coach.dart';
import 'database.dart';
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
  final states = await repo.loadStates();
  final dueByKey = {for (final e in states.entries) e.key: e.value.dueAt};
  final queue = buildReviewQueue(
    cards: index.cards,
    dueByKey: dueByKey,
    now: DateTime.now(),
  );
  return ReviewQueueData(queue: queue, statesByKey: states);
}

/// In-progress study session: the queue, the state snapshot, and a cursor.
class SessionState {
  const SessionState({
    required this.queue,
    required this.statesByKey,
    required this.index,
  });

  final List<ReviewItem> queue;
  final Map<String, SrsState> statesByKey;
  final int index;

  bool get isDone => index >= queue.length;
  int get total => queue.length;
  ReviewItem? get current => isDone ? null : queue[index];

  SessionState copyWith({int? index}) => SessionState(
        queue: queue,
        statesByKey: statesByKey,
        index: index ?? this.index,
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
    return SessionState(
      queue: data.queue,
      statesByKey: Map.of(data.statesByKey),
      index: 0,
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
    final current = s.statesByKey[item.key];

    final outcome = scheduler.review(
      grade: grade,
      reviewedAt: DateTime.now(),
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
    state = AsyncData(s.copyWith(index: s.index + 1));
  }
}
