/// Study-streak computation: consecutive days with at least one study action
/// (a graded review or a newly learned section). Pure and timezone-aware — all
/// bucketing is by *local* calendar day, and day arithmetic goes through
/// `DateTime(y, m, d ± 1)` (never `Duration(days: 1)`) so DST transitions can't
/// drop or double-count a day.
library;

class StreakInfo {
  const StreakInfo({
    required this.current,
    required this.best,
    required this.studiedToday,
    required this.todayCount,
  });

  /// Consecutive study days ending today (if studied today) or yesterday (a
  /// still-alive streak the user can keep by studying today).
  final int current;

  /// The longest run of consecutive study days on record.
  final int best;

  final bool studiedToday;

  /// Study actions recorded today (reviews + newly learned sections).
  final int todayCount;

  static const empty =
      StreakInfo(current: 0, best: 0, studiedToday: false, todayCount: 0);
}

DateTime _dayOf(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

DateTime _prevDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);
DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// Computes the streak from raw study [timestamps] (any timezone/order) as of
/// [today] (should be a local date-only midnight).
StreakInfo computeStreak({
  required List<DateTime> timestamps,
  required DateTime today,
}) {
  if (timestamps.isEmpty) return StreakInfo.empty;

  final days = <DateTime>{};
  var todayCount = 0;
  for (final t in timestamps) {
    final d = _dayOf(t);
    days.add(d);
    if (d == today) todayCount++;
  }

  final studiedToday = days.contains(today);

  // Current streak: walk back from today (or yesterday if nothing today yet).
  var current = 0;
  var cursor = studiedToday ? today : _prevDay(today);
  while (days.contains(cursor)) {
    current++;
    cursor = _prevDay(cursor);
  }

  // Best streak: longest consecutive run across all recorded days.
  final sorted = days.toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? prev;
  for (final d in sorted) {
    run = (prev != null && d == _nextDay(prev)) ? run + 1 : 1;
    if (run > best) best = run;
    prev = d;
  }

  return StreakInfo(
    current: current,
    best: best,
    studiedToday: studiedToday,
    todayCount: todayCount,
  );
}
