import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/coach/coach_update.dart';
import '../../core/deck/aim.dart';
import '../../core/readiness/readiness.dart';
import 'algo.dart';
import 'analytics.dart';
import 'behavioral_readiness.dart';
import 'clock.dart';
import 'readiness.dart';
import 'settings.dart';
import 'srs.dart';
import 'decks.dart';
import 'template.dart';

part 'coach_update.g.dart';

/// The ambient coach update for Home — a single prioritized nudge (or null to
/// stay quiet). Gathers the same signals the dashboard uses (readiness, pace,
/// streak, due backlog, recent review success, new-card load) and runs the pure
/// [buildCoachUpdate] triage over them.
@riverpod
Future<CoachUpdate?> coachUpdate(Ref ref) async {
  // Register synchronously (before the first await) so a mid-flight goal edit
  // rebuilding decks can't leave us using a disposed ref after the gap.
  final deckF = ref.watch(activeDeckProvider.future);
  final subjectF = ref.watch(activeDeckTemplateProvider.future);
  final readiness = await ref.watch(readinessProvider.future);
  if (readiness.isEmpty) return null; // no vault/cards → nothing to coach

  final pace = await ref.watch(readinessPaceProvider.future);
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

  // Days to the nearest upcoming interview (nearest non-ended active-interview
  // round on the active goal, Phase B) — gates the last-mile behavioral nudge.
  final goal = await deckF;
  final subject = await subjectF;
  final interviews = [
    for (final iv in goal.interviews)
      if (iv.active) iv
  ];
  int? daysToInterview;
  for (final iv in interviews) {
    if (iv.status.isEnded) continue;
    final d = iv.currentRound(goal.id, goal.deadline)?.date;
    if (d == null) continue;
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (days >= 0 && (daysToInterview == null || days < daysToInterview)) {
      daysToInterview = days;
    }
  }
  final behavioral = await ref.watch(behavioralReadinessProvider.future);
  // Days until, at the current pace, readiness is forecast to cross the target.
  // This (not a scheduled date) is the primary trigger for the behavioral nudge:
  // when you're ~a month from ready you start applying, and behavioral prep is
  // the last-mile work that begins then — before interviews are on the calendar.
  final forecast = await ref.watch(readinessForecastProvider.future);
  final daysToReady = forecast?.currentReadyDay;

  final weakest = readiness.weakestDomain;
  // Overall coverage = studied sections / all in-scope sections.
  final totalSections = readiness.domains.fold(0, (a, d) => a + d.total);
  final studiedSections = readiness.domains.fold(0, (a, d) => a + d.studied);
  final coverage = totalSections == 0 ? 0.0 : studiedSections / totalSections;

  final signals = CoachSignals(
    anyStudied: readiness.domains.any((d) => d.studied > 0),
    studiedToday: consistency.isNotEmpty && consistency.last > 0,
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
    daysToInterview: daysToInterview,
    daysToReady: daysToReady,
    behavioralStage: behavioral.stage,
    // A neutral subject (no assessment noun) suppresses the "prove it with a
    // mock" nudge — it has no mock/interview to prove it with (G7e).
    hasAssessment: subject.vocabulary.hasAssessment,
  );
  return buildCoachUpdate(signals);
}
