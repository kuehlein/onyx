/// A source of "now", so time-gated logic (review due dates, the daily new-card
/// allowance, streaks) can be driven by a controllable clock in development.
///
/// Release builds always use the real wall clock (zero offset). In a debug
/// build the offset can be advanced from Settings → Developer to fast-forward
/// past the FSRS schedule and exercise the review/interview flow without waiting
/// real days. The offset is applied on top of the real clock, so time still
/// moves normally — it's shifted, not frozen.
class Clock {
  const Clock([this.offset = Duration.zero]);

  final Duration offset;

  DateTime now() => DateTime.now().add(offset);

  /// Local date-only midnight of the current (possibly offset) day.
  DateTime today() {
    final n = now();
    return DateTime(n.year, n.month, n.day);
  }

  static const real = Clock();
}
