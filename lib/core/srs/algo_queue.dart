import '../../shared/models/card.dart';
import 'review_queue.dart' show ReviewItem;

/// Which mode the day's queue nudges you toward for a given problem. Solving is
/// the primary, stronger mode (execution clock); explaining is the phone-doable
/// maintenance mode (recognition clock). The UI offers both on every problem —
/// this just decides which one is prominent.
enum AlgoMode { solve, explain }

/// One scheduled unit of the Algorithms session: the problem, the mode to nudge
/// toward, and a short human reason it surfaced today.
class AlgoTask {
  const AlgoTask({
    required this.item,
    required this.mode,
    required this.reason,
  });

  final ReviewItem item; // card = pattern, section = problem
  final AlgoMode mode;
  final String reason;

  String get key => '${item.card.id}::${item.section.slug}';
}

/// Builds the day's Algorithms session (task #33) across BOTH clocks. Priority,
/// all capped at the daily [goal]:
///
///  1. **Solve-due re-solves** (FSRS due, most overdue first) → nudged to solve.
///  2. **Explain-due** problems whose solve clock is NOT due (recognition due,
///     most overdue first) → nudged to explain (phone-doable on a computerless
///     day).
///  3. **New** problems in NeetCode-150 progression order → nudged to solve.
///
/// Solving always wins ties: a problem due on both clocks appears once, as a
/// solve. A problem with no scheduling state yet is "new"; the first solve seeds
/// its state. [explainDueByKey] maps `"$cardId::$sectionSlug"` → recognition due
/// date (empty before Phase 2 has any explains).
List<AlgoTask> buildAlgoQueue({
  required List<Card> cards,
  required Map<String, DateTime> dueByKey,
  required DateTime now,
  required int goal,
  Map<String, DateTime> explainDueByKey = const {},
}) {
  final solveDue = <({ReviewItem item, DateTime dueAt})>[];
  final explainDue = <({ReviewItem item, DateTime dueAt})>[];
  final fresh = <ReviewItem>[];

  for (final card in cards) {
    if (card.type != CardType.algorithm) continue;
    for (final section in card.quizzableSections) {
      final key = '${card.id}::${section.slug}';
      final item = ReviewItem(card: card, section: section);
      final solveAt = dueByKey[key];
      if (solveAt == null) {
        fresh.add(item); // never solved
        continue;
      }
      if (!solveAt.isAfter(now)) {
        solveDue.add((item: item, dueAt: solveAt)); // solve wins ties
        continue;
      }
      // Solve not due — surface it only if its explain clock has come due.
      final explainAt = explainDueByKey[key];
      if (explainAt != null && !explainAt.isAfter(now)) {
        explainDue.add((item: item, dueAt: explainAt));
      }
    }
  }

  solveDue.sort((a, b) => a.dueAt.compareTo(b.dueAt)); // most overdue first
  explainDue.sort((a, b) => a.dueAt.compareTo(b.dueAt));

  final result = <AlgoTask>[
    for (final d in solveDue)
      AlgoTask(
          item: d.item, mode: AlgoMode.solve, reason: 'Due for a re-solve'),
  ];
  for (final d in explainDue) {
    if (result.length >= goal) break;
    result.add(AlgoTask(
        item: d.item, mode: AlgoMode.explain, reason: 'Due to explain'));
  }
  for (final item in fresh) {
    if (result.length >= goal) break;
    result
        .add(AlgoTask(item: item, mode: AlgoMode.solve, reason: 'New problem'));
  }
  return result.length > goal ? result.sublist(0, goal) : result;
}
