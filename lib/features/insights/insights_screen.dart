import 'package:flutter/material.dart';
import '../../shared/status_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/retention.dart';
import '../../core/interview/assessment.dart'
    show rubricLabel, sweRubricDimensions;
import '../../core/readiness/readiness.dart' show prettyDomain;
import '../../shared/providers/analytics.dart';

/// Insights (task #27+): how well memory is holding and how mock performance is
/// trending — all from data already logged (no AI, no new capture). A bottom-nav
/// destination, not a Home button.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Show the global empty state only when the two core signals are both empty
    // (a brand-new user); otherwise render every section (each handles its own
    // sparse case) so the page is never a wall of placeholders.
    final retention = ref.watch(retentionByDomainProvider).asData?.value;
    final mocks = ref.watch(mockSkillsProvider).asData?.value;
    final algo = ref.watch(algoStatsProvider).asData?.value;
    final bare = (retention?.isEmpty ?? true) &&
        (mocks?.isEmpty ?? true) &&
        (algo?.isEmpty ?? true);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: bare
          ? const _Empty()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: const [
                _MockSkillsSection(),
                _AlgoSection(),
                _RetentionSection(),
                _DueForecastSection(),
                _StrugglingSection(),
                _ConsistencySection(),
              ],
            ),
    );
  }
}

// ── Section scaffold ────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(text,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }
}

// ── Shared bars ─────────────────────────────────────────────────────────────

/// A labeled metric bar (used for retention domains and mock rubric dimensions).
class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.fraction,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final String label;
  final double? fraction; // null → empty track, "—" value
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Track(fraction: fraction, color: color)),
              const SizedBox(width: 12),
              SizedBox(
                width: 42,
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Text(subtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.fraction, required this.color});
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

/// A compact histogram strip (used for due forecast + study consistency).
class _BarStrip extends StatelessWidget {
  const _BarStrip({required this.values, this.height = 56});
  final List<int> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = values.fold(0, (m, v) => v > m ? v : m);
    final c = cs.primary;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(
                  height: max == 0 ? 2 : 2 + (height - 2) * (v / max),
                  decoration: BoxDecoration(
                    color: v == 0 ? cs.surfaceContainerHighest : c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StripAxis extends StatelessWidget {
  const _StripAxis(this.left, this.right);
  final String left;
  final String right;
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(left, style: s), Text(right, style: s)],
      ),
    );
  }
}

Color _recallColor(double r, ColorScheme cs) =>
    r >= 0.85 ? statusGood : (r >= 0.65 ? statusWarn : cs.error);

Color _dimColor(double v /* 1..5 */, ColorScheme cs) =>
    v >= 4 ? statusGood : (v >= 3 ? statusWarn : cs.error);

// ── 1. Mock-interview skills ────────────────────────────────────────────────

