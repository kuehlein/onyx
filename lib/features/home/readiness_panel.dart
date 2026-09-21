import 'package:flutter/material.dart';
import '../../shared/design/onyx_design.dart';
import '../../shared/widgets/status_pill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/ladder.dart';
import '../../core/readiness/pace.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../core/subject/active_subject.dart';
import '../../core/subject/subject_config.dart';
import '../../shared/providers/analytics.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/subject.dart';
import '../insights/weak_area_sheet.dart';
import 'target_sheet.dart';

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
    final goalSubject = ref.watch(activeGoalSubjectProvider).asData?.value;
    final vocab = goalSubject?.vocabulary ?? activeSubject.vocabulary;
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

/// The headline sub-block next to the big %: the tappable target line and the
/// evidence band + recall/interview-tested state. Tapping opens the target
/// sheet, so it's clear the % is measured against (and changes with) the target.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.target,
    required this.isSet,
    required this.readiness,
    required this.anyStudied,
    required this.vocab,
  });

  final ReadinessTarget? target;
  final bool isSet;
  final Readiness readiness;
  final bool anyStudied;
  final Vocabulary vocab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const green = StatusColor.good;

    final unset = target == null || !isSet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A bordered "field" pill so it clearly reads as a tappable form (set
        // level × company × track × date) rather than a static label.
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: Dim.brChip,
            child: InkWell(
              borderRadius: Dim.brChip,
              onTap: () => showTargetSheet(context),
              child: Container(
                // ≥48dp tap target (a11y); left-aligned so it reads as a
                // tappable form field rather than a centered chip.
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                    horizontal: Dim.space3, vertical: Dim.space1),
                decoration: BoxDecoration(
                  borderRadius: Dim.brChip,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flag_outlined,
                        size: Dim.iconSm, color: theme.colorScheme.primary),
                    const SizedBox(width: Dim.space2),
                    Flexible(
                      child: Text(unset ? 'Set your target' : target!.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: unset ? theme.colorScheme.primary : null)),
                    ),
                    const SizedBox(width: Dim.space2),
                    Icon(Icons.tune, size: Dim.iconSm, color: muted),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Dim.space1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Dim.space1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (anyStudied)
                Tooltip(
                  message:
                      readinessTooltip(vocab, interview: readiness.interview),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                      text: '${(readiness.low * 100).round()}'
                          '–${(readiness.high * 100).round()}% likely · ',
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                    TextSpan(
                      text: readinessStateWord(vocab,
                          interview: readiness.interview),
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: readiness.interview ? green : muted,
                          fontWeight: FontWeight.w600),
                    ),
                  ])),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A skeleton the same shape + roughly the same height as the real panel, shown
/// while readiness computes on launch — so the home list doesn't shift when the
/// data arrives.
class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  // Faint fill for the skeleton placeholder blocks (design-system hairline).
  static const _skeletonAlpha = 0.06;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = theme.colorScheme.onSurface.withValues(alpha: _skeletonAlpha);
    Widget block(double? w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: bar, borderRadius: Dim.brChip),
        );
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
          Row(
            children: [
              block(48, 30),
              const SizedBox(width: Dim.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(130, 14),
                    const SizedBox(height: Dim.space2),
                    block(170, 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Dim.space4),
          for (var i = 0; i < 3; i++) ...[
            block(double.infinity, 12),
            const SizedBox(height: Dim.space3),
          ],
          block(double.infinity, 12),
        ],
      ),
    );
  }
}

/// A compact, **no-loss** "last 7 days" activity indicator for the header row —
/// seven day-cells (filled = studied that day), neutral, secondary to readiness.
/// Deliberately NOT a streak: no consecutive-day count, no at-risk/guilt state,
/// no flame, nothing that can "break" (design-system §4.10; readiness-dashboard §6;
/// [[gamification-stance]]). Replaces the deleted loss-aversion `_StreakChip`.
class _ConsistencyChip extends StatelessWidget {
  const _ConsistencyChip(this.last7);

