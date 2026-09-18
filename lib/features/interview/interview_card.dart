import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/prep_goal.dart';
import '../../core/readiness/projection.dart';
import '../../core/readiness/target.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/design/status_color.dart';
import 'interview_actions.dart';
import 'interview_sheet.dart';

/// The one interview row used everywhere (target sheet + upcoming list) so the
/// behavior is identical: tap opens the [InterviewSheet]; swipe archives (undo)
/// an active loop or deletes (confirm) an ended one. Shows the current round +
/// a pace status judged against the interview's OWN role.
class InterviewCard extends ConsumerWidget {
  const InterviewCard({super.key, required this.goal, required this.today});

  final PrepGoal goal;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ended = goal.status.isEnded;

    final row = InkWell(
      onTap: () => showInterviewSheet(context, goal.id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            _leadingIcon(theme, ended),
            const SizedBox(width: 10),
            Expanded(child: _titleBlock(context, ref, ended)),
            const SizedBox(width: 8),
            _trailing(context, ref, ended),
          ],
        ),
      ),
    );

    // Swipe: archive an active loop (reversible, no confirm needed); delete an
    // already-ended one (permanent, so confirm first).
    return Dismissible(
      key: ValueKey('interview-${goal.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        if (ended) return _confirmDelete(context);
        await _archive(context, ref);
        return false; // handled with undo; don't remove from the tree ourselves
      },
      onDismissed: (_) => ref.read(prepGoalsProvider.notifier).remove(goal.id),
      background: _swipeBg(theme, ended),
      child: row,
    );
  }

  Widget _leadingIcon(ThemeData theme, bool ended) {
    final (IconData icon, Color color) = switch (goal.status) {
      InterviewStatus.active => (Icons.flag, theme.colorScheme.primary),
      InterviewStatus.offer => (Icons.celebration, StatusColor.good),
      InterviewStatus.rejected => (Icons.do_not_disturb_on, StatusColor.bad),
      InterviewStatus.withdrawn => (Icons.logout, theme.colorScheme.outline),
      InterviewStatus.archived => (
          Icons.inventory_2,
          theme.colorScheme.outline
        ),
    };
    return Icon(icon, size: 16, color: color);
  }

  Widget _titleBlock(BuildContext context, WidgetRef ref, bool ended) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final title = goal.companyName.isEmpty ? goal.label : goal.companyName;
    final sub = _subtitle(ended);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (sub != null)
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: muted)),
      ],
    );
  }

  String? _subtitle(bool ended) {
    if (ended) return goal.status.label;
    final cur = goal.currentRound;
    if (cur == null) return 'No upcoming round';
    final n = goal.effectiveRounds.length;
    final roundNote = n > 1 ? '  ·  round $n' : '';
    final d = cur.date;
    if (d == null) return '${cur.type.label} · no date yet$roundNote';
    return '${cur.type.label} · ${_fmtDate(d)} · ${_daysAway(d)}$roundNote';
  }

  Widget _trailing(BuildContext context, WidgetRef ref, bool ended) {
    if (ended) {
      return Text(goal.status.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    final cur = goal.currentRound;
    if (cur?.date == null) return const SizedBox.shrink();
    final forecast = ref
        .watch(readinessForecastForProvider((
          level: goal.level,
          company: goal.tier,
          track: goal.track,
        )))
        .asData
        ?.value;
    return _paceChip(context, forecast, cur!.date!);
  }

  Widget _paceChip(BuildContext context, ReadinessForecast? f, DateTime d) {
    if (f == null) return const SizedBox.shrink();
    final days = DateTime(d.year, d.month, d.day).difference(today).inDays;
    final (String text, Color color) = f.alreadyReady
        ? ('ready', StatusColor.good)
        : switch (f.requiredPerDayFor(days)) {
            null => ('too soon', StatusColor.bad),
            final req when req <= f.currentPerDay => (
                'on track',
                StatusColor.good
              ),
            final req => ('~$req/day', StatusColor.warn),
          };
    final role =
        '${goal.level.label} · ${goal.tier.label} · ${goal.track.label}';
    return Tooltip(
      message: 'Judged for $role',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _swipeBg(ThemeData theme, bool ended) {
    // Archive is not destructive → a calm neutral tone (the harsh red was only
    // ever right for a real delete).
    final (Color bg, Color fg, IconData icon) = ended
        ? (
            theme.colorScheme.errorContainer,
            theme.colorScheme.onErrorContainer,
            Icons.delete_outline
          )
        : (
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.onSurfaceVariant,
            Icons.inventory_2_outlined
          );
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: fg),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final before = goal;
    await ref.read(prepGoalsProvider.notifier).upsert(archiveInterview(goal));
    messenger.showSnackBar(SnackBar(
      content: Text(
          'Archived ${goal.companyName.isEmpty ? "interview" : goal.companyName}'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => ref.read(prepGoalsProvider.notifier).upsert(before),
      ),
    ));
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final title = goal.companyName.isEmpty ? goal.label : goal.companyName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete interview?'),
        content: Text('This permanently deletes “$title” and its history.'),
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
