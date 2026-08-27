import 'dart:collection';

import '../../shared/models/card.dart';

/// One item to review in a session: a single quizzable section of a card, and
/// whether it's brand-new (never reviewed) or a scheduled repetition.
class ReviewItem {
  const ReviewItem({
    required this.card,
    required this.section,
    required this.isNew,
  });

  final Card card;
  final CardSection section;
  final bool isNew;

  /// Stable composite key into `srs_state` / `reviews`.
  String get key => '${card.id}::${section.slug}';
}

/// Builds a study session from the parsed cards and their scheduling state.
///
/// A section is included when it is **due** (`dueAt <= now`) or **new** (no
/// entry in [dueByKey]); everything else is skipped. New items are capped at
/// [newLimit] so a session doesn't drown you in unseen material. The result is
/// interleaved by domain (round-robin across tags) — the desirable-difficulty
/// ordering our learning-science synthesis recommends over blocking one topic.
List<ReviewItem> buildReviewQueue({
  required List<Card> cards,
  required Map<String, DateTime> dueByKey,
  required DateTime now,
  int newLimit = 12,
}) {
  final due = <ReviewItem>[];
  final fresh = <ReviewItem>[];

  for (final card in cards) {
    for (final section in card.quizzableSections) {
      final key = '${card.id}::${section.slug}';
      final dueAt = dueByKey[key];
      if (dueAt == null) {
        fresh.add(ReviewItem(card: card, section: section, isNew: true));
      } else if (!dueAt.isAfter(now)) {
        due.add(ReviewItem(card: card, section: section, isNew: false));
      }
    }
  }

  final selected = [...due, ...fresh.take(newLimit)];
  return _interleaveByDomain(selected);
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
