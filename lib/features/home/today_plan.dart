import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/plan/daily_plan.dart';
import '../../core/plan/practice_plan.dart';
import '../../shared/providers/daily_plan.dart';

/// The day's prioritized study queue (task #57) — one row per track that has work
/// today, in priority order, each sized to its estimated time and tappable into
/// its flow. Replaces the old flat list of flow buttons: the plan decides what's
/// worth doing today and how much, so the user just works top-down.
class TodayPlan extends ConsumerWidget {
  const TodayPlan({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final planAsync = ref.watch(dailyPlanProvider);

    return planAsync.when(
      loading: () => const _TodayFrame(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (e, _) => _TodayFrame(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Text('Couldn’t build today’s plan: $e',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error)),
        ),
      ),
      data: (plan) => _TodayBody(plan: plan),
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.plan});

  final DailyPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCore = plan.tracks.any((t) => t.nonNegotiable);

    return _TodayFrame(
      trailing: plan.isEmpty
          ? null
          : Text('~${plan.plannedMinutes.round()} min',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Text(
                'All caught up for today — nice work. New reviews and '
                'problems will surface as they come due.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (var i = 0; i < plan.tracks.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _TrackRow(track: plan.tracks[i]),
            ],
          if (hasCore) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star_rounded,
                    size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Short on time? The starred rows are the ones to keep.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
          for (final locked in plan.locked) ...[
            const SizedBox(height: 8),
            _LockedRow(track: locked),
          ],
        ],
      ),
    );
  }
}

/// A section frame with a "Today" header (+ optional trailing chip).
class _TodayFrame extends StatelessWidget {
  const _TodayFrame({required this.child, this.trailing});

  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
          child: Row(
            children: [
              Text('Today', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        child,
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track});

  final PlannedTrack track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _trackMeta(track.track);
    final count = track.units.length;

    final subtitle = StringBuffer()
      ..write('$count ${_plural(meta.noun, count)} · '
          '~${track.estMinutes.round()} min');
    if (track.deferred > 0) subtitle.write('  ·  +${track.deferred} later');

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _go(context, meta),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(meta.icon, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(track.track.label,
                            style: theme.textTheme.titleSmall),
                        if (track.nonNegotiable) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded,
                              size: 16, color: theme.colorScheme.primary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, _TrackMeta meta) {
    if (meta.push) {
      context.push(meta.route);
    } else {
      context.go(meta.route);
    }
  }

  String _plural(String noun, int n) =>
      (n == 1 || !_pluralizes.contains(noun)) ? noun : '${noun}s';

  // "due"/"new" are adjectival counts ("5 due"); only real nouns take an -s.
  static const _pluralizes = {'problem', 'mock'};
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.track});

  final TrackAvailability track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.lock_outline,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              track.gateReason ?? '${track.track.label} locked',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackMeta {
  const _TrackMeta(this.icon, this.route, this.noun, {this.push = false});
  final IconData icon;
  final String route;
  final String noun;
  final bool push;
}

_TrackMeta _trackMeta(TrackId t) => switch (t) {
      TrackId.review => const _TrackMeta(Icons.school_outlined, '/quiz', 'due'),
      TrackId.learn =>
        const _TrackMeta(Icons.auto_stories_outlined, '/learn', 'new'),
      TrackId.algorithms => const _TrackMeta(
          Icons.terminal_outlined, '/algorithms', 'problem',
          push: true),
      TrackId.systemDesign => const _TrackMeta(
          Icons.architecture_outlined, '/system-design', 'mock',
          push: true),
    };
