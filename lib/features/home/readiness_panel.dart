import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/status_pill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/ladder.dart';
import '../../core/readiness/pace.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../core/template/active_template.dart';
import '../../core/template/deck_template.dart';
import '../../shared/providers/analytics.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/template.dart';
import '../insights/weak_area_sheet.dart';

part 'readiness_status.dart';
part 'readiness_bars.dart';

/// Home dashboard panel: a compact readiness summary — a headline % toward the
/// chosen target (recall-only until mock evidence graduates it to
/// interview-tested) shown as one bar, ladder standing as milestone chips, and
/// per-domain bars with a goal flag. Deliberately tight so it fits without
/// scrolling.
class ReadinessPanel extends ConsumerWidget {
  const ReadinessPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rAsync = ref.watch(readinessProvider);
    final r = rAsync.asData?.value;
    // Reserve the panel's space with a skeleton while readiness computes, so the
    // home page doesn't jump when the data lands. Only truly-empty (loaded, no
    // cards) collapses to nothing.
    if (rAsync.isLoading && r == null) return const _LoadingPanel();
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final target = ref.watch(activeTargetProvider).asData?.value;
    final isSet = ref.watch(activeTargetIsSetProvider).asData?.value ?? false;
    final pace = ref.watch(readinessPaceProvider).asData?.value;
    final ladder = ref.watch(readinessLadderPositionProvider).asData?.value;
    final consistency = ref.watch(studyConsistencyProvider).asData?.value;
    final appliedSummary =
        ref.watch(appliedSummaryProvider).asData?.value ?? const {};
    // The active goal's assessment vocabulary (fall back to the primary while it
    // loads) so a non-SWE goal never reads "interview" copy (G7).
    final deckTemplate = ref.watch(activeDeckTemplateProvider).asData?.value;
    final vocab = deckTemplate?.vocabulary ?? activeTemplate.vocabulary;
    final anyStudied = r.domains.any((d) => d.studied > 0);
    // A no-loss "last 7 days" activity indicator (never a streak/guilt cue —
    // design-system §4.10, readiness-dashboard §6). Shown once there's activity.
    final last7 = consistency == null
        ? const <int>[]
        : (consistency.length <= 7
            ? consistency
            : consistency.sublist(consistency.length - 7));
    final showConsistency = last7.any((c) => c > 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          Dim.space4, Dim.space4, Dim.space4, Dim.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: Dim.brCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headline: the % (or an icon before any study), the tappable target
          // it's measured against, the evidence band + recall/interview state,
          // and a compact streak.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (anyStudied)
                Text('${(r.overall * 100).round()}%',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700, height: 1.0))
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.insights_outlined,
                      size: Dim.iconMd, color: theme.colorScheme.primary),
                ),
              const SizedBox(width: Dim.space3),
              Expanded(
                child: _Headline(
                    target: target,
                    isSet: isSet,
                    readiness: r,
                    anyStudied: anyStudied,
                    vocab: vocab),
              ),
              if (showConsistency) ...[
                const SizedBox(width: Dim.space2),
                _ConsistencyChip(last7),
              ],
            ],
          ),
          if (!anyStudied)
            Padding(
              padding: const EdgeInsets.only(top: Dim.space2),
              child: Text('Study some cards and this fills in.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            )
          else ...[
            if (pace != null) ...[
              const SizedBox(height: Dim.space2),
              _PaceRow(pace, vocab),
            ],
            // The single progress bar — its fill IS the headline % toward the
            // goal, so the number and the bar always agree.
            const SizedBox(height: Dim.space3),
            _OverallBar(r, vocab),
            // Ladder standing shown as discrete milestone chips (levels
            // unlocked), NOT a rival fill bar — see the goal flag on the target.
            if (ladder != null) ...[
              const SizedBox(height: Dim.space3),
              _MilestoneChips(ladder),
            ],
            const SizedBox(height: Dim.space3),
            // Explain the two-tone bars once, only after mocks graduate the view.
            if (r.interview) ...[
              const _BarLegend(),
              const SizedBox(height: Dim.space2),
            ],
            _DomainList(domains: r.domains, appliedSummary: appliedSummary),
          ],
        ],
      ),
    );
  }
}

