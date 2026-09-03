import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/retention.dart';
import '../../core/readiness/readiness.dart' show prettyDomain;
import '../../shared/providers/analytics.dart';

/// Insights (task #27): how well memory is holding, per domain. Recall (didn't
/// lapse) and average FSRS stability (how durable), from the review log — no AI,
/// no new data captured. A bottom-nav destination, not a Home button.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(retentionByDomainProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (domains) {
          if (domains.isEmpty) return const _Empty();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text('Retention by domain',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                'How well it’s sticking over the last ${retentionWindow.inDays} '
                'days — recall (you didn’t forget) and how durable the memory is.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              for (final d in domains) _DomainRow(d),
            ],
          );
        },
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  const _DomainRow(this.data);
  final DomainRetention data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final recall = data.recall;
    final color =
        recall == null ? cs.onSurfaceVariant : _healthColor(recall, cs);
    final valueLabel = recall == null ? '—' : '${(recall * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(prettyDomain(data.domain),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Bar(fraction: recall, color: color)),
              const SizedBox(width: 12),
              SizedBox(
                width: 42,
                child: Text(valueLabel,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(_subtitle(),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    final s = data.avgStabilityDays;
    if (s != null) parts.add('stability ~${s.round()}d');
    if (data.recall != null) {
      parts.add('${data.reviews} reviews');
    } else if (data.reviews == 0) {
      parts.add('no reviews yet');
    } else {
      parts.add(
          'only ${data.reviews} review${data.reviews == 1 ? '' : 's'} — keep going');
    }
    return parts.join(' · ');
  }

  static Color _healthColor(double recall, ColorScheme cs) {
    if (recall >= 0.85) return const Color(0xFF4CC38A); // green — holding well
    if (recall >= 0.65) return const Color(0xFFE3B341); // amber — shaky
    return cs.error; // red — leaking
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  /// Null renders an empty track (not enough data to draw a rate).
  final double? fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 10,
        color: cs.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        child: fraction == null
            ? null
            : FractionallySizedBox(
                widthFactor: fraction!.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.query_stats_outlined,
                size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 14),
            Text('No retention data yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Review some cards and this will show how well each domain is '
              'sticking — and where your memory is leaking.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