  /// Study-action counts for the last (up to) seven days, oldest → newest.
  final List<int> last7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studied = last7.where((c) => c > 0).length;
    return Tooltip(
      message: '$studied of the last 7 days studied',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final count in last7)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: count > 0
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The coverage-pace line toward the interview date. Copy is scoped to
/// *coverage* ("cover your material"), never "interview-ready" — Phase A can't
/// measure the latter.
class _PaceRow extends StatelessWidget {
  const _PaceRow(this.pace, this.vocab);

  final PaceEstimate pace;
  final Vocabulary vocab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, text) = _describe();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Dim.iconSm, color: color),
        const SizedBox(width: Dim.space2),
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
    // SWE: "interview"/"Interview"; a neutral subject: "target"/"Target" (G7).
    final noun = vocab.assessmentNoun ?? 'target';
    final nounTitle = vocab.assessmentNounTitle ?? 'Target';
    const green = StatusColor.good;
    const amber = StatusColor.warn;
    const red = StatusColor.bad;
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
          'On pace to cover your material — $noun $inDays, at '
              '~${_rate(pace.recentPerDay)}/day.'
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
          '$nounTitle $inDays — ~${_rate(pace.requiredPerDay)}/day to cover '
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

// ── G7: assessment-noun phrasing ────────────────────────────────────────────
// The SWE reference (`assessmentNoun: 'interview'`) reproduces the original copy
// byte-identically; a subject with no assessment reads neutral "applied"/"Applied"
// phrasing instead (task #88 / G7d). Pure → unit-tested. NOTE (G7d-tail, deferred):
// the "mock" wording (bar legend, domain evidence caption) and the SWE seniority
// ladder labels (New-grad/Mid/Senior/Staff in `_MilestoneChips`) are tied to the
// applied-evidence + ladder models — a later generalization, not this pass.

/// The recall/applied state word under the headline — SWE: "interview-tested" /
/// "recall only".
@visibleForTesting
String readinessStateWord(Vocabulary v, {required bool interview}) =>
    interview ? '${v.assessmentNoun ?? 'applied'}-tested' : 'recall only';

/// The calibrated "ready" status label — SWE: "Interview-ready".
@visibleForTesting
String readyStatusLabel(Vocabulary v) =>
    '${v.assessmentNounTitle ?? 'Applied'}-ready';

/// The headline evidence-band tooltip — SWE reproduces the original two strings
/// exactly; a neutral subject gets applied/practice phrasing.
@visibleForTesting
String readinessTooltip(Vocabulary v, {required bool interview}) {
  final title = v.assessmentNounTitle;
  final noun = v.assessmentNoun;
  if (interview) {
    return title == null
        ? 'Applied readiness: recall gated by your practice performance. The '
            'band narrows as you practise more.'
        : '$title readiness: recall gated by your mock-$noun performance. The '
            'band narrows as you do more mocks.';
  }
  return title == null
      ? 'Recall readiness. Practise to prove you can apply it — that graduates '
          'this to applied-tested and narrows the band.'
      : 'Recall readiness. Do mock ${noun}s to prove you can apply it — that '
          'graduates this to $noun-tested and narrows the band.';
}

/// Band color for a readiness score: red (needs work) → amber (developing) →
/// green (strong). Shared by the overall bar and the per-domain bars so the
/// color language is identical everywhere.
Color _bandColor(double score) {
  if (score >= 0.75) return StatusColor.good; // green
  if (score >= 0.45) return StatusColor.warn; // amber
  return StatusColor.bad; // red
}

/// The score at/above which (once mock-tested) you're in interview-ready
/// territory — the same 0.75 "Strong" line the domain bars flag.
const _readyLine = 0.75;

