import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/projection.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/shared/models/card.dart';

Card _c(String id, String domain, int tier) => Card(
      id: id,
      type: 'flashcard',
      title: id,
      overview: '',
      tags: [domain],
      tiers: {domain: tier},
      sections: [
        const CardSection(
            heading: 's', slug: 's', content: 'x', quizzable: true)
      ],
      wikilinks: const [],
      filePath: '$id.md',
    );

void main() {
  final today = DateTime.utc(2026, 1, 1);
  final senior = ReadinessTarget.of(
      level: SeniorityLevel.senior,
      company: CompanyTier.faang,
      track: Track.backend);
  // A realistically-sized deck so coverage time (the pace lever) dominates the
  // FSRS maturation noise — on a tiny deck every pace covers it within days, so
  // the ready-day is maturation-bound and pace barely moves it (a wobble well
  // within our month-level hedging).
  final deck = [for (var i = 0; i < 60; i++) _c('c$i', 'ds-a', 1)];

  test('a fully-mastered deck is already ready (day 0)', () {
    final mastered = {
      for (final c in deck)
        '${c.id}::s': SectionSrsState(
          stability: 300,
          difficulty: 5,
          state: 2,
          due: today.add(const Duration(days: 60)),
          lastReview: today.subtract(const Duration(days: 1)),
        )
    };
    final p = projectReadiness(
      cards: deck,
      stateByKey: mastered,
      target: senior,
      pace: const PacePolicy(newSectionsPerDay: 5),
      today: today,
    );
    expect(p.startReadiness, greaterThanOrEqualTo(0.75));
    expect(p.readyDay, 0);
    expect(p.alreadyReady, isTrue);
  });

  test('an unstudied deck becomes ready over time, sooner at a higher pace',
      () {
    final empty = <String, SectionSrsState>{};
    final slow = projectReadiness(
      cards: deck,
      stateByKey: empty,
      target: senior,
      pace: const PacePolicy(newSectionsPerDay: 2),
      today: today,
    );
    final fast = projectReadiness(
      cards: deck,
      stateByKey: empty,
      target: senior,
      pace: const PacePolicy(newSectionsPerDay: 30),
      today: today,
    );
    expect(slow.startReadiness, lessThan(0.75));
    expect(fast.readyDay, isNotNull);
    expect(slow.readyDay, isNotNull);
    expect(fast.readyDay!, lessThanOrEqualTo(slow.readyDay!));
    expect(fast.trajectory.last.readiness,
        greaterThan(fast.trajectory.first.readiness));
  });

  test('an unreachable target within the horizon → readyDay null / unreachable',
      () {
    // A hopeless pace (1 new/day over 60 cards) inside a short horizon never crosses
    // the target — the branch every consumer keys "infeasible" off of.
    final p = projectReadiness(
      cards: deck,
      stateByKey: const {},
      target: senior,
      pace: const PacePolicy(newSectionsPerDay: 1),
      today: today,
      horizonDays: 10,
    );
    expect(p.readyDay, isNull);
    expect(p.unreachable, isTrue);
    expect(p.trajectory, isNotEmpty);
    expect(p.trajectory.last.readiness, lessThan(0.75));
    // The sim is bounded — the last sample never runs past the horizon.
    expect(p.trajectory.last.day, lessThanOrEqualTo(10));
  });

  test('a bigger daily budget reaches readiness no later (budget-native)', () {
    final empty = <String, SectionSrsState>{};
    final lean = projectReadiness(
      cards: deck,
      stateByKey: empty,
      target: senior,
      pace: const PacePolicy(budgetMinutes: 90),
      today: today,
    );
    final rich = projectReadiness(
      cards: deck,
      stateByKey: empty,
      target: senior,
      pace: const PacePolicy(budgetMinutes: 240),
      today: today,
    );
    expect(lean.readyDay, isNotNull);
    expect(rich.readyDay, isNotNull);
    // More budget → derives more new/day each day → ready no later (deterministic).
    expect(rich.readyDay!, lessThanOrEqualTo(lean.readyDay!));
  });

  test(
      'budget curve + forecast: a bigger budget reaches no later, required-budget '
      'rises for a tighter deadline', () {
    final c = projectBudgetCurve(
      cards: deck,
      stateByKey: const {},
      target: senior,
      currentBudget: 150,
      today: today,
    );
    final reached = c.curve.where((p) => p.readyDay != null).toList();
    expect(reached.length, greaterThan(1));
    // ready-day is non-increasing as the budget rises (deterministic — fuzz disabled).
    for (var i = 1; i < reached.length; i++) {
      expect(reached[i].readyDay!, lessThanOrEqualTo(reached[i - 1].readyDay!));
    }
    final f = ReadinessForecast(
      curve: c.curve,
      currentBudget: 150,
      currentPerDay: 8,
      today: today,
      startReadiness: c.startReadiness,
      threshold: 0.75,
    );
    final easy = f.requiredBudgetFor(300); // generous deadline
    final tight = f.requiredBudgetFor(60); // tight deadline
    expect(easy, isNotNull);
    if (tight != null) expect(tight, greaterThanOrEqualTo(easy!));
    expect(f.readyDateForBudget(f.currentBudget), isNotNull);
  });
}
