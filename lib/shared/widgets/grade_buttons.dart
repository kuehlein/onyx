import 'package:flutter/material.dart';

import '../design/onyx_design.dart';

/// One button in a [GradeButtons] row.
class GradeButton {
  const GradeButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.highlighted = false,
  });

  final String label;

  /// The button's accent (background is a tint of it; foreground is it).
  final Color color;
  final VoidCallback onTap;

  /// Optional leading icon (e.g. the interview-outcome row).
  final IconData? icon;

  /// Draws an outline — used for an advisory/suggested grade.
  final bool highlighted;
}

/// A single row of equal-width, color-coded grade buttons — the shared control
/// used to self-grade across the app (quiz review, algorithm solves, explain
/// mode). Keeping them in one widget means every flow positions and styles them
/// identically (part of the design-system consolidation, task #51).
class GradeButtons extends StatelessWidget {
  const GradeButtons({
    super.key,
    required this.buttons,
    this.verticalPadding = Dim.space4,
  });

  final List<GradeButton> buttons;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          Expanded(child: _button(buttons[i])),
          if (i != buttons.length - 1) const SizedBox(width: Dim.space2),
        ],
      ],
    );
  }

  Widget _button(GradeButton b) {
    final style = FilledButton.styleFrom(
      backgroundColor: b.color.withValues(alpha: 0.18),
      foregroundColor: b.color,
      padding: EdgeInsets.symmetric(
          horizontal: Dim.space2, vertical: verticalPadding),
      side: b.highlighted ? BorderSide(color: b.color, width: 2) : null,
    );
    final label = Text(b.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600));
    return b.icon == null
        ? FilledButton(onPressed: b.onTap, style: style, child: label)
        : FilledButton.icon(
            onPressed: b.onTap,
            style: style,
            icon: Icon(b.icon, size: 16),
            label: label);
  }
}
