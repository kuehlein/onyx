import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/goal/interview_aim.dart';
import 'package:onyx/features/interview/round_editing.dart';

InterviewAim _aim(List<InterviewRound> rounds) => InterviewAim(
      id: 'g',
      companyName: 'Stripe',
      rounds: rounds,
    );

InterviewRound _r(String id, int n, DateTime? date,
        [InterviewRoundType type = InterviewRoundType.screen]) =>
    InterviewRound(id: id, number: n, date: date, type: type);

void main() {
  group('syncedAim', () {
    test('orders by date and renumbers 1..n', () {
      final a = _aim([
        _r('a', 1, DateTime(2026, 9, 25)),
        _r('b', 2, DateTime(2026, 9, 10)),
      ]);
      final out = syncedAim(a, a.rounds);
      expect(out.rounds.map((r) => r.id), ['b', 'a']); // date order
      expect(out.rounds.map((r) => r.number), [1, 2]); // renumbered
    });

    test('undated rounds sort last', () {
      final a = _aim([
        _r('a', 1, null),
        _r('b', 2, DateTime(2026, 9, 10)),
      ]);
      final out = syncedAim(a, a.rounds);
      expect(out.rounds.map((r) => r.id), ['b', 'a']);
    });
  });

  group('aimWithRound', () {
    test('replaces an existing round by id', () {
      final a = _aim([_r('a', 1, DateTime(2026, 9, 10))]);
      final edited =
          _r('a', 1, DateTime(2026, 9, 12), InterviewRoundType.systemDesign);
      final out = aimWithRound(a, edited);
      expect(out.rounds.length, 1);
      expect(out.rounds.first.date, DateTime(2026, 9, 12));
      expect(out.rounds.first.type, InterviewRoundType.systemDesign);
    });

    test('appends a new round and re-syncs order', () {
      final a = _aim([_r('a', 1, DateTime(2026, 9, 20))]);
      final added = _r('b', 2, DateTime(2026, 9, 5));
      final out = aimWithRound(a, added);
      expect(out.rounds.map((r) => r.id), ['b', 'a']);
    });
  });

  group('aimWithoutRound', () {
    test('removes a round and re-syncs', () {
      final a = _aim([
        _r('a', 1, DateTime(2026, 9, 10)),
        _r('b', 2, DateTime(2026, 9, 20)),
      ]);
      final out = aimWithoutRound(a, 'a')!;
      expect(out.rounds.map((r) => r.id), ['b']);
      expect(out.rounds.first.number, 1);
    });

    test('returns null when the last round is removed', () {
      final a = _aim([_r('a', 1, DateTime(2026, 9, 10))]);
      expect(aimWithoutRound(a, 'a'), isNull);
    });
  });

  group('draftRound', () {
    test('numbers the next round and defaults to the generic type', () {
      final empty = _aim(const []);
      // No rounds → next is round 1.
      expect(draftRound(empty, seed: 1).number, 1);
      expect(draftRound(empty, seed: 1).type, InterviewRoundType.other);

      final one = _aim([_r('a', 1, DateTime(2026, 9, 10))]);
      final next = draftRound(one, seed: 2);
      expect(next.number, 2);
      expect(next.type, InterviewRoundType.other);
    });
  });
}
