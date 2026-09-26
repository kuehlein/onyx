import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/feasibility.dart';
import 'package:onyx/core/readiness/projection.dart';

/// S4b: the per-aim feasibility signal — "can you be durably ready by [date] at
/// your budget?" — classified purely from a ReadinessForecast vs the aim's date.
/// The lever is the daily time budget (ADR-0010), so `requiredBudget` is minutes.
void main() {
  final today = DateTime(2026, 1, 1);
  final date = today.add(const Duration(days: 20));

  ReadinessForecast forecast({
    required double start,
    double currentBudget = 150,
    List<BudgetPoint> curve = const [], // ascending by budgetMinutes
  }) =>
      ReadinessForecast(
        curve: curve,
        currentBudget: currentBudget,
        currentPerDay:
            8, // felt quantity — unused by these classification tests
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
      forecast: forecast(start: 0.8),
    );
    expect(f.status, FeasibilityStatus.ready);
  });

  test('the current budget makes the date → onTrack', () {
    final f = classifyAimFeasibility(
      date: date, // +20d
      forecast: forecast(start: 0.3, curve: const [BudgetPoint(150, 10)]),
    );
    expect(f.status, FeasibilityStatus.onTrack);
    expect(f.readyBy, today.add(const Duration(days: 10)));
    expect(f.requiredBudget, 150);
  });

  test('reachable only at a bigger budget → behind', () {
    final f = classifyAimFeasibility(
      date: date, // +20d
      forecast: forecast(
          start: 0.3,
          curve: const [BudgetPoint(150, 30), BudgetPoint(300, 15)]),
    );
    expect(f.status, FeasibilityStatus.behind);
    expect(f.requiredBudget, 300); // needs a bigger budget than the current 150
    expect(f.needsAttention, isTrue);
  });

  test('even the largest budget misses → infeasible', () {
    final f = classifyAimFeasibility(
      date: date, // +20d
      forecast: forecast(
          start: 0.3,
          curve: const [BudgetPoint(150, 30), BudgetPoint(300, 25)]),
    );
    expect(f.status, FeasibilityStatus.infeasible);
    expect(f.requiredBudget, isNull);
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
          curve: const [BudgetPoint(150, 30), BudgetPoint(300, 25)]),
    );
    expect(f.status, FeasibilityStatus.openEnded);
    expect(f.needsAttention, isFalse);
  });
}
