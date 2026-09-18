import 'package:flutter/material.dart';

import '../design/onyx_design.dart';

/// Which status a pill conveys — maps to the [OnyxColors] ramp.
enum StatusTone { good, warn, bad, info, muted }

/// How prominently a [StatusPill] is drawn.
enum StatusPillVariant {
  /// Tinted fill + hairline border — confidence badges, grade tags.
  filled,

  /// Transparent with a hairline border — e.g. the AppBar readiness chip.
  outline,

  /// No fill or border — colored inline text (e.g. "paused").
  text,
}

/// The one true way to render a status (design-system §4.1): **color + shape +
/// (optional) number + Semantics are always together**, so no status surface can
/// drift into color-only. `ConfidenceBadge`, the readiness chip, grade tags, and
/// paused rows all compose this instead of re-deriving a tinted container.
///
/// All geometry/opacity comes from [OnyxTokens]; the color from [OnyxColors] via
/// [tone]. Screen readers hear one node ([semanticLabel] ?? the visible text);
/// the inner paint is excluded so it isn't announced twice.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.tone,
    required this.label,
    this.icon,
    this.value,
    this.variant = StatusPillVariant.filled,
    this.dense = false,
    this.tooltip,
    this.semanticLabel,
  });

  final StatusTone tone;
  final String label;
  final IconData? icon;

  /// An optional value rendered after the label (e.g. a confidence score
  /// `"0.82"`) — the "number" channel of color+shape+number+label.
  final String? value;

  final StatusPillVariant variant;
  final bool dense;
  final String? tooltip;

  /// Overrides the announced label (defaults to the visible text). Use to fold in
  /// context, e.g. `"Confidence high, 0.82. Tap for why."`.
  final String? semanticLabel;

  Color _color(BuildContext c) => switch (tone) {
        StatusTone.good => c.onyx.good,
        StatusTone.warn => c.onyx.warn,
        StatusTone.bad => c.onyx.bad,
        StatusTone.info => c.onyx.info,
        StatusTone.muted => c.onyx.muted,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = _color(context);
    final visible = value == null ? label : '$label · $value';
    final base = context.text.labelMedium ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: dense ? 12 : 14, color: color),
          SizedBox(width: t.space1),
        ],
        Text(
          visible,
          style: base.copyWith(
            color: color,
            fontSize: dense ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final pad = EdgeInsets.symmetric(horizontal: t.space2, vertical: t.space1);
    final pill = switch (variant) {
      StatusPillVariant.text => content,
      StatusPillVariant.filled => Container(
          padding: pad,
          decoration: BoxDecoration(
            color: color.withValues(alpha: t.fill),
            borderRadius: t.brChip,
            border: Border.all(color: color.withValues(alpha: t.hairline)),
          ),
          child: content,
        ),
      StatusPillVariant.outline => Container(
          padding: pad,
          decoration: BoxDecoration(
            borderRadius: t.brChip,
            border: Border.all(color: color.withValues(alpha: t.hairline)),
          ),
          child: content,
        ),
    };

    final semantic = Semantics(
      container: true,
      label: semanticLabel ?? visible,
      child: ExcludeSemantics(child: pill),
    );

    return tooltip == null
        ? semantic
        : Tooltip(message: tooltip, child: semantic);
  }
}
