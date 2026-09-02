import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/coach/coach_update.dart';
import '../../shared/providers/coach_update.dart';

const _green = Color(0xFF4CC38A);
const _amber = Color(0xFFE3B341);

/// The ambient coach update on Home: one prioritised, task-level line. Tap to
/// expand the "why now" and take the single suggested action. Renders nothing
/// while loading, on error, or when the coach has nothing worth saying.
class CoachBadge extends ConsumerWidget {
  const CoachBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(coachUpdateProvider).asData?.value;
    if (update == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = _toneColor(update.tone, theme);
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context, update, color),
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

  void _showDetail(BuildContext context, CoachUpdate u, Color color) {
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
        CoachInsightKind.unproven => Icons.psychology_outlined,
        CoachInsightKind.onTrack => Icons.check_circle_outline,
      };
}
