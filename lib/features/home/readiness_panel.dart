import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/readiness/ladder.dart';
import '../../core/readiness/pace.dart';
import '../../core/readiness/readiness.dart';
import '../../core/readiness/target.dart';
import '../../core/stats/streak.dart';
import '../../shared/providers/readiness.dart';
import '../../shared/providers/stats.dart';
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
    final r = ref.watch(readinessProvider).asData?.value;
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final target = ref.watch(readinessTargetControllerProvider).asData?.value;
    final pace = ref.watch(readinessPaceProvider).asData?.value;
    final ladder = ref.watch(readinessLadderPositionProvider).asData?.value;
    final streak = ref.watch(studyStreakProvider).asData?.value;
    final appliedSummary =
        ref.watch(appliedSummaryProvider).asData?.value ?? const {};
    final anyStudied = r.domains.any((d) => d.studied > 0);
    final showStreak =
        streak != null && (streak.current > 0 || streak.studiedToday);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
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
                      size: 22, color: theme.colorScheme.primary),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: _Headline(
                    target: target, readiness: r, anyStudied: anyStudied),
              ),
              if (showStreak) ...[
                const SizedBox(width: 8),
                _StreakChip(streak),
              ],
            ],
          ),
          if (!anyStudied)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Study some cards and this fills in.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            )
          else ...[
            if (pace != null) ...[
              const SizedBox(height: 8),
              _PaceRow(pace),
            ],
            // The single progress bar — its fill IS the headline % toward the
            // goal, so the number and the bar always agree.
            const SizedBox(height: 12),
            _OverallBar(r),
            // Ladder standing shown as discrete milestone chips (levels
            // unlocked), NOT a rival fill bar — see the goal flag on the target.
            if (ladder != null) ...[
              const SizedBox(height: 12),
              _MilestoneChips(ladder),
            ],
            const SizedBox(height: 12),
            // Explain the two-tone bars once, only after mocks graduate the view.
            if (r.interview) ...[
              const _BarLegend(),
              const SizedBox(height: 8),
            ],
            for (final d in r.domains)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DomainRow(d,
                    focus: identical(d, r.domains.first),
                    summary: appliedSummary[d.domain]),
              ),
          ],
        ],
      ),
    );
  }
}

/// The headline sub-block next to the big %: the tappable target line and the
/// evidence band + recall/interview-tested state. Tapping opens the target
/// sheet, so it's clear the % is measured against (and changes with) the target.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.target,
    required this.readiness,
    required this.anyStudied,
  });

  final ReadinessTarget? target;
  final Readiness readiness;
  final bool anyStudied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    const green = Color(0xFF4CC38A);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => showTargetSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('for ',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                Flexible(
                  child: Text(target?.label ?? 'your goal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right, size: 16, color: muted),
              ],
            ),
            if (anyStudied)
              Tooltip(
                message: readiness.interview
                    ? 'Interview readiness: recall gated by your mock-interview '
                        'performance. The band narrows as you do more mocks.'
                    : 'Recall readiness. Do mock interviews to prove you can '
                        'apply it — that graduates this to interview-tested and '
                        'narrows the band.',
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: '${(readiness.low * 100).round()}'
                        '–${(readiness.high * 100).round()}% likely · ',
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                  TextSpan(
                    text: readiness.interview
                        ? 'interview-tested'
                        : 'recall only',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: readiness.interview ? green : muted,
                        fontWeight: FontWeight.w600),
                  ),
                ])),
              ),
          ],
        ),
      ),
    );
  }
}

/// A compact streak chip (flame + current day count) for the header row.
class _StreakChip extends StatelessWidget {
  const _StreakChip(this.streak);

