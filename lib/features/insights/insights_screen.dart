import 'package:flutter/material.dart';
import '../../shared/design/status_color.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/insights.dart' show MockSkills, PatternMastery;
import '../../core/analytics/retention.dart';
import '../../core/interview/assessment.dart'
    show
        behavioralRubricDimensions,
        rubricLabel,
        sweRubricDimensions,
        systemDesignRubricDimensions;
import '../../core/readiness/readiness.dart' show prettyDomain;
import '../../shared/providers/algo.dart';
import '../../shared/providers/analytics.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/study_goals.dart';
import '../../shared/widgets/empty_state.dart';
import '../home/readiness_panel.dart';

/// Insights (task #27+, redesigned #62): the "details" tier of the app's
/// progress story — how ready you are, how well memory is holding, how you
/// perform under pressure, and whether you're showing up. All from data already
/// logged (no AI, no new capture). A bottom-nav destination, not a Home button.
///
/// Structure follows the dataviz research (see the dataviz-principles memory):
/// a critical-few SUMMARY strip up top, then progressive-disclosure GROUPS
/// (Readiness → Memory & recall → Applied performance → Habits) that expand to
/// the detailed bars. Comparison/trend is shown with bars, never rings; tone is
/// non-judgmental ("focus areas", not "failures").
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key, this.focus});

  /// Optional group to reveal on open (`readiness` / `memory` / `applied` /
  /// `habits`), set by a Home metric deep-linking to its explanation here.
  final String? focus;

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  // One key per group so a tapped KPI (or a Home deep-link) can expand it and
  // scroll it into view.
  final _readinessKey = GlobalKey<_GroupState>();
  final _memoryKey = GlobalKey<_GroupState>();
  final _appliedKey = GlobalKey<_GroupState>();
  final _habitsKey = GlobalKey<_GroupState>();

  /// A pending deep-link focus, applied once the groups actually exist (data may
  /// still be loading on the first build, so they aren't built yet then).
  String? _pendingFocus;

  @override
  void initState() {
    super.initState();
    _pendingFocus = widget.focus;
  }

  @override
  void didUpdateWidget(InsightsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-focus when navigated here again with a different target (the tab's
    // state is kept alive by the indexed-stack shell).
    if (widget.focus != null && widget.focus != oldWidget.focus) {
      _pendingFocus = widget.focus;
    }
  }

  GlobalKey<_GroupState>? _keyFor(String? focus) => switch (focus) {
        'readiness' => _readinessKey,
        'memory' => _memoryKey,
        'applied' => _appliedKey,
        'habits' => _habitsKey,
        _ => null,
      };

  /// Expand a group and scroll it into view (after the expansion lays out).
  void _reveal(GlobalKey<_GroupState> key) {
    key.currentState?.expand();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300),
            alignment: 0.02,
            curve: Curves.easeInOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show the global empty state only when every core signal is empty (a
    // brand-new user); otherwise render the groups (each handles its own sparse
    // case, and non-lead groups are collapsed) so the page is never a wall.
    final readiness = ref.watch(readinessProvider).asData?.value;
    final retention = ref.watch(retentionByDomainProvider).asData?.value;
    final mocks = ref.watch(mockSkillsProvider).asData?.value;
    final sd = ref.watch(systemDesignSkillsProvider).asData?.value;
    final behavioral = ref.watch(behavioralSkillsProvider).asData?.value;
    final algo = ref.watch(algoStatsProvider).asData?.value;
    final consistency = ref.watch(studyConsistencyProvider).asData?.value;

    final bare = (readiness?.isEmpty ?? true) &&
        (retention?.isEmpty ?? true) &&
        (mocks?.isEmpty ?? true) &&
        (sd?.isEmpty ?? true) &&
        (behavioral?.isEmpty ?? true) &&
        (algo?.isEmpty ?? true);

    if (bare) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insights')),
        body: const _Empty(),
      );
    }

    // Aggregates for the summary strip + group headers.
    final anyStudied = readiness != null && !readiness.isEmpty;
    final recall = _recallAgg(retention);
    final mockAgg = _mockAgg([mocks, sd, behavioral]);
    final active7 = _active7(consistency);

    // Apply a deep-link focus once the groups are built (only reached when not
    // bare, i.e. the groups below exist to be revealed).
    if (_pendingFocus != null) {
      final key = _keyFor(_pendingFocus);
      _pendingFocus = null;
      if (key != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(key));
      }
    }

    final cs = _cs(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _SummaryStrip(kpis: [
            if (anyStudied)
              _Kpi(
                value: '${(readiness.overall * 100).round()}%',
                label: 'Readiness',
                color: _readinessColor(readiness.overall, cs),
                onTap: () => _reveal(_readinessKey),
              ),
            if (recall != null)
              _Kpi(
                value: '${(recall * 100).round()}%',
                label: 'Recall',
                color: _recallColor(recall, cs),
                onTap: () => _reveal(_memoryKey),
              ),
            if (mockAgg.count > 0)
              _Kpi(
                value: '${mockAgg.avg.round()}',
                label: 'Mock avg',
                color: _dimColor(mockAgg.avg / 20, cs),
                onTap: () => _reveal(_appliedKey),
              ),
            if (active7 > 0)
              _Kpi(
                value: '$active7/7',
                label: 'This week',
                color: cs.primary,
                onTap: () => _reveal(_habitsKey),
              ),
          ]),
          const SizedBox(height: 22),
          // Lead group, expanded: the full readiness breakdown (reuses the rich
          // panel that Home dropped in its ring-hero redesign), plus a link out
          // to the heavier AI narrative report.
          _Group(
            key: _readinessKey,
            title: 'Readiness',
            icon: Icons.insights_outlined,
            summary: anyStudied
                ? '${(readiness.overall * 100).round()}% toward target'
                : 'Not started',
            initiallyExpanded: true,
            children: [
              const ReadinessPanel(),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/report'),
                  icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                  label: const Text('Full AI readiness report'),
                ),
              ),
            ],
          ),
          _Group(
            key: _memoryKey,
            title: 'Memory & recall',
            icon: Icons.psychology_outlined,
            summary: recall == null
                ? 'No reviews yet'
                : '${(recall * 100).round()}% recall, last '
                    '${retentionWindow.inDays}d',
            children: const [
              _RetentionSection(),
              _DueForecastSection(),
              _StrugglingSection(),
            ],
          ),
          _Group(
            key: _appliedKey,
            title: 'Applied performance',
            icon: Icons.speed_outlined,
            summary: mockAgg.count > 0
                ? '${mockAgg.count} mock${mockAgg.count == 1 ? '' : 's'} · avg '
                    '${mockAgg.avg.round()}'
                : (algo != null && !algo.isEmpty
                    ? '${(algo.cleanRate * 100).round()}% clean solves'
                    : 'Not started'),
            children: const [
              _MockSkillsSection(),
              _SystemDesignSection(),
              _BehavioralSection(),
              _AlgoSection(),
              _PatternsSection(),
            ],
          ),
          _Group(
            key: _habitsKey,
            title: 'Habits',
            icon: Icons.calendar_month_outlined,
            summary:
                active7 > 0 ? '$active7 of the last 7 days' : 'No study yet',
            children: const [_ConsistencySection()],
          ),
        ],
      ),
    );
  }
}

