import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/database.dart' show SrsState;
import '../../core/plan/practice_plan.dart';
import '../../core/practice/mock_schedule.dart';
import '../../core/srs/algo_queue.dart' show AlgoMode, AlgoTask;
import '../../core/template/active_template.dart';
import '../../core/template/flow_spec.dart';
import 'algo.dart';
import 'clock.dart';
import 'learn.dart';
import 'srs.dart';
import 'decks.dart';
import 'system_design.dart';
import 'vault.dart';

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
  // Deps for config vault-driven mock flows (task #30 G2a). Registered BEFORE the
  // first await so a settling upstream can't dispose this element mid-build; for a
  // pure-SWE subject (all flows in-code) they resolve but go unused.
  final indexF = ref.watch(vaultIndexProvider.future);
  final statesF = ref.watch(recognitionRepositoryProvider).loadStates();
  final clockF = ref.watch(clockProvider.future);
  final deckF = ref.watch(activeDeckProvider.future);
  // FSRS per-section state (stability + learning state) for the est-minutes
  // maturity scaling (task #133) — a well-learned item is quicker to review/re-solve.
  final srsF = ref.watch(srsStatesProvider.future);

  final review = await ref.watch(reviewQueueProvider.future);
  final learn = await ref.watch(learnQueueProvider.future);
  final algo = await ref.watch(algoQueueProvider.future);
  final sd = await ref.watch(systemDesignProblemsProvider.future);

  final index = await indexF;
  final states = await statesF;
  final now = (await clockF).now();
  final goal = await deckF;
  final srs = await srsF;
  DateTime? mockDueOf(c) => states['${c.id}::mock']?.dueAt;

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
            estMinutes: _est(it.card.estMinutes ?? kReviewMinutes, srs[it.key],
                kReviewFloor),
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
            estMinutes: _algoEst(t, srs),
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
    // Config vault-driven mock flows (task #30 G2a). A flow with `skill != null`
    // is authored in the vault (its interlocutor/grader prompt), so it's handled
    // generically here: its cards enter the plan as whole-card, mock-due-ordered
    // units. In-code SWE flows all have `skill == null`, so this emits nothing for
    // SWE — the four tracks above are unchanged.
    for (final flow in activeTemplate.flows)
      if (flow.skill != null && flow.scheduling == SchedulingModel.mock)
        TrackAvailability(
          track: flow.cardType,
          label: flow.displayLabel,
          units: [
            for (final c in orderByMockDue([
              for (final c in goal.select(index.studyCards))
                if (c.type == flow.cardType) c,
            ], now, mockDueOf))
              PracticeUnit(
                track: flow.cardType,
                id: c.id,
                label: c.title,
                estMinutes: c.estMinutes ?? kMockMinutes,
              ),
          ],
        ),
  ];
}

/// Est-minutes for a section, scaled by its FSRS maturity (task #133); the plain
/// first-time cost [t0] when the section has no state yet.
double _est(double t0, SrsState? st, double floor) => st == null
    ? t0
    : scaleEstMinutes(t0,
        stability: st.stability, fsrsState: st.state, floor: floor);

/// Est-minutes for one algo task: the full SOLVE cost (difficulty-based) or the
/// shorter EXPLAIN cost (recognition), each scaled by the problem's FSRS
/// (solve-clock) maturity with the mode's floor. Preserves the two-clock — an
/// explain is sized as the maintenance pass it is, not a full solve.
double _algoEst(AlgoTask t, SectionStates srs) {
  final solve = t.mode == AlgoMode.solve;
  final t0 = t.item.card.estMinutes ??
      (solve ? algoEstMinutes(t.item.section.content) : kAlgoExplainMinutes);
  return _est(t0, srs[t.item.key], solve ? kAlgoSolveFloor : kAlgoExplainFloor);
}
