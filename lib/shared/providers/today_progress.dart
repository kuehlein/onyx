import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/plan/practice_plan.dart';
import 'clock.dart';
import 'daily_plan.dart';
import 'interview.dart';
import 'srs.dart';

part 'today_progress.g.dart';

/// The day's at-a-glance progress for the Home ring: how many of today's flows
/// are finished vs. still in scope, and how many estimated minutes remain.
///
/// A track counts as "in scope today" if it still has planned work OR you've
/// already touched it today; it's "done" once you've touched it today and it has
/// no remaining planned work (its queue emptied). This stays honest as the plan
/// recomputes — finishing Review drops it from the plan, so it flips to done.
class TodayProgress {
  const TodayProgress({
    required this.done,
    required this.total,
    required this.minutesLeft,
  });

  final int done;
  final int total;
  final int minutesLeft;

  /// True when there was work today and it's all finished (ring fully closed).
  bool get allDone => total > 0 && done >= total;

  /// True when there's genuinely nothing scheduled or done today.
  bool get nothingScheduled => total == 0;

  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
}

@riverpod
Future<TodayProgress> todayProgress(Ref ref) async {
  final plan = await ref.watch(dailyPlanProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final now = clock.now();
  final startOfToday = DateTime(now.year, now.month, now.day);

  final srs = ref.watch(srsRepositoryProvider);
  final reviewedToday = (await srs.reviewGradesSince(startOfToday)).isNotEmpty;
  final learnedToday =
      (await srs.learnTimestamps(since: startOfToday)).isNotEmpty;
  final attemptsToday =
      await ref.watch(appliedRepositoryProvider).attempts(since: startOfToday);
  final algoToday = attemptsToday.any((a) => a.source == 'algo');
  final sdToday = attemptsToday.any((a) => a.source == 'sd-practice');
  final behavioralToday = attemptsToday.any((a) => a.source == 'behavioral');

  final pending = {for (final t in plan.tracks) t.track};
  final didToday = {
    if (reviewedToday) TrackId.review,
    if (learnedToday) TrackId.learn,
    if (algoToday) TrackId.algorithms,
    if (sdToday) TrackId.systemDesign,
    if (behavioralToday) TrackId.behavioral,
  };

  var total = 0;
  var done = 0;
  for (final t in TrackId.values) {
    final inScope = pending.contains(t) || didToday.contains(t);
    if (!inScope) continue;
    total++;
    if (didToday.contains(t) && !pending.contains(t)) done++;
  }

  return TodayProgress(
    done: done,
    total: total,
    minutesLeft: plan.plannedMinutes.round(),
  );
}
