import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/plan/practice_plan.dart';
import 'algo.dart';
import 'learn.dart';
import 'srs.dart';
import 'system_design.dart';

part 'practice_plan.g.dart';

/// The unified availability across all four flows — a priority-ordered list of
/// [PracticeUnit]s per track, adapted from each flow's existing scheduler.
/// This is the single source the daily-plan meta-scheduler, the plan-aware coach,
/// the Home queue, and analytics will read (task #57). Additive: it only *views*
/// the existing schedulers; it changes none of them.
///
/// Prerequisite gating and level/research weighting are layered on later phases;
/// here every track is unlocked and units carry only their flow's own ordering +
/// a rough time estimate.
@riverpod
Future<List<TrackAvailability>> practiceAvailability(Ref ref) async {
  final review = await ref.watch(reviewQueueProvider.future);
  final learn = await ref.watch(learnQueueProvider.future);
  final algo = await ref.watch(algoQueueProvider.future);
  final sd = await ref.watch(systemDesignProblemsProvider.future);

  return [
    TrackAvailability(
      track: kTrackReview,
      label: 'Review',
      units: [
        for (final it in review.queue)
          PracticeUnit(
            track: kTrackReview,
            id: '${it.card.id}::${it.section.slug}',
            label: '${it.card.title} — ${it.section.heading}',
            estMinutes: it.card.estMinutes ?? kReviewMinutes,
          ),
      ],
    ),
    TrackAvailability(
      track: kTrackLearn,
      label: 'Learn',
      units: [
        for (final it in learn)
          PracticeUnit(
            track: kTrackLearn,
            id: '${it.card.id}::${it.section.slug}',
            label: '${it.card.title} — ${it.section.heading}',
            estMinutes: it.card.estMinutes ?? kLearnMinutes,
          ),
      ],
    ),
    TrackAvailability(
      track: kTrackAlgorithms,
      label: 'Algorithms',
      units: [
        for (final t in algo)
          PracticeUnit(
            track: kTrackAlgorithms,
            id: '${t.item.card.id}::${t.item.section.slug}',
            label: '${t.item.card.title}: ${t.item.section.heading}',
            estMinutes: t.item.card.estMinutes ??
                algoEstMinutes(t.item.section.content),
          ),
      ],
    ),
    TrackAvailability(
      track: kTrackSystemDesign,
      label: 'System design',
      units: [
        for (final c in sd)
          PracticeUnit(
            track: kTrackSystemDesign,
            id: c.id,
            label: c.title,
            estMinutes: c.estMinutes ?? kSystemDesignMinutes,
          ),
      ],
    ),
  ];
}
