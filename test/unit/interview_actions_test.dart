import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/features/interview/interview_actions.dart';

PrepGoal _active({List<InterviewRound>? rounds}) => PrepGoal(
      id: 'g',
      companyName: 'Stripe',
      tier: CompanyTier.faang,
      level: SeniorityLevel.senior,
      track: Track.backend,
      rounds: rounds ??
          [
            InterviewRound(
                id: 'g-r1',
                number: 1,
                type: InterviewRoundType.screen,
                date: DateTime(2026, 9, 20)),
          ],
    );

void main() {
  group('currentRound / pastRounds', () {
    test('current is the pending round; past are the resolved ones', () {
      final g = _active(rounds: [
        InterviewRound(
            id: 'a',
            number: 1,
            outcome: GoalOutcome.passed,
            date: DateTime(2026, 9, 1)),
        InterviewRound(id: 'b', number: 2, date: DateTime(2026, 9, 20)),
      ]);
      expect(g.currentRound?.id, 'b');
      expect(g.pastRounds.map((r) => r.id), ['a']);
    });

    test('a legacy single date migrates to a pending current round', () {
      final g = PrepGoal(
        id: 'x',
        tier: CompanyTier.faang,
        level: SeniorityLevel.senior,
        track: Track.backend,
        date: DateTime(2026, 10, 1),
      );
      expect(g.currentRound?.date, DateTime(2026, 10, 1));
      expect(g.pastRounds, isEmpty);
    });
  });

  group('passAndScheduleNext', () {
    test('marks the current round passed and adds a pending next round', () {
      final g = _active();
      final next = InterviewRound(
          id: 'g-r2',
          number: 2,
          type: InterviewRoundType.onsite,
          date: DateTime(2026, 10, 5));
      final out = passAndScheduleNext(g, next);
      expect(out.status, InterviewStatus.active);
      expect(out.pastRounds.length, 1);
      expect(out.pastRounds.first.outcome, GoalOutcome.passed);
      expect(out.currentRound?.id, 'g-r2');
      expect(out.currentRound?.type, InterviewRoundType.onsite);
    });
  });

  group('endInterview', () {
    test('rejected fails the current round and stops biasing study', () {
      final out = endInterview(_active(), InterviewStatus.rejected);
      expect(out.status, InterviewStatus.rejected);
      expect(out.active, isFalse);
      expect(out.effectiveRounds.last.outcome, GoalOutcome.failed);
      expect(out.currentRound, isNull);
    });

    test('offer passes the current round', () {
      final out = endInterview(_active(), InterviewStatus.offer);
      expect(out.status, InterviewStatus.offer);
      expect(out.effectiveRounds.last.outcome, GoalOutcome.passed);
    });

    test('withdrawn leaves the round pending', () {
      final out = endInterview(_active(), InterviewStatus.withdrawn);
      expect(out.status, InterviewStatus.withdrawn);
      expect(out.active, isFalse);
      expect(out.effectiveRounds.last.outcome, GoalOutcome.pending);
    });
  });

  group('archive / reopen', () {
    test('archive ends + stops study; reopen restores active', () {
      final archived = archiveInterview(_active());
      expect(archived.status, InterviewStatus.archived);
      expect(archived.active, isFalse);

      final reopened = reopenInterview(archived);
      expect(reopened.status, InterviewStatus.active);
      expect(reopened.active, isTrue);
    });

    test('reopening a rejected loop restores its round to actionable (pending)',
        () {
      // Guards the "accidentally said didn't pass, now can't edit" case.
      final rejected = endInterview(_active(), InterviewStatus.rejected);
      expect(rejected.currentRound, isNull);
      final reopened = reopenInterview(rejected);
      expect(reopened.status, InterviewStatus.active);
      expect(reopened.currentRound, isNotNull);
      expect(reopened.currentRound?.outcome, GoalOutcome.pending);
    });
  });

  group('rescheduleCurrentRound', () {
    test('updates the current round date + type', () {
      final out = rescheduleCurrentRound(_active(),
          date: DateTime(2026, 9, 28), type: InterviewRoundType.systemDesign);
      expect(out.currentRound?.date, DateTime(2026, 9, 28));
      expect(out.currentRound?.type, InterviewRoundType.systemDesign);
    });

    test('is a no-op once the loop has ended', () {
      final ended = endInterview(_active(), InterviewStatus.rejected);
      final out = rescheduleCurrentRound(ended,
          date: DateTime(2026, 12, 1), type: InterviewRoundType.onsite);
      expect(out.currentRound, isNull);
      expect(out.status, InterviewStatus.rejected);
    });
  });
}
