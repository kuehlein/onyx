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

/// Builds the day's Algorithms session (task #33) across BOTH clocks, sized to a
/// [min]/[max] range. Priority, everything capped at [max]:
///
///  1. **Solve-due re-solves** (FSRS due, most overdue first) → nudged to solve.
///  2. **New** problems (progression order) until the session reaches [min] — a
///     steady daily intake, so a quiet day still grows your repertoire.
///  3. **Explain-due** problems whose solve clock is NOT due (recognition due,
///     most overdue first) → nudged to explain (phone-doable), filling whatever
///     capacity is left up to [max].
///  4. If still below [min] because the deck is exhausted, **pull the soonest
///     upcoming re-solves forward** (mildly early — a minor spacing cost worth a
///     kept daily habit) so you're never left with a near-empty session.
///
/// Solving always wins ties: a problem due on both clocks appears once, as a
/// solve. A problem with no scheduling state yet is "new"; the first solve seeds
/// its state. [explainDueByKey] maps `"$cardId::$sectionSlug"` → recognition due
/// date. [min] is clamped to [max] defensively.
List<AlgoTask> buildAlgoQueue({
  required List<Card> cards,
  required Map<String, DateTime> dueByKey,
  required DateTime now,
  required int min,
  required int max,
  Map<String, DateTime> explainDueByKey = const {},
}) {
  final floor = min > max ? max : min;
  final solveDue = <({ReviewItem item, DateTime dueAt})>[];
  final explainDue = <({ReviewItem item, DateTime dueAt})>[];
  final fresh = <ReviewItem>[];
  final upcoming = <({ReviewItem item, DateTime dueAt})>[];

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
      // Solve not due — an explain may be due; otherwise it's a pull-forward
      // candidate (last resort to reach the floor).
      final explainAt = explainDueByKey[key];
      if (explainAt != null && !explainAt.isAfter(now)) {
        explainDue.add((item: item, dueAt: explainAt));
      } else {
        upcoming.add((item: item, dueAt: solveAt));
      }
    }
  }

  solveDue.sort((a, b) => a.dueAt.compareTo(b.dueAt)); // most overdue first
  explainDue.sort((a, b) => a.dueAt.compareTo(b.dueAt));
  upcoming.sort((a, b) => a.dueAt.compareTo(b.dueAt)); // soonest-due first

  final result = <AlgoTask>[];
  void add(ReviewItem item, AlgoMode mode, String reason) {
    if (result.length < max) {
      result.add(AlgoTask(item: item, mode: mode, reason: reason));
    }
  }

  // 1. Due re-solves (time-sensitive execution).
  for (final d in solveDue) {
    add(d.item, AlgoMode.solve, 'Due for a re-solve');
  }
  // 2. New problems, but only enough to reach the floor (steady daily intake).
  for (final item in fresh) {
    if (result.length >= floor) break;
    add(item, AlgoMode.solve, 'New problem');
  }
  // 3. Due explains fill remaining capacity up to max.
  for (final d in explainDue) {
    add(d.item, AlgoMode.explain, 'Due to explain');
  }
  // 4. Last resort: pull upcoming re-solves forward to reach the floor.
  for (final d in upcoming) {
    if (result.length >= floor) break;
    add(d.item, AlgoMode.solve, 'Practicing ahead');
  }
  return result;
}
