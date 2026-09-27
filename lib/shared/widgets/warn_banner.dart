import 'package:flutter/material.dart';

import '../design/onyx_design.dart';

/// A compact warn-tinted banner (info icon + message) for calm, non-blocking
/// notices — e.g. the deck/allocation "too-little-time" warnings (deck_selection.md).
/// Presentational only: the caller supplies the (subject-neutral) message and any
/// surrounding spacing, so every warning across the deck surfaces reads the same and
/// can't drift apart. Extracted from the two near-identical private banners in
/// deck_settings + the allocation view.
class WarnBanner extends StatelessWidget {
  const WarnBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Dim.space3),
      decoration: BoxDecoration(
        color: StatusColor.warn.withValues(alpha: Dim.fill),
        borderRadius: Dim.brCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: Dim.iconMd, color: StatusColor.warn),
          const SizedBox(width: Dim.space2),
          Expanded(
            child: Text(message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: StatusColor.warn)),
          ),
        ],
      ),
    );
  }
}
