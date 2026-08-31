import '../../shared/models/card.dart';

/// Ranked full-text search over the indexed cards. Case-insensitive; multi-word
/// queries are AND (every term must appear somewhere in the card). Matches are
/// ranked by where terms land — a title hit outweighs a tag/heading hit, which
/// outweighs a body hit — so the most on-topic cards surface first.
///
/// Pure and in-memory: the vault is a few hundred cards, so there's no need for
/// an index or debounce; it re-runs cheaply on each keystroke.
List<Card> searchCards(List<Card> cards, String query) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (terms.isEmpty) return List.of(cards);

  final scored = <({Card card, int score})>[];
  for (final card in cards) {
    final title = card.title.toLowerCase();
    final strong = [
      ...card.tags,
      ...card.concepts,
      ...card.domains,
      if (card.category != null) card.category!,
      for (final s in card.sections) s.heading,
    ].join('\n').toLowerCase();
    final body = [
      card.overview,
      for (final s in card.sections) s.content,
    ].join('\n').toLowerCase();

    var score = 0;
    var matchesAll = true;
    for (final term in terms) {
      if (title.contains(term)) {
        score += 5;
      } else if (strong.contains(term)) {
        score += 3;
      } else if (body.contains(term)) {
        score += 1;
      } else {
        matchesAll = false;
        break;
      }
    }
    if (matchesAll) scored.add((card: card, score: score));
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.card.title.toLowerCase().compareTo(b.card.title.toLowerCase());
  });
  return [for (final s in scored) s.card];
}
