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

part 'insights_charts.dart';
part 'insights_sections.dart';

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

Color _recallColor(double r, ColorScheme cs) =>
    r >= 0.85 ? StatusColor.good : (r >= 0.65 ? StatusColor.warn : cs.error);

Color _dimColor(double v /* 1..5 */, ColorScheme cs) =>
    v >= 4 ? StatusColor.good : (v >= 3 ? StatusColor.warn : cs.error);
