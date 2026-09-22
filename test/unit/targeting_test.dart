import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/aim.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/readiness/targeting.dart';
import 'package:onyx/shared/models/card.dart';

final _base = ReadinessTarget.of(
  level: SeniorityLevel.senior,
  company: CompanyTier.faang,
  track: Track.general,
);

Card _card(String domain, {List<String> concepts = const []}) => Card(
      id: 'c',
      type: 'flashcard',
      title: 'c',
      overview: '',
      tags: [domain],
      tiers: {domain: 1},
      sections: const [],
      wikilinks: const [],
      filePath: 'c.md',
      concepts: concepts,
    );

/// An interview scheduled on a single [date] (a synthetic round 1 carries it).
Aim _on(DateTime date, {Map<String, double> domainWeights = const {}}) => Aim(
      rounds: [InterviewRound(id: 'r', number: 1, date: date)],
      domainWeights: domainWeights,
    );

void main() {
  // The interviews replace the legacy PrepGoal list (Phase B); the weighting math
  // is unchanged — interviews share the goal's track, so their boosts add on top
  // of the base domain weight.
  group('Targeting', () {
    test('no active interviews → identical to the base target weighting', () {
      final t = Targeting(base: _base);
      expect(t.weightForDomain('ds-a'), domainWeight(_base, 'ds-a'));
      expect(t.weightForDomain('system-design'),
          domainWeight(_base, 'system-design'));
      expect(t.weightForCard(_card('ds-a')), domainWeight(_base, 'ds-a'));
      expect(t.stabilityTarget, _base.stabilityTarget);
    });

    test(
        'an active interview raises the weight of a domain it boosts (max, not sum)',
        () {
      const iv = Aim(domainWeights: {'ds-a': 5.0});
      final t = Targeting(base: _base, interviews: [iv]);
      // base ds-a weight is modest; the interview's +5 boost dominates.
      expect(t.weightForDomain('ds-a'),
          greaterThan(domainWeight(_base, 'ds-a') + 4));
      // A domain the interview doesn't touch is unchanged.
      expect(t.weightForDomain('system-design'),
          domainWeight(_base, 'system-design'));
    });

    test(
        'weightForCard adds the strongest concept boost among active interviews',
        () {
      const iv =
          Aim(conceptWeights: {'consistent-hashing': 3.0, 'irrelevant': 1.0});
      final t = Targeting(base: _base, interviews: [iv]);
      final w = t.weightForCard(
          _card('ds-a', concepts: ['consistent-hashing', 'irrelevant']));
      // domain weight + the max matching concept boost (3.0, not 1.0, not 4.0).
      expect(w, closeTo(domainWeight(_base, 'ds-a') + 3.0, 1e-9));
      // A card with no boosted concept gets just the domain weight.
      expect(t.weightForCard(_card('ds-a')), domainWeight(_base, 'ds-a'));
    });

    test('governingDate is the soonest across base + interviews', () {
      final base = _base.copyWith(interviewDate: DateTime(2026, 10, 1));
      final t = Targeting(base: base, interviews: [
        _on(DateTime(2026, 11, 1)),
        _on(DateTime(2026, 9, 20)),
      ]);
      expect(t.governingDate, DateTime(2026, 9, 20));
    });

    test('governingDate is null when nothing is scheduled', () {
      final t = Targeting(base: _base);
      expect(t.governingDate, isNull);
    });

    test('governingDate sees the soonest ROUND of a multi-round loop', () {
      final loop = Aim(rounds: [
        InterviewRound(id: 'r1', number: 1, date: DateTime(2026, 9, 25)),
        InterviewRound(id: 'r2', number: 2, date: DateTime(2026, 9, 10)),
      ]);
      final t = Targeting(base: _base, interviews: [loop]);
      expect(t.governingDate, DateTime(2026, 9, 10));
    });

    test('a roundless interview falls back to the goal deadline (new path)',
        () {
      const iv = Aim(domainWeights: {'ds-a': 5.0});
      final t = Targeting(
        base: _base,
        interviews: [iv],
        goalId: 'g',
        deadline: DateTime(2026, 9, 15),
      );
      // No rounds → the goal's deadline seeds a synthetic round-1 date.
      expect(t.governingDate, DateTime(2026, 9, 15));
    });
  });

  group('desiredRetentionForCard (FSRS-safe interview lever)', () {
    final today = DateTime(2026, 1, 1);

    test('no interviews → the card base (its priority) unchanged', () {
      final t = Targeting(base: _base);
      // default card priority is normal → 0.90.
      expect(t.desiredRetentionForCard(_card('ds-a'), today: today), 0.90);
    });

    test('a near-term interview on the day pushes a targeted card to the cap',
        () {
      final t = Targeting(base: _base, interviews: [
        _on(today, domainWeights: {'ds-a': 5.0})
      ]);
      expect(t.desiredRetentionForCard(_card('ds-a'), today: today),
          closeTo(Targeting.retentionCap, 1e-9));
    });

    test('the bump ramps with proximity (partway between base and cap)', () {
      final t = Targeting(base: _base, interviews: [
        _on(today.add(const Duration(days: 10)), domainWeights: {'ds-a': 5.0}),
      ]);
      final r = t.desiredRetentionForCard(_card('ds-a'), today: today);
      expect(r, greaterThan(0.90));
      expect(r, lessThan(Targeting.retentionCap));
    });

    test('outside the window (too far, or past) → base, no bump', () {
      final far = Targeting(base: _base, interviews: [
        _on(today.add(const Duration(days: 40)), domainWeights: {'ds-a': 5.0}),
      ]);
      final past = Targeting(base: _base, interviews: [
        _on(today.subtract(const Duration(days: 1)),
            domainWeights: {'ds-a': 5.0}),
      ]);
      expect(far.desiredRetentionForCard(_card('ds-a'), today: today), 0.90);
      expect(past.desiredRetentionForCard(_card('ds-a'), today: today), 0.90);
    });

    test('a card the interview does not emphasize is not bumped', () {
      final t = Targeting(base: _base, interviews: [
        _on(today, domainWeights: {'ds-a': 5.0})
      ]);
      // system-design isn't boosted and the role weights it same as base.
      expect(t.desiredRetentionForCard(_card('system-design'), today: today),
          0.90);
    });

    test('never exceeds the cap and never drops below base', () {
      final t = Targeting(base: _base, interviews: [
        _on(today, domainWeights: {'ds-a': 5.0})
      ]);
      final r = t.desiredRetentionForCard(_card('ds-a'), today: today);
      expect(r, lessThanOrEqualTo(Targeting.retentionCap));
      expect(r, greaterThanOrEqualTo(0.90));
    });
  });
}