ColorScheme _cs(BuildContext context) => Theme.of(context).colorScheme;

/// Reviews-weighted mean recall across domains (0..1), or null if no reviews.
double? _recallAgg(List<DomainRetention>? domains) {
  if (domains == null) return null;
  var reviews = 0;
  var acc = 0.0;
  for (final d in domains) {
    final r = d.recall;
    if (r != null) {
      reviews += d.reviews;
      acc += r * d.reviews;
    }
  }
  return reviews == 0 ? null : acc / reviews;
}

/// Combined mock count + count-weighted average score across the mock tracks.
({int count, double avg}) _mockAgg(List<MockSkills?> tracks) {
  var count = 0;
  var sum = 0.0;
  for (final m in tracks) {
    if (m != null && m.count > 0) {
      count += m.count;
      sum += m.avgScore * m.count;
    }
  }
  return (count: count, avg: count == 0 ? 0 : sum / count);
}

/// Active days in the last 7 of the consistency series.
int _active7(List<int>? consistency) {
  if (consistency == null || consistency.isEmpty) return 0;
  final last7 = consistency.length <= 7
      ? consistency
      : consistency.sublist(consistency.length - 7);
  return last7.where((c) => c > 0).length;
}

Color _readinessColor(double v, ColorScheme cs) =>
    v >= 0.75 ? StatusColor.good : (v >= 0.45 ? StatusColor.warn : cs.error);

// ── Summary strip ───────────────────────────────────────────────────────────

class _Kpi {
  const _Kpi({
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });
  final String value;
  final String label;
  final Color color;

  /// Tap to reveal (expand + scroll to) the group this KPI summarizes.
  final VoidCallback? onTap;
}

