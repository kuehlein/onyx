import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/srs/algo_queue.dart';
import '../../core/srs/review_queue.dart' show ReviewItem;
import '../models/card.dart';
import 'clock.dart';
import 'settings.dart';
import 'srs.dart';
import 'vault.dart';

part 'algo.g.dart';

/// The day's Algorithms session — due re-solves + new problems, paced by the
/// [algoDailyGoalProvider]. Built from `type: algorithm` cards only; the main
/// review/learn queues exclude those, so the two tracks never mix.
@riverpod
Future<List<ReviewItem>> algoQueue(Ref ref) async {
  final index = await ref.watch(vaultIndexProvider.future);
  final repo = ref.watch(srsRepositoryProvider);
  final clock = await ref.watch(clockProvider.future);
  final goal = await ref.watch(algoDailyGoalProvider.future);
  final states = await repo.loadStates();
  return buildAlgoQueue(
    cards: [
      for (final c in index.cards)
        if (c.type == CardType.algorithm) c,
    ],
    dueByKey: {for (final e in states.entries) e.key: e.value.dueAt},
    now: clock.now(),
    goal: goal,
  );
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
