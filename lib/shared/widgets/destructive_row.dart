import 'package:flutter/material.dart';

import '../design/onyx_design.dart';

/// A list row for a **destructive** action — restore / reset / delete (design-
/// system §4.9, constraint 7: *danger is never signaled by color alone*). It
/// pairs the `error` hue with an **outlined, verb-labeled** trailing button — a
/// shape distinct from the plain neutral rows around it — and routes every tap
/// through a **confirm dialog**. So the destructive path always takes two
/// deliberate steps and still reads as dangerous to a color-blind user (shape +
/// verb + a second tap carry it, not the red).
///
/// The row owns the confirmation; the caller owns what happens after, via
/// [onConfirmed] (the actual wipe/restore + any snackbar/refresh). Kept
/// theme-agnostic (ColorScheme + TextTheme only), like the other state widgets —
/// so it renders in bare-theme tests without the Onyx `ThemeExtension`s.
///
/// **Scannability:** the bordered error verb on the right is the one loud signal
/// in an otherwise calm settings list — you can find the dangerous row at a
/// glance without reading every subtitle.
class DestructiveRow extends StatelessWidget {
  const DestructiveRow({
    super.key,
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.confirmTitle,
    required this.confirmMessage,
    required this.onConfirmed,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// The verb on the outlined button *and* the confirm button — "Restore",
  /// "Reset", "Delete". Kept short.
  final String actionLabel;

  final String confirmTitle;
  final String confirmMessage;

  /// Runs only after the user confirms — the destructive work plus any feedback.
  /// The caller is responsible for its own post-`await` context safety (capture
  /// `ScaffoldMessenger`/`Navigator` before awaiting, as usual).
  final Future<void> Function() onConfirmed;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = enabled
        ? scheme.error
        : scheme.onSurface.withValues(alpha: Dim.emphasisLow);
    return ListTile(
      leading: Icon(icon, color: tint),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      // The outlined error button is the sole action target — a deliberate,
      // distinct affordance (the row itself is not tappable, so a stray tap on
      // the title can't start a destructive flow).
      trailing: OutlinedButton(
        onPressed: enabled ? () => _confirm(context) : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.error,
          side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
        ),
        child: Text(actionLabel),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(confirmTitle),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (ok == true) await onConfirmed();
  }
}
