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
      const target = ReadinessTarget(
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
