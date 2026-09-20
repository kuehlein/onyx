/// Pure ordering for spaced mock ("re-practice") queues.
///
/// Any mock flow (system design, a vault-authored conversation flow, …) surfaces
/// its cards "what to practice next" in the same spaced-recurrence order: overdue
/// re-mocks first, then never-mocked, then upcoming. [orderByMockDue] is the one
/// shared, side-effect-free implementation so every mock track — in-code or
/// config-driven (task #30, G2a) — orders identically. It carries no readiness
/// weight; it only decides sequence.
library;

import '../../shared/models/card.dart';

/// Orders mock [cards] by spaced recurrence: overdue re-mocks first (most overdue
/// first), then never-mocked, then upcoming (soonest first), title as tiebreak.
/// [dueOf] returns a card's next re-mock due date, or null if never mocked.
///
/// Pure: it sorts a copy and reads only [now] + [dueOf]; the input list is left
/// untouched.
List<Card> orderByMockDue(
  List<Card> cards,
  DateTime now,
  DateTime? Function(Card) dueOf,
) {
  // 0 = overdue, 1 = never mocked, 2 = upcoming.
  int bucket(Card c) {
    final d = dueOf(c);
    if (d == null) return 1;
    return d.isAfter(now) ? 2 : 0;
  }

  final ordered = [...cards]..sort((a, b) {
      final ba = bucket(a), bb = bucket(b);
      if (ba != bb) return ba.compareTo(bb);
      final da = dueOf(a), db = dueOf(b);
      if (da != null && db != null) return da.compareTo(db);
      return a.title.compareTo(b.title);
    });
  return ordered;
}
