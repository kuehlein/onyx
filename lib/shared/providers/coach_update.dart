import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/coach/coach_update.dart';
import '../../core/readiness/readiness.dart';
import 'algo.dart';
import 'analytics.dart';
import 'clock.dart';
import 'readiness.dart';
import 'settings.dart';
import 'srs.dart';
import 'stats.dart';

part 'coach_update.g.dart';

/// The ambient coach update for Home — a single prioritized nudge (or null to
/// stay quiet). Gathers the same signals the dashboard uses (readiness, pace,
/// streak, due backlog, recent review success, new-card load) and runs the pure
/// [buildCoachUpdate] triage over them.
@riverpod
Future<CoachUpdate?> coachUpdate(Ref ref) async {
  final readiness = await ref.watch(readinessProvider.future);
  if (readiness.isEmpty) return null; // no vault/cards → nothing to coach

  final pace = await ref.watch(readinessPaceProvider.future);
  final streak = await ref.watch(studyStreakProvider.future);
  final newLimit = await ref.watch(newCardLimitProvider.future);
  final review = await ref.watch(reviewQueueProvider.future);
  final clock = await ref.watch(clockProvider.future);
  final stats = await ref
      .watch(srsRepositoryProvider)
      .recentReviewStats(clock.now().subtract(const Duration(days: 14)));
  final algoDue = await ref.watch(algoDueCountProvider.future);
  final algoRecognition = await ref.watch(algoRecognitionProvider.future);
  final checkIn = await ref.watch(loadCheckInProvider.future);
  final consistency = await ref.watch(studyConsistencyProvider.future);

  final today = clock.today();
  // The opt-in check-in is due when enabled and unanswered for ~a week.
  final checkInDue = checkIn.enabled &&
      (checkIn.lastAsked == null ||
          today.difference(checkIn.lastAsked!).inDays >= 7);
  // A recent answer still counts (fades after ~10 days).
  final loadFeel =
      (checkIn.feelAt != null && today.difference(checkIn.feelAt!).inDays <= 10)
          ? checkIn.feel
          : null;
  // "Showing up lately" = studied at least 3 of the last 7 days.
  final last7 = consistency.length <= 7
      ? consistency
      : consistency.sublist(consistency.length - 7);
  final activeRecently = last7.where((c) => c > 0).length >= 3;

  final weakest = readiness.weakestDomain;
  // Overall coverage = studied sections / all in-scope sections.
  final totalSections = readiness.domains.fold(0, (a, d) => a + d.total);
  final studiedSections = readiness.domains.fold(0, (a, d) => a + d.studied);
  final coverage = totalSections == 0 ? 0.0 : studiedSections / totalSections;

  final signals = CoachSignals(
    anyStudied: readiness.domains.any((d) => d.studied > 0),
    studiedToday: streak.studiedToday,
    overall: readiness.overall,
    coverage: coverage,
    interviewTested: readiness.interview,
    dueCount: review.queue.length,
    newCardLimit: newLimit,
    reviewsInWindow: stats.total,
    retention: stats.total > 0 ? stats.retained / stats.total : null,
    algoDue: algoDue,
    algoExplainDue: algoRecognition.due,
    paceStatus: pace?.status,
    recentPerDay: pace?.recentPerDay,
    requiredPerDay: pace?.requiredPerDay,
    weakestDomain: weakest,
    weakestDomainPretty: weakest == null ? null : prettyDomain(weakest),
    // Rotate the on-track affirmation by day so it isn't identical each visit.
    affirmSeed: clock.today().difference(DateTime(2020)).inDays,
    checkInDue: checkInDue,
    loadFeel: loadFeel,
    activeRecently: activeRecently,
  );
  return buildCoachUpdate(signals);
}
