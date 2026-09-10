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
/// anywhere. Shows the round history + current round, and CONTEXTUAL actions:
/// before the round you reschedule; after it you log the result (which advances
/// or ends the loop). Secondary/destructive actions live in the header overflow
/// to keep the body uncluttered. Watches the goal live.
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
    final ended = goal.status.isEnded;
    final cur = goal.currentRound;
    // "Occurred" = the round's day has arrived; only then can you log a result.
    final occurred = cur?.date != null && !cur!.date!.isAfter(refDate);

    Future<void> save(PrepGoal g) => notifier.upsert(g);

    Future<void> reschedule() async {
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

    Future<void> confirmDelete() async {
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
          SheetHeader(
            title: title,
            subtitle: role,
            trailing: _overflow(
              context,
              ended: ended,
              onReschedule: cur != null ? reschedule : null,
              onArchive: () => save(archiveInterview(goal)),
              onReopen: () => save(reopenInterview(goal)),
              onDelete: confirmDelete,
            ),
          ),
          SheetScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ended) _EndedBanner(status: goal.status),
                _Timeline(goal: goal, today: refDate),
                if (goal.notes != null && goal.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  CardMarkdown(goal.notes!, compact: true),
                ],
                const SizedBox(height: 16),
                if (ended)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => save(reopenInterview(goal)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reopen — still in progress'),
                    ),
                  )
                else if (occurred) ...[
                  Text('How did it go?',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  _OutcomeRow(
                    onPassed: passAndNext,
                    onOffer: () => end(InterviewStatus.offer),
                    onRejected: () => end(InterviewStatus.rejected),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: reschedule,
                      icon: const Icon(Icons.event_repeat, size: 18),
                      label: const Text('It was rescheduled'),
                    ),
                  ),
                ] else if (cur != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: reschedule,
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(cur.date == null
                          ? 'Set the date'
                          : 'Reschedule this round'),
                    ),
                  ),
                if (!ended) ...[
                  const SizedBox(height: 8),
                  _practiceButton(context, goal),
                  const Divider(height: 28),
                  _StudyToggle(
                    value: goal.active,
                    onChanged: (v) => save(goal.copyWith(active: v)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overflow(
    BuildContext context, {
    required bool ended,
    required VoidCallback? onReschedule,
    required VoidCallback onArchive,
    required VoidCallback onReopen,
    required VoidCallback onDelete,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      tooltip: 'More',
      onSelected: (v) {
        switch (v) {
          case 'reschedule':
            onReschedule?.call();
          case 'archive':
            onArchive();
          case 'reopen':
            onReopen();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) => [
        if (!ended && onReschedule != null)
          const PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
        if (!ended)
          const PopupMenuItem(value: 'archive', child: Text('Archive')),
        if (ended) const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Widget _practiceButton(BuildContext context, PrepGoal goal) {
    final top = _topDomain(goal);
    if (top == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: () {
          Navigator.pop(context);
          context.push('/practice/$top'
              '?for=${Uri.encodeComponent(goal.label)}');
        },
        icon: const Icon(Icons.psychology_outlined, size: 18),
        label: const Text('Practice for this interview'),
      ),
    );
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
            'To keep the record, archive it instead.'),
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

/// The three post-round outcomes on one row, coloured like the FSRS grade
/// buttons: blue (advance), green (offer), red (rejected).
class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.onPassed,
    required this.onOffer,
    required this.onRejected,
  });

  final VoidCallback onPassed;
  final VoidCallback onOffer;
  final VoidCallback onRejected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _btn('Passed', statusInfo, Icons.arrow_forward, onPassed)),
        const SizedBox(width: 8),
        Expanded(
            child:
                _btn('Offer', statusGood, Icons.celebration_outlined, onOffer)),
        const SizedBox(width: 8),
        Expanded(
            child: _btn("Didn't pass", statusBad, Icons.do_not_disturb_alt,
                onRejected)),
      ],
    );
  }

  Widget _btn(String label, Color color, IconData icon, VoidCallback onTap) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.16),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// A clean settings-style row for the study-bias toggle (was an awkward
/// mid-body SwitchListTile).
class _StudyToggle extends StatelessWidget {
  const _StudyToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(Icons.tune, color: theme.colorScheme.onSurfaceVariant),
      title: const Text('Prioritize my study for this'),
      subtitle: Text('Biases which cards come up.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      value: value,
      onChanged: onChanged,
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
    if (days < 0) return 'overdue';
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
