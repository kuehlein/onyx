import 'package:flutter/material.dart';

import '../models/card.dart';
import 'status_pill.dart';

/// A small, color-coded badge showing a card's author-assigned confidence
/// (high/medium/low), with a tooltip explaining how much to trust the card and
/// when to fall back to its Resources. Surfacing this lets the reader calibrate
/// their own skepticism (see docs/card-schema.md).
///
/// A thin wrapper over [StatusPill] (design-system §4.1) — color + shape + label
/// + Semantics come from the one primitive; card confidence is categorical, so
/// there is no numeric `value` to show here.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.confidence, {super.key});

  final Confidence confidence;

  @override
  Widget build(BuildContext context) {
    final (StatusTone tone, IconData icon, String label, String tip) =
        switch (confidence) {
      Confidence.high => (
          StatusTone.good,
          Icons.verified_outlined,
          'High confidence',
          'Passed a clean verification — study with confidence.',
        ),
      Confidence.medium => (
          StatusTone.warn,
          Icons.info_outline,
          'Medium confidence',
          'Minor issues were flagged at authoring — cross-check the card '
              'against its Resources.',
        ),
      Confidence.low => (
          StatusTone.bad,
          Icons.warning_amber_outlined,
          'Low confidence',
          'Major issues were auto-corrected by an AI verifier — read the '
              'Resources before relying on this card.',
        ),
    };

    return StatusPill(
      tone: tone,
      icon: icon,
      label: label,
      dense: true,
      tooltip: tip,
      semanticLabel: '$label. $tip',
    );
  }
}
