import 'package:flutter/material.dart';

import 'status_pill.dart';

/// A calm neutral meta chip (card type, domain, tier, priority, study mode).
/// Composes [StatusPill] with the muted tone — these carry no good/attention/bad
/// meaning. The one shared card-meta chip: it replaces the private `_MetaChip` /
/// `_Pill` copies that the card view and the study screens each hand-rolled.
class CardMetaChip extends StatelessWidget {
  const CardMetaChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => StatusPill(
        tone: StatusTone.muted,
        label: label,
        icon: icon,
        dense: true,
      );
}
