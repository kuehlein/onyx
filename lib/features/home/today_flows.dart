import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/plan/daily_plan.dart';
import '../../core/plan/practice_plan.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/providers/daily_plan.dart';
import '../../shared/providers/readiness.dart';

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
        // Nothing required left today → offer the optional extra-practice run
        // (only when the day is clear, so it never competes with the plan).
        if (plan.tracks.isEmpty) ...[
          if (plan.locked.isNotEmpty) const SizedBox(height: Dim.space3),
          const _ExtraPractice(),
        ],
      ],
    );
  }
}

/// The "if you're feeling good, study more" affordance — surfaced only once the
/// day's scheduled flows are cleared. A short, non-grading coach run over the
/// weakest area that never touches the review schedule (so it can't create a
/// backlog). Deliberately optional and clearly framed as extra.
class _ExtraPractice extends ConsumerWidget {
  const _ExtraPractice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final weakest = ref.watch(readinessProvider).asData?.value.weakestDomain;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap:
            weakest == null ? null : () => context.push('/practice/$weakest'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Dim.space4, 14, Dim.space4, 14),
          child: Row(
            children: [
              Icon(Icons.bolt_outlined, size: 22, color: cs.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("You're clear for today",
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      weakest == null
                          ? 'Extra practice unlocks once you have some studied '
                              'material to draw on.'
                          : 'Feeling good? Do an optional coach-led run over your '
                              "weakest area — it won't affect your review schedule.",
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (weakest != null) ...[
                const SizedBox(width: Dim.space2),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
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

    final cs = theme.colorScheme;
    final isPrimary = emphasis == 0;
    // Each button variant paints on a different surface, so the label/icon must
    // use that variant's matching foreground (textTheme styles carry the dark
    // onSurface colour, which is unreadable on the filled primary button).
    final fg = switch (emphasis) {
      0 => cs.onPrimary,
      1 => cs.onSecondaryContainer,
      _ => cs.onSurface,
    };

    final child = Padding(
      padding: EdgeInsets.symmetric(vertical: isPrimary ? 6 : 2),
      child: Row(
        children: [
          Icon(meta.icon, size: 20, color: fg),
          const SizedBox(width: Dim.space3),
          Expanded(
            child: Text(track.track.label,
                style: (isPrimary
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.titleSmall)
                    ?.copyWith(fontWeight: FontWeight.w600, color: fg)),
          ),
          Text(detail.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: fg.withValues(alpha: isPrimary ? 0.9 : 0.7))),
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
      padding: const EdgeInsets.symmetric(horizontal: Dim.space2, vertical: 2),
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
