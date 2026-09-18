import 'package:flutter/material.dart';
import '../../shared/widgets/loading_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/goal/study_goal.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/daily_plan.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/study_goals.dart';
import 'goal_editor_sheet.dart';

/// The "Today's mix" lanes hub (task #30d, G5): one lane per concurrent study
/// goal, showing its share of today's shared budget, readiness, and deadline.
/// Tapping a lane enters that goal (its own Home). Shown only when ≥2 goals live;
/// a single goal renders today's Home directly (the degradation rule).
class LanesHub extends ConsumerWidget {
  const LanesHub({super.key, required this.onEnter});

  /// Called with a goal id when the user taps into a lane.
  final void Function(String goalId) onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(studyGoalsProvider);

    return goalsAsync.when(
      loading: () => const LoadingView(),
      error: (_, __) => const Center(child: Text('—')),
      data: (goals) {
        final live = [
          for (final g in goals)
            if (g.state != GoalState.graduated) g,
        ];
        final active = [
          for (final g in live)
            if (g.isActive) g
        ];
        final paused = [
          for (final g in live)
            if (g.state == GoalState.paused) g,
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text("Today's mix", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Your study goals share the day. Tap one to study it.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final g in active) ...[
              _GoalLane(goal: g, onEnter: onEnter),
              const SizedBox(height: 10),
            ],
            for (final g in paused) ...[
              _PausedRow(goal: g),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New goal'),
              onPressed: () => showGoalEditor(context),
            ),
          ],
        );
      },
    );
  }
}

class _GoalLane extends ConsumerWidget {
  const _GoalLane({required this.goal, required this.onEnter});

  final StudyGoal goal;
  final void Function(String goalId) onEnter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final minutes = ref.watch(goalBudgetsProvider).asData?.value[goal.id];
    final r = ref.watch(goalReadinessProvider(goal.id)).asData?.value;
    final clock = ref.watch(clockProvider).asData?.value;

    final subParts = <String>[
      if (r != null) '${(r.overall * 100).round()}% ready',
      if (goal.deadline case final d? when clock != null)
        _countdown(d, clock.today()),
    ];

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onEnter(goal.id),
        onLongPress: () => showGoalEditor(context, goal: goal),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (subParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subParts.join('  ·  '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              if (minutes != null && minutes >= 1) ...[
                const SizedBox(width: 8),
                Text('~${minutes.round()}m',
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: cs.primary, fontWeight: FontWeight.w700)),
              ],
              IconButton(
                tooltip: 'Pause',
                icon: const Icon(Icons.pause_circle_outline, size: 22),
                color: cs.onSurfaceVariant,
                onPressed: () => ref
                    .read(studyGoalsProvider.notifier)
                    .upsert(goal.copyWith(state: GoalState.paused)),
              ),
              Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PausedRow extends ConsumerWidget {
  const _PausedRow({required this.goal});

  final StudyGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.pause_circle_filled, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${goal.name} · paused',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => ref
                .read(studyGoalsProvider.notifier)
                .upsert(goal.copyWith(state: GoalState.active)),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }
}

String _countdown(DateTime deadline, DateTime today) {
  final days = DateTime(deadline.year, deadline.month, deadline.day)
      .difference(today)
      .inDays;
  if (days < 0) return 'past due';
  if (days == 0) return 'due today';
  return '${days}d left';
}
