import 'package:flutter/material.dart';
import '../../shared/status_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/coach/coach_update.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../shared/providers/clock.dart';
import '../../shared/providers/coach_update.dart';
import '../../shared/providers/readiness.dart';
import 'coach_chat_sheet.dart';

/// The numbers that seed the "talk about it" chat.
typedef _ChatSeed = ({
  int overallPct,
  int coveragePct,
  String targetLabel,
  int? days,
});

const _green = statusGood;
const _amber = statusWarn;

/// The ambient coach update on Home: one prioritized, task-level line. Tap to
/// expand the "why now" and take the single suggested action. Renders nothing
/// while loading, on error, or when the coach has nothing worth saying.
class CoachBadge extends ConsumerWidget {
  const CoachBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(coachUpdateProvider).asData?.value;
    if (update == null) return const SizedBox.shrink();

    final seed = _chatSeed(
      ref.watch(readinessProvider).asData?.value,
      ref.watch(readinessTargetControllerProvider).asData?.value,
      ref.watch(clockProvider).asData?.value,
    );

    final theme = Theme.of(context);
    final color = _toneColor(update.tone, theme);
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, update, color, seed),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(_icon(update.kind), size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  update.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  _ChatSeed _chatSeed(Readiness? r, ReadinessTarget? t, Clock? clock) {
    final total = r == null ? 0 : r.domains.fold(0, (a, d) => a + d.total);
    final studied = r == null ? 0 : r.domains.fold(0, (a, d) => a + d.studied);
    int? days;
    final date = t?.interviewDate;
    if (date != null && clock != null) {
      days = DateTime(date.year, date.month, date.day)
          .difference(clock.today())
          .inDays;
      if (days < 0) days = 0;
    }
    return (
      overallPct: r == null ? 0 : (r.overall * 100).round(),
      coveragePct: total == 0 ? 0 : (studied / total * 100).round(),
      targetLabel: t?.label ?? 'your goal',
      days: days,
    );
  }

  void _showDetail(
      BuildContext context, CoachUpdate u, Color color, _ChatSeed seed) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon(u.kind), size: 20, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(u.headline,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(u.why,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface, height: 1.4)),
                const SizedBox(height: 20),
                if (u.hasAction)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push(u.actionRoute!);
                      },
                      child: Text(u.actionLabel!),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      showCoachChatSheet(
                        context,
                        update: u,
                        overallPct: seed.overallPct,
                        coveragePct: seed.coveragePct,
                        targetLabel: seed.targetLabel,
                        daysToInterview: seed.days,
                      );
                    },
                    icon: const Icon(Icons.forum_outlined, size: 18),
                    label: const Text('Talk about it'),
                  ),
                ),
                // The deep dive lives here (progressive disclosure) rather than
                // as its own Home button.
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/report');
                    },
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: const Text('Full readiness report'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _toneColor(CoachTone tone, ThemeData theme) => switch (tone) {
        CoachTone.caution => _amber,
        CoachTone.positive => _green,
        CoachTone.info => theme.colorScheme.primary,
      };

  IconData _icon(CoachInsightKind kind) => switch (kind) {
        CoachInsightKind.gettingStarted => Icons.rocket_launch_outlined,
        CoachInsightKind.overloaded => Icons.warning_amber_rounded,
        CoachInsightKind.behindPace => Icons.schedule,
        CoachInsightKind.building => Icons.trending_up,
        CoachInsightKind.algoDue => Icons.terminal_outlined,
        CoachInsightKind.unproven => Icons.psychology_outlined,
        CoachInsightKind.onTrack => Icons.check_circle_outline,
      };
}
