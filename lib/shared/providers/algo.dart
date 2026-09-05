import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/clock.dart';
import '../../core/database/database.dart';
import '../../core/interview/assessment.dart';
import '../../core/srs/algo_queue.dart';
import '../../core/srs/recognition.dart';
import '../models/card.dart';
import 'clock.dart';
import 'interview.dart';
import 'readiness.dart';
import 'settings.dart';
import 'srs.dart';
import 'vault.dart';

part 'algo.g.dart';

/// The day's Algorithms session — due re-solves + new problems, paced by the
/// [algoDailyGoalProvider]. Built from `type: algorithm` cards only; the main
/// review/learn queues exclude those, so the two tracks never mix.
@riverpod
Future<List<AlgoTask>> algoQueue(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final recognitionRepo = ref.watch(recognitionRepositoryProvider);
  final clock = await ref.watch(clockProvider.future);
  final goal = await ref.watch(algoDailyGoalProvider.future);
  final states = await repo.loadStates();
  final recog = await recognitionRepo.loadStates();
  return buildAlgoQueue(
    cards: [
      for (final c in index.cards)
        if (c.type == CardType.algorithm) c,
    ],
    dueByKey: {for (final e in states.entries) e.key: e.value.dueAt},
    explainDueByKey: {for (final e in recog.entries) e.key: e.value.dueAt},
    now: clock.now(),
    goal: goal,
  );
}

/// In-progress Algorithms session: the day's queue, the state snapshot it was
/// built from, and a cursor.
class AlgoSessionState {
  const AlgoSessionState({
    required this.queue,
    required this.statesByKey,
    this.index = 0,
    this.done = 0,
  });

  final List<AlgoTask> queue;
  final Map<String, SrsState> statesByKey;
  final int index;

  /// How many problems were worked this session (for the completion screen).
  final int done;

  bool get isDone => index >= queue.length;
  int get total => queue.length;
  AlgoTask? get current => isDone ? null : queue[index];

  AlgoSessionState copyWith({int? index, int? done}) => AlgoSessionState(
        queue: queue,
        statesByKey: statesByKey,
        index: index ?? this.index,
        done: done ?? this.done,
      );
}

/// One self-reported outcome for a solved problem, mapping how it went to both
/// an FSRS grade (schedules the next re-solve) and applied-transfer numbers
/// (feeds readiness). Reused by the algo session UI.
enum SolveOutcome { clean, hinted, struggled, failed }

extension SolveOutcomeSpec on SolveOutcome {
  ({int grade, int appliedScore, int hintLevel}) get spec => switch (this) {
        SolveOutcome.clean => (grade: 4, appliedScore: 90, hintLevel: 0),
        SolveOutcome.hinted => (grade: 3, appliedScore: 65, hintLevel: 2),
        SolveOutcome.struggled => (grade: 2, appliedScore: 45, hintLevel: 3),
        SolveOutcome.failed => (grade: 1, appliedScore: 20, hintLevel: 5),
      };
}

/// Drives an Algorithms session. Logging a solve does BOTH: schedules the next
/// re-solve via FSRS (the execution clock) AND records an applied-transfer
/// attempt (`source: algo`) so real solves count toward readiness — then
/// advances. Kept alive across tab switches; invalidate [algoQueueProvider] to
/// start fresh.
@riverpod
class AlgoSession extends _$AlgoSession {
  @override
  Future<AlgoSessionState> build() async {
    final queue = await ref.watch(algoQueueProvider.future);
    final states = await ref.read(srsRepositoryProvider).loadStates();
    return AlgoSessionState(queue: queue, statesByKey: states);
  }

  /// Log how the current problem's re-solve went, then advance.
  Future<void> logSolve(SolveOutcome outcome, {String? note}) async {
    final s = state.asData?.value;
    if (s == null || s.isDone) return;
    final item = s.current!.item;
    final spec = outcome.spec;
    final scheduler = ref.read(srsSchedulerProvider);
    final repo = ref.read(srsRepositoryProvider);
    final clock = ref.read(clockProvider).asData?.value ?? Clock.real;
    final current = s.statesByKey[item.key];

    // Execution clock: FSRS schedules the next re-solve (first solve seeds it).
    final result = scheduler.review(
      grade: spec.grade,
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
      grade: spec.grade,
      outcome: result,
    );

    // Applied transfer: a real solve is the truest transfer evidence.
    await ref.read(appliedRepositoryProvider).record(
          cardId: item.card.id,
          sectionSlug: item.section.slug,
          domain: item.card.domain,
          source: 'algo',
          occurredAt: clock.now(),
          assessment: AppliedAssessment(
            appliedScore: spec.appliedScore,
            hintLevel: spec.hintLevel,
            note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
          ),
        );

    // Solving is the strongest recognition signal too — refresh the explain
    // clock so we don't nag you to explain a problem you just solved. A clean
    // or hinted solve is "solid"; a struggle/fail only holds (never "lost",
    // since you engaged the real problem).
    await ref.read(recognitionRepositoryProvider).recordExplain(
          cardId: item.card.id,
          sectionSlug: item.section.slug,
          outcome:
              spec.grade >= 3 ? ExplainOutcome.solid : ExplainOutcome.shaky,
          now: clock.now(),
        );

    // Refresh everything this touches so the dashboard/insights/coach reflect it.
    ref.invalidate(srsStatesProvider);
    ref.invalidate(appliedTransferProvider);
    ref.invalidate(appliedSummaryProvider);
    ref.invalidate(readinessProvider);
    ref.invalidate(algoDueCountProvider);
    state = AsyncData(s.copyWith(index: s.index + 1, done: s.done + 1));
  }

  /// Log how an explanation went. Touches ONLY the recognition clock — never the
  /// solve schedule or readiness ("explain never substitutes for solve") — then
  /// advances.
  Future<void> logExplain(ExplainOutcome outcome) async {
    final s = state.asData?.value;
    if (s == null || s.isDone) return;
    final item = s.current!.item;
    final clock = ref.read(clockProvider).asData?.value ?? Clock.real;
    await ref.read(recognitionRepositoryProvider).recordExplain(
          cardId: item.card.id,
          sectionSlug: item.section.slug,
          outcome: outcome,
          now: clock.now(),
        );
    state = AsyncData(s.copyWith(index: s.index + 1, done: s.done + 1));
  }
}

/// How many algorithm problems are due for a re-solve right now (for a Home
/// badge / "N due" affordance). Ignores the daily-goal cap.
@riverpod
Future<int> algoDueCount(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final clock = await ref.watch(clockProvider.future);
  final states = await repo.loadStates();
  final now = clock.now();
  var due = 0;
  for (final c in index.cards) {
    if (c.type != CardType.algorithm) continue;
    for (final s in c.quizzableSections) {
      final d = states['${c.id}::${s.slug}']?.dueAt;
      if (d != null && !d.isAfter(now)) due++;
    }
  }
  return due;
}
