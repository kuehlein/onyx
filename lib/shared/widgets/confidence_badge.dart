import 'package:flutter/material.dart';
import '../status_colors.dart';

import '../models/card.dart';

/// A small, color-coded badge showing a card's author-assigned confidence
/// (high/medium/low), with a tooltip explaining how much to trust the card and
/// when to fall back to its Resources. Surfacing this lets the reader calibrate
/// their own skepticism (see docs/card-schema.md).
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.confidence, {super.key});

  final Confidence confidence;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String label, String tip) =
        switch (confidence) {
      Confidence.high => (
          statusGood,
          Icons.verified_outlined,
          'High confidence',
          'Passed a clean verification — study with confidence.',
        ),
      Confidence.medium => (
          statusWarn,
          Icons.info_outline,
          'Medium confidence',
          'Minor issues were flagged at authoring — cross-check the card '
              'against its Resources.',
        ),
      Confidence.low => (
          statusBad,
          Icons.warning_amber_outlined,
          'Low confidence',
          'Major issues were auto-corrected by an AI verifier — read the '
              'Resources before relying on this card.',
        ),
    };

    return Tooltip(
      message: tip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