/// The critical-few KPI strip: at most four glanceable tiles, only for signals
/// that have data. The "summary" tier above the progressive-disclosure groups.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.kpis});
  final List<_Kpi> kpis;

  @override
  Widget build(BuildContext context) {
    if (kpis.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        // Two per row so numbers stay large and legible.
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final k in kpis) SizedBox(width: w, child: _Tile(k))],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.kpi);
  final _Kpi kpi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(14);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      child: InkWell(
        onTap: kpi.onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kpi.value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: kpi.color,
                      fontWeight: FontWeight.w700,
                      height: 1.0)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(kpi.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  if (kpi.onTap != null) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Collapsible group (progressive disclosure) ──────────────────────────────

/// A titled, collapsible group of sections with a one-line summary in the header
/// (so you get the signal without expanding). Non-lead groups start collapsed —
/// this is the "details" tier revealed on demand.
class _Group extends StatefulWidget {
  const _Group({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.summary,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final String? summary;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  late bool _expanded = widget.initiallyExpanded;

  /// Open the group (used by a KPI tap or a Home deep-link). No-op if already open.
  void expand() {
    if (!_expanded) setState(() => _expanded = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(widget.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (widget.summary != null && !_expanded)
                  Flexible(
                    child: Text(widget.summary!,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            theme.textTheme.bodySmall?.copyWith(color: muted)),
                  ),
                const SizedBox(width: 6),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: muted),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
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
              style: theme.textTheme.titleSmall
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
    r >= 0.85 ? StatusColor.good : (r >= 0.65 ? StatusColor.warn : cs.error);

Color _dimColor(double v /* 1..5 */, ColorScheme cs) =>
    v >= 4 ? StatusColor.good : (v >= 3 ? StatusColor.warn : cs.error);

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

// ── 1a-ii. System-design mocks ──────────────────────────────────────────────
class _SystemDesignSection extends ConsumerWidget {
  const _SystemDesignSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(systemDesignSkillsProvider);
    return _Section(
      title: 'System-design mocks',
      subtitle: 'How you perform in full design interviews.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (m) {
          if (m.isEmpty) {
            return const _NoData(
                'No system-design mocks yet — run one to see your rubric.');
          }
          final keys = [
            for (final k in systemDesignRubricDimensions)
              if (m.dims.containsKey(k)) k,
            for (final k in m.dims.keys)
              if (!systemDesignRubricDimensions.contains(k)) k,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.count} mock${m.count == 1 ? '' : 's'} · avg score '
                '${m.avgScore.round()}/100',
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

// ── 1a-iii. Behavioral mocks ────────────────────────────────────────────────
class _BehavioralSection extends ConsumerWidget {
  const _BehavioralSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(behavioralSkillsProvider);
    return _Section(
      title: 'Behavioral mocks',
      subtitle: 'How you deliver your STAR stories under probing.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (m) {
          if (m.isEmpty) {
            return const _NoData(
                'No behavioral mocks yet — run one from Interview prep.');
          }
          final keys = [
            for (final k in behavioralRubricDimensions)
              if (m.dims.containsKey(k)) k,
            for (final k in m.dims.keys)
              if (!behavioralRubricDimensions.contains(k)) k,
          ];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${m.count} mock${m.count == 1 ? '' : 's'} · avg score '
                '${m.avgScore.round()}/100',
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
    final recognition = ref.watch(algoRecognitionProvider).asData?.value;
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
              if (recognition != null && recognition.maintained > 0)
                Text(
                  'Explain clock: ${recognition.maintained} '
                  'problem${recognition.maintained == 1 ? '' : 's'} kept sharp'
                  '${recognition.due > 0 ? ' · ${recognition.due} due to explain' : ''}.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── 1c. Patterns mastered ───────────────────────────────────────────────────

class _PatternsSection extends ConsumerWidget {
  const _PatternsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(patternMasteryProvider);
    return _Section(
      title: 'Patterns mastered',
      subtitle: 'How much of each pattern you can durably solve — the goal is '
          'breadth across patterns, not depth on a few.',
      child: async.when(
        loading: () => const _NoData('Loading…'),
        error: (e, _) => _NoData('Error: $e'),
        data: (patterns) {
          if (patterns.isEmpty) {
            return const _NoData(
                'No algorithm patterns yet — add some to your vault.');
          }
          final mastered = patterns.where((p) => p.mastered).length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$mastered of ${patterns.length} '
                'pattern${patterns.length == 1 ? '' : 's'} mastered',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              for (final p in patterns) _patternBar(context, p),
            ],
          );
        },
      ),
    );
  }

  Widget _patternBar(BuildContext context, PatternMastery p) {
    final cs = Theme.of(context).colorScheme;
    final color = p.mastered ? StatusColor.good : _recallColor(p.score, cs);
    return _StatBar(
      label: p.pattern,
      fraction: p.score,
      value: p.mastered ? '✓' : '${(p.score * 100).round()}%',
      color: color,
      subtitle: '${p.started}/${p.total} problems solved'
          '${p.mastered ? ' · mastered' : (p.started == 0 ? ' · not started' : '')}',
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
    // Consistency is a cross-subject habit (the activity log isn't card-scoped),
    // so under multiple goals it's honestly labelled "all subjects" — unlike the
    // other panels, it isn't this lane's number.
    final multiGoal =
        (ref.watch(activeGoalCountProvider).asData?.value ?? 1) >= 2;
    return _Section(
      title: 'Study consistency',
      subtitle: multiGoal
          ? 'Study actions per day across all subjects, last 4 weeks. Showing '
              'up beats cramming.'
          : 'Study actions per day, last 4 weeks. Showing up beats cramming.',
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
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.query_stats_outlined,
        title: 'No insights yet',
        message: 'Review some cards and run a mock or two — this fills in with '
            'how well it’s sticking, where you’re leaking, and how you perform.',
      );
}
