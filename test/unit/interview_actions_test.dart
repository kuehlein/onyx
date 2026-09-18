import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/interview_aim.dart';
import 'package:onyx/features/interview/interview_actions.dart';

InterviewAim _active({List<InterviewRound>? rounds}) => InterviewAim(
      id: 'g',
      companyName: 'Stripe',
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
  group('currentRoundOf / pastRounds', () {
    test('current is the pending round; past are the resolved ones', () {
      final a = _active(rounds: [
        InterviewRound(
            id: 'a',
            number: 1,
            outcome: GoalOutcome.passed,
            date: DateTime(2026, 9, 1)),
        InterviewRound(id: 'b', number: 2, date: DateTime(2026, 9, 20)),
      ]);
      expect(currentRoundOf(a)?.id, 'b');
      expect(a.pastRounds('g', null).map((r) => r.id), ['a']);
    });

    test('a legacy single deadline migrates to a pending current round', () {
      // The interview holds no rounds; the parent goal's deadline seeds a
      // synthetic round 1 via effectiveRounds/currentRound.
      const a = InterviewAim(id: 'x', companyName: 'Stripe');
      expect(a.currentRound('x', DateTime(2026, 10, 1))?.date,
          DateTime(2026, 10, 1));
      expect(a.pastRounds('x', DateTime(2026, 10, 1)), isEmpty);
    });
  });

  group('passAndScheduleNext', () {
    test('marks the current round passed and adds a pending next round', () {
      final a = _active();
      final next = InterviewRound(
          id: 'g-r2',
          number: 2,
          type: InterviewRoundType.onsite,
          date: DateTime(2026, 10, 5));
      final out = passAndScheduleNext(a, next);
      expect(out.status, InterviewStatus.active);
      expect(out.pastRounds('g', null).length, 1);
      expect(out.pastRounds('g', null).first.outcome, GoalOutcome.passed);
      expect(currentRoundOf(out)?.id, 'g-r2');
      expect(currentRoundOf(out)?.type, InterviewRoundType.onsite);
    });
  });

  group('endInterview', () {
    test('rejected fails the current round and stops biasing study', () {
      final out = endInterview(_active(), InterviewStatus.rejected);
      expect(out.status, InterviewStatus.rejected);
      expect(out.active, isFalse);
      expect(out.rounds.last.outcome, GoalOutcome.failed);
      expect(currentRoundOf(out), isNull);
    });

    test('offer passes the current round', () {
      final out = endInterview(_active(), InterviewStatus.offer);
      expect(out.status, InterviewStatus.offer);
      expect(out.rounds.last.outcome, GoalOutcome.passed);
    });

    test('withdrawn leaves the round pending', () {
      final out = endInterview(_active(), InterviewStatus.withdrawn);
      expect(out.status, InterviewStatus.withdrawn);
      expect(out.active, isFalse);
      expect(out.rounds.last.outcome, GoalOutcome.pending);
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
      expect(currentRoundOf(rejected), isNull);
      final reopened = reopenInterview(rejected);
      expect(reopened.status, InterviewStatus.active);
      expect(currentRoundOf(reopened), isNotNull);
      expect(currentRoundOf(reopened)?.outcome, GoalOutcome.pending);
    });
  });

  group('rescheduleCurrentRound', () {
    test('updates the current round date + type', () {
      final out = rescheduleCurrentRound(_active(),
          date: DateTime(2026, 9, 28), type: InterviewRoundType.systemDesign);
      expect(currentRoundOf(out)?.date, DateTime(2026, 9, 28));
      expect(currentRoundOf(out)?.type, InterviewRoundType.systemDesign);
    });

    test('is a no-op once the loop has ended', () {
      final ended = endInterview(_active(), InterviewStatus.rejected);
      final out = rescheduleCurrentRound(ended,
          date: DateTime(2026, 12, 1), type: InterviewRoundType.onsite);
      expect(currentRoundOf(out), isNull);
      expect(out.status, InterviewStatus.rejected);
    });
  });
}
