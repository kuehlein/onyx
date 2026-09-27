import 'package:flutter/material.dart';

import '../../core/deck/deck.dart' show PriorityTier, PriorityTierWeight;
import '../design/onyx_design.dart';

/// A compact four-chip picker for a [PriorityTier] — the user's coarse "how much I
/// care" signal for a deck (cross-deck split) or an aim (ADR-0018). Ties are allowed
/// by design (each deck/aim sets its own; several may share a tier). Subject-neutral
/// labels come from [PriorityTier.label]. The engine turns the tier into a time
/// share; the user never types a number.
class PriorityTierPicker extends StatelessWidget {
  const PriorityTierPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PriorityTier value;
  final ValueChanged<PriorityTier> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Dim.space2,
      runSpacing: Dim.space2,
      children: [
        for (final t in PriorityTier.values)
          ChoiceChip(
            label: Text(t.label),
            selected: t == value,
            onSelected: (_) => onChanged(t),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
