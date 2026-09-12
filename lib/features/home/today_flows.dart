import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/plan/daily_plan.dart';
import '../../core/plan/practice_plan.dart';
import '../../shared/providers/daily_plan.dart';

/// Today's flows as a priority-ordered action stack (task #57 / Home redesign).
/// The plan decides the order; emphasis follows Material 3's button hierarchy —
/// the top flow is the one obvious next thing to do (filled), the rest step down
/// (tonal → outlined) so the screen never presents four equally-loud choices.
class TodayFlows extends ConsumerWidget {
  const TodayFlows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(dailyPlanProvider).asData?.value;
    if (plan == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < plan.tracks.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _FlowButton(track: plan.tracks[i], emphasis: i),
        ],
        for (final locked in plan.locked) ...[
          const SizedBox(height: 10),
          _LockedRow(track: locked),
        ],
        // Everything scheduled is bigger than what's left in the budget: be
        // explicit rather than looking "all caught up".
        if (plan.tracks.isEmpty && plan.locked.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Nothing scheduled right now — new reviews and problems surface as '
              'they come due.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _FlowButton extends StatelessWidget {
  const _FlowButton({required this.track, required this.emphasis});

  final PlannedTrack track;

  /// 0 = primary (filled), 1 = secondary (tonal), 2+ = tertiary (outlined).
  final int emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _trackMeta(track.track);
    final n = track.units.length;
    final detail = StringBuffer('$n ${_plural(meta.noun, n)} · '
        '~${track.estMinutes.round()}m');
    if (track.deferred > 0) detail.write('  +${track.deferred}');

    final isPrimary = emphasis == 0;
    final onSurfaceForRow = isPrimary
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    final child = Padding(
      padding: EdgeInsets.symmetric(vertical: isPrimary ? 6 : 2),
      child: Row(
        children: [
          Icon(meta.icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(track.track.label,
                style: (isPrimary
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Text(detail.toString(),
              style:
                  theme.textTheme.bodySmall?.copyWith(color: onSurfaceForRow)),
        ],
      ),
    );

    void go() => meta.push ? context.push(meta.route) : context.go(meta.route);

    return switch (emphasis) {
      0 => FilledButton(onPressed: go, child: child),
      1 => FilledButton.tonal(onPressed: go, child: child),
      _ => OutlinedButton(onPressed: go, child: child),
    };
  }

  String _plural(String noun, int n) =>
      (n == 1 || !_pluralizes.contains(noun)) ? noun : '${noun}s';

  static const _pluralizes = {'problem', 'mock'};
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.track});

  final TrackAvailability track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Icon(Icons.lock_outline,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
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
