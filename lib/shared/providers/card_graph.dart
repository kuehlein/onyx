import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/vault/card_links_repository.dart';
import 'database.dart';
import 'vault.dart';

part 'card_graph.g.dart';

/// Reads the `card_links` graph the indexer maintains (task #50, S1).
@riverpod
CardLinksRepository cardLinksRepository(Ref ref) =>
    CardLinksRepository(ref.watch(appDatabaseProvider));

/// A card's resolved link neighborhood — outbound links + backlinks, each with a
/// title for display, for the card-detail second-brain surface. Ids no longer in
/// the index (e.g. a card deleted since the last reindex) are dropped so every
/// entry is navigable.
@riverpod
Future<CardNeighborhood> cardNeighborhood(Ref ref, String cardId) async {
  final repo = ref.watch(cardLinksRepositoryProvider);
  final index = await ref.watch(vaultIndexProvider.future);
  final titleById = {for (final c in index.cards) c.id: c.title};

  LinkedCard? resolve(String id) {
    final title = titleById[id];
    return title == null ? null : LinkedCard(id, title);
  }

  final outbound = [
    for (final id in await repo.outbound(cardId))
      if (resolve(id) case final l?) l,
  ];
  final backlinks = [
    for (final id in await repo.backlinks(cardId))
      if (resolve(id) case final l?) l,
  ];
  return CardNeighborhood(outbound: outbound, backlinks: backlinks);
}
