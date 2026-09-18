import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/aim_migration.dart';
import 'package:onyx/core/goal/study_goal.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/subject/software_interviews.dart';

/// Phase B (B2): folding the legacy base target + interview PrepGoals into the
/// whole-vault default StudyGoal loses nothing — slots/deadline + each interview.
void main() {
  test('migratedDefaultGoal folds the base target + prep goals in', () {
    final base = ReadinessTarget.of(
      level: SeniorityLevel.senior,
      company: CompanyTier.faang,
      track: Track.backend,
      interviewDate: DateTime(2026, 6, 1),
    );
    final prep = PrepGoal(
      id: 'g1',
      companyName: 'Google',
      level: SeniorityLevel.senior,
      tier: CompanyTier.faang,
      track: Track.backend,
      date: DateTime(2026, 5, 15),
      active: false,
      domainWeights: {'system-design': 1.3},
    );

    final goal = migratedDefaultGoal(softwareInterviewsConfig,
        baseTarget: base, prepGoals: [prep]);

    // Default goal carries the base target's slots + deadline (ids == enum names).
    expect(goal.id, defaultGoalId);
    expect([goal.levelId, goal.contextId, goal.trackId],
        ['senior', 'faang', 'backend']);
    expect(goal.deadline, DateTime(2026, 6, 1));

    // Each prep goal → an InterviewAim, preserving its facets, toggle + date.
    expect(goal.interviews.length, 1);
    final iv = goal.interviews.single;
    expect(iv.companyName, 'Google');
    expect(iv.active, isFalse);
    expect(iv.domainWeights['system-design'], 1.3);
    // A single-date prep goal materializes a synthetic round 1 (date preserved).
    expect(iv.rounds.single.date, DateTime(2026, 5, 15));

    // No legacy data → a bare default goal (template fallbacks stand).
    final bare = migratedDefaultGoal(softwareInterviewsConfig);
    expect(bare.levelId, isNull);
    expect(bare.interviews, isEmpty);
  });
}
