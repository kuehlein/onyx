import 'package:flutter/material.dart';

/// One button in a [GradeButtons] row.
class GradeButton {
  const GradeButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;

  /// The button's accent (background is a tint of it; foreground is it).
  final Color color;
  final VoidCallback onTap;

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
    this.verticalPadding = 14,
  });

  final List<GradeButton> buttons;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          Expanded(
            child: FilledButton(
              onPressed: buttons[i].onTap,
              style: FilledButton.styleFrom(
                backgroundColor: buttons[i].color.withValues(alpha: 0.18),
                foregroundColor: buttons[i].color,
                padding: EdgeInsets.symmetric(vertical: verticalPadding),
                side: buttons[i].highlighted
                    ? BorderSide(color: buttons[i].color, width: 2)
                    : null,
              ),
              child: Text(buttons[i].label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          if (i != buttons.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
