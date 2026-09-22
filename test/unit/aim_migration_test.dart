import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/aim_migration.dart';
import 'package:onyx/core/goal/study_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/core/template/software_interviews.dart';

/// Phase B (B5): the legacy aim stores (base target + the old `onyx-goals.json`
/// PrepGoal array) fold into the whole-vault default StudyGoal losing nothing —
/// slots/deadline + each interview. The user's real vault has legacy data, so the
/// `legacyInterviewsFromRaw` parse (guarded here) must stay correct.
void main() {
  group('legacyInterviewsFromRaw', () {
    test('maps a legacy onyx-goals.json array into InterviewAims', () {
      // The old PrepGoal.toJson shape: tier/level/track are DROPPED (interviews
      // share the goal's slots); rounds carry over; `notes` → planNotes.
      const raw = '[{"id":"g1","companyName":"Google","tier":"faang",'
          '"level":"senior","track":"backend","active":false,'
          '"domainWeights":{"system-design":1.3},'
          '"conceptWeights":{"consistent-hashing":2.0},'
          '"outcome":"passed","outcomeNotes":"strong","notes":"plan text",'
          '"status":"offer","rounds":[{"id":"g1-r1","number":1,'
          '"type":"systemDesign","date":"2026-05-15","outcome":"passed"}]}]';
      final aims = legacyInterviewsFromRaw(raw);

      expect(aims.length, 1);
      final iv = aims.single;
      expect(iv.id, 'g1');
      expect(iv.companyName, 'Google');
      expect(iv.active, isFalse);
      expect(iv.status, InterviewStatus.offer);
      expect(iv.outcome, AimOutcome.passed);
      expect(iv.outcomeNotes, 'strong');
      expect(iv.domainWeights['system-design'], 1.3);
      expect(iv.conceptWeights['consistent-hashing'], 2.0);
      // legacy 'notes' → planNotes.
      expect(iv.planNotes, 'plan text');
      // Stored rounds carry over verbatim.
      expect(iv.rounds.single.type, InterviewRoundType.systemDesign);
      expect(iv.rounds.single.date, DateTime(2026, 5, 15));
    });

    test('synthesizes round 1 from a single date when no rounds are stored',
        () {
      const raw = '[{"id":"g2","companyName":"Amazon","date":"2026-06-01",'
          '"active":true,"status":"active"}]';
      final iv = legacyInterviewsFromRaw(raw).single;
      expect(iv.rounds.length, 1);
      expect(iv.rounds.single.id, 'g2-r1');
      expect(iv.rounds.single.number, 1);
      expect(iv.rounds.single.date, DateTime(2026, 6, 1));
    });

    test('drops entries with no id; tolerates junk / non-list', () {
      const raw = '[{"companyName":"NoId"},{"id":"","companyName":"Empty"},'
          '{"id":"ok","companyName":"Kept"}]';
      final aims = legacyInterviewsFromRaw(raw);
      expect(aims.map((a) => a.id), ['ok']);

      expect(legacyInterviewsFromRaw('not json'), isEmpty);
      expect(legacyInterviewsFromRaw('{"not":"a list"}'), isEmpty);
      expect(legacyInterviewsFromRaw(null), isEmpty);
      expect(legacyInterviewsFromRaw(''), isEmpty);
    });
  });

  group('migratedDefaultGoal', () {
    test('folds the base target + interviews into the default goal', () {
      final base = ReadinessTarget.of(
        level: SeniorityLevel.senior,
        company: CompanyTier.faang,
        track: Track.backend,
        interviewDate: DateTime(2026, 6, 1),
      );
      final interviews = legacyInterviewsFromRaw(
        '[{"id":"g1","companyName":"Google","tier":"faang","level":"senior",'
        '"track":"backend","date":"2026-05-15","active":false,'
        '"domainWeights":{"system-design":1.3},"status":"active"}]',
      );

      final goal = migratedDefaultGoal(softwareInterviewsTemplate,
          baseTarget: base, interviews: interviews);

      // Default goal carries the base target's slots + deadline (ids == enum
      // names).
      expect(goal.id, defaultGoalId);
      expect([goal.levelId, goal.contextId, goal.trackId],
          ['senior', 'faang', 'backend']);
      expect(goal.deadline, DateTime(2026, 6, 1));

      // Each legacy interview → an Aim, preserving its facets + date.
      expect(goal.interviews.length, 1);
      final iv = goal.interviews.single;
      expect(iv.companyName, 'Google');
      expect(iv.active, isFalse);
      expect(iv.domainWeights['system-design'], 1.3);
      // A single-date legacy entry materialized a synthetic round 1 (date kept).
      expect(iv.rounds.single.date, DateTime(2026, 5, 15));
    });

    test('no legacy data → a bare default goal (template fallbacks stand)', () {
      final bare = migratedDefaultGoal(softwareInterviewsTemplate);
      expect(bare.levelId, isNull);
      expect(bare.deadline, isNull);
      expect(bare.interviews, isEmpty);
    });
  });
}
