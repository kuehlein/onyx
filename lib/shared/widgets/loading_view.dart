import 'package:flutter/material.dart';

/// A calm, **non-spinning** indeterminate loading state (design-system §2.6/§8
/// progressPolicy): a static status line — a muted glyph + label wrapped in a
/// `Semantics` live-region — never a spinning `CircularProgressIndicator` (which
/// loops forever and ignores Reduce-Motion). Used for provider `loading:` states
/// and inline waits. Where a content preview is worth it, a `SkeletonBlock`
/// (Step 6) is the richer replacement.
///
/// Deliberately **theme-agnostic** (only `ColorScheme` + `TextTheme`, never the
/// Onyx `ThemeExtension`s): loading frames render before/around every screen, so
/// this must not require the full app theme to be in scope (e.g. in widget tests).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Loading…', this.compact = false});

  final String label;

  /// Inline (just the row) vs a centered full-area state.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final row = Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: muted),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
    return compact ? row : Center(child: row);
  }
}
