// Material's `Card` widget collides with our domain `Card` model.
import 'package:flutter/material.dart' hide Card;
import 'package:go_router/go_router.dart';

import '../design/onyx_design.dart';
import '../models/card.dart';

/// A quiet link from a study flow to a card's full view — shown only when the
/// card has non-quizzable sections (implementation, resources, related) that the
/// study reveal omits, so the learner can reach them without leaving the flow.
/// Renders nothing otherwise. The one shared study→card affordance (was
/// duplicated verbatim in Learn and Review; ADR-0012 shared-component layer).
class ViewFullCardButton extends StatelessWidget {
  const ViewFullCardButton({super.key, required this.card});

  final Card card;

  @override
  Widget build(BuildContext context) {
    if (!card.sections.any((s) => !s.quizzable)) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => context.push('/card/${card.id}'),
        icon: const Icon(Icons.article_outlined, size: Dim.iconMd),
        label: const Text('View full card'),
      ),
    );
  }
}
