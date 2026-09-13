import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';

void main() {
  group('PrepGoal', () {
    test('label uses the company when present, else the plain target label',
        () {
      const withCompany = PrepGoal(
        id: 'g1',
        companyName: 'Google',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
      );
      expect(withCompany.label, 'Google · Senior · Backend');

      const baseline = PrepGoal(
        id: 'primary',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.general,
      );
      expect(baseline.label, 'Senior · FAANG · General');
    });

    test('toTarget() adapts to the legacy ReadinessTarget the app consumes',
        () {
      final g = PrepGoal(
        id: 'g1',
        companyName: 'Google',
        tier: CompanyTier.faang,
        level: SeniorityLevel.staff,
        track: Track.ml,
        date: DateTime(2026, 10, 1),
      );
      final t = g.toTarget();
      expect(t.level, SeniorityLevel.staff);
      expect(t.company, CompanyTier.faang);
      expect(t.track, Track.ml);
      expect(t.interviewDate, DateTime(2026, 10, 1));
    });

    test('fromTarget seeds a baseline goal (no company, default id)', () {
      final target = ReadinessTarget.of(
        level: SeniorityLevel.mid,
        company: CompanyTier.typical,
        track: Track.frontend,
      );
      final g = PrepGoal.fromTarget(target);
      expect(g.id, 'primary');
      expect(g.companyName, '');
      expect(g.tier, CompanyTier.typical);
      expect(g.level, SeniorityLevel.mid);
      expect(g.track, Track.frontend);
      expect(g.active, isTrue);
      expect(g.outcome, GoalOutcome.pending);
    });

    test('round-trips through JSON, including weights + outcome + date', () {
      final g = PrepGoal(
        id: 'g2',
        companyName: 'Netflix',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
        date: DateTime(2026, 9, 20),
        active: false,
        domainWeights: {'system-design': 1.5},
        conceptWeights: {'consistent-hashing': 2.0},
        outcome: GoalOutcome.failed,
        outcomeNotes: 'weak on scaling',
        notes: 'focus sys-design',
      );
      final back = PrepGoal.fromJson(g.toJson())!;
      expect(back.id, 'g2');
      expect(back.companyName, 'Netflix');
      expect(back.tier, CompanyTier.faang);
      expect(back.level, SeniorityLevel.senior);
      expect(back.track, Track.backend);
      expect(back.date, DateTime(2026, 9, 20));
      expect(back.active, isFalse);
      expect(back.domainWeights['system-design'], 1.5);
      expect(back.conceptWeights['consistent-hashing'], 2.0);
      expect(back.outcome, GoalOutcome.failed);
      expect(back.outcomeNotes, 'weak on scaling');
      expect(back.notes, 'focus sys-design');
    });

    test('copyWith can clear the date (sentinel) and flip active', () {
      final g = PrepGoal(
        id: 'g1',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.general,
        date: DateTime(2026, 10, 1),
      );
      expect(g.copyWith(date: null).date, isNull);
      expect(g.copyWith(active: false).active, isFalse);
      // Unspecified fields are preserved.
      expect(g.copyWith(active: false).date, DateTime(2026, 10, 1));
    });

    test('rounds round-trip through JSON, preserving order + type + outcome',
        () {
      final g = PrepGoal(
        id: 'g3',
        companyName: 'Stripe',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
        rounds: [
          InterviewRound(
            id: 'g3-r1',
            number: 1,
            type: InterviewRoundType.screen,
            date: DateTime(2026, 9, 15),
            outcome: GoalOutcome.passed,
          ),
          InterviewRound(
            id: 'g3-r2',
            number: 2,
            type: InterviewRoundType.systemDesign,
            date: DateTime(2026, 9, 25),
            notes: 'design a rate limiter',
          ),
        ],
      );
      final back = PrepGoal.fromJson(g.toJson())!;
      expect(back.rounds.length, 2);
      expect(back.rounds[0].number, 1);
      expect(back.rounds[0].type, InterviewRoundType.screen);
      expect(back.rounds[0].date, DateTime(2026, 9, 15));
      expect(back.rounds[0].outcome, GoalOutcome.passed);
      expect(back.rounds[1].type, InterviewRoundType.systemDesign);
      expect(back.rounds[1].notes, 'design a rate limiter');
    });

    test('effectiveRounds migrates a legacy single date into a synthetic r1',
        () {
      final legacy = PrepGoal(
        id: 'old',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
        date: DateTime(2026, 10, 1),
      );
      final eff = legacy.effectiveRounds;
      expect(eff.length, 1);
      expect(eff.first.number, 1);
      expect(eff.first.date, DateTime(2026, 10, 1));
      expect(legacy.roundDates, [DateTime(2026, 10, 1)]);

      // A goal with no date and no rounds has no effective rounds.
      const unscheduled = PrepGoal(
        id: 'u',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
      );
      expect(unscheduled.effectiveRounds, isEmpty);
      expect(unscheduled.roundDates, isEmpty);
    });

    test('nextRoundDate returns the soonest round on/after a reference date',
        () {
      final g = PrepGoal(
        id: 'g4',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
        rounds: [
          InterviewRound(id: 'r1', number: 1, date: DateTime(2026, 9, 10)),
          InterviewRound(id: 'r2', number: 2, date: DateTime(2026, 9, 20)),
          InterviewRound(id: 'r3', number: 3, date: DateTime(2026, 9, 30)),
        ],
      );
      expect(g.nextRoundDate(), DateTime(2026, 9, 10)); // earliest
      expect(g.nextRoundDate(DateTime(2026, 9, 15)), DateTime(2026, 9, 20));
      expect(g.nextRoundDate(DateTime(2026, 9, 20)), DateTime(2026, 9, 20));
      // Past the last round → clamps to the last.
      expect(g.nextRoundDate(DateTime(2026, 10, 5)), DateTime(2026, 9, 30));
    });

    test('normalized() resets a future-dated resolved round to pending', () {
      // The Uber bug: a round dated in the future left "passed" by an old build.
      final g = PrepGoal(
        id: 'uber',
        companyName: 'Uber',
        tier: CompanyTier.faang,
        level: SeniorityLevel.mid,
        track: Track.backend,
        rounds: [
          InterviewRound(
              id: 'uber-r1',
              number: 1,
              date: DateTime(2026, 10, 29),
              outcome: GoalOutcome.passed),
        ],
      );
      final fixed = g.normalized(DateTime(2026, 9, 10));
      expect(fixed.currentRound?.id, 'uber-r1');
      expect(fixed.currentRound?.outcome, GoalOutcome.pending);
    });

    test('normalized() leaves a past resolved round alone + is identity if ok',
        () {
      final past = PrepGoal(
        id: 'g',
        tier: CompanyTier.faang,
        level: SeniorityLevel.mid,
        track: Track.backend,
        rounds: [
          InterviewRound(
              id: 'r1',
              number: 1,
              date: DateTime(2026, 9, 1),
              outcome: GoalOutcome.passed),
        ],
      );
      final n = past.normalized(DateTime(2026, 9, 10));
      expect(n.effectiveRounds.first.outcome, GoalOutcome.passed);
      expect(identical(n, past), isTrue); // unchanged → same instance
    });

    test('encodeList / decodeList round-trip; junk decodes to empty', () {
      final goals = [
        const PrepGoal(
            id: 'a',
            tier: CompanyTier.faang,
            level: SeniorityLevel.senior,
            track: Track.general),
        const PrepGoal(
            id: 'b',
            companyName: 'Amazon',
            tier: CompanyTier.faang,
            level: SeniorityLevel.mid,
            track: Track.backend),
      ];
      final decoded = PrepGoal.decodeList(PrepGoal.encodeList(goals));
      expect(decoded.map((g) => g.id), ['a', 'b']);
      expect(PrepGoal.decodeList('not json'), isEmpty);
      expect(PrepGoal.decodeList(null), isEmpty);
    });
  });
}
