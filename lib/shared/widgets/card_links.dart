import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/vault/card_links_repository.dart';
import '../design/onyx_design.dart';
import '../providers/card_graph.dart';

/// The card's link neighborhood — outbound links + backlinks from the
/// `card_links` graph. Hidden when the card has no resolved links; each chip
/// navigates to that card. Shared card-view component (was the private
/// `_LinksSection` in card_detail); VIEW-only (a stub sources References from the
/// unresolved graph instead).
class CardLinks extends ConsumerWidget {
  const CardLinks({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nb = ref.watch(cardNeighborhoodProvider(cardId)).asData?.value;
    if (nb == null || nb.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nb.outbound.isNotEmpty)
          _LinkGroup(
              title: 'Links', icon: Icons.north_east, cards: nb.outbound),
        if (nb.backlinks.isNotEmpty)
          _LinkGroup(
              title: 'Backlinks', icon: Icons.south_west, cards: nb.backlinks),
      ],
    );
  }
}

/// One labelled group of navigable link chips (outbound or backlinks).
class _LinkGroup extends StatelessWidget {
  const _LinkGroup(
      {required this.title, required this.icon, required this.cards});

  final String title;
  final IconData icon;
  final List<LinkedCard> cards;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Dim.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: Dim.iconSm, color: cs.onSurfaceVariant),
              const SizedBox(width: Dim.space2),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: Dim.space2),
          Wrap(
            spacing: Dim.space2,
            runSpacing: Dim.space2,
            children: [
              for (final c in cards)
                ActionChip(
                  label: Text(c.title),
                  onPressed: () => context.push('/card/${c.id}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