/// A calibrated readiness status derived from the score + evidence. Honest by
/// construction: "Interview-ready" needs mock evidence AND even the pessimistic
/// band bound clearing the line — recall alone can never claim it.
({String label, Color color, bool ready}) _readyStatus(
    Readiness r, Vocabulary vocab) {
  const green = StatusColor.good;
  const amber = StatusColor.warn;
  const red = StatusColor.bad;
  if (!r.interview) {
    // Recall-only: never "ready" (unproven). Describe recall strength instead.
    if (r.overall >= _readyLine) {
      return (label: 'Strong recall', color: amber, ready: false);
    }
    if (r.overall >= 0.45) {
      return (label: 'Building recall', color: amber, ready: false);
    }
    return (label: 'Getting started', color: red, ready: false);
  }
  if (r.low >= _readyLine) {
    return (label: readyStatusLabel(vocab), color: green, ready: true);
  }
  if (r.overall >= _readyLine) {
    return (label: 'Almost ready', color: green, ready: false);
  }
  if (r.overall >= 0.5) {
    return (label: 'Developing', color: amber, ready: false);
  }
  return (label: 'Building', color: red, ready: false);
}

/// The overall progress bar + calibrated ready status. The fill IS the headline
/// % (so the number and the bar can never disagree), with a goal flag at the
/// interview-ready line and a status word under the bar naming where you stand
/// (Building → Developing → Interview-ready).
class _OverallBar extends StatelessWidget {
  const _OverallBar(this.r, this.vocab);

  final Readiness r;
  final Vocabulary vocab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _readyStatus(r, vocab);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TickedBar(
          value: r.overall,
          color: _bandColor(r.overall),
          goal: _readyLine,
        ),
        const SizedBox(height: Dim.space1),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (status.ready) ...[
              Icon(Icons.check_circle, size: Dim.iconSm, color: status.color),
              const SizedBox(width: Dim.space1),
            ],
            Text(status.label,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: status.color, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

/// Ladder standing as discrete **milestone chips** — one per seniority level,
/// checked when cleared, outlined when in progress, muted when still locked,
/// with a flag on the goal level. Deliberately NOT a fill bar: "levels
/// unlocked" is a yes/no milestone, so it shouldn't read as a rival percentage
/// competing with the headline. A caption spells out the current rung + goal.
class _MilestoneChips extends StatelessWidget {
  const _MilestoneChips(this.pos);

  final LadderPosition pos;

  static const _levels = ['New-grad', 'Mid', 'Senior', 'Staff'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final goalLevel = pos.goalIndex ~/ 2; // 2 rungs (Typical, FAANG) per level
    final goalLabel = pos.goalLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ladder standing',
            style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(height: Dim.space2),
        Wrap(
          spacing: Dim.space2,
          runSpacing: Dim.space2,
          children: [
            for (var i = 0; i < _levels.length; i++)
              _LevelChip(
                label: _levels[i],
                // Each level owns rungs [2i, 2i+1]; how many are cleared?
                clearedInLevel: (pos.clearedCount - 2 * i).clamp(0, 2),
                isFrontier:
                    pos.clearedCount >= 2 * i && pos.clearedCount < 2 * (i + 1),
                isGoal: i == goalLevel,
              ),
          ],
        ),
        const SizedBox(height: Dim.space2),
        Text(_caption(goalLabel),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface)),
      ],
    );
  }

  String _caption(String goalLabel) {
    if (pos.atOrAboveGoal) {
      return 'You clear your $goalLabel goal — validate it with mocks.';
    }
    final where = pos.currentLabel == null
        ? 'Building your foundation'
        : 'Clears up to ${pos.currentLabel}';
    return '$where · aiming $goalLabel.';
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.clearedInLevel,
    required this.isFrontier,
    required this.isGoal,
  });

  /// 0, 1 or 2 of this level's two rungs cleared.
  final int clearedInLevel;

  /// True when this is the level currently being worked on (all below cleared).
  final bool isFrontier;
  final bool isGoal;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cleared = clearedInLevel >= 2;
    final active = cleared || clearedInLevel >= 1 || isFrontier;
    // Milestone emphasis (not a status): accent for reached/active rungs, muted
    // when locked; filled once cleared, outline while active/locked.
    return StatusPill(
      tone: active ? StatusTone.accent : StatusTone.muted,
      variant: cleared ? StatusPillVariant.filled : StatusPillVariant.outline,
      icon: cleared
          ? Icons.check_circle
          : (active ? Icons.radio_button_unchecked : Icons.lock_outline),
      label: label,
      trailingIcon: isGoal ? Icons.flag : null,
      dense: true,
    );
  }
}

