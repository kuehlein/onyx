import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/readiness/targeting.dart';
import 'package:onyx/shared/models/card.dart';

const _base = ReadinessTarget(
  level: SeniorityLevel.senior,
  company: CompanyTier.faang,
  track: Track.general,
);

Card _card(String domain, {List<String> concepts = const []}) => Card(
      id: 'c',
      type: CardType.flashcard,
      title: 'c',
      overview: '',
      tags: [domain],
      tiers: {domain: 1},
      sections: const [],
      wikilinks: const [],
      filePath: 'c.md',
      concepts: concepts,
    );

void main() {
  group('Targeting', () {
    test('no active goals → identical to the base target weighting', () {
      const t = Targeting(base: _base, goals: []);
      expect(t.weightForDomain('ds-a'), domainWeight(_base, 'ds-a'));
      expect(t.weightForDomain('system-design'),
          domainWeight(_base, 'system-design'));
      expect(t.weightForCard(_card('ds-a')), domainWeight(_base, 'ds-a'));
      expect(t.stabilityTarget, _base.stabilityTarget);
    });

    test(
        'an active goal raises the weight of a domain it boosts (max, not sum)',
        () {
      const goal = PrepGoal(
        id: 'g',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.general,
        domainWeights: {'ds-a': 5.0},
      );
      const t = Targeting(base: _base, goals: [goal]);
      // base ds-a weight is modest; the goal's +5 boost dominates.
      expect(t.weightForDomain('ds-a'),
          greaterThan(domainWeight(_base, 'ds-a') + 4));
      // A domain the goal doesn't touch is unchanged.
      expect(t.weightForDomain('system-design'),
          domainWeight(_base, 'system-design'));
    });

    test('weightForCard adds the strongest concept boost among active goals',
        () {
      const goal = PrepGoal(
        id: 'g',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.general,
        conceptWeights: {'consistent-hashing': 3.0, 'irrelevant': 1.0},
      );
      const t = Targeting(base: _base, goals: [goal]);
      final w = t.weightForCard(
          _card('ds-a', concepts: ['consistent-hashing', 'irrelevant']));
      // domain weight + the max matching concept boost (3.0, not 1.0, not 4.0).
      expect(w, closeTo(domainWeight(_base, 'ds-a') + 3.0, 1e-9));
      // A card with no boosted concept gets just the domain weight.
      expect(t.weightForCard(_card('ds-a')), domainWeight(_base, 'ds-a'));
    });

    test('governingDate is the soonest across base + goals', () {
      final base = _base.copyWith(interviewDate: DateTime(2026, 10, 1));
      final sooner = PrepGoal(
        id: 'g1',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.general,
        date: DateTime(2026, 9, 20),
      );
      final later = PrepGoal(
        id: 'g2',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.general,
        date: DateTime(2026, 11, 1),
      );
      final t = Targeting(base: base, goals: [later, sooner]);
      expect(t.governingDate, DateTime(2026, 9, 20));
    });

    test('governingDate is null when nothing is scheduled', () {
      const t = Targeting(base: _base, goals: []);
      expect(t.governingDate, isNull);
    });
  });

  group('desiredRetentionForCard (FSRS-safe interview lever)', () {
    final today = DateTime(2026, 1, 1);
    // A goal that boosts ds-a, dated relative to `today`.
    PrepGoal goalOn(DateTime date) => PrepGoal(
          id: 'g',
          tier: CompanyTier.faang,
          level: SeniorityLevel.senior,
          track: Track.general,
          date: date,
          domainWeights: const {'ds-a': 5.0},
        );

    test('no goals → the card base (its priority) unchanged', () {
      const t = Targeting(base: _base, goals: []);
      // default card priority is normal → 0.90.
      expect(t.desiredRetentionForCard(_card('ds-a'), today: today), 0.90);
    });

    test('a near-term goal on the day pushes a targeted card to the cap', () {
      final t = Targeting(base: _base, goals: [goalOn(today)]);
      expect(t.desiredRetentionForCard(_card('ds-a'), today: today),
          closeTo(Targeting.retentionCap, 1e-9));
    });

    test('the bump ramps with proximity (partway between base and cap)', () {
      final t = Targeting(
          base: _base, goals: [goalOn(today.add(const Duration(days: 10)))]);
      final r = t.desiredRetentionForCard(_card('ds-a'), today: today);
      expect(r, greaterThan(0.90));
      expect(r, lessThan(Targeting.retentionCap));
    });

    test('outside the window (too far, or past) → base, no bump', () {
      final far = Targeting(
          base: _base, goals: [goalOn(today.add(const Duration(days: 40)))]);
      final past = Targeting(
          base: _base,
          goals: [goalOn(today.subtract(const Duration(days: 1)))]);
      expect(far.desiredRetentionForCard(_card('ds-a'), today: today), 0.90);
      expect(past.desiredRetentionForCard(_card('ds-a'), today: today), 0.90);
    });

    test('a card the goal does not emphasise is not bumped', () {
      final t = Targeting(base: _base, goals: [goalOn(today)]); // boosts ds-a
      // system-design isn't boosted and the role weights it same as base.
      expect(t.desiredRetentionForCard(_card('system-design'), today: today),
          0.90);
    });

    test('never exceeds the cap and never drops below base', () {
      final t = Targeting(base: _base, goals: [goalOn(today)]);
      final r = t.desiredRetentionForCard(_card('ds-a'), today: today);
      expect(r, lessThanOrEqualTo(Targeting.retentionCap));
      expect(r, greaterThanOrEqualTo(0.90));
    });
  });
}
