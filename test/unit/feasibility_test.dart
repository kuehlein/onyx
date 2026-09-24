import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/feasibility.dart';
import 'package:onyx/core/readiness/projection.dart';

/// S4b: the per-aim feasibility signal — "can you be durably ready by [date] at
/// your pace?" — classified purely from a ReadinessForecast vs the aim's date.
void main() {
  final today = DateTime(2026, 1, 1);
  final date = today.add(const Duration(days: 20));

  ReadinessForecast forecast({
    required double start,
    required int currentPerDay,
    required List<PacePoint> curve,
  }) =>
      ReadinessForecast(
        curve: curve, // ascending by perDay
        currentPerDay: currentPerDay,
        today: today,
        startReadiness: start,
        threshold: 0.75,
      );

  test('no date → open-ended (coverage, not a ready-by)', () {
    expect(
        classifyAimFeasibility(date: null).status, FeasibilityStatus.openEnded);
  });

  test('dated but no forecast → unknown', () {
    final f = classifyAimFeasibility(date: date, forecast: null);
    expect(f.status, FeasibilityStatus.unknown);
    expect(f.date, date);
  });

  test('already at the bar → ready', () {
    final f = classifyAimFeasibility(
      date: date,
      forecast: forecast(start: 0.8, currentPerDay: 8, curve: const []),
    );
    expect(f.status, FeasibilityStatus.ready);
  });

  test('current pace makes the date → onTrack', () {
    final f = classifyAimFeasibility(
      date: date, // +20d
      forecast: forecast(
          start: 0.3, currentPerDay: 8, curve: const [PacePoint(8, 10)]),
    );
    expect(f.status, FeasibilityStatus.onTrack);
    expect(f.readyBy, today.add(const Duration(days: 10)));
    expect(f.requiredPerDay, 8);
  });

  test('reachable only at a faster pace → behind', () {
    final f = classifyAimFeasibility(
      date: date, // +20d
      forecast: forecast(
          start: 0.3,
          currentPerDay: 8,
          curve: const [PacePoint(8, 30), PacePoint(16, 15)]),
    );
    expect(f.status, FeasibilityStatus.behind);
    expect(f.requiredPerDay, 16); // needs a faster pace than 8
    expect(f.needsAttention, isTrue);
  });

  test('even the fastest pace misses → infeasible', () {
    final f = classifyAimFeasibility(
      date: date, // +20d
      forecast: forecast(
          start: 0.3,
          currentPerDay: 8,
          curve: const [PacePoint(8, 30), PacePoint(16, 25)]),
    );
    expect(f.status, FeasibilityStatus.infeasible);
    expect(f.requiredPerDay, isNull);
    expect(f.needsAttention, isTrue);
  });

  test('a past date on a still-pending round → open-ended, never infeasible',
      () {
    // The event already happened; its outcome just isn't logged (awaiting
    // debrief, #90). A negative days-left must NOT read as infeasible — that would
    // max the aim's daily-plan urgency for a done interview. Even with a forecast
    // that would otherwise be hopeless, a past date is coverage-only.
    final f = classifyAimFeasibility(
      date: today.subtract(const Duration(days: 5)),
      forecast: forecast(
          start: 0.3,
          currentPerDay: 8,
          curve: const [PacePoint(8, 30), PacePoint(16, 25)]),
    );
    expect(f.status, FeasibilityStatus.openEnded);
    expect(f.needsAttention, isFalse);
  });
}
