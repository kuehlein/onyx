import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/stats/streak.dart';
import 'clock.dart';
import 'srs.dart';

part 'stats.g.dart';

/// The study streak for the Home dashboard. Watches [srsStatesProvider] purely
/// as a refresh trigger — it's invalidated after every grade and graduation, so
/// the streak stays live without any explicit wiring at the call sites.
@riverpod
Future<StreakInfo> studyStreak(Ref ref) async {
  // Establish the invalidation dependency (value itself is unused).
  await ref.watch(srsStatesProvider.future);

  final today = (await ref.watch(clockProvider.future)).today();
  // 400 days back comfortably covers any current streak plus best-run history.
  final since = DateTime(today.year, today.month, today.day - 400);
  final timestamps =
      await ref.watch(srsRepositoryProvider).studyTimestamps(since: since);
  return computeStreak(timestamps: timestamps, today: today);
}
