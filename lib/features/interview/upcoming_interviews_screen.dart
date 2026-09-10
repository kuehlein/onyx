import 'package:flutter/material.dart';
import '../../shared/status_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/readiness/prep_goal.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/sheet_header.dart';
import 'round_editing.dart';

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

  // Soonest upcoming round first; undated goals last.
  int _byDate(PrepGoal a, PrepGoal b) {
    final da = a.nextRoundDate();
    final db = b.nextRoundDate();
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
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
    final rounds = goal.effectiveRounds;
    final next = goal.nextRoundDate(today);
    if (next == null) return 'No date set';
    // Name the upcoming round when it's part of a multi-round loop.
    final upcoming = rounds.firstWhere(
      (r) =>
          r.date != null &&
          DateTime(r.date!.year, r.date!.month, r.date!.day) == next,
      orElse: () => rounds.first,
    );
    final prefix = rounds.length > 1 ? '${upcoming.type.label} · ' : '';
    final label = '$prefix${_fmt(next)}';
    if (today == null) return label;
    final days = next.difference(today!).inDays;
    if (days < 0) return '$label · past';
    if (days == 0) return '$label · today';
    return '$label · in $days ${days == 1 ? 'day' : 'days'}';
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _InterviewDetailSheet(goalId: goal.id),
    );
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

/// The interview detail sheet — the full round-by-round management surface (the
/// target-sheet list stays compact and shows only the next round). Watches the
/// goal live so round edits reflect at once. Add/edit/remove rounds, practice,
/// debrief, or remove the whole interview.
class _InterviewDetailSheet extends ConsumerWidget {
  const _InterviewDetailSheet({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final goals = ref.watch(prepGoalsProvider).asData?.value ?? const [];
    final goal = goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null) return const SizedBox.shrink();
    final today = ref.watch(clockProvider).asData?.value.today();
    final rounds = goal.effectiveRounds;
    final notifier = ref.read(prepGoalsProvider.notifier);
    final refDate = today ?? DateTime.now();

    Future<void> addRound() async {
      final added = await showRoundDialog(context,
          today: refDate, existing: draftRound(goal, seed: _seed()));
      if (added != null) await notifier.upsert(goalWithRound(goal, added));
    }

    Future<void> editRound(InterviewRound r) async {
      final edited =
          await showRoundDialog(context, today: refDate, existing: r);
      if (edited != null) await notifier.upsert(goalWithRound(goal, edited));
    }

    Future<void> removeRound(InterviewRound r) async {
      final updated = goalWithoutRound(goal, r.id);
      if (updated == null) {
        await notifier.remove(goal.id);
        if (context.mounted) Navigator.pop(context);
      } else {
        await notifier.upsert(updated);
      }
    }

    final topDomain = _topDomain(goal);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(title: goal.label),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (goal.notes != null && goal.notes!.isNotEmpty) ...[
                  Flexible(
                    child: SingleChildScrollView(
                      child: CardMarkdown(goal.notes!, compact: true),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // A rule sets the rounds list apart from the plan/notes above.
                const Divider(height: 8),
                Row(
                  children: [
                    Text('Rounds',
                        style:
                            theme.textTheme.labelLarge?.copyWith(color: muted)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: addRound,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add round'),
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ],
                ),
                for (final r in rounds)
                  _RoundTile(
                    round: r,
                    today: today,
                    onEdit: () => editRound(r),
                    onRemove: () => removeRound(r),
                  ),
                const SizedBox(height: 16),
                if (topDomain != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
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
                      Navigator.pop(context);
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
                    onPressed: () async {
                      final ok = await _confirmRemove(context, goal);
                      if (ok) {
                        await notifier.remove(goal.id);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    label: Text('Remove interview',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The goal's highest-weighted domain (for a quick "practice this" jump).
  String? _topDomain(PrepGoal goal) {
    if (goal.domainWeights.isEmpty) return null;
    final keys = goal.domainWeights.keys.toList()
      ..sort(
          (a, b) => goal.domainWeights[b]!.compareTo(goal.domainWeights[a]!));
    return keys.first;
  }

  int _seed() => DateTime.now().microsecondsSinceEpoch;

  Future<bool> _confirmRemove(BuildContext context, PrepGoal goal) async {
    final title = goal.companyName.isEmpty ? goal.label : goal.companyName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove interview?'),
        content: Text('This deletes “$title” and its rounds.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// One round in the detail sheet: outcome dot + label + date, with an
/// edit/remove menu.
class _RoundTile extends StatelessWidget {
  const _RoundTile({
    required this.round,
    required this.today,
    required this.onEdit,
    required this.onRemove,
  });

  final InterviewRound round;
  final DateTime? today;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final d = round.date;
    final sub = d == null ? 'No date yet' : '${_fmt(d)}${_daysAway(d)}';
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _outcomeDot(context, round.outcome),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(round.label, style: theme.textTheme.bodyMedium),
                  Text(sub,
                      style:
                          theme.textTheme.labelSmall?.copyWith(color: muted)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              tooltip: 'Round options',
              onSelected: (v) => v == 'edit' ? onEdit() : onRemove(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'remove', child: Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _outcomeDot(BuildContext context, GoalOutcome o) {
    final (IconData icon, Color color) = switch (o) {
      GoalOutcome.passed => (Icons.check_circle, statusGood),
      GoalOutcome.failed => (Icons.cancel, Theme.of(context).colorScheme.error),
      GoalOutcome.pending => (
          Icons.radio_button_unchecked,
          Theme.of(context).colorScheme.primary
        ),
    };
    return Icon(icon, size: 16, color: color);
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _daysAway(DateTime d) {
    if (today == null) return '';
    final days = DateTime(d.year, d.month, d.day).difference(today!).inDays;
    if (days < 0) return ' · past';
    if (days == 0) return ' · today';
    if (days < 14) return ' · in $days days';
    return ' · in ${(days / 7).round()} wks';
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