/// The per-domain bars, weakest-first. Capped to the few most-relevant (weakest)
/// domains with a "show all" toggle so a broad, multi-domain deck doesn't make
/// the home panel scroll. Weakest-first ordering means the collapsed tail is the
/// strong domains that least need attention.
class _DomainList extends StatefulWidget {
  const _DomainList({required this.domains, required this.appliedSummary});

  final List<DomainReadiness> domains;
  final Map<String, ({int attempts, int contested})> appliedSummary;

  @override
  State<_DomainList> createState() => _DomainListState();
}

class _DomainListState extends State<_DomainList> {
  static const _cap = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.domains;
    final capped = all.length > _cap;
    final shown = (_expanded || !capped) ? all : all.take(_cap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: Dim.space2),
            child: _DomainRow(d,
                focus: identical(d, all.first),
                summary: widget.appliedSummary[d.domain]),
          ),
        if (capped)
          InkWell(
            borderRadius: Dim.brChip,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Dim.space1),
              child: Row(
                children: [
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: Dim.iconSm, color: theme.colorScheme.primary),
                  const SizedBox(width: Dim.space1),
                  Text(
                    _expanded ? 'Show fewer' : 'Show all ${all.length} domains',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DomainRow extends ConsumerWidget {
  const _DomainRow(this.d, {required this.focus, this.summary});

  final DomainReadiness d;
  final bool focus;

  /// Applied-evidence counts for this domain (attempts + contested), or null.
  final ({int attempts, int contested})? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final mocks = summary?.attempts ?? 0;
    // Two-tone "proven vs recall" only where mock evidence actually exists. A
    // domain with no mocks is recall-only — its score is silently discounted by
    // the transfer prior, which we do NOT visualise as "proven in mocks" (that
    // read as "proven" with zero mocks). Deeper question — whether readiness
    // should discount before any evidence — is task #49.
    final proven = d.transfer != null && mocks > 0;
    final shown = proven ? d.score : d.recall;
    final color = d.studied == 0 ? StatusColor.muted : _bandColor(shown);

    final meta = _meta;
    // The whole bar is tappable: it opens the AI weak-area drill-down for this
    // domain (task #23) — why it's where it is + targeted next steps. Padded so
    // the tap target is comfortable without shifting the row's visual rhythm.
    return InkWell(
      borderRadius: Dim.brChip,
      onTap: () => showWeakAreaSheet(context, ref,
          domain: d.domain, prettyName: prettyDomain(d.domain)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Dim.space1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name (ellipsizes) + focus marker on the left; % flush-right. The
            // name group is a single Expanded so the % lands at the same x on
            // every row (previously a Flexible + Spacer both flexed, drifting the
            // % by title length).
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(prettyDomain(d.domain),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      if (focus) ...[
                        const SizedBox(width: Dim.space2),
                        Icon(Icons.my_location,
                            size: Dim.iconSm, color: theme.colorScheme.primary),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Dim.space2),
                Text(d.studied == 0 ? d.label : '${(shown * 100).round()}%',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: Dim.space1),
            // Goal flag at the "Strong" line (0.75) — the target for this domain.
            // In interview mode the lighter portion is recall, the darker is what
            // mocks have actually proven.
            _TickedBar(
                value: shown,
                recall: proven ? d.recall : null,
                color: color,
                goal: 0.75),
            // Evidence caption (interview mode only): mock count + contested flag.
            if (meta != null)
              Padding(
                padding: const EdgeInsets.only(top: Dim.space1),
                child: Text(meta,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted)),
              ),
          ],
        ),
      ),
    );
  }

  /// In interview mode, a compact evidence caption — mock count and any contested
  /// grades (the adversarial critic disagreed). Null in the recall-only view.
  String? get _meta {
    if (d.transfer == null) return null;
    final n = summary?.attempts ?? 0;
    if (n == 0) return 'no mocks yet';
    final contested = summary?.contested ?? 0;
    final base = '$n mock${n == 1 ? '' : 's'} · transfer '
        '${((d.transfer ?? 0) * 100).round()}%';
    return contested > 0 ? '$base · $contested contested' : base;
  }
}
