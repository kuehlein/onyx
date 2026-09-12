import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/plan/practice_plan.dart'
    show kLearnMinutes, kReviewMinutes, kSystemDesignMinutes;
import 'clock.dart';
import 'daily_plan.dart';
import 'interview.dart';
import 'srs.dart';

part 'today_progress.g.dart';

/// A rough per-solve minute estimate for the Algorithms track (they vary; medium
/// is the fallback), used only to weight today's completed work in the ring.
const double _kAlgoNominalMinutes = 25;

/// The day's at-a-glance progress for the Home ring — how much of today's work is
/// done, by estimated MINUTES (so partial progress in a flow counts: doing half
/// of a Learn block that's half the day reads as ~a quarter done, not zero). Done
/// = today's completed units × their per-flow estimate; remaining = the plan's
/// still-scheduled minutes. Behavioral is excluded (it's a hub/last-mile track,
/// not part of the daily plan).
class TodayProgress {
  const TodayProgress(
      {required this.doneMinutes, required this.remainingMinutes});

  final int doneMinutes;
  final int remainingMinutes;

  int get totalMinutes => doneMinutes + remainingMinutes;

  double get fraction =>
      totalMinutes == 0 ? 0 : (doneMinutes / totalMinutes).clamp(0.0, 1.0);

  int get percent => (fraction * 100).round();

  /// True when there was work today and it's all finished (ring fully closed).
  bool get allDone => totalMinutes > 0 && remainingMinutes == 0;

  /// True when there's genuinely nothing scheduled or done today.
  bool get nothingScheduled => totalMinutes == 0;
}

@riverpod
Future<TodayProgress> todayProgress(Ref ref) async {
  final plan = await ref.watch(dailyPlanProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final startOfToday = clock.today();

  final srs = ref.watch(srsRepositoryProvider);
  final reviewsToday = (await srs.reviewGradesSince(startOfToday)).length;
  final learnsToday = (await srs.learnTimestamps(since: startOfToday)).length;
  final attemptsToday =
      await ref.watch(appliedRepositoryProvider).attempts(since: startOfToday);
  final algoToday = attemptsToday.where((a) => a.source == 'algo').length;
  final sdToday = attemptsToday.where((a) => a.source == 'sd-practice').length;

  final doneMinutes = (reviewsToday * kReviewMinutes +
          learnsToday * kLearnMinutes +
          algoToday * _kAlgoNominalMinutes +
          sdToday * kSystemDesignMinutes)
      .round();

  return TodayProgress(
    doneMinutes: doneMinutes,
    remainingMinutes: plan.plannedMinutes.round(),
  );
}