class _MockSkillsSection extends ConsumerWidget {
  const _MockSkillsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(mockSkillsProvider);
    return _Section(
      title: 'Mock-interview skills',
      subtitle: 'How you perform under pressure — not just what you recall.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (m) {
          if (m.isEmpty) {
            return const _NoData(
                'No mock interviews yet — run one to see your rubric.');
          }
          final keys = [
            for (final k in sweRubricDimensions)
              if (m.dims.containsKey(k)) k,
            for (final k in m.dims.keys)
              if (!sweRubricDimensions.contains(k)) k,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.count} mock${m.count == 1 ? '' : 's'} · avg score '
                '${m.avgScore.round()} · hints ~${m.avgHintLevel.toStringAsFixed(1)}/5 '
                '· ${(m.novelFraction * 100).round()}% novel',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              for (final k in keys)
                _StatBar(
                  label: rubricLabel(k),
                  fraction: m.dims[k]! / 5,
                  value: m.dims[k]!.toStringAsFixed(1),
                  color: _dimColor(m.dims[k]!, theme.colorScheme),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 1b. Algorithm practice ──────────────────────────────────────────────────

class _AlgoSection extends ConsumerWidget {
  const _AlgoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(algoStatsProvider);
    return _Section(
      title: 'Algorithm practice',
      subtitle: 'Solving problems cold — the execution clock. Counts toward '
          'readiness alongside recall.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (a) {
          if (a.isEmpty) {
            return const _NoData(
                'No problems logged yet — work the Algorithms track.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${a.distinctProblems} problem${a.distinctProblems == 1 ? '' : 's'} '
                'across ${a.patterns} pattern${a.patterns == 1 ? '' : 's'} · '
                '${a.logged} solve${a.logged == 1 ? '' : 's'} logged · '
                '${a.last7} this week',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              _StatBar(
                label: 'Clean-solve rate',
                fraction: a.cleanRate,
                value: '${(a.cleanRate * 100).round()}%',
                color: _recallColor(a.cleanRate, theme.colorScheme),
                subtitle: 'Solved without a hint or a struggle.',
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── 2. Retention by domain ──────────────────────────────────────────────────

class _RetentionSection extends ConsumerWidget {
  const _RetentionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(retentionByDomainProvider);
    return _Section(
      title: 'Retention by domain',
      subtitle: 'Recall (you didn’t forget) and how durable it is, '
          'last ${retentionWindow.inDays} days.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (domains) {
          if (domains.isEmpty) {
            return const _NoData('Review some cards to see this.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final d in domains) _domainBar(context, d)],
          );
        },
      ),
    );
  }

  Widget _domainBar(BuildContext context, DomainRetention d) {
    final cs = Theme.of(context).colorScheme;
    final recall = d.recall;
    final parts = <String>[
      if (d.avgStabilityDays != null)
        'stability ~${d.avgStabilityDays!.round()}d',
      if (recall != null)
        '${d.reviews} reviews'
      else if (d.reviews == 0)
        'no reviews yet'
      else
        'only ${d.reviews} review${d.reviews == 1 ? '' : 's'} — keep going',
    ];
    return _StatBar(
      label: prettyDomain(d.domain),
      fraction: recall,
      value: recall == null ? '—' : '${(recall * 100).round()}%',
      color: recall == null ? cs.onSurfaceVariant : _recallColor(recall, cs),
      subtitle: parts.join(' · '),
    );
  }
}

// ── 3. Upcoming review load ─────────────────────────────────────────────────

class _DueForecastSection extends ConsumerWidget {
  const _DueForecastSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dueForecastProvider);
    return _Section(
      title: 'Upcoming review load',
      subtitle: 'Cards coming due over the next 2 weeks — spot a crunch early.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (counts) {
          final total = counts.fold(0, (a, b) => a + b);
          if (total == 0) {
            return const _NoData('Nothing due in the next 2 weeks.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BarStrip(values: counts),
              const _StripAxis('Due now', '+2 weeks'),
              const SizedBox(height: 6),
              Text('${counts.first} due now · $total over the next 2 weeks',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          );
        },
      ),
    );
  }
}

// ── 4. Struggling cards ─────────────────────────────────────────────────────

class _StrugglingSection extends ConsumerWidget {
  const _StrugglingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(strugglingCardsProvider);
    return _Section(
      title: 'Struggling cards',
      subtitle: 'Where you keep pressing “Again” — worth reformulating or '
          'splitting.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (cards) {
          if (cards.isEmpty) {
            return const _NoData('No repeat lapses — nothing to fix.');
          }
          return Column(
            children: [
              for (final c in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(c.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Text('${c.lapses} lapses / ${c.reviews}',
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 5. Study consistency ────────────────────────────────────────────────────

class _ConsistencySection extends ConsumerWidget {
  const _ConsistencySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(studyConsistencyProvider);
    return _Section(
      title: 'Study consistency',
      subtitle: 'Study actions per day, last 4 weeks. Showing up beats '
          'cramming.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (counts) {
          final activeDays = counts.where((c) => c > 0).length;
          if (activeDays == 0) return const _NoData('No study logged yet.');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BarStrip(values: counts, height: 48),
              const _StripAxis('4 weeks ago', 'Today'),
              const SizedBox(height: 6),
              Text('Studied $activeDays of the last ${counts.length} days',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          );
        },
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
            Text('No insights yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              'Review some cards and run a mock or two — this fills in with how '
              'well it’s sticking, where you’re leaking, and how you perform.',
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
