import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/ladder.dart';
import '../../core/readiness/pace.dart';
import '../../core/readiness/readiness.dart';
import '../../shared/providers/readiness.dart';
import 'target_sheet.dart';

/// Home dashboard panel: honest **knowledge-base readiness** (Phase A) —
/// per-domain recall strength × coverage, weakest domain flagged "focus here",
/// reported as a band, with an explicit "this is recall, not interview
/// readiness" caveat.
class ReadinessPanel extends ConsumerWidget {
  const ReadinessPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ref.watch(readinessProvider).asData?.value;
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final target = ref.watch(readinessTargetControllerProvider).asData?.value;
    final pace = ref.watch(readinessPaceProvider).asData?.value;
    final ladder = ref.watch(readinessLadderPositionProvider).asData?.value;
    final anyStudied = r.domains.any((d) => d.studied > 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Knowledge-base readiness',
                    style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'How well your studied material is retained — recall, not '
            'problem-solving.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _TargetRow(label: target?.label ?? '—'),
          if (pace != null) ...[
            const SizedBox(height: 10),
            _PaceRow(pace),
          ],
          const SizedBox(height: 14),
          if (!anyStudied)
            Text('Study some cards and this fills in.',
                style: theme.textTheme.bodyMedium)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${(r.overall * 100).round()}%',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${(r.low * 100).round()}–${(r.high * 100).round()}% range',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (ladder != null)
              _LadderGauge(ladder)
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: r.overall,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            const SizedBox(height: 16),
            for (final d in r.domains)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DomainRow(d, focus: identical(d, r.domains.first)),
              ),
            const SizedBox(height: 4),
            Text(
              'Recall only — solve novel problems and mock interviews to gauge '
              'true interview readiness.',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

/// The tappable "aiming at `target`" row that opens the target sheet.
class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showTargetSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(Icons.flag_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Aiming at',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The coverage-pace line toward the interview date. Copy is scoped to
/// *coverage* ("cover your material"), never "interview-ready" — Phase A can't
/// measure the latter.
class _PaceRow extends StatelessWidget {
  const _PaceRow(this.pace);

  final PaceEstimate pace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, text) = _describe();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurface)),
        ),
      ],
    );
  }

  (IconData, Color, String) _describe() {
    final days = pace.daysLeft;
    final inDays =
        days == 0 ? 'today' : 'in $days ${days == 1 ? 'day' : 'days'}';
    const green = Color(0xFF4CC38A);
    const amber = Color(0xFFE3B341);
    const red = Color(0xFFF07178);
    switch (pace.status) {
      case PaceStatus.coverageComplete:
        return (
          Icons.check_circle_outline,
          green,
          'All in-scope material started — $inDays to deepen recall.'
        );
      case PaceStatus.onTrack:
        return (
          Icons.trending_up,
          green,
          'On track — interview $inDays, at ~${_rate(pace.recentPerDay)}/day.'
        );
      case PaceStatus.slightlyBehind:
        return (
          Icons.schedule,
          amber,
          'Slightly behind — ~${_rate(pace.requiredPerDay)}/day to cover it '
              'all $inDays (you\'re at ~${_rate(pace.recentPerDay)}/day).'
        );
      case PaceStatus.behind:
        return (
          Icons.warning_amber_outlined,
          red,
          'Behind — need ~${_rate(pace.requiredPerDay)}/day to cover it all '
              '$inDays (you\'re at ~${_rate(pace.recentPerDay)}/day).'
        );
      case PaceStatus.notStarted:
        return (
          Icons.flag_outlined,
          amber,
          'Interview $inDays — ~${_rate(pace.requiredPerDay)}/day to cover '
              'your material.'
        );
    }
  }

  String _rate(double v) {
    if (v >= 10) return v.round().toString();
    final s = v.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }
}

/// A horizontal gauge spanning New-grad→Staff with two pins: a filled "you"
/// marker at the current inferred rung and a flag at the goal rung. Lets the
/// user recalibrate — aim high, but see where they actually stand today.
class _LadderGauge extends StatelessWidget {
  const _LadderGauge(this.pos);

  final LadderPosition pos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalLabel = readinessLadder[pos.goalIndex].label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final youX = (pos.youFraction * w).clamp(7.0, w - 7.0);
            final goalX = (pos.goalFraction * w).clamp(6.0, w - 6.0);
            return SizedBox(
              height: 34,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 6,
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  // Filled up to the current position.
                  Positioned(
                    left: 0,
                    top: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 6,
                        width: youX,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  // Goal: a flag above a tick line.
                  Positioned(
                    left: goalX - 6,
                    top: 0,
                    child: Icon(Icons.flag,
                        size: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  Positioned(
                    left: goalX - 1,
                    top: 14,
                    child: Container(
                        width: 2,
                        height: 16,
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  // You: a filled circle with a ring, on the track.
                  Positioned(
                    left: youX - 7,
                    top: 16,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.colorScheme.surfaceContainerHigh,
                            width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('New-grad',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            Text('Staff',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        Text(_summary(goalLabel),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface)),
      ],
    );
  }

  String _summary(String goalLabel) {
    if (pos.clearedCount == 0) {
      return 'Building your foundation — not yet clearing '
          '${readinessLadder.first.label} (recall).';
    }
    if (pos.atOrAboveGoal) {
      return 'Your knowledge base is at or above your $goalLabel goal '
          '(recall) — validate it with mock interviews.';
    }
    final n = pos.rungsToGo;
    return 'Your knowledge base is around ${pos.currentLabel} — '
        '$n ${n == 1 ? 'rung' : 'rungs'} below your $goalLabel goal.';
  }
}

class _DomainRow extends StatelessWidget {
  const _DomainRow(this.d, {required this.focus});

  final DomainReadiness d;
  final bool focus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(d);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_pretty(d.domain),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (focus) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text('Focus here',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 8),
            ],
            Text(d.studied == 0 ? d.label : '${(d.score * 100).round()}%',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: d.score,
            minHeight: 6,
            color: color,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 2),
        Text('${d.studied}/${d.total} started · ${d.label}',
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Color _color(DomainReadiness d) {
    if (d.studied == 0) return const Color(0xFF8A8F98); // muted grey
    if (d.score >= 0.75) return const Color(0xFF4CC38A); // green
    if (d.score >= 0.45) return const Color(0xFFE3B341); // amber
    return const Color(0xFFF07178); // red
  }

  String _pretty(String domain) {
    switch (domain) {
      case 'ds-a':
        return 'DS & A';
      case 'system-design':
        return 'System design';
    }
    return domain
        .split(RegExp(r'[-_]'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
