import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/readiness.dart';
import '../../shared/providers/readiness.dart';

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
            const SizedBox(height: 8),
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
