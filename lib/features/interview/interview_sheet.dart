import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/goal/study_goal.dart';
import '../../core/readiness/target.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/study_goals.dart';
import '../../shared/providers/template.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/card_markdown.dart';
import '../../shared/widgets/grade_buttons.dart';
import '../../shared/widgets/sheet_header.dart';
import 'interview_actions.dart';
import 'round_editing.dart';

/// The single place to act on an interview — opened by tapping any [InterviewCard]
/// anywhere. Shows the round history + current round, and CONTEXTUAL actions:
/// before the round you reschedule; after it you log the result (which advances
/// or ends the loop). Secondary/destructive actions live in the header overflow
/// to keep the body uncluttered. Watches the active goal's interview live.
Future<void> showInterviewSheet(BuildContext context, String aimId) =>
    showOnyxSheet<void>(
      context,
      builder: (_) => _InterviewSheet(aimId: aimId),
    );

class _InterviewSheet extends ConsumerWidget {
  const _InterviewSheet({required this.aimId});

  final String aimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(activeStudyGoalProvider).asData?.value;
    if (goal == null) return const SizedBox.shrink();
    final aim0 = goal.interviews.where((iv) => iv.id == aimId).firstOrNull;
    if (aim0 == null) return const SizedBox.shrink();
    // A migrated interview can have no stored rounds but a synthetic current round
    // seeded from the goal deadline; materialize it so the round transitions
    // (which read stored rounds) act on it instead of silently no-op'ing.
    final eff = aim0.effectiveRounds(goal.id, goal.deadline);
    final aim = aim0.rounds.isEmpty && eff.isNotEmpty
        ? aim0.copyWith(rounds: eff)
        : aim0;

    final theme = Theme.of(context);
    final today =
        ref.watch(clockProvider).asData?.value.today() ?? DateTime.now();
    final refDate = DateTime(today.year, today.month, today.day);
    final notifier = ref.read(studyGoalsProvider.notifier);
    final registry = ref.watch(templateRegistryProvider).asData?.value;
    final target = registry == null
        ? null
        : goal.toTarget(registry.byId(goal.templateId) ?? registry.primary);
    final role = target?.label ?? '';
    final ended = aim.status.isEnded;
    final cur = aim.currentRound(goal.id, goal.deadline);
    // "Occurred" = the round's day has arrived; only then can you log a result.
    final occurred = cur?.date != null && !cur!.date!.isAfter(refDate);

    Future<void> save(InterviewAim a) => notifier.upsertInterview(goal.id, a);

    Future<void> reschedule() async {
      if (cur == null) return;
      final edited = await showRoundDialog(context,
          today: refDate, existing: cur, title: 'Reschedule round');
      if (edited != null) {
        await save(
            rescheduleCurrentRound(aim, date: edited.date, type: edited.type));
      }
    }

    Future<void> passAndNext() async {
      final draft = draftRound(aim, seed: refDate.millisecondsSinceEpoch);
      final next = await showRoundDialog(context,
          today: refDate, existing: draft, title: 'Next round');
      if (next != null) await save(passAndScheduleNext(aim, next));
    }

    Future<void> end(InterviewStatus status) async {
      await save(endInterview(aim, status));
      if (context.mounted) Navigator.pop(context);
    }

    Future<void> confirmDelete() async {
      final ok = await _confirmDelete(context, aim, target);
      if (ok) {
        await notifier.removeInterview(goal.id, aim.id);
        if (context.mounted) Navigator.pop(context);
      }
    }

