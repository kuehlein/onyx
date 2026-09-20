import 'package:flutter/material.dart';

import '../design/onyx_design.dart';

/// The one calm "nothing here (yet)" state (design-system §6 catalog). Replaces
/// the ad-hoc `Center > Column` blocks that had drifted across screens so every
/// empty/first-run/error frame reads the same way.
///
/// **Scannability:** one outlined [icon] anchors the eye in the accent color, a
/// short [title] is the scannable headline, an optional [message] is quiet
/// supporting copy (never competing with the title), and an optional [action] is
/// the single obvious next step. The measure is capped at ~360dp so the copy
/// stays readable instead of sprawling across a tablet width.
///
/// Deliberately **theme-agnostic** (only `ColorScheme` + `TextTheme`, never the
/// Onyx `ThemeExtension`s) — like [LoadingView], empty/error frames render inside
/// every screen (and its tests), so this must not require the full app theme in
/// scope. Color still flows from the scheme, so a restyle carries through.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.icon,
    this.message,
    this.action,
    this.dense = false,
  });

  /// The scannable headline (e.g. "No new material"). Kept short.
  final String title;

  /// Optional outlined glyph, drawn in the accent color. Omit for a plain
  /// message state (the old `_Message` shape).
  final IconData? icon;

  /// Optional supporting line — why it's empty / what fills it in.
  final String? message;

  /// Optional single next step (usually a button). Shown below the copy.
  final Widget? action;

  /// Tighter padding for inline/nested use (e.g. inside a card or a tab body).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(dense ? Dim.space5 : Dim.space6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 44, color: theme.colorScheme.primary),
                const SizedBox(height: Dim.space4),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: Dim.space2),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Dim.space5),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
