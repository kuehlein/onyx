import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/projection.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/shared/models/card.dart';

Card _c(String id, String domain, int tier) => Card(
      id: id,
      type: CardType.flashcard,
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
  const senior = ReadinessTarget(
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

  test('scenarios are ordered: push ≤ current ≤ chill (days to ready)', () {
    final s = projectScenarios(
      cards: deck,
      stateByKey: const {},
      target: senior,
      currentPerDay: 3,
      today: today,
    );
    final chill = s['chill']!.readyDay;
    final cur = s['current']!.readyDay;
    final push = s['push']!.readyDay;
    expect(push, isNotNull);
    expect(cur, isNotNull);
    expect(chill, isNotNull);
    expect(push!, lessThanOrEqualTo(cur!));
    expect(cur, lessThanOrEqualTo(chill!));
  });
}
