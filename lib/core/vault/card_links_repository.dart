import '../database/database.dart';

/// One end of a resolved card→card link, with a display title.
class LinkedCard {
  const LinkedCard(this.id, this.title);
  final String id;
  final String title;
}

/// A card's resolved link neighborhood — what it links OUT to and what links IN
/// (backlinks). Dangling links (targets that aren't cards) aren't here; they live
/// in the unresolved-links view (#20).
class CardNeighborhood {
  const CardNeighborhood({required this.outbound, required this.backlinks});
  final List<LinkedCard> outbound;
  final List<LinkedCard> backlinks;
  bool get isEmpty => outbound.isEmpty && backlinks.isEmpty;
}

/// Reads the card→card link graph from the `card_links` cache the indexer
/// rebuilds every reindex — the second-brain surface (task #50, S1). Edges are
/// resolved id→id (a wikilink whose target is a real card); resolution +
/// dangling detection happen at index time.
class CardLinksRepository {
  CardLinksRepository(this._db);

  final AppDatabase _db;

  /// Card ids this card links OUT to (its resolved `[[wikilinks]]`).
  Future<List<String>> outbound(String cardId) async {
    final rows = await (_db.select(_db.cardLinks)
          ..where((t) => t.fromCard.equals(cardId)))
        .get();
    return [for (final r in rows) r.toCard];
  }

  /// Card ids that link IN to this card (backlinks).
  Future<List<String>> backlinks(String cardId) async {
    final rows = await (_db.select(_db.cardLinks)
          ..where((t) => t.toCard.equals(cardId)))
        .get();
    return [for (final r in rows) r.fromCard];
  }
}
