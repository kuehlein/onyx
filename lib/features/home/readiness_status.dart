part of 'readiness_panel.dart';

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
              onTap: () => context.push('/aims'),
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
// phrasing instead (task #88 / G7d). Pure → unit-tested. The ladder labels are now
// config-driven (`LadderPosition.levelLabels`/`contextsPerLevel`, from the goal's
// template — S4c), so `_MilestoneChips` is no longer SWE-tied. NOTE (G7d-tail,
// deferred): the "mock" wording (bar legend, domain evidence caption) is still tied
// to the applied-evidence model — a later generalization, not this pass.

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
