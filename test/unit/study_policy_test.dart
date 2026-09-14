import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/srs/srs_scheduler.dart';
import 'package:onyx/core/subject/study_policy.dart';

void main() {
  group('resolveStudyPolicy', () {
    test('default (durable, no deadline) → 0.90 · durable · bar clamped', () {
      final p = resolveStudyPolicy();
      expect(p.desiredRetention, 0.90);
      expect(p.isCram, isFalse);
      expect(p.scheduleProfile.learningSteps, isEmpty);
      expect(p.prereqCompetenceBar, 0.7);
    });

    test('terminal goal near a deadline → cram + higher retention', () {
      final p = resolveStudyPolicy(
          permanence: GoalPermanence.terminal, daysToTarget: 5);
      expect(p.isCram, isTrue);
      expect(p.scheduleProfile.learningSteps, isNotEmpty);
      expect(p.desiredRetention, retentionCramTarget); // 0.95
    });

    test('a prerequisite flow is always durable, even under cram pressure', () {
      final p = resolveStudyPolicy(
        permanence: GoalPermanence.terminal,
        daysToTarget: 3,
        gatesDownstream: true,
      );
      expect(p.isCram, isFalse); // foundation protected from cramming
      expect(p.desiredRetention, 0.90);
    });

    test('durable goal never crams, even near a date', () {
      final p = resolveStudyPolicy(
          permanence: GoalPermanence.durable, daysToTarget: 2);
      expect(p.isCram, isFalse);
    });

    test('terminal but far out → durable', () {
      final p = resolveStudyPolicy(
          permanence: GoalPermanence.terminal, daysToTarget: 60);
      expect(p.isCram, isFalse);
    });

    test('clamps: retention to [0.80, 0.97], competence bar to [0, 1]', () {
      expect(resolveStudyPolicy(baseRetention: 0.999).desiredRetention, 0.97);
      expect(resolveStudyPolicy(baseRetention: 0.5).desiredRetention, 0.80);
      expect(resolveStudyPolicy(competenceBar: 1.5).prereqCompetenceBar, 1.0);
      expect(resolveStudyPolicy(competenceBar: -1).prereqCompetenceBar, 0.0);
    });
  });

  group('SrsScheduler learning steps (schedule-profile axis)', () {
    final at = DateTime.utc(2026, 1, 1, 9);

    // A brand-new card graded Good.
    DateTime dueFor(List<Duration> steps) =>
        SrsScheduler(learningSteps: steps).review(grade: 3, reviewedAt: at).due;

    test('durable ([]) graduates a new Good card to a spaced (>1 day) interval',
        () {
      final due = dueFor(const []);
      expect(due.difference(at).inDays, greaterThanOrEqualTo(1));
    });

    test('cram (same-day steps) keeps a new Good card due the same day', () {
      final due = dueFor(ScheduleProfile.cram.learningSteps);
      expect(due.difference(at).inHours, lessThan(24));
    });
  });
}
