import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/readiness/prep_goal.dart';
import 'package:onyx/core/readiness/target.dart';
import 'package:onyx/features/interview/round_editing.dart';

PrepGoal _goal(List<InterviewRound> rounds) => PrepGoal(
      id: 'g',
      companyName: 'Stripe',
      tier: CompanyTier.faang,
      level: SeniorityLevel.senior,
      track: Track.backend,
      rounds: rounds,
    );

InterviewRound _r(String id, int n, DateTime? date,
        [InterviewRoundType type = InterviewRoundType.screen]) =>
    InterviewRound(id: id, number: n, date: date, type: type);

void main() {
  group('syncedGoal', () {
    test('orders by date, renumbers 1..n, and denormalizes the earliest date',
        () {
      final g = _goal([
        _r('a', 1, DateTime(2026, 9, 25)),
        _r('b', 2, DateTime(2026, 9, 10)),
      ]);
      final out = syncedGoal(g, g.rounds);
      expect(out.rounds.map((r) => r.id), ['b', 'a']); // date order
      expect(out.rounds.map((r) => r.number), [1, 2]); // renumbered
      expect(out.date, DateTime(2026, 9, 10)); // earliest mirrored
    });

    test('undated rounds sort last', () {
      final g = _goal([
        _r('a', 1, null),
        _r('b', 2, DateTime(2026, 9, 10)),
      ]);
      final out = syncedGoal(g, g.rounds);
      expect(out.rounds.map((r) => r.id), ['b', 'a']);
      expect(out.date, DateTime(2026, 9, 10));
    });
  });

  group('goalWithRound', () {
    test('replaces an existing round by id', () {
      final g = _goal([_r('a', 1, DateTime(2026, 9, 10))]);
      final edited =
          _r('a', 1, DateTime(2026, 9, 12), InterviewRoundType.systemDesign);
      final out = goalWithRound(g, edited);
      expect(out.rounds.length, 1);
      expect(out.rounds.first.date, DateTime(2026, 9, 12));
      expect(out.rounds.first.type, InterviewRoundType.systemDesign);
    });

    test('appends a new round and re-syncs order', () {
      final g = _goal([_r('a', 1, DateTime(2026, 9, 20))]);
      final added = _r('b', 2, DateTime(2026, 9, 5));
      final out = goalWithRound(g, added);
      expect(out.rounds.map((r) => r.id), ['b', 'a']);
      expect(out.date, DateTime(2026, 9, 5));
    });
  });

  group('goalWithoutRound', () {
    test('removes a round and re-syncs', () {
      final g = _goal([
        _r('a', 1, DateTime(2026, 9, 10)),
        _r('b', 2, DateTime(2026, 9, 20)),
      ]);
      final out = goalWithoutRound(g, 'a')!;
      expect(out.rounds.map((r) => r.id), ['b']);
      expect(out.rounds.first.number, 1);
      expect(out.date, DateTime(2026, 9, 20));
    });

    test('returns null when the last round is removed', () {
      final g = _goal([_r('a', 1, DateTime(2026, 9, 10))]);
      expect(goalWithoutRound(g, 'a'), isNull);
    });
  });

  group('draftRound', () {
    test('first round defaults to screen, later rounds to onsite', () {
      final empty = _goal(const []);
      // effectiveRounds is empty (no date, no rounds) → next is round 1.
      expect(draftRound(empty, seed: 1).number, 1);
      expect(draftRound(empty, seed: 1).type, InterviewRoundType.screen);

      final one = _goal([_r('a', 1, DateTime(2026, 9, 10))]);
      final next = draftRound(one, seed: 2);
      expect(next.number, 2);
      expect(next.type, InterviewRoundType.onsite);
    });
  });
}
