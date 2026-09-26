part of 'readiness_panel.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Rungs per seniority level + the level labels are config-driven (the goal's
    // template), so this isn't tied to SWE's 4 levels × 2 contexts.
    final cpl = pos.contextsPerLevel;
    final goalLevel = cpl == 0 ? 0 : pos.deckIndex ~/ cpl;
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
            for (var i = 0; i < pos.levelLabels.length; i++)
              _LevelChip(
                label: pos.levelLabels[i],
                // Each level owns rungs [cpl*i, cpl*(i+1)); how many are cleared?
                clearedInLevel: (pos.clearedCount - cpl * i).clamp(0, cpl),
                rungsInLevel: cpl,
                isFrontier: pos.clearedCount >= cpl * i &&
                    pos.clearedCount < cpl * (i + 1),
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
      return 'You clear your $goalLabel target — validate it with mocks.';
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
    required this.rungsInLevel,
    required this.isFrontier,
    required this.isGoal,
  });

  /// How many of this level's [rungsInLevel] rungs are cleared (0..rungsInLevel).
  final int clearedInLevel;
  final int rungsInLevel;

  /// True when this is the level currently being worked on (all below cleared).
  final bool isFrontier;
  final bool isGoal;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cleared = clearedInLevel >= rungsInLevel;
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
        final deckX = goal == null ? null : goal!.clamp(0.0, 1.0) * w;
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
              if (deckX != null) ...[
                // Flag sits above the bar, with a thin tick connecting down from
                // just under the flag through the track — no overlap.
                Positioned(
                  left: (deckX - 5).clamp(0.0, w - 10),
                  top: 0,
                  child: Icon(Icons.flag, size: _goalFlagSize, color: muted),
                ),
                Positioned(
                  left: (deckX - 0.75).clamp(0.0, w - 1.5),
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
