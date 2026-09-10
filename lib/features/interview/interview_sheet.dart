import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/readiness/prep_goal.dart';
import '../../core/readiness/target.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/status_colors.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/sheet_header.dart';
import 'interview_actions.dart';
import 'round_editing.dart';

/// The single place to act on an interview — opened by tapping any [InterviewCard]
/// anywhere. Shows the round history + the current round, and the lifecycle
/// actions: reschedule, log a result (which advances or ends the loop), withdraw,
/// reopen, or delete. Watches the goal live so it updates as you act.
Future<void> showInterviewSheet(BuildContext context, String goalId) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _InterviewSheet(goalId: goalId),
    );

class _InterviewSheet extends ConsumerWidget {
  const _InterviewSheet({required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(prepGoalsProvider).asData?.value ?? const [];
    final goal = goals.where((g) => g.id == goalId).firstOrNull;
    if (goal == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final today =
        ref.watch(clockProvider).asData?.value.today() ?? DateTime.now();
    final refDate = DateTime(today.year, today.month, today.day);
    final notifier = ref.read(prepGoalsProvider.notifier);
    final role =
        '${goal.level.label} · ${goal.tier.label} · ${goal.track.label}';

    Future<void> save(PrepGoal g) => notifier.upsert(g);

    Future<void> reschedule() async {
      final cur = goal.currentRound;
      if (cur == null) return;
      final edited = await showRoundDialog(context,
          today: refDate, existing: cur, title: 'Reschedule round');
      if (edited != null) {
        await save(
            rescheduleCurrentRound(goal, date: edited.date, type: edited.type));
      }
    }

    Future<void> passAndNext() async {
      final draft = draftRound(goal, seed: refDate.millisecondsSinceEpoch);
      final next = await showRoundDialog(context,
          today: refDate, existing: draft, title: 'Next round');
      if (next != null) await save(passAndScheduleNext(goal, next));
    }

    Future<void> end(InterviewStatus status) async {
      await save(endInterview(goal, status));
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> delete() async {
      final ok = await _confirmDelete(context, goal);
      if (ok) {
        await notifier.remove(goal.id);
        if (context.mounted) Navigator.pop(context);
      }
    }

    final title = goal.companyName.isEmpty ? goal.label : goal.companyName;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetHeader(title: title, subtitle: role),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (goal.status.isEnded) _EndedBanner(status: goal.status),
                  _Timeline(goal: goal, today: refDate),
                  if (goal.notes != null && goal.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    CardMarkdown(goal.notes!, compact: true),
                  ],
                  if (!goal.status.isEnded)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Prioritize my study for this'),
                      subtitle: const Text(
                          'Active interviews bias which cards come up.'),
                      value: goal.active,
                      onChanged: (v) => save(goal.copyWith(active: v)),
                    ),
                  const SizedBox(height: 8),
                  if (!goal.status.isEnded)
                    ..._activeActions(context, ref, goal,
                        reschedule: reschedule,
                        passAndNext: passAndNext,
                        end: end)
                  else
                    ..._endedActions(context, ref, goal, save: save),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: delete,
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                      label: Text('Delete',
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _activeActions(
    BuildContext context,
    WidgetRef ref,
    PrepGoal goal, {
    required Future<void> Function() reschedule,
    required Future<void> Function() passAndNext,
    required Future<void> Function(InterviewStatus) end,
  }) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final topDomain = _topDomain(goal);
    final hasRound = goal.currentRound != null;
    return [
      if (hasRound)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: reschedule,
            icon: const Icon(Icons.event_repeat, size: 18),
            label: const Text('Reschedule this round'),
          ),
        ),
      const SizedBox(height: 16),
      Text('How did it go?',
          style: theme.textTheme.labelLarge?.copyWith(color: muted)),
      const SizedBox(height: 8),
      _ActionButton(
        icon: Icons.arrow_forward,
        label: 'Passed — schedule the next round',
        color: statusGood,
        onPressed: passAndNext,
      ),
      const SizedBox(height: 8),
      _ActionButton(
        icon: Icons.celebration_outlined,
        label: 'Got an offer',
        color: statusGood,
        onPressed: () => end(InterviewStatus.offer),
      ),
      const SizedBox(height: 8),
      _ActionButton(
        icon: Icons.do_not_disturb_alt,
        label: "Didn't pass",
        color: statusBad,
        onPressed: () => end(InterviewStatus.rejected),
      ),
      const SizedBox(height: 16),
      if (topDomain != null)
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/practice/$topDomain'
                  '?for=${Uri.encodeComponent(goal.label)}');
            },
            icon: const Icon(Icons.psychology_outlined, size: 18),
            label: const Text('Practice for this interview'),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => end(InterviewStatus.withdrawn),
          child: Text('Withdraw',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ),
    ];
  }

  List<Widget> _endedActions(
    BuildContext context,
    WidgetRef ref,
    PrepGoal goal, {
    required Future<void> Function(PrepGoal) save,
  }) {
    return [
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => save(reopenInterview(goal)),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reopen — still in progress'),
        ),
      ),
    ];
  }

  String? _topDomain(PrepGoal goal) {
    if (goal.domainWeights.isEmpty) return null;
    final keys = goal.domainWeights.keys.toList()
      ..sort(
          (a, b) => goal.domainWeights[b]!.compareTo(goal.domainWeights[a]!));
    return keys.first;
  }

  Future<bool> _confirmDelete(BuildContext context, PrepGoal goal) async {
    final title = goal.companyName.isEmpty ? goal.label : goal.companyName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete interview?'),
        content: Text('This permanently deletes “$title” and its history. '
            'To keep the record, withdraw or archive instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// A full-width tinted action button used for the "how did it go?" choices.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: color.withValues(alpha: 0.16),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// A short banner naming an ended interview's outcome.
class _EndedBanner extends StatelessWidget {
  const _EndedBanner({required this.status});
  final InterviewStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData icon) = switch (status) {
      InterviewStatus.offer => (statusGood, Icons.celebration),
      InterviewStatus.rejected => (statusBad, Icons.do_not_disturb_on),
      _ => (theme.colorScheme.outline, Icons.inventory_2),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(status.label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// The round pipeline: resolved rounds (with their outcome) then the current
/// upcoming round, highlighted.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.goal, required this.today});

  final PrepGoal goal;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final past = goal.pastRounds;
    final current = goal.currentRound;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in past) _row(context, r, current: false),
        if (current != null) _row(context, current, current: true),
        if (past.isEmpty && current == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No rounds scheduled.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, InterviewRound r, {required bool current}) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final (IconData icon, Color color) = switch (r.outcome) {
      GoalOutcome.passed => (Icons.check_circle, statusGood),
      GoalOutcome.failed => (Icons.cancel, statusBad),
      GoalOutcome.pending => (
          Icons.radio_button_checked,
          theme.colorScheme.primary
        ),
    };
    final d = r.date;
    final when = d == null
        ? 'No date yet'
        : '${_fmtDate(d)}${current ? ' · ${_daysAway(d)}' : ''}';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: current
          ? BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            )
          : null,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              current ? 'Up next · ${r.type.label}' : r.type.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: current ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
          Text(when, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        ],
      ),
    );
  }

  String _daysAway(DateTime d) {
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (days < 0) return 'past';
    if (days == 0) return 'today';
    if (days < 14) return 'in $days days';
    return 'in ${(days / 7).round()} wks';
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
