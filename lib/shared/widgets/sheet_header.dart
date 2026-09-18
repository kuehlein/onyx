import 'package:flutter/material.dart';

import 'fading_scroll_edges.dart';

/// The one launcher for Onyx's slide-up modals (design-system §4.9): a thin
/// wrapper over `showModalBottomSheet` so every sheet inherits the same chrome
/// from one place — the themed sheet radius + drag handle (from
/// `bottomSheetTheme`), `isScrollControlled`/`showDragHandle` defaulted to the
/// common case, and typed `T?` returns. Compose the [builder]'s content with a
/// [SheetHeader] on top and a [SheetScrollBody] for scrolling bodies.
///
/// [backgroundColor] defaults to the theme's sheet surface (`bottomSheetTheme`);
/// the remaining knobs cover the few variants (e.g. the coach sheet's custom
/// handle → `showDragHandle: false`) without another copy-pasted call.
///
/// [barrierColor] is the §4.9 scrim (black @ ~0.45) applied to every sheet from
/// here. [useSafeArea] is exposed but defaults **off** on purpose: ~7 sheets
/// hand-size to a fixed fraction of the screen height (`0.8`–`0.9`), and wrapping
/// those in a safe area would shrink the available height and clip them on
/// notched devices — turning it on globally needs those converted to `maxHeight`
/// constraints first. Per-sheet safe-area is already handled where it matters
/// (bodies use `SafeArea` / `MediaQuery.viewInsets`).
Future<T?> showOnyxSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  Color? backgroundColor,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  Color barrierColor = const Color(0x73000000), // black @ ~0.45 (§4.9)
  BoxConstraints? constraints,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    constraints: constraints,
    builder: builder,
  );
}

/// The resolved surface a sheet sits on — its themed background
/// (`bottomSheetTheme.backgroundColor`, §2.5) with a scaffold-surface fallback.
/// Fade edges inside sheets read this so they always blend into the *current*
/// sheet color; retune the sheet surface in one place (the theme) and every fade
/// follows automatically.
Color sheetSurface(BuildContext context) {
  final theme = Theme.of(context);
  return theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface;
}

/// The scrollable body of a slide-up sheet, with a soft fade at whichever edge
/// has more content — so overflow (you-can-scroll-for-more) is always obvious.
/// The fade lives in the body, not the [SheetHeader], because the header never
/// scrolls; building it here means every sheet opts in the same way and the fade
/// blends into the correct sheet background. Place under a [SheetHeader] inside a
/// [Column]; it takes the remaining height.
class SheetScrollBody extends StatelessWidget {
  const SheetScrollBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;

  /// The color the content fades into — defaults to the current sheet surface
  /// ([sheetSurface]) so the fade blends into it; override only if the body sits
  /// on a different color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: FadingScrollEdges(
        color: color ?? sheetSurface(context),
        child: SingleChildScrollView(padding: padding, child: child),
      ),
    );
  }
}

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

  /// Defaults to the theme's primary color.
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