/// A rounded progress bar with a **goal flag** marking the readiness target for
/// this domain — the fill shows how far along you are, the flag shows the line
/// you're aiming for (consistent with the overall level gauge's goal flag).
class _TickedBar extends StatelessWidget {
  const _TickedBar({
    required this.value,
    required this.color,
    this.recall,
    this.goal,
  });

  /// The darker "proven" fill — the interview-adjusted score.
  final double value;
  final Color color;

  /// The lighter recall "ceiling" the [value] fill sits inside. When it exceeds
  /// [value] (i.e. mocks haven't yet proven all the recalled material), the gap
  /// is drawn in a faded [color] — "you know this, prove it with mocks". Null or
  /// ≤ [value] renders a single solid bar (the recall-only view).
  final double? recall;

  /// Fraction (0..1) at which to place the goal flag, or null for no flag.
  final double? goal;

  static const _barHeight = 6.0;
  static const _flagZone = 16.0; // clear space above the bar for the flag
  // Goal-marker flag glyph height. Layout-coupled: the connector tick starts at
  // the flag's foot (top) and its length subtracts this same height. Sub-scale
  // decorative glyph, deliberately off the icon scale.
  static const double _goalFlagSize = 11;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final radius = BorderRadius.circular(_barHeight / 2);
        final goalX = goal == null ? null : goal!.clamp(0.0, 1.0) * w;
        final ceiling = (recall ?? value).clamp(0.0, 1.0);
        final showCeiling = ceiling > value.clamp(0.0, 1.0) + 1e-6;
        return SizedBox(
          height: _flagZone + _barHeight + 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track.
              Positioned(
                left: 0,
                right: 0,
                top: _flagZone,
                child: ClipRRect(
                  borderRadius: radius,
                  child: Container(
                      height: _barHeight,
                      color: theme.colorScheme.surfaceContainerHighest),
                ),
              ),
              // Recall ceiling (lighter) — drawn first so the proven fill sits
              // on top of it. Only visible where it extends past `value`.
              if (showCeiling)
                Positioned(
                  left: 0,
                  top: _flagZone,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Container(
                        height: _barHeight,
                        width: ceiling * w,
                        color: color.withValues(alpha: Dim.emphasisLow)),
                  ),
                ),
              // Proven fill (darker).
              Positioned(
                left: 0,
                top: _flagZone,
                child: ClipRRect(
                  borderRadius: radius,
                  child: Container(
                      height: _barHeight,
                      width: value.clamp(0.0, 1.0) * w,
                      color: color),
                ),
              ),
              if (goalX != null) ...[
                // Flag sits above the bar, with a thin tick connecting down from
                // just under the flag through the track — no overlap.
                Positioned(
                  left: (goalX - 5).clamp(0.0, w - 10),
                  top: 0,
                  child: Icon(Icons.flag, size: _goalFlagSize, color: muted),
                ),
                Positioned(
                  left: (goalX - 0.75).clamp(0.0, w - 1.5),
                  top: _goalFlagSize,
                  child: Container(
                      width: 1.5,
                      height: _flagZone + _barHeight - _goalFlagSize,
                      color: muted.withValues(alpha: Dim.emphasisMed)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A one-line key for the two-tone domain bars, shown only in interview mode:
/// the darker fill is what mocks have proven, the lighter is recall you haven't
/// yet applied. The gap between them is the value of doing more mocks.
class _BarLegend extends StatelessWidget {
  const _BarLegend();

  // Subtle rounding on the small legend swatch bars.
  static const _swatchRadius = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final ink = theme.colorScheme.onSurface;
    Widget swatch(double alpha) => Container(
          width: 12,
          height: 6,
          decoration: BoxDecoration(
            color: ink.withValues(alpha: alpha),
            borderRadius: BorderRadius.circular(_swatchRadius),
          ),
        );
    return Row(
      children: [
        swatch(0.85),
        const SizedBox(width: Dim.space1),
        Text('proven in mocks',
            style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(width: Dim.space3),
        swatch(0.28),
        const SizedBox(width: Dim.space1),
        Flexible(
          child: Text('recall to prove',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: muted)),
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
