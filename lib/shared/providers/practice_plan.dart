import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/plan/practice_plan.dart';
import 'algo.dart';
import 'learn.dart';
import 'srs.dart';
import 'system_design.dart';

part 'practice_plan.g.dart';

/// The unified availability across all four flows — a priority-ordered list of
/// [PracticeUnit]s per [TrackId], adapted from each flow's existing scheduler.
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
      track: TrackId.review,
      units: [
        for (final it in review.queue)
          PracticeUnit(
            track: TrackId.review,
            id: '${it.card.id}::${it.section.slug}',
            label: '${it.card.title} — ${it.section.heading}',
            estMinutes: kReviewMinutes,
          ),
      ],
    ),
    TrackAvailability(
      track: TrackId.learn,
      units: [
        for (final it in learn)
          PracticeUnit(
            track: TrackId.learn,
            id: '${it.card.id}::${it.section.slug}',
            label: '${it.card.title} — ${it.section.heading}',
            estMinutes: kLearnMinutes,
          ),
      ],
    ),
    TrackAvailability(
      track: TrackId.algorithms,
      units: [
        for (final t in algo)
          PracticeUnit(
            track: TrackId.algorithms,
            id: '${t.item.card.id}::${t.item.section.slug}',
            label: '${t.item.card.title}: ${t.item.section.heading}',
            estMinutes: algoEstMinutes(t.item.section.content),
          ),
      ],
    ),
    TrackAvailability(
      track: TrackId.systemDesign,
      units: [
        for (final c in sd)
          PracticeUnit(
            track: TrackId.systemDesign,
            id: c.id,
            label: c.title,
            estMinutes: kSystemDesignMinutes,
          ),
      ],
    ),
  ];
}
