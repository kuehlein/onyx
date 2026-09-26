part of 'insights_screen.dart';

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
        const gap = Dim.space3;
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
    const radius = Dim.brCard;
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      child: InkWell(
        onTap: kpi.onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              Dim.space4, Dim.space3, Dim.space4, Dim.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kpi.value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: kpi.color,
                      fontWeight: FontWeight.w700,
                      height: 1.0)),
              const SizedBox(height: Dim.space1),
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
                    const SizedBox(width: Dim.space1),
                    Icon(Icons.chevron_right,
                        size: Dim.iconSm,
                        color: theme.colorScheme.onSurfaceVariant),
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
          borderRadius: Dim.brCard,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Dim.space3),
            child: Row(
              children: [
                Icon(widget.icon,
                    size: Dim.iconMd, color: theme.colorScheme.primary),
                const SizedBox(width: Dim.space3),
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
                const SizedBox(width: Dim.space2),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: Dim.iconMd, color: muted),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(top: Dim.space1, bottom: Dim.space2),
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
      padding: const EdgeInsets.only(bottom: Dim.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: Dim.space1),
            Text(subtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: Dim.space4),
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

  // Fixed width of the right-aligned value column so bars align across rows.
  static const _valueWidth = 42.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Dim.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: Dim.space2),
          Row(
            children: [
              Expanded(child: _Track(fraction: fraction, color: color)),
              const SizedBox(width: Dim.space3),
              SizedBox(
                width: _valueWidth,
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: color, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: Dim.space1),
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

  static const _trackHeight = 10.0; // bar thickness
  static const _barRadius = 5.0; // fully rounded (== half the height → pill)

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_barRadius),
      child: Container(
        height: _trackHeight,
        color: cs.surfaceContainerHighest,
        alignment: Alignment.centerLeft,
        // The fill eases from empty to its fraction (design-system "bar-fill",
        // motionBase). context.motionBase is pre-gated on reduce-motion → an
        // instant jump when the OS setting is on.
        child: fraction == null
            ? null
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction!.clamp(0.0, 1.0)),
                duration: context.motionBase,
                curve: context.tokens.easeStandard,
                builder: (context, value, _) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(color: color),
                ),
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

  static const _barRadius = 2.0; // subtle rounding on the histogram bars

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
                    borderRadius: BorderRadius.circular(_barRadius),
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
      padding: const EdgeInsets.only(top: Dim.space2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(left, style: s), Text(right, style: s)],
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
