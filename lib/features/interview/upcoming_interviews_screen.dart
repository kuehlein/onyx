import 'package:flutter/material.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/goal/study_goal.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/study_goals.dart';
import '../../shared/design/onyx_design.dart';
import 'interview_card.dart';
import 'interview_planner_sheet.dart';

/// The learner's interviews — active loops (soonest round first) with a
/// collapsible "Past" section for ended/archived ones. Every row is the shared
/// [InterviewCard]: tap opens the action sheet, swipe archives (active) or
/// deletes (past). The one place to manage interviews. Reads the active study
/// goal's interviews (Phase B).
class UpcomingInterviewsScreen extends ConsumerWidget {
  const UpcomingInterviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalAsync = ref.watch(activeStudyGoalProvider);
    final today =
        ref.watch(clockProvider).asData?.value.today() ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Interviews')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showInterviewPlannerSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Plan an interview'),
      ),
      body: goalAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goal) {
          final interviews = goal.interviews;
          if (interviews.isEmpty) return const _Empty();
          final active = [
            for (final iv in interviews)
              if (!iv.status.isEnded) iv,
          ]..sort((a, b) => _byRound(a, b, goal));
          final past = [
            for (final iv in interviews)
              if (iv.status.isEnded) iv,
          ]..sort((a, b) => _byRound(a, b, goal));

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                Dim.space3, Dim.space2, Dim.space3, 96),
            children: [
              const _Explainer(),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                      Dim.space2, Dim.space2, Dim.space2, Dim.space2),
                  child: Text('No active interviews — plan one below.'),
                ),
              for (final iv in active)
                InterviewCard(aim: iv, goal: goal, today: today),
              if (past.isNotEmpty)
                _PastSection(past: past, goal: goal, today: today),
            ],
          );
        },
      ),
    );
  }

  // Sort by the CURRENT (upcoming) round — so scheduling a later round re-sorts
  // by that round, not the first one. Ended loops fall back to their last round.
  int _byRound(Aim a, Aim b, StudyGoal goal) {
    final da = _sortDate(a, goal);
    final db = _sortDate(b, goal);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  DateTime? _sortDate(Aim a, StudyGoal goal) {
    final cur = a.currentRound(goal.id, goal.deadline)?.date;
    if (cur != null) return cur;
    final dates = a.roundDates(goal.id, goal.deadline);
    return dates.isEmpty
        ? null
        : dates.reduce((x, y) => x.isAfter(y) ? x : y); // latest
  }
}

/// A collapsible section for ended interviews (kept for the record).
class _PastSection extends StatefulWidget {
  const _PastSection(
      {required this.past, required this.goal, required this.today});

  final List<Aim> past;
  final StudyGoal goal;
  final DateTime today;

  @override
  State<_PastSection> createState() => _PastSectionState();
}

class _PastSectionState extends State<_PastSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Dim.space2),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: Dim.brChip,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Dim.space2, vertical: Dim.space2),
            child: Row(
              children: [
                Icon(_open ? Icons.expand_more : Icons.chevron_right,
                    size: Dim.iconMd,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: Dim.space2),
                Text('Past interviews (${widget.past.length})',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        if (_open)
          for (final iv in widget.past)
            InterviewCard(aim: iv, goal: widget.goal, today: widget.today),
      ],
    );
  }
}

/// A one-line explainer: interviews bias study while active.
class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Dim.space2, 0, Dim.space2, Dim.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: Dim.iconSm, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: Dim.space2),
          Expanded(
            child: Text(
              'Tap an interview to log a result, reschedule, or manage it. '
              'Active interviews prioritize your study; swipe to archive.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Dim.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined,
                size: Dim.iconLg, color: theme.colorScheme.primary),
            const SizedBox(height: Dim.space4),
            Text('No interviews planned yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: Dim.space2),
            Text(
              'Plan one and Onyx will prioritize your study for it — and flag '
              'what to prep elsewhere.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
