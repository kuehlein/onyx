import '../../shared/models/card.dart';
import 'review_queue.dart' show ReviewItem;

/// Builds the day's Algorithms session (task #33, phase 1): a paced list of
/// problems to (re)work. Due re-solves come first (most overdue first); the rest
/// of the daily [goal] is filled with brand-new problems in NeetCode-150
/// progression order (the card list order, then section order). Capped at [goal]
/// so a session is consistent and achievable rather than "0 some days, a pile on
/// others".
///
/// Each item is a `(card, section)` where card = pattern, section = problem —
/// reusing [ReviewItem] since it's the same shape. A problem with no scheduling
/// state yet is "new" (never solved); the first solve seeds its state.
List<ReviewItem> buildAlgoQueue({
  required List<Card> cards,
  required Map<String, DateTime> dueByKey,
  required DateTime now,
  required int goal,
}) {
  final due = <({ReviewItem item, DateTime dueAt})>[];
  final fresh = <ReviewItem>[];
  for (final card in cards) {
    if (card.type != CardType.algorithm) continue;
    for (final section in card.quizzableSections) {
      final item = ReviewItem(card: card, section: section);
      final dueAt = dueByKey['${card.id}::${section.slug}'];
      if (dueAt == null) {
        fresh.add(item); // never solved
      } else if (!dueAt.isAfter(now)) {
        due.add((item: item, dueAt: dueAt)); // due for a re-solve
      }
    }
  }
  // Most-overdue re-solves first.
  due.sort((a, b) => a.dueAt.compareTo(b.dueAt));

  final result = [for (final d in due.take(goal)) d.item];
  if (result.length < goal) {
    result.addAll(fresh.take(goal - result.length));
  }
  return result;
}