  final StreakInfo streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const flame = Color(0xFFF2792B);
    const amber = Color(0xFFE3B341);
    final atRisk = !streak.studiedToday;
    return Tooltip(
      message: atRisk
          ? 'Study today to keep your ${streak.current}-day streak'
          : '${streak.todayCount} studied today · ${streak.current}-day streak',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department,
              size: 18, color: atRisk ? amber : flame),
          const SizedBox(width: 2),
          Text('${streak.current}',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
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

/// Band colour for a readiness score: red (needs work) → amber (developing) →
/// green (strong). Shared by the overall bar and the per-domain bars so the
/// colour language is identical everywhere.
Color _bandColor(double score) {
  if (score >= 0.75) return const Color(0xFF4CC38A); // green
  if (score >= 0.45) return const Color(0xFFE3B341); // amber
  return const Color(0xFFF07178); // red
}

/// The overall progress bar. Its fill IS the headline % (so the number and the
/// bar can never disagree), with a goal flag at the "Strong" line — the same
/// bar widget and flag the per-domain rows use.
class _OverallBar extends StatelessWidget {
  const _OverallBar(this.r);

  final Readiness r;

  @override
  Widget build(BuildContext context) {
    return _TickedBar(
        value: r.overall, color: _bandColor(r.overall), goal: 0.75);
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
    final goalLabel = readinessLadder[pos.goalIndex].label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ladder standing',
            style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
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
        const SizedBox(height: 6),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final cleared = clearedInLevel >= 2;
    final active = cleared || clearedInLevel >= 1 || isFrontier;

    final Color bg, border, fg;
    if (cleared) {
      bg = primary.withValues(alpha: 0.16);
      border = primary.withValues(alpha: 0.5);
      fg = primary;
    } else if (active) {
      bg = Colors.transparent;
      border = primary.withValues(alpha: 0.45);
      fg = primary;
    } else {
      bg = Colors.transparent;
      border = muted.withValues(alpha: 0.3);
      fg = muted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            cleared
                ? Icons.check_circle
                : (active ? Icons.radio_button_unchecked : Icons.lock_outline),
            size: 12,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: cleared ? FontWeight.w600 : FontWeight.w500)),
          if (isGoal) ...[
            const SizedBox(width: 4),
            Icon(Icons.flag, size: 11, color: fg),
          ],
        ],
      ),
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
                        color: color.withValues(alpha: 0.32)),
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
                  child: Icon(Icons.flag, size: 11, color: muted),
                ),
                Positioned(
                  left: (goalX - 0.75).clamp(0.0, w - 1.5),
                  top: 11,
                  child: Container(
                      width: 1.5,
                      height: _flagZone + _barHeight - 11,
                      color: muted.withValues(alpha: 0.55)),
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
            borderRadius: BorderRadius.circular(3),
          ),
        );
    return Row(
      children: [
        swatch(0.85),
        const SizedBox(width: 5),
        Text('proven in mocks',
            style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        const SizedBox(width: 12),
        swatch(0.28),
        const SizedBox(width: 5),
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

class _DomainRow extends StatelessWidget {
  const _DomainRow(this.d, {required this.focus, this.summary});

  final DomainReadiness d;
  final bool focus;

  /// Applied-evidence counts for this domain (attempts + contested), or null.
  final ({int attempts, int contested})? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final color = _color(d);

    final meta = _meta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name (ellipsizes) + focus marker on the left; % flush-right. The name
        // group is a single Expanded so the % lands at the same x on every row
        // (previously a Flexible + Spacer both flexed, drifting the % by title
        // length).
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(_pretty(d.domain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  if (focus) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.my_location,
                        size: 13, color: theme.colorScheme.primary),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(d.studied == 0 ? d.label : '${(d.score * 100).round()}%',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 3),
        // Goal flag at the "Strong" line (0.75) — the target for this domain.
        // In interview mode the lighter portion is recall, the darker is what
        // mocks have actually proven.
        _TickedBar(value: d.score, recall: d.recall, color: color, goal: 0.75),
        // Evidence caption (interview mode only): mock count + contested flag.
        if (meta != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(meta,
                style: theme.textTheme.labelSmall?.copyWith(color: muted)),
          ),
      ],
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

  Color _color(DomainReadiness d) {
    if (d.studied == 0) return const Color(0xFF8A8F98); // muted grey
    return _bandColor(d.score);
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