    final title = aim.companyName.isEmpty
        ? (target?.label ?? 'Interview')
        : aim.companyName;

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
              onArchive: () => save(archiveInterview(aim)),
              onReopen: () => save(reopenInterview(aim)),
              onDelete: confirmDelete,
            ),
          ),
          SheetScrollBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ended) _EndedBanner(status: aim.status),
                _Timeline(aim: aim, goal: goal, today: refDate),
                if (aim.planNotes != null && aim.planNotes!.isNotEmpty) ...[
                  const SizedBox(height: Dim.space3),
                  CardMarkdown(aim.planNotes!, compact: true),
                ],
                const SizedBox(height: Dim.space4),
                if (ended)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => save(reopenInterview(aim)),
                      icon: const Icon(Icons.refresh, size: Dim.iconMd),
                      label: const Text('Reopen — still in progress'),
                    ),
                  )
                else if (occurred) ...[
                  Text('How did it go?',
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: Dim.space2),
                  _OutcomeRow(
                    onPassed: passAndNext,
                    onOffer: () => end(InterviewStatus.offer),
                    onRejected: () => end(InterviewStatus.rejected),
                  ),
                  const SizedBox(height: Dim.space3),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: reschedule,
                      icon: const Icon(Icons.event_repeat, size: Dim.iconMd),
                      label: const Text('It was rescheduled'),
                    ),
                  ),
                ] else if (cur != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: reschedule,
                      icon: const Icon(Icons.event, size: Dim.iconMd),
                      label: Text(cur.date == null
                          ? 'Set the date'
                          : 'Reschedule this round'),
                    ),
                  ),
                if (!ended) ...[
                  const SizedBox(height: Dim.space2),
                  _practiceButton(context, aim, target),
                  const Divider(height: Dim.space6),
                  _StudyToggle(
                    value: aim.active,
                    onChanged: (v) => save(aim.copyWith(active: v)),
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

  Widget _practiceButton(
      BuildContext context, InterviewAim aim, ReadinessTarget? target) {
    final top = _topDomain(aim);
    if (top == null) return const SizedBox.shrink();
    final forLabel = aim.companyName.isEmpty
        ? (target?.label ?? 'interview')
        : aim.companyName;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: () {
          Navigator.pop(context);
          context.push('/practice/$top'
              '?for=${Uri.encodeComponent(forLabel)}');
        },
        icon: const Icon(Icons.psychology_outlined, size: Dim.iconMd),
        label: const Text('Practice for this interview'),
      ),
    );
  }

  String? _topDomain(InterviewAim aim) {
    if (aim.domainWeights.isEmpty) return null;
    final keys = aim.domainWeights.keys.toList()
      ..sort((a, b) => aim.domainWeights[b]!.compareTo(aim.domainWeights[a]!));
    return keys.first;
  }

  Future<bool> _confirmDelete(
      BuildContext context, InterviewAim aim, ReadinessTarget? target) async {
    final title = aim.companyName.isEmpty
        ? (target?.label ?? 'this interview')
        : aim.companyName;
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

/// The three post-round outcomes on one row, colored like the FSRS grade
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
    return GradeButtons(
      verticalPadding: Dim.space3,
      buttons: [
        GradeButton(
            label: 'Passed',
            color: StatusColor.info,
            icon: Icons.arrow_forward,
            onTap: onPassed),
        GradeButton(
            label: 'Offer',
            color: StatusColor.good,
            icon: Icons.celebration_outlined,
            onTap: onOffer),
        GradeButton(
            label: "Didn't pass",
            color: StatusColor.bad,
            icon: Icons.do_not_disturb_alt,
            onTap: onRejected),
      ],
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
      InterviewStatus.offer => (StatusColor.good, Icons.celebration),
      InterviewStatus.rejected => (StatusColor.bad, Icons.do_not_disturb_on),
      _ => (theme.colorScheme.outline, Icons.inventory_2),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Dim.space1),
      padding: const EdgeInsets.symmetric(
          horizontal: Dim.space3, vertical: Dim.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: Dim.fill),
        borderRadius: Dim.brCard,
      ),
      child: Row(
        children: [
          Icon(icon, size: Dim.iconMd, color: color),
          const SizedBox(width: Dim.space2),
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
  const _Timeline({required this.aim, required this.goal, required this.today});

  final InterviewAim aim;
  final StudyGoal goal;
  final DateTime today;

  // Faint primary wash marking the current round's row.
  static const _currentRowFillAlpha = 0.06;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final past = aim.pastRounds(goal.id, goal.deadline);
    final current = aim.currentRound(goal.id, goal.deadline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in past) _row(context, r, current: false),
        if (current != null) _row(context, current, current: true),
        if (past.isEmpty && current == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Dim.space2),
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
      GoalOutcome.passed => (Icons.check_circle, StatusColor.good),
      GoalOutcome.failed => (Icons.cancel, StatusColor.bad),
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
      margin: const EdgeInsets.symmetric(vertical: Dim.space1),
      padding: const EdgeInsets.symmetric(
          horizontal: Dim.space3, vertical: Dim.space2),
      decoration: current
          ? BoxDecoration(
              color: theme.colorScheme.primary
                  .withValues(alpha: _currentRowFillAlpha),
              borderRadius: Dim.brChip,
              border: Border.all(
                  color: theme.colorScheme.primary
                      .withValues(alpha: Dim.emphasisLow)),
            )
          : null,
      child: Row(
        children: [
          Icon(icon, size: Dim.iconSm, color: color),
          const SizedBox(width: Dim.space3),
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
