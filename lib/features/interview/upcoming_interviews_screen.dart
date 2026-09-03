import 'package:flutter/material.dart';
import '../../shared/status_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/readiness/prep_goal.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/widgets/card_markdown.dart';

/// The learner's upcoming interviews — the prep goals, soonest first. Toggle each
/// on/off (active goals bias study via the targeting layer), remove, view its
/// plan, or practice for it. The front door for the interview-targeting feature.
class UpcomingInterviewsScreen extends ConsumerWidget {
  const UpcomingInterviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(prepGoalsProvider);
    final today = ref.watch(clockProvider).asData?.value.today();

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming interviews')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/plan-interview'),
        icon: const Icon(Icons.add),
        label: const Text('Plan an interview'),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) {
          if (goals.isEmpty) return const _Empty();
          final sorted = [...goals]..sort(_byDate);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const _ToggleExplainer(),
              for (final g in sorted) _GoalRow(goal: g, today: today),
            ],
          );
        },
      ),
    );
  }

  // Soonest date first; undated goals last.
  int _byDate(PrepGoal a, PrepGoal b) {
    if (a.date == null && b.date == null) return 0;
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    return a.date!.compareTo(b.date!);
  }
}

class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.goal, required this.today});

  final PrepGoal goal;
  final DateTime? today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final active = goal.active;
    final countdown = _countdown();

    return Opacity(
      opacity: active ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetail(context, ref),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (goal.outcome != GoalOutcome.pending)
                            _OutcomeChip(goal.outcome),
                          Flexible(
                            child: Text(countdown,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: muted)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: active
                      ? 'On — study is prioritized for this interview. '
                          'Turn off to stop biasing toward it.'
                      : 'Off — turn on to prioritize your study for this '
                          'interview.',
                  child: Switch(
                    value: active,
                    onChanged: (v) => ref
                        .read(prepGoalsProvider.notifier)
                        .setActive(goal.id, v),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _countdown() {
    final d = goal.date;
    if (d == null) return 'No date set';
    final label = _fmt(d);
    if (today == null) return label;
    final days = DateTime(d.year, d.month, d.day).difference(today!).inDays;
    if (days < 0) return '$label · past';
    if (days == 0) return '$label · today';
    return '$label · in $days ${days == 1 ? 'day' : 'days'}';
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    final topDomain = _topDomain();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(goal.label,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(_countdown(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (goal.notes != null && goal.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: CardMarkdown(goal.notes!, compact: true),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (topDomain != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/practice/$topDomain'
                            '?for=${Uri.encodeComponent(goal.label)}');
                      },
                      icon: const Icon(Icons.psychology_outlined),
                      label: const Text('Practice for this interview'),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/debrief/${goal.id}');
                    },
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Debrief — how did it go?'),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(prepGoalsProvider.notifier).remove(goal.id);
                    },
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    label: Text('Remove',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The goal's highest-weighted domain (for a quick "practice this" jump).
  String? _topDomain() {
    if (goal.domainWeights.isEmpty) return null;
    final keys = goal.domainWeights.keys.toList()
      ..sort(
          (a, b) => goal.domainWeights[b]!.compareTo(goal.domainWeights[a]!));
    return keys.first;
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

/// A one-line explainer above the list: what the per-interview toggle does. A
/// bare switch is ambiguous, so this makes its effect discoverable without a
/// long-press on the tooltip.
class _ToggleExplainer extends StatelessWidget {
  const _ToggleExplainer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Toggle an interview on to prioritize your study for it — active '
              'ones bias which cards come up. Turn others off to focus.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip(this.outcome);
  final GoalOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = outcome == GoalOutcome.passed;
    final color = passed ? statusGood : theme.colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(passed ? 'Passed' : 'Didn’t pass',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
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
