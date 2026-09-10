import 'package:flutter/material.dart';

/// A consistent header for slide-up (bottom-sheet) modals: an optional leading
/// icon, a title (+ optional subtitle), and a close button — so every sheet's
/// top reads the same instead of each rolling its own margins and X.
///
/// Pair with `showModalBottomSheet(showDragHandle: true)`; this sits just below
/// the grabber. Set [divider] for sheets whose body is a scrolling list that
/// benefits from a separating rule under the header.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onClose,
    this.divider = false,
  });

  final String title;
  final IconData? icon;

  /// Defaults to the theme's primary colour.
  final Color? iconColor;
  final String? subtitle;

  /// An optional action (e.g. "Clear all") shown just left of the close button.
  final Widget? trailing;

  /// Defaults to popping the sheet.
  final VoidCallback? onClose;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            onPressed: onClose ?? () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
    if (!divider) return header;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [header, const Divider(height: 1)],
    );
  }
}
