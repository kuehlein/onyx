import '../../shared/models/card.dart';
import 'deck.dart';

/// Builds a content-only [DeckManifest] from local [cards] for publishing — the
/// inverse of `importDeck` (docs/registry-and-sync.md §4). Each card contributes
/// only its content (id / type / title / tags / reconstructed body); the local
/// lifecycle (`status`, `deck`) and all SRS/review state are dropped. Because
/// [DeckManifest]/[DeckCard] have no schedule fields, **"scheduling never
/// travels" holds by construction** — a subscriber who pulls this back gets fresh
/// drafts, never the maintainer's progress.
///
/// Pure (no I/O): the caller supplies the parsed cards that make up the deck.
DeckManifest buildDeckManifest({
  required String deckId,
  required String name,
  required String author,
  required List<Card> cards,
  String? license,
}) =>
    DeckManifest(
      deckId: deckId,
      name: name,
      author: author,
      license: license,
      cards: [for (final c in cards) _toDeckCard(c)],
    );

/// Reconstructs a [DeckCard] from a parsed [Card]: the body is the pre-section
/// overview followed by each `## ` section, mirroring the on-disk shape the
/// parser produced (and that `importDeck` writes back after the H1).
DeckCard _toDeckCard(Card card) {
  final b = StringBuffer();
  if (card.overview.trim().isNotEmpty) b.write(card.overview.trim());
  for (final s in card.sections) {
    if (b.isNotEmpty) b.write('\n\n');
    b
      ..write('## ')
      ..write(s.heading)
      ..write('\n\n')
      ..write(s.content.trim());
  }
  return DeckCard(
    id: card.id,
    type: card.type,
    title: card.title,
    tags: card.tags,
    body: b.toString(),
  );
}
