import 'dart:collection';

import '../../shared/models/card.dart';

/// One item to review in a session: a single quizzable section of a card.
class ReviewItem {
  const ReviewItem({required this.card, required this.section});

  final Card card;
  final CardSection section;

  /// Stable composite key into `srs_state` / `reviews`.
  String get key => '${card.id}::${section.slug}';
}

/// Builds a review session: only sections that are already **due**
/// (`dueAt <= now`). First exposure to un-seeded sections belongs to Learn mode,
/// not here — a section reaches this queue only after graduating out of Learn.
/// The result is interleaved by domain (round-robin across tags) — the
/// desirable-difficulty ordering our learning-science synthesis recommends over
/// blocking one topic (the opposite of Learn's grouping).
List<ReviewItem> buildReviewQueue({
  required List<Card> cards,
  required Map<String, DateTime> dueByKey,
  required DateTime now,
}) {
  final due = <ReviewItem>[];
  for (final card in cards) {
    for (final section in card.quizzableSections) {
      final dueAt = dueByKey['${card.id}::${section.slug}'];
      if (dueAt != null && !dueAt.isAfter(now)) {
        due.add(ReviewItem(card: card, section: section));
      }
    }
  }
  return _interleaveByDomain(due);
}

/// Round-robin across domain buckets so consecutive items differ in topic where
/// possible, preserving each bucket's original order.
List<ReviewItem> _interleaveByDomain(List<ReviewItem> items) {
  // A plain map literal is already insertion-ordered (LinkedHashMap).
  final buckets = <String, Queue<ReviewItem>>{};
  for (final item in items) {
    buckets
        .putIfAbsent(item.card.domain ?? 'other', () => Queue<ReviewItem>())
        .add(item);
  }

  final result = <ReviewItem>[];
  var moved = true;
  while (moved) {
    moved = false;
    for (final bucket in buckets.values) {
      if (bucket.isNotEmpty) {
        result.add(bucket.removeFirst());
        moved = true;
      }
    }
  }
  return result;
}
