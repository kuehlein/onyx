import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/prep_goal.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import 'interview_card.dart';
import 'interview_planner_sheet.dart';

/// The learner's interviews — active loops (soonest round first) with a
/// collapsible "Past" section for ended/archived ones. Every row is the shared
/// [InterviewCard]: tap opens the action sheet, swipe archives (active) or
/// deletes (past). The one place to manage interviews.
class UpcomingInterviewsScreen extends ConsumerWidget {
  const UpcomingInterviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(prepGoalsProvider);
    final today =
        ref.watch(clockProvider).asData?.value.today() ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Interviews')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showInterviewPlannerSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Plan an interview'),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) {
          if (goals.isEmpty) return const _Empty();
          final active = [
            for (final g in goals)
              if (!g.status.isEnded) g,
          ]..sort(_byRound);
          final past = [
            for (final g in goals)
              if (g.status.isEnded) g,
          ]..sort(_byRound);

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              const _Explainer(),
              if (active.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Text('No active interviews — plan one below.'),
                ),
              for (final g in active) InterviewCard(goal: g, today: today),
              if (past.isNotEmpty) _PastSection(past: past, today: today),
            ],
          );
        },
      ),
    );
  }

  // Sort by the CURRENT (upcoming) round — so scheduling a later round re-sorts
  // by that round, not the first one. Ended loops fall back to their last round.
  int _byRound(PrepGoal a, PrepGoal b) {
    final da = _sortDate(a);
    final db = _sortDate(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  DateTime? _sortDate(PrepGoal g) {
    final cur = g.currentRound?.date;
    if (cur != null) return cur;
    final dates = g.roundDates;
    return dates.isEmpty
        ? null
        : dates.reduce((a, b) => a.isAfter(b) ? a : b); // latest
  }
}

/// A collapsible section for ended interviews (kept for the record).
class _PastSection extends StatefulWidget {
  const _PastSection({required this.past, required this.today});

  final List<PrepGoal> past;
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
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Icon(_open ? Icons.expand_more : Icons.chevron_right,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Past interviews (${widget.past.length})',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        if (_open)
          for (final g in widget.past)
            InterviewCard(goal: g, today: widget.today),
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
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined,
                size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text('No interviews planned yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
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
